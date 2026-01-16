## 0.10.0-dev.3

> Note: This release has breaking changes.

 - **FEAT**: bump analyzer dependency (#25).
 - **FEAT**: added support for schema refs/defs in the schema generator (#22).
 - **BREAKING** **REFACTOR**: renamed genkit_schema_builder package to schemantic (#26).

## 0.10.0-dev.2

 - **FIX**: register generate action with the correct name.
 - **FEAT**: implemented live api using firebase ai logic (#19).

## 0.10.0-dev.1

- Initial release of Genkit Dart framework.
- **BREAKING CHANGE**: `RemoteAction` has 2 extra generic type parameters `I` and `Init` for the input and init types. 
- feat: defineRemoteAction now accepts inputType, outputType and streamType parameters using genkit schema builder types.

## 0.9.0

- Made `fromResponse` and `fromStreamChunk` optional in `defineRemoteAction`. If not provided, the response and stream chunks will be `dynamic` objects decoded from JSON, instead of requiring a typed conversion function.

## 0.8.0

- **BREAKING CHANGE**: The `.stream()` method now returns an `ActionStream` instead of a `FlowStreamResponse` record. `ActionStream` is a `Stream` that provides two ways to access the flow's final, non-streamed response:
  - `onResult`: A `Future` that completes with the result. This is the recommended approach. It will complete with a `GenkitException` if the stream terminates with an error or is cancelled. 
  - `result`: A synchronous getter that should only be used after the stream is fully consumed. It will throw a `GenkitException` if the stream is not consumed, terminates with an error or is cancelled. 

  **Migration**:
  Code that previously looked like this:
  ```dart
  final (:stream, :response) = myAction.stream(input: ...);
  await for (final chunk in stream) {
    // ...
  }
  final finalResult = await response;
  ```

  Should be updated to use `onResult`:
  ```dart
  final stream = myAction.stream(input: ...);
  await for (final chunk in stream) {
    // ...
  }
  final finalResult = await stream.onResult;
  // or
  final finalResult = stream.result;
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
