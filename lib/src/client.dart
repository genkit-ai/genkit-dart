import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'exception.dart';
import 'flow_response.dart';

/// {@template remote_action}
/// Represents a remote Genkit action (flow) that can be invoked or streamed.
///
/// This class is typically instantiated via [defineRemoteAction].
/// It encapsulates the URL, default headers, HTTP client, and data conversion logic
/// for a specific flow.
///
/// Type parameters for methods:
///   - `I`: The type of the input data for the flow (inferred at call/stream time).
///   - `O`: The type of the output data from a non-streaming flow invocation,
///          or the type of the final response from a streaming flow (defined by fromResponse).
///   - `S`: The type of the data chunks streamed from the flow (defined by fromStreamChunk).
/// {@endtemplate}
class RemoteAction<O, S> {
  final String _url;
  final Map<String, String>? _defaultHeaders;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final O Function(dynamic jsonData) _fromResponseData;
  final S Function(dynamic jsonData)? _fromStreamChunkData;

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
       _fromResponseData = fromResponse,
       _fromStreamChunkData = fromStreamChunk;

  Future<dynamic> _runInternal<I>({
    required I input,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(_url);
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
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
        'HTTP request failed in RemoteAction._runInternal',
        underlyingException: e,
        stackTrace: s,
      );
    }

    if (response.statusCode != 200) {
      dynamic errorDetailsJson;
      try {
        errorDetailsJson = jsonDecode(response.body);
      } catch (_) {
        errorDetailsJson = response.body;
      }
      String message =
          'Server returned error (${response.statusCode}) in RemoteAction._runInternal';
      if (errorDetailsJson is Map<String, dynamic> &&
          errorDetailsJson.containsKey('error')) {
        final errorContent = errorDetailsJson['error'];
        if (errorContent is Map<String, dynamic> &&
            errorContent.containsKey('message')) {
          message = errorContent['message'] as String? ?? message;
        } else if (errorContent is String) {
          message = errorContent;
        }
      }
      throw GenkitException(
        message,
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    final dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException catch (e, s) {
      throw GenkitException(
        'Failed to decode JSON response body in RemoteAction._runInternal',
        underlyingException: e,
        details: response.body,
        stackTrace: s,
      );
    }

    if (decodedBody is Map<String, dynamic>) {
      if (decodedBody.containsKey('error')) {
        final errorData = decodedBody['error'];
        String errorMessage =
            'Flow returned an error object (HTTP 200 OK) in RemoteAction._runInternal';
        if (errorData is String) {
          errorMessage = errorData;
        } else if (errorData is Map<String, dynamic> &&
            errorData.containsKey('message') &&
            errorData['message'] is String) {
          errorMessage = errorData['message'] as String;
        }
        throw GenkitException(errorMessage, details: jsonEncode(errorData));
      }

      if (decodedBody.containsKey('result')) {
        return decodedBody['result'];
      }

      throw GenkitException(
        'Invalid response format (HTTP 200 OK, missing \'result\' or \'error\') in RemoteAction._runInternal.',
        details: response.body,
      );
    } else {
      return decodedBody;
    }
  }

  FlowStreamResponse<dynamic, dynamic> _streamInternal<I>({
    required I input,
    Map<String, String>? headers,
  }) {
    final streamController = StreamController<dynamic>();
    final responseCompleter = Completer<dynamic>();

    Future<void> performStreamSetupAndListen() async {
      http.StreamedResponse? streamedResponse;
      StreamSubscription? subscription;

      streamController.onCancel = () async {
        if (subscription != null) {
          await subscription.cancel();
        }
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(
            GenkitException(
              'Stream operation cancelled by user in RemoteAction._streamInternal.',
              stackTrace: StackTrace.current,
            ),
          );
        }
        if (!streamController.isClosed) {
          await streamController.close();
        }
      };

      try {
        final uri = Uri.parse(_url);
        final request = http.Request('POST', uri);

        request.headers['Accept'] = 'text/event-stream';
        request.headers['Content-Type'] = 'application/json';
        if (headers != null) {
          request.headers.addAll(headers);
        }
        request.body = jsonEncode({'data': input});

        try {
          streamedResponse = await _httpClient.send(request);
        } catch (e, s) {
          final err = GenkitException(
            'Failed to send streaming request in RemoteAction._streamInternal',
            underlyingException: e,
            stackTrace: s,
          );
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(err, s);
          }
          if (!streamController.isClosed) {
            streamController.addError(err, s);
            await streamController.close();
          }
          return;
        }

        if (streamedResponse.statusCode != 200) {
          final responseBody = await streamedResponse.stream.bytesToString();
          final exception = GenkitException(
            'Server returned error (${streamedResponse.statusCode}) in RemoteAction._streamInternal setup',
            statusCode: streamedResponse.statusCode,
            details: responseBody,
          );
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(exception);
          }
          if (!streamController.isClosed) {
            streamController.addError(exception);
            await streamController.close();
          }
          return;
        }

        var buffer = '';
        subscription = streamedResponse.stream
            .transform(utf8.decoder)
            .listen(
              (decodedChunk) async {
                buffer += decodedChunk;
                while (buffer.contains(flowStreamDelimiter)) {
                  final endOfChunk = buffer.indexOf(flowStreamDelimiter);
                  final chunkData = buffer.substring(0, endOfChunk);
                  buffer = buffer.substring(
                    endOfChunk + flowStreamDelimiter.length,
                  );

                  if (!chunkData.startsWith(sseDataPrefix)) {
                    continue;
                  }
                  final jsonData = chunkData.substring(sseDataPrefix.length);
                  if (jsonData.isEmpty) continue;

                  try {
                    final parsedJson = jsonDecode(jsonData);
                    if (parsedJson is Map<String, dynamic>) {
                      if (parsedJson.containsKey('message')) {
                        if (!streamController.isClosed) {
                          streamController.add(parsedJson['message']);
                        }
                      } else if (parsedJson.containsKey('result')) {
                        if (!responseCompleter.isCompleted) {
                          responseCompleter.complete(parsedJson['result']);
                        }
                      } else if (parsedJson.containsKey('error')) {
                        final errorData = parsedJson['error'];
                        String errorMessage =
                            'Unknown streaming error format in RemoteAction._streamInternal';
                        if (errorData is Map<String, dynamic>) {
                          errorMessage =
                              errorData['message'] as String? ?? errorMessage;
                        } else if (errorData is String) {
                          errorMessage = errorData;
                        }
                        final exception = GenkitException(
                          errorMessage,
                          details: jsonEncode(errorData),
                        );
                        if (!responseCompleter.isCompleted) {
                          responseCompleter.completeError(exception);
                        }
                        if (!streamController.isClosed) {
                          streamController.addError(exception);
                          if (subscription != null) {
                            await subscription.cancel();
                          }
                          buffer = '';
                          if (!streamController.isClosed) {
                            await streamController.close();
                          }
                        }
                        return;
                      }
                    } else {
                      if (!streamController.isClosed) {
                        streamController.add(parsedJson);
                      }
                    }
                  } on FormatException catch (e, s) {
                    final err = GenkitException(
                      'Failed to decode JSON chunk from stream in RemoteAction._streamInternal',
                      underlyingException: e,
                      details: jsonData,
                      stackTrace: s,
                    );
                    if (!streamController.isClosed) {
                      streamController.addError(err, s);
                    }
                  } catch (e, s) {
                    final err = GenkitException(
                      'Error processing stream chunk in RemoteAction._streamInternal',
                      underlyingException: e,
                      details: jsonData,
                      stackTrace: s,
                    );
                    if (!streamController.isClosed) {
                      streamController.addError(err, s);
                    }
                  }
                }
              },
              onError: (error, stackTrace) async {
                final err = GenkitException(
                  'Error from HTTP stream in RemoteAction._streamInternal',
                  underlyingException: error,
                  stackTrace: stackTrace,
                );
                if (!responseCompleter.isCompleted) {
                  responseCompleter.completeError(err, stackTrace);
                }
                if (!streamController.isClosed) {
                  streamController.addError(err, stackTrace);
                  await streamController.close();
                }
              },
              onDone: () async {
                if (buffer.isNotEmpty &&
                    !streamController.isClosed &&
                    !responseCompleter.isCompleted) {
                  final err = GenkitException(
                    'Stream ended with unprocessed data in buffer in RemoteAction._streamInternal',
                    details: buffer,
                  );
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.completeError(err);
                  }
                  if (!streamController.isClosed) {
                    streamController.addError(err);
                  }
                } else if (!responseCompleter.isCompleted &&
                    !streamController.isClosed &&
                    (streamController.hasListener ||
                        !streamController.isPaused)) {
                  responseCompleter.completeError(
                    GenkitException(
                      'Stream finished without a final result or error chunk in RemoteAction._streamInternal.',
                    ),
                  );
                }
                if (!streamController.isClosed) await streamController.close();
              },
              cancelOnError: true,
            );
      } catch (e, s) {
        final err = GenkitException(
          'Failed to setup streaming request in RemoteAction._streamInternal (outer catch)',
          underlyingException: e,
          stackTrace: s,
        );
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(err, s);
        }
        if (!streamController.isClosed) {
          streamController.addError(err, s);
          await streamController.close();
        }
      } finally {
        Future.wait([
          responseCompleter.future.catchError((_) => <String, dynamic>{}),
          streamController.done.catchError((_) {}),
        ]).ignore();
      }
    }

    performStreamSetupAndListen();
    return (
      stream: streamController.stream,
      response: responseCompleter.future,
    );
  }

  /// Invokes the remote flow.
  Future<O> call<I>({required I input, Map<String, String>? headers}) async {
    final dynamic requestPayload = input;

    final combinedHeaders = {
      if (_defaultHeaders != null) ..._defaultHeaders,
      if (headers != null) ...headers,
    };

    try {
      final rawResult = await _runInternal<I>(
        input: requestPayload,
        headers: combinedHeaders,
      );

      try {
        return _fromResponseData(rawResult);
      } catch (e, s) {
        if (e is GenkitException) rethrow;
        throw GenkitException(
          'Failed to convert response data using fromResponse for RemoteAction',
          underlyingException: e,
          details:
              'Received data from flow: ${rawResult is String ? rawResult : jsonEncode(rawResult)}',
          stackTrace: s,
        );
      }
    } on GenkitException {
      rethrow;
    } catch (e, s) {
      throw GenkitException(
        'An unexpected error occurred in RemoteAction call for flow at $_url',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }

  /// Invokes the remote flow and streams its response.
  FlowStreamResponse<O, S> stream<I>({
    required I input,
    Map<String, String>? headers,
  }) {
    if (_fromStreamChunkData == null) {
      final error = GenkitException(
        'fromStreamChunk must be provided to defineRemoteAction for streaming operations.',
      );
      return (
        response: Future.error(error, StackTrace.current),
        stream: Stream.error(error, StackTrace.current),
      );
    }

    final dynamic requestPayload = input;

    final combinedHeaders = {
      if (_defaultHeaders != null) ..._defaultHeaders,
      if (headers != null) ...headers,
    };

    final rawStreamResponse = _streamInternal<I>(
      input: requestPayload,
      headers: combinedHeaders,
    );

    final Stream<S> convertedStream = rawStreamResponse.stream
        .map((rawChunk) {
          try {
            return _fromStreamChunkData(rawChunk);
          } catch (e, s) {
            throw GenkitException(
              'Failed to convert stream chunk data using fromStreamChunk for RemoteAction',
              underlyingException: e,
              details:
                  'Expected chunk type: ${S.toString()}, Received data: ${rawChunk is String ? rawChunk : jsonEncode(rawChunk)}',
              stackTrace: s,
            );
          }
        })
        .handleError((error, stackTrace) {
          if (error is GenkitException) throw error;
          throw GenkitException(
            'Error in RemoteAction stream after chunk conversion attempt',
            underlyingException: error,
            stackTrace: stackTrace,
          );
        });

    final Future<O> convertedResponse = rawStreamResponse.response.then(
      (rawResult) {
        try {
          return _fromResponseData(rawResult);
        } catch (e, s) {
          throw GenkitException(
            'Failed to convert final response data from RemoteAction stream using fromResponse',
            underlyingException: e,
            details:
                'Expected output type: ${O.toString()}, Received data: ${rawResult is String ? rawResult : jsonEncode(rawResult)}',
            stackTrace: s,
          );
        }
      },
      onError: (error, stackTrace) {
        if (error is GenkitException) throw error;
        throw GenkitException(
          'Error in final response of RemoteAction stream before conversion',
          underlyingException: error,
          stackTrace: stackTrace,
        );
      },
    );

    return (response: convertedResponse, stream: convertedStream);
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

/// Defines a remote Genkit action (flow) client.
///
/// This function returns a [RemoteAction] instance, which can be used to call
/// or stream the specified Genkit flow. It simplifies the process of setting up
/// a flow client by allowing direct specification of data conversion functions.
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
