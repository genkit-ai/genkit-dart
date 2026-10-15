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
