import 'dart:async';

// Define the delimiter used by the flow stream protocol
const flowStreamDelimiter = '\n\n';
const sseDataPrefix = 'data: ';

/// Record type returned by [GenkitClient.streamFlow], containing the stream of chunks
/// and a future for the final response.
typedef FlowStreamResponse<O, S> = ({Future<O> response, Stream<S> stream});
