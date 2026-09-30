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

const _streamDelimiter = '\n\n';
const _internalErrorMessage = 'Internal server error';

final class _ShelfError {
  final int code;
  final String status;
  final String message;

  const _ShelfError({
    required this.code,
    required this.status,
    required this.message,
  });
}

_ShelfError _toShelfError(Object error) {
  if (error is GenkitException) {
    return _ShelfError(
      code: error.status.httpStatus,
      status: error.status.name,
      message: error.message,
    );
  }

  return _ShelfError(
    code: HttpStatus.internalServerError,
    status: StatusCodes.INTERNAL.name,
    message: _internalErrorMessage,
  );
}

/// Builds the action context for a request, typically from auth headers.
///
/// Throwing rejects the request with `403 PERMISSION_DENIED` before the
/// action runs.
typedef ContextProvider =
    FutureOr<Map<String, dynamic>> Function(Request request);

/// Serves a single [action] (flow, model, tool, ...) as a shelf [Handler].
///
/// Speaks the Genkit client protocol: POST `{"data": ..., "init": ...}`,
/// streaming with `?stream=true` or `Accept: text/event-stream`. Use
/// `GenkitRouter` to serve several actions at once.
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
    dynamic init;
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
        init = jsonBody['init'];
      }
      if (action.inputSchema != null && input != null) {
        input = action.inputSchema!.parse(input);
      }
      if (action.initSchema != null && init != null) {
        init = action.initSchema!.parse(init);
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
      // Trace/span ids are only known once the span starts, but headers must be
      // set before the streaming Response is returned. Capture them via
      // onTraceStart and await before building the response; the controller
      // buffers any chunks emitted in the meantime. Every exit path completes
      // the completer: `Action.run` can be overridden by subclasses that never
      // call onTraceStart, and awaiting it would then hang the request.
      final traceInfo = Completer<({String traceId, String spanId})>();
      void completeTraceInfoIfPending() {
        if (!traceInfo.isCompleted) {
          traceInfo.complete((traceId: '', spanId: ''));
        }
      }

      void sendChunk(String prefix, Map<String, dynamic> payload) {
        final chunk = '$prefix ${jsonEncode(payload)}$_streamDelimiter';
        controller.add(utf8.encode(chunk));
      }

      // Start processing in background to feed the stream
      action
          .run(
            input,
            context: context,
            init: init,
            onTraceStart: ({required traceId, required spanId}) {
              if (!traceInfo.isCompleted) {
                traceInfo.complete((traceId: traceId, spanId: spanId));
              }
            },
            onChunk: (chunk) {
              sendChunk('data:', {'message': chunk});
            },
          )
          .then((result) {
            completeTraceInfoIfPending();
            sendChunk('data:', {'result': result.result});
            controller.close();
          })
          .catchError((Object e) {
            // Also covers an action that failed before the span started.
            completeTraceInfoIfPending();
            final mapped = _toShelfError(e);
            sendChunk('error:', {
              'error': {
                'code': mapped.code,
                'status': mapped.status,
                'message': mapped.message,
              },
            });
            controller.close();
          });

      final ids = await traceInfo.future;

      return Response.ok(
        controller.stream,
        headers: {
          'Content-Type': 'text/plain',
          'Cache-Control': 'no-cache',
          // Same guard as the non-stream path: omit blank ids so an
          // uninstrumented run doesn't look like a broken exporter.
          if (ids.traceId.isNotEmpty) 'x-genkit-trace-id': ids.traceId,
          if (ids.spanId.isNotEmpty) 'x-genkit-span-id': ids.spanId,
        },
        context: {'shelf.io.buffer_output': false},
      );
    } else {
      try {
        final result = await action.run(input, context: context, init: init);

        return Response.ok(
          jsonEncode({'result': result.result}),
          headers: {
            'Content-Type': 'application/json',
            // Omit trace/span headers when uninstrumented (empty ids): a blank
            // value looks like a broken exporter to clients.
            if (result.traceId.isNotEmpty) 'x-genkit-trace-id': result.traceId,
            if (result.spanId.isNotEmpty) 'x-genkit-span-id': result.spanId,
          },
        );
      } catch (e) {
        final mapped = _toShelfError(e);
        return Response(
          mapped.code,
          body: jsonEncode({
            'code': mapped.code,
            'status': mapped.status,
            'message': mapped.message,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
  };
}
