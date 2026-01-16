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
import 'package:genkit/src/schema.dart';
import 'package:genkit/src/utils.dart';
import 'package:path/path.dart' as p;
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

class StatusCodes {
  // Not an error; returned on success.
  //
  // HTTP Mapping: 200 OK
  static const int ok = 0;

  // The operation was cancelled, typically by the caller.
  //
  // HTTP Mapping: 499 Client Closed Request
  static const int cancelled = 1;

  // Unknown error.  For example, this error may be returned when
  // a `Status` value received from another address space belongs to
  // an error space that is not known in this address space.  Also
  // errors raised by APIs that do not return enough error information
  // may be converted to this error.
  //
  // HTTP Mapping: 500 Internal Server Error
  static const int unknown = 2;

  // The client specified an invalid argument.  Note that this differs
  // from `FAILED_PRECONDITION`.  `INVALID_ARGUMENT` indicates arguments
  // that are problematic regardless of the state of the system
  // (e.g., a malformed file name).
  //
  // HTTP Mapping: 400 Bad Request
  static const int invalidArgument = 3;

  // The deadline expired before the operation could complete. For operations
  // that change the state of the system, this error may be returned
  // even if the operation has completed successfully.  For example, a
  // successful response from a server could have been delayed long
  // enough for the deadline to expire.
  //
  // HTTP Mapping: 504 Gateway Timeout
  static const int deadlineExceeded = 4;

  // Some requested entity (e.g., file or directory) was not found.
  //
  // Note to server developers: if a request is denied for an entire class
  // of users, such as gradual feature rollout or undocumented allowlist,
  // `NOT_FOUND` may be used. If a request is denied for some users within
  // a class of users, such as user-based access control, `PERMISSION_DENIED`
  // must be used.
  //
  // HTTP Mapping: 404 Not Found
  static const int notFound = 5;

  // The entity that a client attempted to create (e.g., file or directory)
  // already exists.
  //
  // HTTP Mapping: 409 Conflict
  static const int alreadyExists = 6;

  // The caller does not have permission to execute the specified
  // operation. `PERMISSION_DENIED` must not be used for rejections
  // caused by exhausting some resource (use `RESOURCE_EXHAUSTED`
  // instead for those errors). `PERMISSION_DENIED` must not be
  // used if the caller can not be identified (use `UNAUTHENTICATED`
  // instead for those errors). This error code does not imply the
  // request is valid or the requested entity exists or satisfies
  // other pre-conditions.
  //
  // HTTP Mapping: 403 Forbidden
  static const int permissionDenied = 7;

  // The request does not have valid authentication credentials for the
  // operation.
  //
  // HTTP Mapping: 401 Unauthorized
  static const int unauthenticated = 16;

  // Some resource has been exhausted, perhaps a per-user quota, or
  // perhaps the entire file system is out of space.
  //
  // HTTP Mapping: 429 Too Many Requests
  static const int resourceExhausted = 8;

  // The operation was rejected because the system is not in a state
  // required for the operation's execution.  For example, the directory
  // to be deleted is non-empty, an rmdir operation is applied to
  // a non-directory, etc.
  //
  // Service implementors can use the following guidelines to decide
  // between `FAILED_PRECONDITION`, `ABORTED`, and `UNAVAILABLE`:
  //  (a) Use `UNAVAILABLE` if the client can retry just the failing call.
  //  (b) Use `ABORTED` if the client should retry at a higher level. For
  //      example, when a client-specified test-and-set fails, indicating the
  //      client should restart a read-modify-write sequence.
  //  (c) Use `FAILED_PRECONDITION` if the client should not retry until
  //      the system state has been explicitly fixed. For example, if an "rmdir"
  //      fails because the directory is non-empty, `FAILED_PRECONDITION`
  //      should be returned since the client should not retry unless
  //      the files are deleted from the directory.
  //
  // HTTP Mapping: 400 Bad Request
  static const int failedPrecondition = 9;

  // The operation was aborted, typically due to a concurrency issue such as
  // a sequencer check failure or transaction abort.
  //
  // See the guidelines above for deciding between `FAILED_PRECONDITION`,
  // `ABORTED`, and `UNAVAILABLE`.
  //
  // HTTP Mapping: 409 Conflict
  static const int aborted = 10;

  // The operation was attempted past the valid range.  E.g., seeking or
  // reading past end-of-file.
  //
  // Unlike `INVALID_ARGUMENT`, this error indicates a problem that may
  // be fixed if the system state changes. For example, a 32-bit file
  // system will generate `INVALID_ARGUMENT` if asked to read at an
  // offset that is not in the range [0,2^32-1], but it will generate
  // `OUT_OF_RANGE` if asked to read from an offset past the current
  // file size.
  //
  // There is a fair bit of overlap between `FAILED_PRECONDITION` and
  // `OUT_OF_RANGE`.  We recommend using `OUT_OF_RANGE` (the more specific
  // error) when it applies so that callers who are iterating through
  // a space can easily look for an `OUT_OF_RANGE` error to detect when
  // they are done.
  //
  // HTTP Mapping: 400 Bad Request
  static const int outOfRange = 11;

  // The operation is not implemented or is not supported/enabled in this
  // service.
  //
  // HTTP Mapping: 501 Not Implemented
  static const int unimplemented = 12;

  // Internal errors.  This means that some invariants expected by the
  // underlying system have been broken.  This error code is reserved
  // for serious errors.
  //
  // HTTP Mapping: 500 Internal Server Error
  static const int internal = 13;

  // The service is currently unavailable.  This is most likely a
  // transient condition, which can be corrected by retrying with
  // a backoff. Note that it is not always safe to retry
  // non-idempotent operations.
  //
  // See the guidelines above for deciding between `FAILED_PRECONDITION`,
  // `ABORTED`, and `UNAVAILABLE`.
  //
  // HTTP Mapping: 503 Service Unavailable
  static const int unavailable = 14;

  // Unrecoverable data loss or corruption.
  //
  // HTTP Mapping: 500 Internal Server Error
  static const int dataLoss = 15;
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
        if (action.inputType != null)
          'inputSchema': toJsonSchema(type: action.inputType),
        if (action.outputType != null)
          'outputSchema': toJsonSchema(type: action.outputType),
      };
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(convertedActions))
      ..close();
  }

  Future<void> _handleRunAction(HttpRequest request) async {
    final body = jsonDecode(await utf8.decodeStream(request));
    final key = body['key'] as String;
    final input = body['input'];
    final stream = request.uri.queryParameters['stream'] == 'true';

    final parts = key.split('/');
    if (parts.length != 3 || parts[0] != '') {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Invalid action key format')
        ..close();
      return;
    }
    final action = await registry.lookupAction(parts[1], parts[2]);

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
      );
      request.response.bufferOutput = false;

      try {
        final result = await action.runRaw(
          input,
          onChunk: (chunk) {
            request.response.write('${jsonEncode(chunk)}\n');
          },
        );
        final response = RunActionResponse(
          result: result.result,
          telemetry: {'traceId': result.traceId},
        );
        request.response.write(jsonEncode(response.toJson()));
        await request.response.close();
      } catch (e, stack) {
        print('Error running action: $e\n$stack');
        final errorResponse = RunActionResponse(
          error: Status(
            code: StatusCodes.internal,
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
        print('Error running action: $e\n$stack');
        final errorResponse = Status(
          code: StatusCodes.internal,
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
        final fileContent = await file.readAsString();
        final data = jsonDecode(fileContent);
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
