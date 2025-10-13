// Copyright 2024 Google LLC
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

import 'exception.dart';

const _flowStreamDelimiter = '\n\n';

Future<O?> streamFlow<O, S>({
  required String url,
  required void Function(S chunk) onChunk,
  void Function(StreamSubscription)? onSubscription,
  void Function(void Function() cancelCallback)? setCancelCallback,
  dynamic input,
  Map<String, String>? headers,
  http.Client? httpClient,
  O Function(dynamic jsonData)? fromResponse,
  S Function(dynamic jsonData)? fromStreamChunk,
}) async {
  final responseCompleter = Completer<O?>();

  httpClient ??= http.Client();
  fromResponse ??= (json) => json;
  fromStreamChunk ??= (json) => json;

  final uri = Uri.parse(url);
  final request = http.Request('POST', uri)
    ..headers.addAll({
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    })
    ..body = jsonEncode({'data': input});

  final streamedResponse = await httpClient.send(request);

  if (streamedResponse.statusCode != 200) {
    final body = await streamedResponse.stream.bytesToString();
    throw GenkitException(
      'Server returned error: ${streamedResponse.statusCode}',
      statusCode: streamedResponse.statusCode,
      details: body,
    );
  }

  bool errorOccurred = false;

  void handleError(Object error, [StackTrace? stackTrace]) {
    if (errorOccurred) return;
    errorOccurred = true;

    final finalError = error is GenkitException
        ? error
        : GenkitException('Error in stream', underlyingException: error);

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

            if (chunkString.startsWith('error: ')) {
              final jsonString = chunkString.substring('error: '.length);
              final errorData = jsonDecode(jsonString);
              if (errorData is Map<String, dynamic> &&
                  errorData.containsKey('error')) {
                final errorContent = errorData['error'];
                final message =
                    errorContent['message'] ?? 'Unknown streaming error';
                return handleError(
                  GenkitException(message, details: jsonEncode(errorContent)),
                );
              } else {
                return handleError(
                  GenkitException(
                    errorData.toString(),
                    details: jsonEncode(errorData),
                  ),
                );
              }
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
              if (data.containsKey('result')) {
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
///   - `O`: The type of the output data from a non-streaming flow invocation,
///          or the type of the final response from a streaming flow.
///   - `S`: The type of the data chunks streamed from the flow.
///
/// Parameters:
///   - `url`: The absolute URL of the Genkit flow.
///   - `defaultHeaders`: Optional default HTTP headers to be sent with every request.
///   - `httpClient`: Optional `http.Client` instance. If not provided, a new one
///                   will be created and managed by the [RemoteAction]. If provided,
///                   the caller is responsible for its lifecycle (e.g., closing it).
///   - `fromResponse`: A function that converts the JSON-decoded response data
///                     (typically a `Map<String, dynamic>` or primitive type from `jsonDecode`)
///                     into the expected output type [O]. This is mandatory.
///   - `fromStreamChunk`: An optional function that converts the JSON-decoded stream
///                        chunk data into the expected stream type [S]. This is
///                        required if you intend to use the `.stream()` method.
///
/// Returns a [RemoteAction<O, S>] instance.
RemoteAction<O, S> defineRemoteAction<O, S>({
  required String url,
  Map<String, String>? defaultHeaders,
  http.Client? httpClient,
  required O Function(dynamic jsonData) fromResponse,
  S Function(dynamic jsonData)? fromStreamChunk,
}) {
  return RemoteAction<O, S>(
    url: url,
    defaultHeaders: defaultHeaders,
    httpClient: httpClient,
    fromResponse: fromResponse,
    fromStreamChunk: fromStreamChunk,
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
///   - `O`: The type of the output data from a non-streaming flow invocation,
///          or the type of the final response from a streaming flow.
///   - `S`: The type of the data chunks streamed from the flow.
/// {@endtemplate}
class RemoteAction<O, S> {
  final String _url;
  final Map<String, String>? _defaultHeaders;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final O Function(dynamic jsonData) _fromResponse;
  final S Function(dynamic jsonData)? _fromStreamChunk;

  /// {@macro remote_action}
  RemoteAction({
    required String url,
    Map<String, String>? defaultHeaders,
    http.Client? httpClient,
    required O Function(dynamic jsonData) fromResponse,
    S Function(dynamic jsonData)? fromStreamChunk,
  }) : _url = url,
       _defaultHeaders = defaultHeaders,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _fromResponse = fromResponse,
       _fromStreamChunk = fromStreamChunk;

  /// Invokes the remote flow.
  Future<O> call<I>({required I input, Map<String, String>? headers}) async {
    final uri = Uri.parse(_url);
    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?_defaultHeaders,
      ...?headers,
    };
    final requestBody = jsonEncode({'data': input});

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
        underlyingException: e,
        stackTrace: s,
      );
    }

    if (response.statusCode != 200) {
      throw GenkitException(
        'Server returned error: ${response.statusCode}',
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException catch (e, s) {
      throw GenkitException(
        'Failed to decode JSON response: ${e.toString()}',
        underlyingException: e,
        details: response.body,
        stackTrace: s,
      );
    }

    if (decodedBody is Map<String, dynamic>) {
      if (decodedBody.containsKey('error')) {
        final errorData = decodedBody['error'];
        final message =
            (errorData is Map<String, dynamic> &&
                errorData.containsKey('message'))
            ? errorData['message'] as String
            : errorData.toString();
        throw GenkitException(message, details: jsonEncode(errorData));
      }
      if (decodedBody.containsKey('result')) {
        return _fromResponse(decodedBody['result']);
      }
    }

    // Fallback for non-standard successful responses.
    return _fromResponse(decodedBody);
  }

  /// Invokes the remote flow and streams its response.
  ActionStream<S, O> stream<I>({
    required I input,
    Map<String, String>? headers,
  }) {
    final fromStreamChunk = _fromStreamChunk;
    if (fromStreamChunk == null) {
      final error = GenkitException(
        'fromStreamChunk must be provided for streaming operations.',
      );
      final stream = Stream<S>.error(error);
      final actionStream = ActionStream<S, O>(stream);
      actionStream._setError(error, StackTrace.current);
      return actionStream;
    }

    StreamSubscription? subscription;
    final streamController = StreamController<S>();

    final actionStream = ActionStream<S, O>(streamController.stream);

    streamFlow<O, S>(
      url: _url,
      fromResponse: _fromResponse,
      fromStreamChunk: _fromStreamChunk,
      headers: {
        if (_defaultHeaders != null) ..._defaultHeaders,
        if (headers != null) ...headers,
      },
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
      httpClient: _httpClient,
    ).then(
      (d) {
        actionStream._setResult(d as O);
        if (!streamController.isClosed) {
          streamController.close();
        }
      },
      onError: (error, st) {
        actionStream._setError(error, st);
        if (!streamController.isClosed) {
          streamController.addError(error, st);
          streamController.close();
        }
      },
    );

    return actionStream;
  }

  /// Disposes of the underlying HTTP client if it was created by this [RemoteAction].
  /// Call this when the [RemoteAction] is no longer needed to free up resources,
  /// but only if an `httpClient` was not provided at construction.
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

class ActionStream<S, F> extends StreamView<S> {
  bool _done = false;
  F? _result;
  Object? _streamError;
  StackTrace? _streamStackTrace;
  Completer<F>? _completer;

  Future<F> get onResult {
    if (_completer == null) {
      _completer = Completer<F>();
      if (_done) {
        if (_streamError != null) {
          _completer!.completeError(_streamError!, _streamStackTrace);
        } else {
          _completer!.complete(_result as F);
        }
      }
    }
    return _completer!.future;
  }

  F get result {
    if (!_done) {
      throw GenkitException('Stream not consumed yet');
    }
    if (_streamError != null) {
      throw _streamError!;
    }
    return _result as F;
  }

  void _setResult(F result) {
    _done = true;
    _result = result;
    if (_completer?.isCompleted == false) {
      _completer!.complete(result);
    }
  }

  void _setError(Object error, StackTrace st) {
    _done = true;
    _streamError = error;
    _streamStackTrace = st;
    if (_completer?.isCompleted == false) {
      _completer!.completeError(error, st);
    }
  }

  ActionStream(super.stream);
}
