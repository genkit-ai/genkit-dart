## 1.0.0

### Breaking Changes

 - move converters and Live helpers to lib/src and stop exporting them (#716)
 - report Live sessions the server closes, and receive errors (#677)
 - send tool input schemas verbatim as parametersJsonSchema (#666)
 - map Gemini finish reasons to Genkit vocabulary (#608)
 - map Firebase AI and HTTP errors to GenkitException with a status code (#615)
 - remove unsupported responseLogprobs and logprobs from GeminiOptions (#606)
 - send output schema verbatim as responseJsonSchema; forward the option (#612)

### Migrating from 0.4

 - **Converters are private (#716).** `toGemini*`, `fromGemini*`,
   `extractUsage`, `runLiveSession`, `toLiveGenerationConfig` and the other
   converter and Live helpers are no longer exported. Call models through
   `firebaseAI` with `ai.generate` or `ai.generateBidi`.
 - **Errors are `GenkitException`s (#615).** The model throws a
   `GenkitException` with a `status` instead of `firebase_ai` exceptions, so
   `on QuotaExceeded catch (e)` and `response.cause is QuotaExceeded` no longer
   match. Check `status` (for example `StatusCode.resourceExhausted`) instead.
   The `firebase_ai` exception, when there is one, is the `cause` of the
   `GenkitException`.
 - **Finish reasons use Genkit's names (#608).** `maxTokens` is now `length`,
   `safety` is `blocked`, `malformedFunctionCall` is `other`, and values
   `firebase_ai` can't parse are `unknown`. Compare against the `FinishReason`
   constants. The value `firebase_ai` parsed is in `custom['finishReason']`.
 - **Schemas go to Gemini unchanged (#612, #666).** Output schemas are sent as
   `responseJsonSchema` and tool input schemas as `parametersJsonSchema`,
   instead of being converted to OpenAPI-style schemas. Keywords that used to be
   dropped (`enum`, `oneOf`, `additionalProperties`, `default`, `$ref` and
   more) now reach the model, and only the fields in `required` are required.
   The same schema can produce different output, so check prompts that relied
   on every field being filled in.
 - **`logprobs` and `responseLogprobs` are removed from `GeminiOptions`
   (#606).** Firebase AI Logic never sent them. Remove them from your config.
 - **Live sessions report errors (#677).** A session the server closes, even
   with a normal close code, now ends with a `GenkitException` carrying the
   server's reason instead of `finishReason: stop`. A system message sent after
   the first request fails with `INVALID_ARGUMENT`; put system instructions in
   the first request.

### Features

 - add speechConfig, imageConfig and mediaResolution to GeminiOptions (#669)
 - add Google Search, URL context and Google Maps grounding (#668)
 - abort in-flight requests on cancellation (#667)
 - give each known model its own label, stage and capabilities (#671)
 - add safetySettings to GeminiOptions (#665)
 - register the Firebase AI Logic model list in init() (#670)
 - expose GeminiOptions as the generate models' options (#678)
 - allow firebase_ai 5.x (#673)
 - add thinkingLevel for Gemini 3.x; replace deprecated ThinkingConfig() (#614)

### Fixes

 - report a malformed data: URL as INVALID_ARGUMENT (#697)
 - send every Live system message as systemInstruction (#681)
 - report unsupported parts as INVALID_ARGUMENT (#679)
 - reject streaming with candidateCount > 1 (#676)
 - leave absent token counts null instead of 0 (#675)
 - send system messages as systemInstruction (#605)
 - map code execution, file and unknown response parts instead of throwing (#607)
 - map thoughts, cached and tool-use token counts into usage (#604)
 - surface prompt block reason instead of StateError on empty candidates (#613)
 - parse Live config through its schema and route media by type (#651)
 - keep thought signatures when aggregating streamed parts (#650)
 - omit responseMimeType when it is not set (#649)
 - close the per-request http.Client when none is passed (#648)

### Other Changes

 - document gemini-3.8-live on Agent Platform with a regional location (#723)
 - refresh README for App Check enforcement, models and options (#664)
 - note that Gemini 3 ignores or rejects the sampling options (#674)


## 0.4.0

### Breaking Changes

 - replace vertexAI with agentPlatform; drop appCheck and auth params (#609)

### Features

 - add httpClient parameter and wire-test harness (#602)

### Fixes

 - allow firebase_ai 4.x (#601)

### Other Changes

 - remove temporary analyzer pin (#634)


## 0.3.0

### Breaking Changes

 - type usage counts and indexes as int (#546)
 - non-null input for Model/Embedder/Evaluator/Flow constructors (#536)
 - generate plain JSON schema maps instead of json_schema_builder calls (#522)
 - make constrained generation simulation an opt-in middleware (#519)
 - simulate constrained generation when a model lacks native support (#453)

### Fixes

 - stop pre-registering the retired gemini-2.5-pro (#509)
 - honor the portable toolChoice option (#496)

### Other Changes

 - temporarily pin analyzer below 14.5.0 (#625)
 - add Genkit Dart agent skill install instructions to READMEs (#521)
 - add example/ programs to genkit_chrome, genkit_firebase_ai, genkit_google_cloud (#505)


## 0.2.2

### Breaking Changes

 - move live/bidi model surface to experimental (#461)


## 0.2.1

 - updated internal dependencies.

## 0.2.0

### Breaking Changes

 - redesign tool API around ToolResult + multipart, type actionType with ActionType (#350)


## 0.1.14

### Fixes

 - map tool role to "user" for Gemini API compatibility (#340)


## 0.1.13

### Fixes

 - normalize nested models to JSON in generated setters (#337)


## 0.1.12

### Features

 - agent & session schema types (1/8) (#310)


## 0.1.11

### Features

 - Support Vertex AI Gemini API (#296)


## 0.1.10

 - updated internal dependencies.

## 0.1.9

### Other Changes

 - update model references to gemini-flash-latest (#293)
 - split schemantic into runtime and schemantic_builder packages (#292)


## 0.1.8

 - updated internal dependencies.

## 0.1.7

### Features

 - generate docs for generated schemantic types (#274)


## 0.1.6

### Features

 - add additionalProperties support to @Schema and implement strict object validation (#251)


## 0.1.5

 - updated internal dependencies.

## 0.1.4

 - updated internal dependencies.

## 0.1.3

 - updated internal dependencies.

## 0.1.2

 - updated internal dependencies.

## 0.1.1+1

 - Update a dependency to the latest release.

## 0.1.1

 - bump missed genkit and schemantic versions.

## 0.1.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.0.1-dev.3

- Updated dependencies.

## 0.0.1-dev.2

- Implemented/fixed tool calling and structured output for Gemini models.

## 0.0.1-dev.1

- Initial release.
