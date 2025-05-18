/// Defines how to convert between Dart types and JSON data for Genkit flows.
///
/// Type parameters:
///   - `I`: The type of the input data for the flow.
///   - `O`: The type of the final output data from the flow.
///   - `S`: The type of the streaming chunk data (if applicable). `void` can be used if not applicable.
class GenkitConverter<I, O, S> {
  /// Converts the flow input object [input] of type [I] to a JSON-encodable
  /// object (e.g., String, int, List, Map) that represents the actual payload for the flow.
  /// This payload will be wrapped in `{'data': payload}` by the GenkitClient before sending.
  final dynamic Function(I input) toRequestData;

  /// Converts the direct payload [data] (which can be a primitive, a Map, a List, etc.)
  /// from the flow's response to an object of type [O].
  /// The implementer is responsible for handling the actual type of [data]
  /// and converting it to [O].
  final O Function(dynamic data) fromResponseData;

  /// Converts a JSON `Map<String, dynamic>` [json] from a stream chunk
  /// to an object of type [S]. This is required for typed streaming flows.
  final S Function(dynamic json)? fromStreamChunkData;

  const GenkitConverter({
    required this.toRequestData,
    required this.fromResponseData,
    this.fromStreamChunkData,
  });
}
