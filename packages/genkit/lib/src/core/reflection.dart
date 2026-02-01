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

import 'package:path/path.dart' as p;

import '../exception.dart';
import '../schema.dart';
import '../utils.dart';
import 'registry.dart';

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

class ReflectionServer {
  final Registry registry;
  final int port;
  final String bodyLimit;
  final List<String> configuredEnvs;
  final String? name;

  HttpServer? _server;
  String? runtimeFilePath;

  ReflectionServer(
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
    print('Reflection server running on http://localhost:${_server!.port}');

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
        print('Error handling request: $e\n$stack');
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

    if (stream) {
      request.response.headers.contentType = ContentType(
        'application',
        'x-ndjson',
        charset: 'utf-8',
      );
      request.response.bufferOutput = false;

      try {
        final result = await action.runRaw(
          input,
          onChunk: (chunk) {
            request.response.writeln(jsonEncode(chunk));
          },
        );
        final response = RunActionResponse(
          result: result.result,
          telemetry: {'traceId': result.traceId},
        );
        request.response.write(jsonEncode(response.toJson()));
        await request.response.close();
      } catch (e, stack) {
        printError(e, stack);
        final errorResponse = RunActionResponse(
          error: Status(
            code: StatusCodes.INTERNAL.value,
            message: e.toString(),
            details: {'stack': stack.toString()},
          ),
        );
        request.response.write(jsonEncode(errorResponse.toJson()));
        await request.response.close();
      }
    } else {
      try {
        final result = await action.runRaw(input);
        final response = RunActionResponse(
          result: result.result,
          telemetry: {'traceId': result.traceId},
        );
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(response.toJson()))
          ..close();
      } catch (e, stack) {
        printError(e, stack);
        final errorResponse = Status(
          code: StatusCodes.INTERNAL.value,
          message: e.toString(),
          details: {'stack': stack.toString()},
        );
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(errorResponse.toJson()))
          ..close();
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
        'id': getEnvVar('GENKIT_RUNTIME_ID') ?? _runtimeId,
        'pid': pid,
        'name': name ?? pid.toString(),
        'reflectionServerUrl': 'http://localhost:${_server!.port}',
        'timestamp': timestamp,
        'genkitVersion': 'dart/$genkitVersion',
        'reflectionApiSpecVersion': genkitReflectionApiSpecVersion,
      });
      await Directory(runtimesDir).create(recursive: true);
      await File(runtimeFilePath!).writeAsString(fileContent);
      print('Runtime file written: $runtimeFilePath');
    } catch (e) {
      print('Error writing runtime file: $e');
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
          print('Runtime file cleaned up: $runtimeFilePath');
        }
      }
    } catch (e) {
      print('Error cleaning up runtime file: $e');
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
