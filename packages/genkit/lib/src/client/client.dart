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

import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';

import '../core/action.dart';
import '../exception.dart';

const _flowStreamDelimiter = '\n\n';

/// Builds a [GenkitException] from a Genkit error body, keeping the server's
/// status and message.
///
/// Accepts the bare shape (`{code, status, message}`, the non-200 body sent by
/// GenkitRouter) and the wrapped one (`{error: {...}}`). [httpStatus] is only
/// a fallback for bodies without a recognizable status (a proxy's HTML page,
/// say): the HTTP mapping is lossy, e.g. both `FAILED_PRECONDITION` and
/// `INVALID_ARGUMENT` are sent as 400.
///
/// [details] defaults to [body] (encoded as JSON unless it is a string).
GenkitException _wireError(
  Object? body, {
  int? httpStatus,
  required String fallbackMessage,
  String? details,
}) {
  var error = body;
  if (error is Map && error['error'] is Map) {
    error = error['error'];
  }

  String? wireName;
  String? message;
  if (error is Map) {
    if (error['status'] case final String s) wireName = s;
    if (error['message'] case final String m when m.isNotEmpty) message = m;
  }

  var status = wireName == null ? null : StatusCode.fromWireName(wireName);
  // fromWireName maps unrecognized names (a newer server's, or JS express's
  // 'INVALID ARGUMENT') to UNKNOWN. Prefer the HTTP-derived status when there
  // is one, unless the server really sent UNKNOWN.
  final recognized =
      status != null && (status != StatusCode.unknown || wireName == 'UNKNOWN');
  if (!recognized && httpStatus != null) {
    status = StatusCode.fromHttpStatus(httpStatus);
  }

  return GenkitException(
    message ?? fallbackMessage,
    // Null (no status at all) falls back to GenkitException's default
    // (`internal`).
    status: status,
    details:
        details ??
        (body == null ? null : (body is String ? body : jsonEncode(body))),
  );
}

/// Like [_wireError], for a raw non-200 response body.
///
/// Only a JSON body is read for status and message. Anything else (a proxy's
/// HTML page, the Go server's plain-text errors) gets the HTTP-derived status
/// and a generic message; the raw body is always kept in `details`.
GenkitException _httpError(int statusCode, String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    // Not JSON; leave `decoded` null so only the HTTP status is used.
  }
  return _wireError(
    decoded,
    httpStatus: statusCode,
    fallbackMessage: 'Server returned error: $statusCode',
    details: body.isEmpty ? null : body,
  );
}

/// Maps the `error` payload of a response or stream frame to a
/// [GenkitException]. A plain string payload is used as the message.
GenkitException _errorPayload(Object? error, String fallbackMessage) =>
    _wireError(
      error,
      fallbackMessage: error is String && error.isNotEmpty
          ? error
          : fallbackMessage,
    );

/// Maps the `error` payload of a streamed error frame to a [GenkitException].
GenkitException _streamError(Object? error) =>
    _errorPayload(error, 'Unknown streaming error');

Future<Output?> streamFlow<Output, Chunk>({
  required String url,
  required void Function(Chunk chunk) onChunk,
  void Function(StreamSubscription)? onSubscription,
  void Function(void Function() cancelCallback)? setCancelCallback,
  dynamic input,
  dynamic init,
  Map<String, String>? headers,
  http.Client? httpClient,
  Output Function(dynamic jsonData)? fromResponse,
  Chunk Function(dynamic jsonData)? fromStreamChunk,
}) async {
  final responseCompleter = Completer<Output?>();

  httpClient ??= http.Client();
  fromResponse ??= (json) => json as Output;
  fromStreamChunk ??= (json) => json as Chunk;

  final uri = Uri.parse(url);
  final request = http.Request('POST', uri)
    ..headers.addAll({
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
      ...?headers,
    })
    ..body = jsonEncode({'data': input, 'init': ?init});

  final streamedResponse = await httpClient.send(request);

  if (streamedResponse.statusCode != 200) {
    final body = await streamedResponse.stream.bytesToString();
    throw _httpError(streamedResponse.statusCode, body);
  }

  var errorOccurred = false;

  void handleError(Object error, [StackTrace? stackTrace]) {
    if (errorOccurred) return;
    errorOccurred = true;

    final finalError = error is GenkitException
        ? error
        : GenkitException(
            // The cause text goes in the message too: callers such as the
            // agent client surface only `message`.
            'Error in stream: $error',
            cause: error,
            stackTrace: stackTrace,
          );

    if (!responseCompleter.isCompleted) {
      responseCompleter.completeError(finalError, stackTrace);
    }
  }

  var buffer = '';
  final subscription = streamedResponse.stream
      .transform(utf8.decoder)
      .listen(
        (chunk) {
          buffer += chunk;
          while (buffer.contains(_flowStreamDelimiter)) {
            final endOfChunk = buffer.indexOf(_flowStreamDelimiter);
            final chunkString = buffer.substring(0, endOfChunk).trim();
            buffer = buffer.substring(endOfChunk + _flowStreamDelimiter.length);

            if (chunkString.isEmpty) continue;

            // Stream errors arrive as `data: {"error": ...}` (handled below,
            // as Go, Python and current Dart servers send). The legacy
            // `error: ...` frame comes from JS servers and Dart servers with
            // `sendLegacyErrorFrame` set. JS express wraps the payload
            // (`{"error": {...}}`); the JS Next.js plugin doesn't
            // (`{status, message}`).
            if (chunkString.startsWith('error: ')) {
              final jsonString = chunkString.substring('error: '.length);
              final errorData = jsonDecode(jsonString);
              return handleError(
                _streamError(
                  errorData is Map && errorData.containsKey('error')
                      ? errorData['error']
                      : errorData,
                ),
              );
            }

            if (!chunkString.startsWith('data: ')) {
              return handleError(
                FormatException('Invalid SSE data chunk', chunkString),
              );
            }

            final jsonString = chunkString.substring('data: '.length);
            if (jsonString.isEmpty) continue;

            final data = jsonDecode(jsonString);
            if (data is Map<String, dynamic>) {
              // Only the frame's top-level key counts: user payloads sit under
              // `message`/`result`, so an `error` field in them is plain data.
              if (data.containsKey('error')) {
                return handleError(_streamError(data['error']));
              } else if (data.containsKey('result')) {
                if (!responseCompleter.isCompleted) {
                  responseCompleter.complete(fromResponse!(data['result']));
                }
              } else if (data.containsKey('message')) {
                onChunk(fromStreamChunk!(data['message']));
              }
            }
          }
        },
        onError: handleError,
        onDone: () {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(
              GenkitException('Stream finished without a final result chunk.'),
            );
          }
        },
        cancelOnError: true,
      );
  onSubscription?.call(subscription);
  setCancelCallback?.call(() {
    if (!responseCompleter.isCompleted) {
      responseCompleter.completeError(
        GenkitException('Stream cancelled by client.'),
      );
    }
  });

  return responseCompleter.future;
}

/// Defines a remote Genkit action (flow) client.
///
/// This function returns a [RemoteAction] instance, which can be used to call
/// or stream the specified Genkit flow. It simplifies the process of setting up
/// a flow client by allowing direct specification of data conversion functions.
///
/// Type parameters:
///   - `Output`: The type of the output data from a non-streaming flow invocation,
///          or the type of the final response from a streaming flow.
///   - `Chunk`: The type of the data chunks streamed from the flow.
///
/// Parameters:
///   - `url`: The absolute URL of the Genkit flow.
///   - `defaultHeaders`: Optional default HTTP headers to be sent with every request.
///   - `httpClient`: Optional `http.Client` instance. If not provided, a new one
///                   will be created and managed by the [RemoteAction]. If provided,
///                   the caller is responsible for its lifecycle (e.g., closing it).
///   - `fromResponse`: An optional function that converts the JSON-decoded response data
///                     (typically a `Map<String, dynamic>` or primitive type from `jsonDecode`)
///                     into the expected output type [Output]. If not provided, the
///                     result is a `dynamic` object from `jsonDecode`.
///   - `fromStreamChunk`: An optional function that converts the JSON-decoded stream
///                        chunk data into the expected stream type [Chunk]. If not
///                        provided, chunks are `dynamic` objects from `jsonDecode`.
///
/// Returns a [RemoteAction<Output, Chunk>] instance.
RemoteAction<Input, Output, Chunk, Init>
defineRemoteAction<Input, Output, Chunk, Init>({
  required String url,
  Map<String, String>? defaultHeaders,
  http.Client? httpClient,
  Output Function(dynamic jsonData)? fromResponse,
  Chunk Function(dynamic jsonData)? fromStreamChunk,
  SchemanticType<Input>? inputSchema,
  SchemanticType<Output>? outputSchema,
  SchemanticType<Chunk>? streamSchema,
}) {
  if (fromResponse != null && outputSchema != null) {
    throw ArgumentError(
      'Cannot provide both fromResponse and outputSchema. Please provide only one.',
    );
  }
  if (fromStreamChunk != null && streamSchema != null) {
    throw ArgumentError(
      'Cannot provide both fromStreamChunk and streamSchema. Please provide only one.',
    );
  }

  return RemoteAction<Input, Output, Chunk, Init>(
    url: url,
    defaultHeaders: defaultHeaders,
    httpClient: httpClient,
    fromResponse:
        fromResponse ??
        (outputSchema != null
            ? (d) => outputSchema.parse(d)
            : (d) => d as Output),
    fromStreamChunk:
        fromStreamChunk ??
        (streamSchema != null
            ? (d) => streamSchema.parse(d)
            : (d) => d as Chunk),
  );
}

/// {@template remote_action}
/// Represents a remote Genkit action (flow) that can be invoked or streamed.
///
/// This class is typically instantiated via [defineRemoteAction].
/// It encapsulates the URL, default headers, HTTP client, and data conversion logic
/// for a specific flow.
///
/// Type parameters:
///   - `Output`: The type of the output data from a non-streaming flow invocation,
///          or the type of the final response from a streaming flow.
///   - `Chunk`: The type of the data chunks streamed from the flow.
/// {@endtemplate}
interface class RemoteAction<Input, Output, Chunk, Init> {
  final String _url;
  final Map<String, String>? _defaultHeaders;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Output Function(dynamic jsonData) _fromResponse;
  final Chunk Function(dynamic jsonData)? _fromStreamChunk;

  /// {@macro remote_action}
  RemoteAction({
    required this._url,
    this._defaultHeaders,
    http.Client? httpClient,
    required this._fromResponse,
    required this._fromStreamChunk,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  /// Invokes the remote flow.
  Future<Output> call({
    required Input input,
    Init? init,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(_url);
    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?_defaultHeaders,
      ...?headers,
    };
    final requestBody = jsonEncode({'data': input, 'init': ?init});

    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: requestHeaders,
        body: requestBody,
      );
    } catch (e, s) {
      throw GenkitException(
        'HTTP request failed: ${e.toString()}',
        cause: e,
        stackTrace: s,
      );
    }

    if (response.statusCode != 200) {
      throw _httpError(response.statusCode, response.body);
    }

    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException catch (e, s) {
      throw GenkitException(
        'Failed to decode JSON response: ${e.toString()}',
        cause: e,
        details: response.body,
        stackTrace: s,
      );
    }

    if (decodedBody is Map<String, dynamic>) {
      if (decodedBody.containsKey('error')) {
        final errorData = decodedBody['error'];
        throw _errorPayload(errorData, 'Unknown server error');
      }
      if (decodedBody.containsKey('result')) {
        return _fromResponse(decodedBody['result']);
      }
    }

    // Fallback for non-standard successful responses.
    return _fromResponse(decodedBody);
  }

  /// Invokes the remote flow and streams its response.
  ActionStream<Chunk, Output> stream({
    required Input input,
    Init? init,
    Map<String, String>? headers,
  }) {
    final fromStreamChunk = _fromStreamChunk;
    if (fromStreamChunk == null) {
      final error = GenkitException(
        'fromStreamChunk must be provided for streaming operations.',
      );
      final stream = Stream<Chunk>.error(error);
      final actionStream = ActionStream<Chunk, Output>(stream);
      actionStream.setError(error, StackTrace.current);
      return actionStream;
    }

    StreamSubscription? subscription;
    final streamController = StreamController<Chunk>();

    final actionStream = ActionStream<Chunk, Output>(streamController.stream);

    streamFlow<Output, Chunk>(
      url: _url,
      fromResponse: _fromResponse,
      fromStreamChunk: _fromStreamChunk,
      headers: {...?_defaultHeaders, ...?headers},
      onChunk: (chunk) {
        if (streamController.isClosed) return;
        streamController.add(chunk);
      },
      onSubscription: (sub) => subscription = sub,
      setCancelCallback: (cancelCallback) {
        streamController.onCancel = () {
          cancelCallback();
          subscription?.cancel();
        };
      },
      input: input,
      init: init,
      httpClient: _httpClient,
    ).then(
      (d) {
        actionStream.setResult(d as Output);
        if (!streamController.isClosed) {
          streamController.close();
        }
      },
      onError: (Object error, StackTrace st) {
        actionStream.setError(error, st);
        if (!streamController.isClosed) {
          streamController.addError(error, st);
          streamController.close();
        }
      },
    );

    return actionStream;
  }

  /// Closes the underlying HTTP client if this [RemoteAction] created it.
  ///
  /// A caller-provided `httpClient` is left open; its owner closes it.
  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
