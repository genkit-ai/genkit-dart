import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'converter.dart';
import 'exception.dart';
import 'flow_response.dart';

/// {@template genkit_client}
/// A client for interacting with Genkit flows.
///
/// This client provides methods to run and stream flows, handling
/// authentication, request/response conversion, and error management.
/// {@endtemplate}
class GenkitClient {
  /// {@macro genkit_client}
  GenkitClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.defaultHeaders = const {},
  }) : _httpClient = httpClient ?? http.Client();

  /// The base URL for the Genkit flows.
  final String baseUrl;

  /// Default headers to be included in every request.
  ///
  /// Useful for setting common headers like API keys (though authentication
  /// tokens are typically handled by [AuthProvider]).
  final Map<String, String> defaultHeaders;

  final http.Client _httpClient;

  /// Disposes of the underlying HTTP client.
  /// Call this when the GenkitClient is no longer needed to free up resources.
  void dispose() {
    _httpClient.close();
  }

  /// Resolves a relative path against the [baseUrl].
  Uri _resolveUrl(String path) {
    if (baseUrl.endsWith('/') || path.startsWith('/')) {
      return Uri.parse('$baseUrl$path');
    } else {
      return Uri.parse('$baseUrl/$path');
    }
  }

  /// Invokes a deployed flow over HTTP(s) with type conversion.
  ///
  /// {@template runFlow_template}
  /// Example:
  /// ```dart
  /// // Define your models (e.g., using json_serializable or freezed)
  /// /*
  /// @JsonSerializable() // Assuming you use json_serializable
  /// class MyInput {
  ///   final String message;
  ///   MyInput({required this.message});
  ///   factory MyInput.fromJson(Map<String, dynamic> json) => _$MyInputFromJson(json);
  ///   Map<String, dynamic> toJson() => _$MyInputToJson(this);
  /// }
  ///
  /// @JsonSerializable()
  /// class MyOutput {
  ///   final String reply;
  ///   MyOutput({required this.reply});
  ///   factory MyOutput.fromJson(Map<String, dynamic> json) => _$MyOutputFromJson(json);
  ///   Map<String, dynamic> toJson() => _$MyOutputToJson(this);
  /// }
  /// */
  ///
  /// // Create a converter
  /// // final converter = GenkitConverter<MyInput, MyOutput, void>( // void for StreamChunk if not streaming
  /// //   toRequestData: (input) => input.toJson(),
  /// //   fromResponseData: (json) => MyOutput.fromJson(json),
  /// // );
  ///
  /// // final client = GenkitClient(baseUrl: 'https://project-region-project-name.cloudfunctions.net');
  /// // try {
  /// //   final response = await client.runFlow<MyInput, MyOutput>(
  /// //     flowUrlOrPath: '/myFlow',
  /// //     input: MyInput(message: 'Hello Genkit'),
  /// //     converter: converter,
  /// //   );
  /// //   print(response.reply);
  /// // } on GenkitException catch (e) {
  /// //   print('Error running flow: $e');
  /// // }
  /// ```
  /// {@endtemplate}
  ///
  /// Parameters:
  ///   - `flowUrlOrPath`: URL or path (if `baseUrl` is set) of the deployed flow.
  ///   - `input`: The input data for the flow, of type [I].
  ///   - `converter`: Optional [GenkitConverter] to handle data conversion.
  ///     If `null` (default), assumes `I` and `O` are `Map<String, dynamic>` (or `dynamic`/
  ///     `Object?`) and passes JSON data through directly. The flow's result must be a
  ///     JSON object (`Map<String, dynamic>`) in this case, unless `O` is `dynamic` or `Object?`,
  ///     in which case primitive results from the flow might be directly returned.
  ///   - `headers`: Optional custom HTTP headers for this specific request.
  ///
  /// Returns a [Future] that completes with the flow's output of type [O].
  /// Throws a [GenkitException] if an error occurs.
  Future<O> runFlow<I, O>({
    required String flowUrlOrPath,
    required I input,
    GenkitConverter<I, O, dynamic>? converter,
    Map<String, String>? headers,
  }) async {
    final effectiveConverter =
        converter ?? _createDefaultJsonConverter<I, O, dynamic>();

    final dynamic requestPayload;
    try {
      requestPayload = effectiveConverter.toRequestData(input);
    } catch (e, s) {
      throw GenkitException(
        'Failed to convert input data using toRequestData for runFlow',
        underlyingException: e,
        details:
            'Input type: ${input.runtimeType.toString()}, Converter: ${effectiveConverter.runtimeType}',
        stackTrace: s,
      );
    }

    final resolvedUrl = _resolveUrl(flowUrlOrPath);
    final combinedHeaders = {
      ...defaultHeaders,
      if (headers != null) ...headers,
    };

    try {
      final rawResult = await _runFlowInternal(
        httpClient: _httpClient,
        url: resolvedUrl.toString(),
        input: requestPayload,
        headers: combinedHeaders,
      );

      try {
        return effectiveConverter.fromResponseData(rawResult);
      } catch (e, s) {
        if (e is GenkitException) rethrow;
        throw GenkitException(
          'Failed to convert response data using fromResponseData',
          underlyingException: e,
          details: 'Received data from flow: ${jsonEncode(rawResult)}',
          stackTrace: s,
        );
      }
    } on GenkitException {
      rethrow;
    } catch (e, s) {
      throw GenkitException(
        'An unexpected error occurred in runFlow for flow at $resolvedUrl',
        underlyingException: e,
        stackTrace: s,
      );
    }
  }

  /// Invokes a deployed flow over HTTP(s) and streams its response with type conversion.
  ///
  /// {@template streamFlow_template}
  /// Example:
  /// ```dart
  /// // (Define MyInput, MyFinalOutput, MyChunkOutput models and streamConverter)
  /// /*
  /// @JsonSerializable()
  /// class MyInput { /* ... */ } // Define as in runFlow
  ///
  /// @JsonSerializable()
  /// class MyChunkOutput {
  ///   final String chunk;
  ///   MyChunkOutput({required this.chunk});
  ///   factory MyChunkOutput.fromJson(Map<String, dynamic> json) => _$MyChunkOutputFromJson(json);
  ///   Map<String, dynamic> toJson() => _$MyChunkOutputToJson(this);
  /// }
  ///
  /// @JsonSerializable()
  /// class MyFinalOutput {
  ///   final String summary;
  ///   MyFinalOutput({required this.summary});
  ///   factory MyFinalOutput.fromJson(Map<String, dynamic> json) => _$MyFinalOutputFromJson(json);
  ///   Map<String, dynamic> toJson() => _$MyFinalOutputToJson(this);
  /// }
  ///
  /// final streamConverter = GenkitConverter<MyInput, MyFinalOutput, MyChunkOutput>(
  ///   toRequestData: (input) => input.toJson(),
  ///   fromResponseData: (json) => MyFinalOutput.fromJson(json),
  ///   fromStreamChunkData: (json) => MyChunkOutput.fromJson(json),
  /// );
  ///
  /// final client = GenkitClient(baseUrl: 'https://my-flows');
  /// try {
  ///   final (:stream, :response) = client.streamFlow<MyInput, MyFinalOutput, MyChunkOutput>(
  ///     flowUrlOrPath: '/myStreamingFlow',
  ///     input: MyInput(message: 'Tell me a story'),
  ///     converter: streamConverter,
  ///   );
  ///
  ///   await for (final chunk in stream) {
  ///     print('Chunk: ${chunk.chunk}');
  ///   }
  ///   final finalResult = await response;
  ///   print('Final: ${finalResult.summary}');
  ///
  /// } on GenkitException catch (e) {
  ///   print('Error streaming flow: $e');
  /// }
  /// */
  /// ```
  /// {@endtemplate}
  ///
  /// Parameters:
  ///   - `flowUrlOrPath`: URL or path (if `baseUrl` is set) of the deployed flow.
  ///   - `input`: The input data for the flow, of type [I].
  ///   - `converter`: Optional [GenkitConverter] to handle data conversion.
  ///     If `null` (default), assumes `I`, `O`, and `S` are `Map<String, dynamic>`
  ///     (or `dynamic`/`Object?`) and passes JSON data through directly.
  ///     The flow's final result and stream chunks must be JSON objects (`Map<String, dynamic>`)
  ///     in this case, unless `O` or `S` are `dynamic` or `Object?`.
  ///   - `headers`: Optional custom HTTP headers for this specific request.
  ///
  /// Returns a [FlowStreamResponse] record.
  /// Throws a [GenkitException] for setup errors. Stream errors are emitted on the stream.
  FlowStreamResponse<O, S> streamFlow<I, O, S>({
    required String flowUrlOrPath,
    required I input,
    GenkitConverter<I, O, S>? converter,
    Map<String, String>? headers,
  }) {
    final GenkitConverter<I, O, S> effectiveConverter =
        converter ?? _createDefaultJsonConverter<I, O, S>();

    if (effectiveConverter.fromStreamChunkData == null &&
        converter !=
            null /* only enforce if a custom converter was meant for streaming but lacked the method */ ) {
      // If a custom converter is given but it's missing fromStreamChunkData, it's an error for streamFlow.
      // If converter is null (meaning default JSON passthrough), the default one WILL have fromStreamChunkData.
      final error = GenkitException(
        'The provided GenkitConverter.fromStreamChunkData must be non-null for streamFlow when a custom converter is specified.',
      );
      return (response: Future.error(error), stream: Stream.error(error));
    }

    final dynamic requestPayload;
    try {
      requestPayload = effectiveConverter.toRequestData(input);
    } catch (e, s) {
      final error = GenkitException(
        'Failed to convert input data to JSON for streamFlow',
        underlyingException: e,
        details: 'Input type: ${I.toString()}',
        stackTrace: s,
      );
      return (response: Future.error(error, s), stream: Stream.error(error, s));
    }

    final resolvedUrl = _resolveUrl(flowUrlOrPath);
    final combinedHeaders = {
      ...defaultHeaders,
      if (headers != null) ...headers,
    };

    final rawStreamResponse = _streamFlowInternal(
      httpClient: _httpClient,
      url: resolvedUrl.toString(),
      input: requestPayload,
      headers: combinedHeaders,
    );

    final convertedStream = rawStreamResponse.stream
        .map((rawChunk) {
          try {
            // fromStreamChunkData will be non-null if we passed the check above
            // or if it's the default converter.
            return effectiveConverter.fromStreamChunkData!(rawChunk);
          } catch (e, s) {
            throw GenkitException(
              'Failed to convert stream chunk data using fromStreamChunkData',
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
            'Error in stream after chunk conversion attempt',
            underlyingException: error,
            stackTrace: stackTrace,
          );
        });

    final Future<O> convertedResponse = rawStreamResponse.response.then(
      (rawResult) {
        try {
          return effectiveConverter.fromResponseData(rawResult);
        } catch (e, s) {
          throw GenkitException(
            'Failed to convert final response data from stream using fromResponseData',
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
          'Error in final response of stream before conversion',
          underlyingException: error,
          stackTrace: stackTrace,
        );
      },
    );

    return (response: convertedResponse, stream: convertedStream);
  }
}

// Helper to create a default JSON pass-through converter.
// This converter expects I, O, S to be compatible with Map<String, dynamic> or dynamic.
GenkitConverter<I, O, S> _createDefaultJsonConverter<I, O, S>() {
  return GenkitConverter<I, O, S>(
    toRequestData: (input) => input,
    fromResponseData: (dynamic data) {
      if (data is O) return data;

      try {
        return data as O;
      } catch (e, s) {
        throw GenkitException(
          'Failed to convert or cast flow response data (type: ${data?.runtimeType}) to expected type $O. '
          'Input data: ${data is String ? data : jsonEncode(data)}. '
          'Ensure your flow returns data compatible with $O, or provide a custom GenkitConverter '
          'that can perform the conversion (e.g., for custom objects, implement a fromJson factory).',
          underlyingException: e,
          stackTrace: s,
        );
      }
    },
    fromStreamChunkData: (dynamic data) {
      if (data is S) return data;

      try {
        return data as S;
      } catch (e, s) {
        throw GenkitException(
          'Failed to convert or cast stream chunk data (type: ${data?.runtimeType}) to expected type $S. '
          'Input data: ${data is String ? data : jsonEncode(data)}. ',
          underlyingException: e,
          stackTrace: s,
        );
      }
    },
  );
}

// Internal helper function adapted from the original top-level runFlow
Future<dynamic> _runFlowInternal({
  required http.Client httpClient,
  required String url,
  dynamic input,
  Map<String, String>? headers,
}) async {
  final uri = Uri.parse(url);
  final requestHeaders = <String, String>{
    'Content-Type': 'application/json',
    if (headers != null) ...headers,
  };
  final requestBody = jsonEncode({'data': input});

  http.Response response;
  try {
    response = await httpClient.post(
      uri,
      headers: requestHeaders,
      body: requestBody,
    );
  } catch (e, s) {
    throw GenkitException(
      'HTTP request failed',
      underlyingException: e,
      stackTrace: s,
    );
  }

  if (response.statusCode != 200) {
    dynamic errorDetailsJson;
    try {
      errorDetailsJson = jsonDecode(response.body);
    } catch (_) {
      // If not JSON, use raw body as details
      errorDetailsJson = response.body;
    }
    String message = 'Server returned error';
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
      details: response.body, // Keep raw body for full details
    );
  }

  final dynamic decodedBody;
  try {
    decodedBody = jsonDecode(response.body);
  } on FormatException catch (e, s) {
    throw GenkitException(
      'Failed to decode JSON response body from flow',
      underlyingException: e,
      details: response.body,
      stackTrace: s,
    );
  }

  if (decodedBody is Map<String, dynamic>) {
    // Check for a Genkit-specific error structure within a 200 OK response (e.g. from a misconfigured flow)
    if (decodedBody.containsKey('error')) {
      final errorData = decodedBody['error'];
      String errorMessage = 'Flow returned an error object despite HTTP 200 OK';
      if (errorData is String) {
        errorMessage = errorData;
      } else if (errorData is Map<String, dynamic> &&
          errorData.containsKey('message') &&
          errorData['message'] is String) {
        errorMessage = errorData['message'] as String;
      }
      // It's debatable whether this should have a statusCode if HTTP was 200.
      // For now, treat it as a client-side interpretation error or bad flow contract.
      throw GenkitException(
        errorMessage,
        details: jsonEncode(
          errorData,
        ), // errorData itself might be a string or map
      );
    }

    if (decodedBody.containsKey('result')) {
      return decodedBody['result'];
    }

    throw GenkitException(
      'Invalid response format: HTTP 200 OK but missing "result" or "error" key in JSON object.',
      details: response.body,
    );
  } else {
    // If the response is 200 OK but not a JSON object, this is a contract violation.
    throw GenkitException(
      'Invalid response format: Expected a JSON object from flow response, got ${decodedBody.runtimeType}.',
      details: response.body,
    );
  }
}

// Internal helper function adapted from the original top-level streamFlow
FlowStreamResponse<dynamic, dynamic> _streamFlowInternal({
  required http.Client httpClient,
  required String url,
  dynamic input,
  Map<String, String>? headers,
}) {
  final streamController = StreamController<dynamic>();
  final responseCompleter = Completer<dynamic>();

  Future<void> run() async {
    http.StreamedResponse? streamedResponse;
    StreamSubscription? subscription;

    // Add onCancel handler to the streamController
    streamController.onCancel = () async {
      // print('Stream cancelled by consumer.');
      await subscription?.cancel();
      // Note: We don't close the httpClient here as it's managed by GenkitClient instance
      // and shared across multiple calls.
      // If a new client were created per stream, it would be closed here.
      if (!responseCompleter.isCompleted) {
        responseCompleter.completeError(
          GenkitException(
            'Stream operation cancelled by user.',
            stackTrace: StackTrace.current,
          ),
        );
      }
      if (!streamController.isClosed) {
        await streamController.close();
      }
    };

    try {
      final uri = Uri.parse(url);
      final request = http.Request('POST', uri);

      request.headers['Accept'] = 'text/event-stream';
      request.headers['Content-Type'] = 'application/json';
      if (headers != null) {
        request.headers.addAll(headers);
      }
      request.body = jsonEncode({'data': input});

      try {
        streamedResponse = await httpClient.send(request);
      } catch (e, s) {
        final err = GenkitException(
          'Failed to send streaming request',
          underlyingException: e,
          stackTrace: s,
        );
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(err, s);
        }
        if (!streamController.isClosed) {
          streamController.addError(err, s);
          streamController.close();
        }
        return; // Important to exit on setup errors
      }

      if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        final exception = GenkitException(
          'Server returned error in stream setup',
          statusCode: streamedResponse.statusCode,
          details: responseBody,
        );
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(exception);
        }
        if (!streamController.isClosed) {
          streamController.addError(exception);
          streamController.close();
        }
        return;
      }

      var buffer = '';
      subscription = streamedResponse.stream
          .transform(utf8.decoder)
          .listen(
            (decodedChunk) {
              buffer += decodedChunk;
              while (buffer.contains(flowStreamDelimiter)) {
                final endOfChunk = buffer.indexOf(flowStreamDelimiter);
                final chunkData = buffer.substring(0, endOfChunk);
                buffer = buffer.substring(
                  endOfChunk + flowStreamDelimiter.length,
                );

                if (!chunkData.startsWith(sseDataPrefix)) {
                  // print('Ignoring chunk without data prefix: "$chunkData"');
                  continue;
                }
                final jsonData = chunkData.substring(sseDataPrefix.length);
                if (jsonData.isEmpty) continue;

                try {
                  final parsedJson = jsonDecode(jsonData);
                  if (parsedJson is Map<String, dynamic>) {
                    if (parsedJson.containsKey('message')) {
                      if (!streamController.isClosed) {
                        // Pass the 'message' payload (dynamic) directly
                        streamController.add(parsedJson['message']);
                      }
                    } else if (parsedJson.containsKey('result')) {
                      if (!responseCompleter.isCompleted) {
                        // Pass the 'result' payload (dynamic) directly
                        responseCompleter.complete(parsedJson['result']);
                      }
                    } else if (parsedJson.containsKey('error')) {
                      final errorData = parsedJson['error'];
                      String errorMessage = 'Unknown streaming error format';
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
                        streamController.close();
                      }
                      subscription?.cancel();
                      buffer = '';
                      return;
                    }
                    // Silently ignore unknown JSON structures within a data: line for now
                  } else {
                    // Parsed JSON wasn't a map
                    if (!streamController.isClosed) {
                      final err = GenkitException(
                        'Expected JSON map from stream, got: ${parsedJson.runtimeType}',
                        details: jsonData,
                      );
                      streamController.addError(err);
                      if (!responseCompleter.isCompleted) {
                        responseCompleter.completeError(err);
                      }
                    }
                  }
                } on FormatException catch (e, s) {
                  final err = GenkitException(
                    'Failed to decode JSON chunk from stream',
                    underlyingException: e,
                    details: jsonData,
                    stackTrace: s,
                  );
                  if (!streamController.isClosed) {
                    streamController.addError(err, s);
                  }
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.completeError(err, s);
                  }
                } catch (e, s) {
                  final err = GenkitException(
                    'Error processing stream chunk',
                    underlyingException: e,
                    details: jsonData,
                    stackTrace: s,
                  );
                  if (!streamController.isClosed) {
                    streamController.addError(err, s);
                  }
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.completeError(err, s);
                  }
                }
              }
            },
            onError: (error, stackTrace) {
              final err = GenkitException(
                'Error from HTTP stream',
                underlyingException: error,
                stackTrace: stackTrace,
              );
              if (!responseCompleter.isCompleted) {
                responseCompleter.completeError(err, stackTrace);
              }
              if (!streamController.isClosed) {
                streamController.addError(err, stackTrace);
                streamController.close();
              }
            },
            onDone: () {
              if (buffer.isNotEmpty &&
                  !streamController.isClosed &&
                  !responseCompleter.isCompleted) {
                final err = GenkitException(
                  'Stream ended with unprocessed data in buffer',
                  details: buffer,
                );
                if (!responseCompleter.isCompleted) {
                  responseCompleter.completeError(err);
                }
                if (!streamController.isClosed) streamController.addError(err);
              } else if (!responseCompleter.isCompleted &&
                  !streamController.isClosed) {
                responseCompleter.completeError(
                  GenkitException(
                    'Stream finished without a final result or error chunk.',
                  ),
                );
              }
              if (!streamController.isClosed) streamController.close();
            },
            cancelOnError: true,
          );
    } catch (e, s) {
      final err = GenkitException(
        'Failed to send streaming request',
        underlyingException: e,
        stackTrace: s,
      );
      if (!responseCompleter.isCompleted) {
        responseCompleter.completeError(err, s);
      }
      if (!streamController.isClosed) {
        streamController.addError(err, s);
        streamController.close();
      }
    } finally {
      Future.wait([
        responseCompleter.future.catchError((_) => <String, dynamic>{}),
        streamController.done.catchError((_) {}),
      ]);
    }
  }

  run();
  return (stream: streamController.stream, response: responseCompleter.future);
}
