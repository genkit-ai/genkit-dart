import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
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

  ReflectionServer(
    this.registry, {
    this.port = 3100,
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
            'inputSchema': action.inputType!.jsonSchema.toJson(),
          if (action.outputType != null)
            'outputSchema': action.outputType!.jsonSchema.toJson(),
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
            .runWithTelemetry(
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
        );
      } else {
        try {
          final result = await action.runWithTelemetry(input);
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
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    print('Reflection server stopped.');
  }
}
