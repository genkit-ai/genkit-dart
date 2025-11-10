import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'registry.dart';

const genkitVersion = '0.1.0';
const genkitReflectionApiSpecVersion = '1';

String _jsonSchemaWithDraft(jsb.Schema jsonSchema) {
  final schemaMap = Map<String, Object?>.from(jsonSchema.value);
  schemaMap['\$schema'] = 'http://json-schema.org/draft-07/schema#';
  return jsonEncode(schemaMap);
}

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
  static const int INTERNAL = 13;
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
  String? _runtimeFilePath;

  ReflectionServer(
    this.registry, {
    this.port = 3110,
    this.bodyLimit = '30mb',
    this.configuredEnvs = const ['dev'],
    this.name,
  });

  Future<void> start() async {
    final router = Router();

    router.get('/api/__health', (shelf.Request request) async {
      await registry.listActions();
      return shelf.Response.ok('OK');
    });

    router.post('/api/notify', (shelf.Request request) async {
      return shelf.Response.ok('OK');
    });

    router.get('/api/__quitquitquit', (shelf.Request request) async {
      final response = shelf.Response.ok('OK');
      await stop();
      return response;
    });

    router.get('/api/actions', (shelf.Request request) async {
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
            'inputSchema':
                jsonDecode(_jsonSchemaWithDraft(action.inputType!.jsonSchema)),
          if (action.outputType != null)
            'outputSchema':
                jsonDecode(_jsonSchemaWithDraft(action.outputType!.jsonSchema)),
        };
      }
      return shelf.Response.ok(
        jsonEncode(convertedActions),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/runAction', (shelf.Request request) async {
      final body = jsonDecode(await request.readAsString());
      final key = body['key'] as String;
      final input = body['input'];
      final stream = request.url.queryParameters['stream'] == 'true';

      final parts = key.split('/');
      if (parts.length != 3 || parts[0] != '') {
        return shelf.Response(404, body: 'Invalid action key format');
      }
      final action = await registry.get(parts[1], parts[2]);

      if (action == null) {
        return shelf.Response(404, body: 'action $key not found');
      }

      if (stream) {
        final controller = StreamController<List<int>>();
        void sendChunk(dynamic chunk) {
          controller.add(utf8.encode('${jsonEncode(chunk)}\n'));
        }

        action
            .run(
              input,
              onChunk: (chunk) {
                sendChunk(chunk);
              },
            )
            .then((result) {
              final response = RunActionResponse(
                result: result.result,
                telemetry: {'traceId': result.traceId},
              );
              sendChunk(response.toJson());
              controller.close();
            })
            .catchError((e, stack) {
              final errorResponse = RunActionResponse(
                error: Status(
                  code: StatusCodes.INTERNAL,
                  message: e.toString(),
                  details: {'stack': stack.toString()},
                ),
              );
              sendChunk(errorResponse.toJson());
              controller.close();
            });

        return shelf.Response.ok(
          controller.stream,
          headers: {'Content-Type': 'application/x-ndjson'},
          context: {"shelf.io.buffer_output": false},
        );
      } else {
        try {
          final result = await action.run(input);
          final response = RunActionResponse(
            result: result.result,
            telemetry: {'traceId': result.traceId},
          );
          return shelf.Response.ok(
            jsonEncode(response.toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e, stack) {
          final errorResponse = Status(
            code: StatusCodes.INTERNAL,
            message: e.toString(),
            details: {'stack': stack.toString()},
          );
          return shelf.Response.internalServerError(
            body: jsonEncode(errorResponse.toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
    });

    final handler = const shelf.Pipeline()
        .addMiddleware(
          (innerHandler) => (request) async {
            final response = await innerHandler(request);
            return response.change(
              headers: {'x-genkit-version': genkitVersion, ...response.headers},
            );
          },
        )
        .addMiddleware(shelf.logRequests())
        .addHandler(router);

    _server = await shelf_io.serve(handler, 'localhost', port);
    print('Reflection server running on http://localhost:${_server!.port}');
    await _writeRuntimeFile();
  }

  Future<void> stop() async {
    await _cleanupRuntimeFile();
    await _server?.close(force: true);
    _server = null;
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
      _runtimeFilePath =
          p.join(runtimesDir, '${_runtimeId}-${time}.json');
      final fileContent = jsonEncode({
        'id': Platform.environment['GENKIT_RUNTIME_ID'] ?? _runtimeId,
        'pid': pid,
        'name': name ?? pid.toString(),
        'reflectionServerUrl': 'http://localhost:${_server!.port}',
        'timestamp': timestamp,
        'genkitVersion': 'dart/$genkitVersion',
        'reflectionApiSpecVersion': genkitReflectionApiSpecVersion,
      });
      await Directory(runtimesDir).create(recursive: true);
      await File(_runtimeFilePath!).writeAsString(fileContent);
      print('Runtime file written: $_runtimeFilePath');
    } catch (e) {
      print('Error writing runtime file: $e');
    }
  }

  Future<void> _cleanupRuntimeFile() async {
    if (_runtimeFilePath == null) {
      return;
    }
    try {
      final file = File(_runtimeFilePath!);
      if (await file.exists()) {
        final fileContent = await file.readAsString();
        final data = jsonDecode(fileContent);
        if (data['pid'] == pid) {
          await file.delete();
          print('Runtime file cleaned up: $_runtimeFilePath');
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
