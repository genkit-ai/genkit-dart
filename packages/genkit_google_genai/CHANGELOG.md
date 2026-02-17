## 0.0.1-dev.13

> Note: This release has breaking changes.

 - **REFACTOR**: remove detailed token usage arrays from usage metadata and add tests for usage extraction. (#127).
 - **FEAT**: Implemented real-time tracing (#128).
 - **BREAKING** **REFACTOR**: generate api cleanup (#125).

## 0.0.1-dev.12

 - **FEAT**: added support for embedders (embedding models) (#88).

## 0.0.1-dev.11

> Note: This release has breaking changes.

 - **FIX**: Coerce `num` values to `double` for generated double fields during JSON parsing. (#65).
 - **FEAT**: add Google Search and multi-speaker voice config support, extract usage metadata, and introduce reasoning parts (#82).
 - **FEAT**: Add `$GenerateResponse` type, refine schema types, and update generated class constructors to use `late final` and regular constructors. (#66).
 - **FEAT**: added schemas for gemini models, made sure TTS and nano banana models are working (#63).
 - **BREAKING** **REFACTOR**: update GenkitException to use a StatusCodes enum instead of raw integer status codes. (#68).

## 0.0.1-dev.10

 - **FEAT**: updated AnyOf support for union types in Schemantic, including helper class generation and schema type handling. (#62).

## 0.0.1-dev.9

> Note: This release has breaking changes.

 - **REFACTOR**: reimplement schema generation from extension types to classes, enhance `PartExtension` getters, and simplify `GenerateResponse` and tool invocation. (#53).
 - **FEAT**: Add support for specifying default values for schema fields and types, and generate them in the JSON Schema. (#61).
 - **FEAT**: use combining builder and header option (#52).
 - **BREAKING** **FEAT**: implement Schemantic API redesign with $ prefixed schema definitions and static `$schema` for unified schema access. (#60).

## 0.0.1-dev.8

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: renamed JsonExtensionType to SchemanticType (#44).

## 0.0.1-dev.7

 - **REFACTOR**: Consolidate Google GenAI examples into a single file, fixed tools calling, and schema flattening helper (#43).
 - **FEAT**: implemented streaming and various config options for genkit_google_genai plugin (#42).

## 0.0.1-dev.6

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: Refactor basic types into factory functions to support schema constraints (#34).

## 0.0.1-dev.5

 - **REFACTOR**: move the package-specific schema generator into a peer package (#31).

## 0.0.1-dev.4

 - **REFACTOR**: make generated JsonExtensionType factory classes (*TypeFactory) private (#29).
 - **FEAT**: added support for defining listType and mapType in schemantic (#28).

## 0.0.1-dev.3

> Note: This release has breaking changes.

 - **FEAT**: bump analyzer dependency (#25).
 - **FEAT**: added support for schema refs/defs in the schema generator (#22).
 - **BREAKING** **REFACTOR**: renamed genkit_schema_builder package to schemantic (#26).

## 0.0.1-dev.2

 - Update a dependency to the latest release.

## 0.0.1-dev.1

- Initial release.
