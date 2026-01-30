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

import 'package:genkit/genkit.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

const _streamDelimiter = '\n\n';

/// Context provider function.
typedef ContextProvider =
    FutureOr<Map<String, dynamic>> Function(Request request);

/// A wrapper object containing a flow with its associated auth policy.
class FlowWithContextProvider {
  final Flow flow;
  final ContextProvider context;

  FlowWithContextProvider({required this.flow, required this.context});
}

/// Exposes provided flow or an action as shelf handler.
Handler shelfHandler(Action action, {ContextProvider? contextProvider}) {
  return (Request request) async {
    if (request.method != 'POST') {
      return Response(405);
    }

    final queryParams = request.url.queryParameters;
    final streamParam = queryParams['stream'];
    final acceptHeader = request.headers['Accept'];
    final isStreaming =
        acceptHeader == 'text/event-stream' || streamParam == 'true';

    String bodyStr;
    try {
      bodyStr = await request.readAsString();
    } catch (e) {
      return Response(
        400,
        body: jsonEncode({
          'code': 400,
          'status': 'INVALID_ARGUMENT',
          'message': 'Failed to read request body',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    dynamic input;
    try {
      if (bodyStr.isNotEmpty) {
        final jsonBody = jsonDecode(bodyStr);
        if (jsonBody is! Map || !jsonBody.containsKey('data')) {
          return Response(
            400,
            body: jsonEncode({
              'code': 400,
              'status': 'INVALID_ARGUMENT',
              'message':
                  'Request body must be a JSON object with a "data" field.',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
        input = jsonBody['data'];
      }
      if (action.inputSchema != null && input != null) {
        input = action.inputSchema!.parse(input);
      }
    } catch (e) {
      return Response(
        400,
        body: jsonEncode({
          'code': 400,
          'status': 'INVALID_ARGUMENT',
          'message': 'Invalid input: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    Map<String, dynamic>? context;
    if (contextProvider != null) {
      try {
        context = await contextProvider(request);
      } catch (e) {
        return Response(
          403,
          body: jsonEncode({
            'code': 403,
            'status': 'PERMISSION_DENIED',
            'message': e.toString(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    if (isStreaming) {
      final controller = StreamController<List<int>>();

      void sendChunk(String prefix, Map<String, dynamic> payload) {
        final chunk = '$prefix ${jsonEncode(payload)}$_streamDelimiter';
        controller.add(utf8.encode(chunk));
      }

      // Start processing in background to feed the stream
      action
          .run(
            input,
            context: context,
            onChunk: (chunk) {
              sendChunk('data:', {'message': chunk});
            },
          )
          .then((result) {
            sendChunk('data:', {'result': result.result});
            controller.close();
          })
          .catchError((e) {
            // TODO: Map GenkitException to status/message properly
            sendChunk('error:', {
              'error': {'message': e.toString(), 'status': 'INTERNAL'},
            });
            controller.close();
          });

      return Response.ok(
        controller.stream,
        headers: {'Content-Type': 'text/plain', 'Cache-Control': 'no-cache'},
        context: {'shelf.io.buffer_output': false},
      );
    } else {
      try {
        final result = await action.run(input, context: context);
        return Response.ok(
          jsonEncode({'result': result.result}),
          headers: {
            'Content-Type': 'application/json',
            'x-genkit-trace-id': result.traceId,
            'x-genkit-span-id': result.spanId,
          },
        );
      } catch (e) {
        // TODO: Map error codes
        return Response(
          500,
          body: jsonEncode({
            'code': 500,
            'status': 'INTERNAL',
            'message': e.toString(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
  };
}

/// Starts a shelf server with the provided flows and options.
Future<HttpServer> startFlowServer({
  required List<dynamic> flows,
  int port = 3400,
  Map<String, dynamic>? cors,
}) async {
  final app = Router();

  for (final item in flows) {
    if (item is Flow) {
      app.post('/${item.name}', shelfHandler(item));
    } else if (item is FlowWithContextProvider) {
      app.post(
        '/${item.flow.name}',
        shelfHandler(item.flow, contextProvider: item.context),
      );
    }
  }

  Handler handler = app.call;
  if (cors != null) {
    handler = const Pipeline()
        .addMiddleware((innerHandler) {
          return (request) async {
            if (request.method == 'OPTIONS') {
              return Response.ok(
                '',
                headers: {
                  'Access-Control-Allow-Origin': cors['origin'] ?? '*',
                  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
                  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                },
              );
            }
            final response = await innerHandler(request);
            return response.change(
              headers: {
                'Access-Control-Allow-Origin': cors['origin'] ?? '*',
                ...response.headers,
              },
            );
          };
        })
        .addHandler(handler);
  }

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Flow server running on http://localhost:${server.port}');
  return server;
}
