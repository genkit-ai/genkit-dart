## 0.8.0

- **BREAKING CHANGE**: The `.stream()` method now returns a `GenkitStream` instead of a `FlowStreamResponse` record. `GenkitStream` is a `Stream` that also provides a `finalResult` property to access the flow's final, non-streamed response. This simplifies the API for handling streaming responses.

  **Migration**:
  Code that previously looked like this:
  ```dart
  final (:stream, :response) = myAction.stream(input: ...);
  await for (final chunk in stream) {
    // ...
  }
  final finalResult = await response;
  ```

  Should be updated to:
  ```dart
  final stream = myAction.stream(input: ...);
  await for (final chunk in stream) {
    // ...
  }
  final finalResult = stream.finalResult;
  ```

## 0.7.0

- **BREAKING CHANGE**: The package has been renamed from `package:genkit/genkit.dart` to `package:genkit/client.dart`. You will need to update your import statements.
- **BREAKING CHANGE**: The `response` future returned by the `.stream()` method is now nullable (`Future<O?>`). This change supports improved error handling and cancellation.
- **Improved Error Handling**: Errors occurring on the server during a stream are now thrown by the `stream` itself. This allows you to catch exceptions directly within a `try/catch` block surrounding an `await for` loop.

## 0.6.0

- Added standard Genkit data classes for working with generative models, including `GenerateResponse`, `Message`, and `Part` types.
- Added helper getters like `.text` and `.media` for easier data extraction.

## 0.5.1

- README cleanup

## 0.5.0

- **Enhanced type-safe client**: Added comprehensive generics support for type-safe operations
- **Streaming support**: Implemented real-time data streaming with Server-Sent Events (SSE)
- **Improved error handling**: Introduced `GenkitException` with detailed error information and HTTP status codes
- **Authentication support**: Added support for custom headers including Firebase Auth integration
- **Better integration**: Enhanced compatibility with `json_serializable` for object serialization
- **Comprehensive documentation**: Added detailed API documentation and usage examples
- **Platform support**: Full cross-platform support for iOS, Android, Web, Windows, macOS, and Linux
- **Testing improvements**: Added comprehensive unit and integration tests

## 0.0.1

- Initial version.
