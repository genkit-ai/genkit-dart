import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Invokes a deployed flow over HTTP(s).
///
/// For example:
///
/// ```dart
/// import 'package:genkit/client.dart';
///
/// void main() async {
///   try {
///     final response = await runFlow( // Specify expected output type
///       url: 'https://my-flow-deployed-url',
///       input: 'foo',
///       headers: {'Authorization': 'Bearer YOUR_TOKEN'}, // Optional headers
///     ) as String;
///     print(response); // Output: (depends on the flow's return value)
///   } catch (e) {
///     print('Error running flow: $e');
///   }
/// }
/// ```
Future runFlow({
  /// URL of the deployed flow.
  required String url,

  /// Flow input (will be JSON encoded). Can be any JSON-encodable object.
  dynamic input,

  /// A map of HTTP headers to be added to the HTTP call.
  Map<String, String>? headers,
}) async {
  final uri = Uri.parse(url); // Parse the URL string into a Uri object

  // Prepare the headers
  final requestHeaders = <String, String>{
    'Content-Type': 'application/json',
    // Add custom headers if provided, overwriting defaults if necessary
    if (headers != null) ...headers,
  };

  // Prepare the body
  final requestBody = jsonEncode({
    'data': input, // Wrap the input in a 'data' field as per the TS example
  });

  http.Response response;
  try {
    response = await http.post(
      uri,
      headers: requestHeaders,
      body: requestBody,
    );
  } catch (e) {
    // Catch network or other errors during the request itself
    throw Exception('HTTP request failed: $e');
  }

  if (response.statusCode != 200) {
    throw Exception(
      'Server returned: ${response.statusCode}: ${response.body}',
    );
  }

  final decodedBody = jsonDecode(response.body);

  // Ensure the decoded body is a Map
  if (decodedBody is Map<String, dynamic>) {
    // Check if the response contains an error field
    if (decodedBody.containsKey('error')) {
      final errorData = decodedBody['error'];
      if (errorData is String) {
        throw Exception(errorData);
      } else {
        // TODO: Consider parsing the error structure if it's known
        // (like the HttpError mentioned in the TS comments)
        // For now, stringify the error object.
        throw Exception(jsonEncode(errorData));
      }
    }
    // Check if the response contains the result field
    else if (decodedBody.containsKey('result')) {
      return decodedBody['result'];
    } else {
      // Neither 'error' nor 'result' key found
      throw Exception(
          'Invalid response format: Missing "result" or "error" key.');
    }
  } else {
    // Response body was not a valid JSON map
    throw Exception('Invalid response format: Expected a JSON object.');
  }
}

// Define the delimiter used by the flow stream protocol
const _flowStreamDelimiter = '\n\n';
const _sseDataPrefix = 'data: ';

/// Record type returned by [streamFlow], containing the stream of chunks
/// and a future for the final response.
typedef FlowStreamResponse<O, S> = ({Future<O> response, Stream<S> stream});

/// Invokes a deployed flow over HTTP(s) and streams its response.
///
/// Expects the server to respond with a stream format like Server-Sent Events,
/// where each message chunk is prefixed with "data: " and followed by "\n\n".
/// The final result or an error is expected within such a chunk.
///
/// Example:
///
/// ```dart
/// import 'your_file.dart'; // Assuming the function is in this file
///
/// void main() async {
///   try {
///     // Use named record destructuring to get the stream and response future
///     final (:stream, :response) = await streamFlow<String, String>( // Specify final output type O and stream chunk type S
///       url: 'http://localhost:3000/myStreamingFlow', // Replace with your flow URL
///       input: {'prompt': 'Tell me a short story'},
///       headers: {'Authorization': 'Bearer YOUR_TOKEN'}, // Optional headers
///     );
///
///     print('Streaming chunks:');
///     await for (final chunk in stream) {
///       print('Chunk: $chunk');
///     }
///
///     // Wait for the final result after the stream is finished
///     print('\nStream finished.');
///     final finalResult = await response;
///     print('Final Response: $finalResult');
///
///   } catch (e) {
///     print('\nError streaming flow: $e');
///     if (e is FlowStreamException) {
///        print('Status Code: ${e.statusCode}');
///        print('Details: ${e.details}');
///     }
///   }
/// }
/// ```
FlowStreamResponse<O, S> streamFlow<O, S>({
  /// URL of the deployed flow.
  required String url,

  /// Flow input (will be JSON encoded). Can be any JSON-encodable object.
  dynamic input,

  /// A map of HTTP headers to be added to the HTTP call.
  Map<String, String>? headers,
}) {
  final streamController = StreamController<S>();
  final responseCompleter = Completer<O>();
  final client = http.Client(); // Create a client to manage the connection

  // This async function performs the actual request and processing.
  // We don't await it directly in streamFlow so that streamFlow can
  // return the stream/future record synchronously.
  Future<void> run() async {
    http.StreamedResponse? streamedResponse;
    StreamSubscription? subscription;

    try {
      final uri = Uri.parse(url);
      final request = http.Request('POST', uri);

      // Set headers
      request.headers['Accept'] = 'text/event-stream'; // Crucial for streaming
      request.headers['Content-Type'] = 'application/json';
      if (headers != null) {
        request.headers.addAll(headers);
      }

      // Set body
      request.body = jsonEncode({'data': input});

      // Send the request and get a streamed response
      streamedResponse = await client.send(request);

      // Check status code *before* processing the stream body
      if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        throw FlowStreamException(
          'Server returned error',
          statusCode: streamedResponse.statusCode,
          details: responseBody,
        );
      }

      // Process the stream
      var buffer = '';
      subscription = streamedResponse.stream
          .transform(utf8.decoder) // Decode bytes to UTF-8 strings
          .listen(
        (decodedChunk) {
          buffer += decodedChunk;

          // Process buffer as long as it contains the delimiter
          while (buffer.contains(_flowStreamDelimiter)) {
            final endOfChunk = buffer.indexOf(_flowStreamDelimiter);
            final chunkData = buffer.substring(0, endOfChunk);
            buffer = buffer.substring(endOfChunk +
                _flowStreamDelimiter.length); // Remove processed part

            if (!chunkData.startsWith(_sseDataPrefix)) {
              // Skip lines that don't start with 'data: ', could be comments or empty lines
              // Or potentially throw an error if the format is strictly expected.
              // Let's silently ignore for now, similar to SSE specs.
              print('Ignoring chunk without data prefix: "$chunkData"');
              continue;
            }

            final jsonData = chunkData.substring(_sseDataPrefix.length);

            if (jsonData.isEmpty) {
              // Ignore empty data chunks if necessary
              continue;
            }

            try {
              final parsedJson = jsonDecode(jsonData);

              if (parsedJson is Map<String, dynamic>) {
                if (parsedJson.containsKey('message')) {
                  if (!streamController.isClosed) {
                    // Add the message chunk to the stream
                    streamController.add(parsedJson['message'] as S);
                  }
                } else if (parsedJson.containsKey('result')) {
                  if (!responseCompleter.isCompleted &&
                      !streamController.isClosed) {
                    // Complete the response future with the final result
                    responseCompleter.complete(parsedJson['result'] as O);
                    // We might want to close the stream controller here if the result signals the end
                    // streamController.close(); // Let's rely on onDone for closing
                  }
                } else if (parsedJson.containsKey('error')) {
                  final errorData = parsedJson['error'];
                  String errorMessage = 'Unknown streaming error format';
                  String? errorDetails;
                  int? errorStatus; // Assuming error might contain status info

                  if (errorData is Map<String, dynamic>) {
                    errorMessage =
                        errorData['message'] as String? ?? errorMessage;
                    errorDetails = errorData['details'] as String?;
                    errorStatus =
                        errorData['status'] as int?; // Example structure
                  } else if (errorData is String) {
                    errorMessage = errorData;
                  }

                  final exception = FlowStreamException(errorMessage,
                      statusCode: errorStatus,
                      details: errorDetails ??
                          jsonEncode(errorData) // Fallback details
                      );

                  if (!responseCompleter.isCompleted &&
                      !streamController.isClosed) {
                    responseCompleter.completeError(exception);
                  }
                  if (!streamController.isClosed) {
                    streamController.addError(exception);
                    streamController.close(); // Close stream on error
                  }
                  // Cancel further processing
                  subscription?.cancel();
                  buffer = ''; // Clear buffer as we are stopping
                  return; // Exit listen callback
                } else {
                  // Unknown chunk format inside the JSON map
                  if (!streamController.isClosed) {
                    final err =
                        FormatException('Unknown JSON chunk format: $jsonData');
                    streamController.addError(err);
                    if (!responseCompleter.isCompleted) {
                      responseCompleter.completeError(err);
                    }
                  }
                }
              } else {
                // Parsed JSON wasn't a map - unexpected format
                if (!streamController.isClosed) {
                  final err =
                      FormatException('Expected JSON map, got: $jsonData');
                  streamController.addError(err);
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.completeError(err);
                  }
                }
              }
            } on FormatException catch (e, s) {
              // Handle JSON decoding errors
              if (!streamController.isClosed) {
                streamController.addError(
                    FormatException(
                        'Failed to decode JSON chunk: "$jsonData"', e),
                    s);
                if (!responseCompleter.isCompleted) {
                  responseCompleter.completeError(
                      FormatException(
                          'Failed to decode JSON chunk: "$jsonData"', e),
                      s);
                }
              }
            } catch (e, s) {
              // Catch casting errors (as S / as O) or others
              if (!streamController.isClosed) {
                streamController.addError(e, s);
                if (!responseCompleter.isCompleted) {
                  responseCompleter.completeError(e, s);
                }
              }
            }
          } // end while
        },
        onError: (error, stackTrace) {
          // Handle errors from the underlying HTTP stream itself
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(error, stackTrace);
          }
          if (!streamController.isClosed) {
            streamController.addError(error, stackTrace);
            streamController.close(); // Ensure stream is closed on error
          }
        },
        onDone: () {
          // Stream from server finished
          if (buffer.isNotEmpty) {
            // Handle any trailing data that wasn't followed by a delimiter
            // This might indicate an incomplete message from the server.
            final err = FlowStreamException(
                'Stream ended with unprocessed data in buffer: "$buffer"');
            if (!responseCompleter.isCompleted) {
              responseCompleter.completeError(err);
            }
            if (!streamController.isClosed) {
              streamController.addError(err);
            }
          } else if (!responseCompleter.isCompleted) {
            // If the stream finished but we never received a 'result' or 'error' chunk
            responseCompleter.completeError(
              FlowStreamException(
                  'Stream finished without a final result or error chunk.'),
            );
          }

          if (!streamController.isClosed) {
            streamController
                .close(); // Close the controller when the source is done
          }
        },
        cancelOnError: true, // Cancel subscription if an error occurs
      );
    } catch (e, s) {
      // Catch synchronous errors during setup or initial request sending
      if (!responseCompleter.isCompleted) {
        responseCompleter.completeError(e, s);
      }
      if (!streamController.isClosed) {
        streamController.addError(e, s);
        streamController.close();
      }
    } finally {
      // Ensure client is closed once the stream OR response future is done
      // Using whenComplete on both ensures cleanup happens regardless of which finishes first
      // or if one errors out.
      Future.wait([
        responseCompleter.future
            .catchError((_) {}), // Ignore future errors here
      ]).whenComplete(() => client.close());
    }
  }

  run(); // Start the async operation

  // Return the stream and future immediately
  return (stream: streamController.stream, response: responseCompleter.future);
}

/// Custom exception for errors encountered during flow streaming.
class FlowStreamException implements Exception {
  final String message;
  final int? statusCode; // HTTP status code if applicable
  final String? details; // Further details, potentially response body

  FlowStreamException(this.message, {this.statusCode, this.details});

  @override
  String toString() {
    var str = 'FlowStreamException: $message';
    if (statusCode != null) {
      str += ' (Status Code: $statusCode)';
    }
    if (details != null && details!.isNotEmpty) {
      str += '\nDetails: $details';
    }
    return str;
  }
}
