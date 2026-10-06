## 1.0.0-rc.3

 - updated internal dependencies.

## 1.0.0-rc.2

### Breaking Changes

 - prefix exported option types with provider (#572)


## 1.0.0-rc.1

### Breaking Changes

 - type usage counts and indexes as int (#546)
 - non-null input for Model/Embedder/Evaluator/Flow constructors (#536)
 - remove GoogleAiModels, stop exporting catalog enums, refresh the catalog (#524)
 - rename StatusCodes to StatusCode with lowerCamelCase values (#542)
 - remove embedMany in favor of embed (#535)
 - align naming of ToolFnArg, ModelInfo params and RemoteAction.close (#537)
 - generate plain JSON schema maps instead of json_schema_builder calls (#522)

### Features

 - discover gemini-embedding-* embedders and embed media (#394)
 - extend curated model catalog toward the JS/Go union (#513)

### Fixes

 - degrade list() to curated catalog on discovery failure (#512)
 - stop closing injected clients and honour late cancellation (#454)

### Other Changes

 - build the curated model list from the catalog map (#523)
 - add Genkit Dart agent skill install instructions to READMEs (#521)


## 0.3.2

### Features

 - curate and discover Gemma models (#438)


## 0.3.1

 - updated internal dependencies.

## 0.3.0

### Breaking Changes

 - redesign tool API around ToolResult + multipart, type actionType with ActionType (#350)


## 0.2.12

 - updated internal dependencies.

## 0.2.11

 - updated internal dependencies.

## 0.2.10

### Features

 - curated known-model metadata + P0 Gemini 3.x registrations (#320)
 - support Gemini and multimodal embedders (#261)

### Other Changes

 - model curated Gemini catalog as an enum (#323)


## 0.2.9

 - updated internal dependencies.

## 0.2.8

### Other Changes

 - update model references to gemini-flash-latest (#293)
 - split schemantic into runtime and schemantic_builder packages (#292)


## 0.2.7

 - updated internal dependencies.

## 0.2.6

 - updated internal dependencies.

## 0.2.5

 - updated internal dependencies.

## 0.2.4

 - updated internal dependencies.

## 0.2.3

 - updated internal dependencies.

## 0.2.2

 - updated internal dependencies.

## 0.2.1

 - updated internal dependencies.

## 0.2.0+1

 - Update a dependency to the latest release.

## 0.2.0

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: moved vertexAI plugin from genkit_google_genai into genkit_vertexai package (#202).

## 0.1.0

- Initial release. Extracted Vertex AI plugin implementation from `genkit_google_genai` into a standalone package.
