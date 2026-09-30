// Copyright 2026 Google LLC
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

import '../core/action.dart';
import '../exception.dart';
import 'http.dart';

const _streamDelimiter = '\n\n';
const _internalErrorMessage = 'Internal server error';

/// Serves a single [action] (flow, model, tool, ...) as a framework-neutral
/// [GenkitHttpHandler].
///
/// Speaks the Genkit client protocol: POST `{"data": ..., "init": ...}`,
/// answered with `{"result": ...}`, or streamed with `?stream=true` or
/// `Accept: text/event-stream`. So `defineRemoteAction`, `defineRemoteModel`
/// and `remoteAgent` from `package:genkit/client.dart` can call it.
///
/// This is the building block for HTTP framework adapters. To serve actions
/// directly, use `GenkitRouter` or `ioHandler` instead.
///
/// [sendLegacyErrorFrame] makes a failed stream end with an
/// `error: {"error": ...}` frame instead of `data: {"error": ...}`. Only Dart
/// clients from `package:genkit` 0.17 and earlier need it: they don't
/// recognize the `data:` form and report a generic "stream finished" error
/// instead of the server's. Enable it while such clients (typically shipped
/// Flutter apps) are still in use, then remove it.
GenkitHttpHandler actionHandler(
  Action action, {
  ContextProvider? contextProvider,
  bool sendLegacyErrorFrame = false,
}) {
  return (GenkitHttpRequest request) async {
    if (request.method != 'POST') {
      return GenkitHttpResponse(
        statusCode: 405,
        headers: const {'allow': 'POST'},
      );
    }

    final isStreaming =
        request.headers['accept'] == 'text/event-stream' ||
        request.queryParameters['stream'] == 'true';

    String bodyStr;
    try {
      bodyStr = await utf8.decodeStream(request.body);
    } catch (_) {
      return _errorResponse(
        StatusCodes.INVALID_ARGUMENT,
        'Failed to read request body',
      );
    }

    Object? input;
    Object? init;
    try {
      if (bodyStr.isNotEmpty) {
        final jsonBody = jsonDecode(bodyStr);
        if (jsonBody is! Map || !jsonBody.containsKey('data')) {
          return _errorResponse(
            StatusCodes.INVALID_ARGUMENT,
            'Request body must be a JSON object with a "data" field.',
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
      return _errorResponse(StatusCodes.INVALID_ARGUMENT, 'Invalid input: $e');
    }

    Map<String, dynamic>? context;
    if (contextProvider != null) {
      try {
        context = await contextProvider(
          RequestData(
            method: request.method,
            headers: request.headers,
            input: input,
          ),
        );
      } on GenkitException catch (e) {
        return _errorResponse(e.status, e.message);
      } catch (e) {
        return _errorResponse(StatusCodes.PERMISSION_DENIED, e.toString());
      }
    }

    if (isStreaming) {
      return _runStreaming(
        action,
        input,
        init,
        context,
        sendLegacyErrorFrame: sendLegacyErrorFrame,
      );
    }
    try {
      final result = await action.run(input, context: context, init: init);
      return GenkitHttpResponse(
        statusCode: 200,
        headers: {
          'content-type': 'application/json',
          ..._traceHeaders(result.traceId, result.spanId),
        },
        body: Stream.value(utf8.encode(jsonEncode({'result': result.result}))),
      );
    } catch (e) {
      final (status, message) = _clientError(e);
      return _errorResponse(status, message);
    }
  };
}

Future<GenkitHttpResponse> _runStreaming(
  Action action,
  Object? input,
  Object? init,
  Map<String, dynamic>? context, {
  required bool sendLegacyErrorFrame,
}) async {
  final controller = StreamController<List<int>>();
  // Trace/span ids are only known once the span starts, but headers must be
  // set before the streaming response is returned. Capture them via
  // onTraceStart and await before building the response; the controller
  // buffers any chunks emitted in the meantime. Every exit path completes the
  // completer: `Action.run` can be overridden by subclasses that never call
  // onTraceStart, and awaiting it would then hang the request.
  final traceInfo = Completer<({String traceId, String spanId})>();
  void completeTraceInfoIfPending() {
    if (!traceInfo.isCompleted) {
      traceInfo.complete((traceId: '', spanId: ''));
    }
  }

  void sendChunk(String prefix, Map<String, dynamic> payload) {
    controller.add(
      utf8.encode('$prefix ${jsonEncode(payload)}$_streamDelimiter'),
    );
  }

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
        onChunk: (chunk) => sendChunk('data:', {'message': chunk}),
      )
      .then((result) {
        completeTraceInfoIfPending();
        sendChunk('data:', {'result': result.result});
        controller.close();
      })
      .catchError((Object e) {
        // Also covers an action that failed before the span started.
        completeTraceInfoIfPending();
        final (status, message) = _clientError(e);
        // `data: {"error": ...}` matches Go and Python servers and is what
        // current clients read; genkit <= 0.17 Dart clients only know the
        // `error:` prefix (see actionHandler's sendLegacyErrorFrame).
        sendChunk(sendLegacyErrorFrame ? 'error:' : 'data:', {
          'error': _errorBody(status, message),
        });
        controller.close();
      });

  final ids = await traceInfo.future;
  return GenkitHttpResponse(
    statusCode: 200,
    headers: {
      // Also keeps proxies and compression middleware from buffering it.
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache',
      ..._traceHeaders(ids.traceId, ids.spanId),
    },
    body: controller.stream,
  );
}

/// Omits blank ids: an uninstrumented run has none, and an empty header value
/// looks like a broken exporter to clients.
Map<String, String> _traceHeaders(String traceId, String spanId) => {
  if (traceId.isNotEmpty) 'x-genkit-trace-id': traceId,
  if (spanId.isNotEmpty) 'x-genkit-span-id': spanId,
};

/// Only [GenkitException] messages reach the client; anything else may carry
/// internals (credentials, provider errors), so it becomes a generic 500.
(StatusCodes, String) _clientError(Object error) => error is GenkitException
    ? (error.status, error.message)
    : (StatusCodes.INTERNAL, _internalErrorMessage);

Map<String, dynamic> _errorBody(StatusCodes status, String message) => {
  'code': status.httpStatus,
  'status': status.name,
  'message': message,
};

GenkitHttpResponse _errorResponse(StatusCodes status, String message) =>
    GenkitHttpResponse(
      statusCode: status.httpStatus,
      headers: const {'content-type': 'application/json'},
      body: Stream.value(utf8.encode(jsonEncode(_errorBody(status, message)))),
    );
