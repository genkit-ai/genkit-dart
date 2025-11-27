# Generate API Implementation Summary

## Goal

The primary goal of this task was to replace the placeholder `generate` API in `lib/genkit.dart` with a full-featured implementation, bringing the Dart version of Genkit in line with its JavaScript and Go counterparts. The new API is designed to be extensible and developer-friendly, supporting advanced features like model configuration, structured outputs, and tool usage.

## Work Completed

- **Created a new Generate API:**
  - Introduced user-friendly data classes (`GenerateOptions`, `GenerateConfig`, `GenerateOutput`) in `lib/src/ai/generate.dart` to structure the `generate` call.
  - Made `GenerateConfig` an abstract base class to allow for extensible, model-specific configurations.

- **Refactored Core Logic:**
  - The internal `generate` action logic was moved into a `defineGenerateAction` function within `lib/src/ai/generate.dart` for better code organization.
  - The `Genkit` class constructor in `lib/genkit.dart` was updated to use this new function.
  - Implemented a `toToolDefinition` helper function to convert `Tool` objects into `ToolDefinition` schemas for the model.

- **Improved Developer Experience:**
  - The public `generate` method in `lib/genkit.dart` was updated to use named parameters instead of a single options class, making the API more intuitive and easier to use.

- **Ensured Quality:**
  - Added a new unit test to `test/genkit_test.dart` to verify that the `generate` method correctly invokes the underlying model with the given parameters.

## Reference Materials

- **JS and Go API Docs:** [ref/models.mdx](ref/models.mdx)
- **Go Implementation Reference:** [ref/generate.go](ref/generate.go)

## Generate API Features

The Genkit `generate` API provides a unified interface for interacting with generative models. It is designed to be powerful and extensible, handling everything from simple text generation to complex, multi-turn tool use.

### Core API Contract

-   **Input**: The API takes a `GenerateActionOptions` object, which encapsulates all parameters for the generation request.
-   **Output**: It returns a `ModelResponse` object containing the model's full response, including candidates, usage stats, and other metadata.
-   **Streaming**: The API can stream the response in chunks of type `ModelResponseChunk`, allowing for real-time updates.

### `GenerateActionOptions`: Key Features

The `GenerateActionOptions` object is the heart of the API, providing a rich set of features to control the generation process.

-   **`model` (Required)**: A string identifying the model to use (e.g., `googleai/gemini-2.5-flash`).
-   **`messages` (Required)**: A list of `Message` objects representing the conversation history. Each message has a `role` (`user`, `model`, etc.) and `content`, which is a list of `Part` objects.
-   **`config`**: A flexible `Map<String, dynamic>` for model-specific settings like `temperature`, `topK`, and `maxOutputTokens`.
-   **`tools`**: A list of tool names (strings) to make available to the model. The API automatically handles:
    -   Resolving tool definitions from the registry.
    -   Executing tool calls when requested by the model.
    -   Returning results back to the model in a multi-turn loop.
-   **`toolChoice`**: A string to force the model to call a specific tool.
-   **`maxTurns`**: A number to limit the number of tool-calling iterations to prevent infinite loops.
-   **`returnToolRequests`**: A boolean that, if `true`, causes the API to return the model-generated tool requests to the caller instead of executing them.
-   **`output`**: An `OutputConfig` object to define the desired output format.
    -   **`format`**: Specifies the output format (e.g., `json`, `text`). Default: `json`. This maps to registered formats.
    -   **`jsonSchema`**: A JSON schema definition for requesting structured, typed output from the model. The API will guide the model to produce output that conforms to this schema.
    -   **`constrained`**: A boolean to request the use of the model's native constrained output feature, if available.
-   **`docs`**: A list of `DocumentData` objects to provide as context for Retrieval-Augmented Generation (RAG).
-   **`resume`**: An object used to resume a previously interrupted generation, particularly useful for continuing a multi-step tool-use flow.

### The `Part` System: Rich Content Types

The `content` of each `Message` is an array of `Part` objects, allowing for rich, multimodal interactions.

-   **`TextPart`**: The most basic part, containing a simple string of text.
-   **`MediaPart`**: Used for multimodal inputs like images, audio, or video. It contains a `media` object with a `url` (which can be a public HTTPS URL or a base64-encoded data URL) and an optional `contentType`.
-   **`ToolRequestPart`**: Represents the model's request to execute a tool. It contains the tool `name`, its `input` arguments, and a unique `ref` to track the call.
-   **`ToolResponsePart`**: The response sent back to the model after a tool is executed. It contains the tool's `output` and the matching `ref` from the request.
-   **`DataPart`**: A generic part for embedding arbitrary data.
-   **`ResourcePart`**: Represents a request to load a resource (e.g., a document) by URI. The API resolves this part and replaces it with the resource's content before sending the request to the model.
-   **`ReasoningPart`**: Contains the model's thought process or reasoning steps, which can be useful for debugging and introspection.

## Remaining TODOs

-   [x] **Implement Streaming Support**:
    -   [x] **Text Streaming**: Implement streaming for mode chunk responses.
-   [x] **Implement Context Support (Zones)**: Investigate and implement context propagation using Dart's `Zone`s to mimic `AsyncLocalStorage` in Node.js or `contextvars` in Python, allowing for implicit context passing through async calls.
-   [x] **Create New Example for Generate API**: Create a new, dedicated example file (`example/generate_example.dart`) that showcases the various features of the new `generate` API.
-   [x] **Implement Full Tool Support**:
    -   [x] **Basic tool calling**: yeah, basics: generate action constructs the tool definition object.
    -   [x] **Tool Choice**: Implement the `toolChoice` parameter to force the model to use a specific tool.
    -   [x] **Return Tool Requests**: Implement the `returnToolRequests` parameter.
    -   [ ] DO LATER: **Interrupts**: Implement the ability for a tool to interrupt the generation flow and return control to the caller.
    -   [ ] DO LATER: **Stateful Resumption**: Implement the `resume` parameter to allow for the continuation of an interrupted generation, including providing `respond` and `restart` directives for pending tool calls.
-   [ ] **Implement Structured Output Handling**:
    -   [ ] **Format Handling**: Implement a `FormatHandler` system to parse and validate model output against a JSON schema.
    -   [ ] **Instruction Injection**: For models without native constrained output, automatically inject instructions into the prompt to guide the model toward the desired schema.
    -   [ ] **Structured Data Streaming**: Implement support for streaming partially constructed JSON objects when a `jsonSchema` is provided. (can leave this till the end)
-   [ ] **Implement Resource Handling**:
    -   [ ] **Resource Part Processing**: Implement the logic to process `ResourcePart` in messages, executing the resource and embedding its content before calling the model.
-   [ ] **Implement Middleware Pipeline**:
    -   [ ] **Core Middleware Support**: Add the ability to pass a list of `ModelMiddleware` to the `generate` call.
    -   [ ] **System Prompt Simulation**: Create middleware to simulate system prompts for models without native support.
    -   [ ] **Automatic Telemetry**: Create middleware to automatically capture usage metrics like latency and token counts.
-   [ ] **Implement RAG Support**: Implement the `docs` parameter to support Retrieval-Augmented Generation.
-   [ ] **Revisit `GenerateConfig` Design**: The current abstract class design for `GenerateConfig` is functional but may be revisited for further improvements.
