// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../exception.dart';
import '../../schema.dart';
import '../../utils.dart';
import '../registry.dart';

final _logger = Logger('genkit.reflection.v1');

const genkitVersion = '0.1.0';
const genkitReflectionApiSpecVersion = '1';

class Status {
  final int code;
  final String message;
  final Map<String, dynamic> details;

  Status({required this.code, required this.message, this.details = const {}});

  Map<String, dynamic> toJson() {
    return {'code': code, 'message': message, 'details': details};
  }
}

class RunActionResponse {
  final dynamic result;
  final Status? error;
  final Map<String, dynamic>? telemetry;

  RunActionResponse({this.result, this.error, this.telemetry});

  Map<String, dynamic> toJson() {
    return {
      if (result != null) 'result': result,
      if (error != null) 'error': error!.toJson(),
      if (telemetry != null) 'telemetry': telemetry,
    };
  }
}

class ReflectionServerV1 {
  final Registry registry;
  final int port;
  final String bodyLimit;
  final List<String> configuredEnvs;
  final String? name;

  HttpServer? _server;
  String? runtimeFilePath;

  ReflectionServerV1(
    this.registry, {
    this.port = 3110,
    this.bodyLimit = '30mb',
    this.configuredEnvs = const ['dev'],
    this.name,
  });

  Future<void> start() async {
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: true,
    );
    _logger.fine(
      'Reflection server running on http://localhost:${_server!.port}',
    );

    _server!.listen((HttpRequest request) async {
      request.response.headers.add('x-genkit-version', genkitVersion);
      try {
        if (request.method == 'GET' && request.uri.path == '/api/__health') {
          await registry.listActions();
          request.response
            ..write('OK')
            ..close();
        } else if (request.method == 'POST' &&
            request.uri.path == '/api/notify') {
          request.response
            ..write('OK')
            ..close();
        } else if (request.method == 'GET' &&
            request.uri.path == '/api/__quitquitquit') {
          request.response
            ..write('OK')
            ..close();
          await stop();
        } else if (request.method == 'GET' &&
            request.uri.path == '/api/actions') {
          await _handleActions(request);
        } else if (request.method == 'POST' &&
            request.uri.path == '/api/runAction') {
          await _handleRunAction(request);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found')
            ..close();
        }
      } catch (e, stack) {
        _logger.severe('Error handling request: $e\n$stack');
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Internal Server Error')
          ..close();
      }
    });

    await _writeRuntimeFile();
  }

  Future<void> _handleActions(HttpRequest request) async {
    final actions = await registry.listActions();
    final convertedActions = <String, dynamic>{};
    for (final action in actions) {
      final key = getKey(action.actionType, action.name);
      convertedActions[key] = {
        'key': key,
        'name': action.name,
        'description': action.metadata['description'],
        'metadata': action.metadata,
        if (action.inputSchema != null)
          'inputSchema': toJsonSchema(type: action.inputSchema),
        if (action.outputSchema != null)
          'outputSchema': toJsonSchema(type: action.outputSchema),
      };
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(convertedActions))
      ..close();
  }

  Future<void> _handleRunAction(HttpRequest request) async {
    final body = await _jsonDecodeStream(request);
    final key = body['key'] as String;
    final input = body['input'];
    final stream = request.uri.queryParameters['stream'] == 'true';

    final parts = key.split('/');
    if (parts.length < 3 || parts[0] != '') {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Invalid action key format')
        ..close();
      return;
    }
    final action = await registry.lookupAction(
      parts[1],
      parts.sublist(2).join('/'),
    );

    if (action == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('action $key not found')
        ..close();
      return;
    }

    var headersFlushed = false;

    void onTraceStart({required String traceId, required String spanId}) {
      if (headersFlushed) return;
      try {
        request.response.headers.add('x-genkit-trace-id', traceId);
        request.response.headers.add('x-genkit-span-id', spanId);
        request.response.headers.add('x-genkit-version', genkitVersion);
        // Force headers to be sent immediately
        request.response.headers.chunkedTransferEncoding = true;
        // Disable buffering so the write triggers a flush immediately
        request.response.bufferOutput = false;
        // Write a whitespace character to trigger header flush.
        // This is valid leading whitespace for both JSON and NDJSON.
        request.response.write(' ');
        // Do NOT call flush() as we cannot await it and it blocks future writes
        headersFlushed = true;
      } catch (e) {
        _logger.warning('Failed to set trace headers: $e');
      }
    }

    if (stream) {
      request.response.headers.contentType = ContentType(
        'application',
        'x-ndjson',
        charset: 'utf-8',
      );
      // bufferOutput is set to false in onTraceStart if called,
      // or we can set it here too to be safe/explicit for streaming.
      request.response.bufferOutput = false;

      try {
        final result = await action.runRaw(
          input,
          onChunk: (chunk) {
            request.response.writeln(jsonEncode(chunk));
          },
          onTraceStart: onTraceStart,
        );
        final response = RunActionResponse(
          result: result.result,
          telemetry: {'traceId': result.traceId},
        );
        request.response.write(jsonEncode(response.toJson()));
        await request.response.close();
      } catch (e, stack) {
        _logger.severe('Error running action: $e', stack);
        final errorResponse = RunActionResponse(
          error: Status(
            code: StatusCodes.INTERNAL.value,
            message: e.toString(),
            details: {'stack': stack.toString()},
          ),
        );
        if (!headersFlushed) {
          request.response.statusCode = HttpStatus.internalServerError;
          // For streaming, we already set content type to x-ndjson
        }
        request.response.write(jsonEncode(errorResponse.toJson()));
        await request.response.close();
      }
    } else {
      try {
        // Set contentType early as onTraceStart will flush headers
        request.response.headers.contentType = ContentType.json;
        final result = await action.runRaw(input, onTraceStart: onTraceStart);
        final response = RunActionResponse(
          result: result.result,
          telemetry: {'traceId': result.traceId},
        );
        request.response.write(jsonEncode(response.toJson()));
        await request.response.close();
      } catch (e, stack) {
        _logger.severe('Error running action: $e', stack);
        final errorResponse = Status(
          code: StatusCodes.INTERNAL.value,
          message: e.toString(),
          details: {'stack': stack.toString()},
        );
        if (!headersFlushed) {
          request.response.statusCode = HttpStatus.internalServerError;
          // contentType is already set to JSON
        }
        request.response.write(jsonEncode({'error': errorResponse.toJson()}));
        await request.response.close();
      }
    }
  }

  Future<void> stop() async {
    await _cleanupRuntimeFile();
    await _server?.close(force: true);
    _server = null;
    runtimeFilePath = null;
    print('Reflection server stopped.');
  }

  int get actualPort => _server?.port ?? 0;

  String get _runtimeId => '$pid${_server != null ? '-${_server!.port}' : ''}';

  Future<void> _writeRuntimeFile() async {
    try {
      final rootDir = await _findProjectRoot();
      if (rootDir == null) {
        print('Could not find project root (pubspec.yaml not found)');
        return;
      }
      final runtimesDir = p.join(rootDir, '.genkit', 'runtimes');
      final date = DateTime.now();
      final time = date.millisecondsSinceEpoch;
      final timestamp = date.toIso8601String();
      runtimeFilePath = p.join(runtimesDir, '$_runtimeId-$time.json');
      final fileContent = jsonEncode({
        'id': getConfigVar('GENKIT_RUNTIME_ID') ?? _runtimeId,
        'pid': pid,
        'name': name ?? pid.toString(),
        'reflectionServerUrl': 'http://localhost:${_server!.port}',
        'timestamp': timestamp,
        'genkitVersion': 'dart/$genkitVersion',
        'reflectionApiSpecVersion': genkitReflectionApiSpecVersion,
      });
      await Directory(runtimesDir).create(recursive: true);
      await File(runtimeFilePath!).writeAsString(fileContent);
      _logger.fine('Runtime file written: $runtimeFilePath');
    } catch (e) {
      _logger.severe('Error writing runtime file: $e');
    }
  }

  Future<void> _cleanupRuntimeFile() async {
    if (runtimeFilePath == null) {
      return;
    }
    try {
      final file = File(runtimeFilePath!);
      if (await file.exists()) {
        final data = await _jsonDecodeStream(file.openRead());
        if (data['pid'] == pid) {
          await file.delete();
          _logger.fine('Runtime file cleaned up: $runtimeFilePath');
        }
      }
    } catch (e) {
      _logger.severe('Error cleaning up runtime file: $e');
    }
  }
}

Future<String?> _findProjectRoot() async {
  var current = Directory.current.path;
  while (current != p.dirname(current)) {
    final pubspecPath = p.join(current, 'pubspec.yaml');
    if (await File(pubspecPath).exists()) {
      return current;
    }
    current = p.dirname(current);
  }
  return null;
}

Future<Map<String, dynamic>> _jsonDecodeStream(Stream<List<int>> stream) async {
  return await _jsonStreamDecoder.bind(stream).single as Map<String, dynamic>;
}

final _jsonStreamDecoder = utf8.decoder.fuse(json.decoder);
