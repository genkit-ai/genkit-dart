## 0.10.0-dev.16

 - **REFACTOR**: Introduce a dedicated plugin.dart entry point for plugin-related exports (#149).
 - **FEAT**: improve partial json extraction (#150).
 - **FEAT**: add error handling for plugin action listing and report failures to stderr (#148).
 - **FEAT**: Allow ReflectionServerV1 to automatically find an available port if none is specified. (#146).

## 0.10.0-dev.15

 - **FIX**: prevent incorrect partial JSON repair by validating stack state (#144).
 - **FEAT**: Add remote model support and enable serving actions via shelf (#143).

## 0.10.0-dev.14

 - **REFACTOR**: automate telemetry exporter configuration (#131).
 - **FEAT**: implemented/fixed tools calling and structured output for firebase_ai (#138).

## 0.10.0-dev.13

> Note: This release has breaking changes.

 - **FIX**: Wrap error responses in a JSON object under an 'error' key (#130).
 - **FEAT**: Implemented real-time tracing (#128).
 - **FEAT**: created a genkit_middleware package with skills, filesystem and toolApproval middleware (#126).
 - **FEAT**: add MCP (Model Context Protocol) plugin (#94).
 - **FEAT**: implemented interrupt restart (#124).
 - **BREAKING** **REFACTOR**: generate api cleanup (#125).

## 0.10.0-dev.12

 - **FEAT**: introducing registered middleware (#87).
 - **FEAT**: added support for embedders (embedding models) (#88).

## 0.10.0-dev.11

> Note: This release has breaking changes.

 - **FIX**: Coerce `num` values to `double` for generated double fields during JSON parsing. (#65).
 - **FEAT**: add Google Search and multi-speaker voice config support, extract usage metadata, and introduce reasoning parts (#82).
 - **FEAT**: allow `generate` and `generateBidi` to accept `Tool` objects directly in the `tools` list alongside tool names (#79).
 - **FEAT**: Implement hierarchical registry with parent delegation and merging for values and actions (#78).
 - **FEAT**: Implement streaming chunk indexing across turns and improve `maxTurns` error handling with a new default. (#75).
 - **FEAT**: implemented interrupts (#73).
 - **FEAT**: Add retry middleware for AI model and tool calls with configurable backoff and error handling. (#67).
 - **FEAT**: Add `$GenerateResponse` type, refine schema types, and update generated class constructors to use `late final` and regular constructors. (#66).
 - **FEAT**: added schemas for gemini models, made sure TTS and nano banana models are working (#63).
 - **BREAKING** **REFACTOR**: update GenkitException to use a StatusCodes enum instead of raw integer status codes. (#68).

## 0.10.0-dev.10

 - **FEAT**: updated AnyOf support for union types in Schemantic, including helper class generation and schema type handling. (#62).

## 0.10.0-dev.9

> Note: This release has breaking changes.

 - **REFACTOR**: reimplement schema generation from extension types to classes, enhance `PartExtension` getters, and simplify `GenerateResponse` and tool invocation. (#53).
 - **FEAT**: use combining builder and header option (#52).
 - **BREAKING** **FEAT**: implement Schemantic API redesign with $ prefixed schema definitions and static `$schema` for unified schema access. (#60).

## 0.10.0-dev.8

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: renamed JsonExtensionType to SchemanticType (#44).

## 0.10.0-dev.7

 - **REFACTOR**: Consolidate Google GenAI examples into a single file, fixed tools calling, and schema flattening helper (#43).
 - **FEAT**: implemented streaming and various config options for genkit_google_genai plugin (#42).

## 0.10.0-dev.6

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: Refactor basic types into factory functions to support schema constraints (#34).

## 0.10.0-dev.5

> Note: This release has breaking changes.

 - **REFACTOR**: move the package-specific schema generator into a peer package (#31).
 - **BREAKING** **REFACTOR**: renamed @Key annotation to @Field (#30).

## 0.10.0-dev.4

 - **REFACTOR**: make generated JsonExtensionType factory classes (*TypeFactory) private (#29).
 - **FEAT**: added support for defining listType and mapType in schemantic (#28).

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
