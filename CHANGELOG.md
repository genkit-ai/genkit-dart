# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-02-17

### Changes

---

Packages with breaking changes:

 - [`genkit` - `v0.10.0-dev.13`](#genkit---v0100-dev13)
 - [`genkit_anthropic` - `v0.0.1-dev.4`](#genkit_anthropic---v001-dev4)
 - [`genkit_google_genai` - `v0.0.1-dev.13`](#genkit_google_genai---v001-dev13)

Packages with other changes:

 - [`genkit_chrome` - `v0.0.1-dev.4`](#genkit_chrome---v001-dev4)
 - [`genkit_mcp` - `v0.0.1-dev.2`](#genkit_mcp---v001-dev2)
 - [`genkit_middleware` - `v0.0.1-dev.2`](#genkit_middleware---v001-dev2)
 - [`genkit_openai` - `v0.0.1-dev.2`](#genkit_openai---v001-dev2)
 - [`schemantic` - `v0.0.1-dev.15`](#schemantic---v001-dev15)
 - [`genkit_shelf` - `v0.0.1-dev.13`](#genkit_shelf---v001-dev13)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `genkit_shelf` - `v0.0.1-dev.13`

---

#### `genkit` - `v0.10.0-dev.13`

 - **FIX**: Wrap error responses in a JSON object under an 'error' key (#130).
 - **FEAT**: Implemented real-time tracing (#128).
 - **FEAT**: created a genkit_middleware package with skills, filesystem and toolApproval middleware (#126).
 - **FEAT**: add MCP (Model Context Protocol) plugin (#94).
 - **FEAT**: implemented interrupt restart (#124).
 - **BREAKING** **REFACTOR**: generate api cleanup (#125).

#### `genkit_anthropic` - `v0.0.1-dev.4`

 - **BREAKING** **REFACTOR**: generate api cleanup (#125).

#### `genkit_google_genai` - `v0.0.1-dev.13`

 - **REFACTOR**: remove detailed token usage arrays from usage metadata and add tests for usage extraction. (#127).
 - **FEAT**: Implemented real-time tracing (#128).
 - **BREAKING** **REFACTOR**: generate api cleanup (#125).

#### `genkit_chrome` - `v0.0.1-dev.4`

 - **FEAT**: add language config options to Chrome plugin (#123).

#### `genkit_mcp` - `v0.0.1-dev.2`

 - **FEAT**: add MCP (Model Context Protocol) plugin (#94).

#### `genkit_middleware` - `v0.0.1-dev.2`

 - **FEAT**: add initial CHANGELOG.md for genkit_middleware.
 - **FEAT**: created a genkit_middleware package with skills, filesystem and toolApproval middleware (#126).

#### `genkit_openai` - `v0.0.1-dev.2`

 - **REFACTOR**: minor cleanup for the new openai plugin (#129).
 - **FEAT**(plugins): add OpenAI plugin (#95).

#### `schemantic` - `v0.0.1-dev.15`

 - **FEAT**: implemented interrupt restart (#124).


## 2026-02-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`genkit` - `v0.10.0-dev.12`](#genkit---v0100-dev12)
 - [`genkit_chrome` - `v0.0.1-dev.3`](#genkit_chrome---v001-dev3)
 - [`genkit_google_genai` - `v0.0.1-dev.12`](#genkit_google_genai---v001-dev12)
 - [`schemantic` - `v0.0.1-dev.14`](#schemantic---v001-dev14)
 - [`genkit_anthropic` - `v0.0.1-dev.3`](#genkit_anthropic---v001-dev3)
 - [`genkit_shelf` - `v0.0.1-dev.12`](#genkit_shelf---v001-dev12)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `genkit_anthropic` - `v0.0.1-dev.3`
 - `genkit_shelf` - `v0.0.1-dev.12`

---

#### `genkit` - `v0.10.0-dev.12`

 - **FEAT**: introducing registered middleware (#87).
 - **FEAT**: added support for embedders (embedding models) (#88).

#### `genkit_chrome` - `v0.0.1-dev.3`

 - **FEAT**: more complete implementation of the Chrome API (#97).
 - **FEAT**: added readme to genkit_chrome (#96).

#### `genkit_google_genai` - `v0.0.1-dev.12`

 - **FEAT**: added support for embedders (embedding models) (#88).

#### `schemantic` - `v0.0.1-dev.14`

 - **FEAT**: Added `nullable` that makes any schema nullable (#93).


## 2026-02-04

### Changes

---

Packages with breaking changes:

 - [`genkit` - `v0.10.0-dev.11`](#genkit---v0100-dev11)
 - [`genkit_google_genai` - `v0.0.1-dev.11`](#genkit_google_genai---v001-dev11)
 - [`genkit_shelf` - `v0.0.1-dev.11`](#genkit_shelf---v001-dev11)

Packages with other changes:

 - [`genkit_anthropic` - `v0.0.1-dev.2`](#genkit_anthropic---v001-dev2)
 - [`schemantic` - `v0.0.1-dev.13`](#schemantic---v001-dev13)
 - [`genkit_chrome` - `v0.0.1-dev.2`](#genkit_chrome---v001-dev2)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `genkit_chrome` - `v0.0.1-dev.2`

---

#### `genkit` - `v0.10.0-dev.11`

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

#### `genkit_google_genai` - `v0.0.1-dev.11`

 - **FIX**: Coerce `num` values to `double` for generated double fields during JSON parsing. (#65).
 - **FEAT**: add Google Search and multi-speaker voice config support, extract usage metadata, and introduce reasoning parts (#82).
 - **FEAT**: Add `$GenerateResponse` type, refine schema types, and update generated class constructors to use `late final` and regular constructors. (#66).
 - **FEAT**: added schemas for gemini models, made sure TTS and nano banana models are working (#63).
 - **BREAKING** **REFACTOR**: update GenkitException to use a StatusCodes enum instead of raw integer status codes. (#68).

#### `genkit_shelf` - `v0.0.1-dev.11`

 - **BREAKING** **REFACTOR**: update GenkitException to use a StatusCodes enum instead of raw integer status codes. (#68).

#### `genkit_anthropic` - `v0.0.1-dev.2`

 - **REFACTOR**: renamed anthropic.claude to model.
 - **FEAT**: added anthropic plugin (#86).

#### `schemantic` - `v0.0.1-dev.13`

 - **FIX**: Coerce `num` values to `double` for generated double fields during JSON parsing. (#65).
 - **FEAT**: Add `$GenerateResponse` type, refine schema types, and update generated class constructors to use `late final` and regular constructors. (#66).


## 2026-01-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`genkit` - `v0.10.0-dev.10`](#genkit---v0100-dev10)
 - [`genkit_google_genai` - `v0.0.1-dev.10`](#genkit_google_genai---v001-dev10)
 - [`genkit_shelf` - `v0.0.1-dev.10`](#genkit_shelf---v001-dev10)
 - [`schemantic` - `v0.0.1-dev.12`](#schemantic---v001-dev12)

---

#### `genkit` - `v0.10.0-dev.10`

 - **FEAT**: updated AnyOf support for union types in Schemantic, including helper class generation and schema type handling. (#62).

#### `genkit_google_genai` - `v0.0.1-dev.10`

 - **FEAT**: updated AnyOf support for union types in Schemantic, including helper class generation and schema type handling. (#62).

#### `genkit_shelf` - `v0.0.1-dev.10`

 - **FEAT**: updated AnyOf support for union types in Schemantic, including helper class generation and schema type handling. (#62).

#### `schemantic` - `v0.0.1-dev.12`

 - **REFACTOR**: Identify schema types using a new `Type.isSchema` getter instead of string-based checks.
 - **FEAT**: updated AnyOf support for union types in Schemantic, including helper class generation and schema type handling. (#62).


## 2026-01-29

### Changes

---

Packages with breaking changes:

 - [`genkit` - `v0.10.0-dev.9`](#genkit---v0100-dev9)
 - [`genkit_google_genai` - `v0.0.1-dev.9`](#genkit_google_genai---v001-dev9)
 - [`genkit_shelf` - `v0.0.1-dev.9`](#genkit_shelf---v001-dev9)
 - [`schemantic` - `v0.0.1-dev.11`](#schemantic---v001-dev11)

Packages with other changes:

 - There are no other changes in this release.

---

#### `genkit` - `v0.10.0-dev.9`

 - **REFACTOR**: reimplement schema generation from extension types to classes, enhance `PartExtension` getters, and simplify `GenerateResponse` and tool invocation. (#53).
 - **FEAT**: use combining builder and header option (#52).
 - **BREAKING** **FEAT**: implement Schemantic API redesign with $ prefixed schema definitions and static `$schema` for unified schema access. (#60).

#### `genkit_google_genai` - `v0.0.1-dev.9`

 - **REFACTOR**: reimplement schema generation from extension types to classes, enhance `PartExtension` getters, and simplify `GenerateResponse` and tool invocation. (#53).
 - **FEAT**: Add support for specifying default values for schema fields and types, and generate them in the JSON Schema. (#61).
 - **FEAT**: use combining builder and header option (#52).
 - **BREAKING** **FEAT**: implement Schemantic API redesign with $ prefixed schema definitions and static `$schema` for unified schema access. (#60).

#### `genkit_shelf` - `v0.0.1-dev.9`

 - **FEAT**: use combining builder and header option (#52).
 - **BREAKING** **FEAT**: implement Schemantic API redesign with $ prefixed schema definitions and static `$schema` for unified schema access. (#60).

#### `schemantic` - `v0.0.1-dev.11`

 - **REFACTOR**: reimplement schema generation from extension types to classes, enhance `PartExtension` getters, and simplify `GenerateResponse` and tool invocation. (#53).
 - **FEAT**: Add support for specifying default values for schema fields and types, and generate them in the JSON Schema. (#61).
 - **FEAT**: `AnyOf` support and simplified license headers (#59).
 - **FEAT**: use combining builder and header option (#52).
 - **FEAT**: allow referencing other schemas when using `Schema` schematic (#46).
 - **BREAKING** **REFACTOR**: removed support for generation from jsb Schema defs (#48).
 - **BREAKING** **FEAT**: implement Schemantic API redesign with $ prefixed schema definitions and static `$schema` for unified schema access. (#60).


## 2026-01-18

### Changes

---

Packages with breaking changes:

 - [`genkit` - `v0.10.0-dev.8`](#genkit---v0100-dev8)
 - [`genkit_google_genai` - `v0.0.1-dev.8`](#genkit_google_genai---v001-dev8)
 - [`genkit_shelf` - `v0.0.1-dev.8`](#genkit_shelf---v001-dev8)
 - [`schemantic` - `v0.0.1-dev.9`](#schemantic---v001-dev9)

Packages with other changes:

 - There are no other changes in this release.

---

#### `genkit` - `v0.10.0-dev.8`

 - **BREAKING** **REFACTOR**: renamed JsonExtensionType to SchemanticType (#44).

#### `genkit_google_genai` - `v0.0.1-dev.8`

 - **BREAKING** **REFACTOR**: renamed JsonExtensionType to SchemanticType (#44).

#### `genkit_shelf` - `v0.0.1-dev.8`

 - **BREAKING** **REFACTOR**: renamed JsonExtensionType to SchemanticType (#44).

#### `schemantic` - `v0.0.1-dev.9`

 - **FEAT**: Enable schema generation from final Schema variables (#45).
 - **BREAKING** **REFACTOR**: renamed JsonExtensionType to SchemanticType (#44).


## 2026-01-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`schemantic` - `v0.0.1-dev.8`](#schemantic---v001-dev8)

---

#### `schemantic` - `v0.0.1-dev.8`


## 2026-01-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`genkit` - `v0.10.0-dev.7`](#genkit---v0100-dev7)
 - [`genkit_google_genai` - `v0.0.1-dev.7`](#genkit_google_genai---v001-dev7)
 - [`genkit_shelf` - `v0.0.1-dev.7`](#genkit_shelf---v001-dev7)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `genkit_shelf` - `v0.0.1-dev.7`

---

#### `genkit` - `v0.10.0-dev.7`

 - **REFACTOR**: Consolidate Google GenAI examples into a single file, fixed tools calling, and schema flattening helper (#43).
 - **FEAT**: implemented streaming and various config options for genkit_google_genai plugin (#42).

#### `genkit_google_genai` - `v0.0.1-dev.7`

 - **REFACTOR**: Consolidate Google GenAI examples into a single file, fixed tools calling, and schema flattening helper (#43).
 - **FEAT**: implemented streaming and various config options for genkit_google_genai plugin (#42).


## 2026-01-16

### Changes

---

Packages with breaking changes:

 - [`genkit` - `v0.10.0-dev.6`](#genkit---v0100-dev6)
 - [`genkit_google_genai` - `v0.0.1-dev.6`](#genkit_google_genai---v001-dev6)
 - [`genkit_shelf` - `v0.0.1-dev.6`](#genkit_shelf---v001-dev6)
 - [`schemantic` - `v0.0.1-dev.7`](#schemantic---v001-dev7)

Packages with other changes:

 - There are no other changes in this release.

---

#### `genkit` - `v0.10.0-dev.6`

 - **BREAKING** **FEAT**: Refactor basic types into factory functions to support schema constraints (#34).

#### `genkit_google_genai` - `v0.0.1-dev.6`

 - **BREAKING** **FEAT**: Refactor basic types into factory functions to support schema constraints (#34).

#### `genkit_shelf` - `v0.0.1-dev.6`

 - **BREAKING** **FEAT**: Refactor basic types into factory functions to support schema constraints (#34).

#### `schemantic` - `v0.0.1-dev.7`

 - **BREAKING** **FEAT**: Refactor basic types into factory functions to support schema constraints (#34).


## 2026-01-16

### Changes

---

Packages with breaking changes:

 - [`genkit` - `v0.10.0-dev.5`](#genkit---v0100-dev5)
 - [`schemantic` - `v0.0.1-dev.6`](#schemantic---v001-dev6)

Packages with other changes:

 - [`genkit_google_genai` - `v0.0.1-dev.5`](#genkit_google_genai---v001-dev5)
 - [`genkit_shelf` - `v0.0.1-dev.5`](#genkit_shelf---v001-dev5)

---

#### `genkit` - `v0.10.0-dev.5`

 - **REFACTOR**: move the package-specific schema generator into a peer package (#31).
 - **BREAKING** **REFACTOR**: renamed @Key annotation to @Field (#30).

#### `schemantic` - `v0.0.1-dev.6`

 - **REFACTOR**: move the package-specific schema generator into a peer package (#31).
 - **FEAT**: Add specialized `StringField`, `IntegerField`, and `NumberField` annotations for detailed JSON schema constraint generation with type validation. (#32).
 - **DOCS**: add dynamic list and map type demonstrations.
 - **BREAKING** **REFACTOR**: renamed @Key annotation to @Field (#30).

#### `genkit_google_genai` - `v0.0.1-dev.5`

 - **REFACTOR**: move the package-specific schema generator into a peer package (#31).

#### `genkit_shelf` - `v0.0.1-dev.5`

 - **REFACTOR**: move the package-specific schema generator into a peer package (#31).


## 2026-01-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`genkit` - `v0.10.0-dev.4`](#genkit---v0100-dev4)
 - [`genkit_google_genai` - `v0.0.1-dev.4`](#genkit_google_genai---v001-dev4)
 - [`schemantic` - `v0.0.1-dev.5`](#schemantic---v001-dev5)
 - [`genkit_shelf` - `v0.0.1-dev.4`](#genkit_shelf---v001-dev4)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `genkit_shelf` - `v0.0.1-dev.4`

---

#### `genkit` - `v0.10.0-dev.4`

 - **REFACTOR**: make generated JsonExtensionType factory classes (*TypeFactory) private (#29).
 - **FEAT**: added support for defining listType and mapType in schemantic (#28).

#### `genkit_google_genai` - `v0.0.1-dev.4`

 - **REFACTOR**: make generated JsonExtensionType factory classes (*TypeFactory) private (#29).
 - **FEAT**: added support for defining listType and mapType in schemantic (#28).

#### `schemantic` - `v0.0.1-dev.5`

 - **REFACTOR**: make generated JsonExtensionType factory classes (*TypeFactory) private (#29).
 - **FEAT**: added support for defining listType and mapType in schemantic (#28).


## 2026-01-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`schemantic` - `v0.0.1-dev.4`](#schemantic---v001-dev4)

---

#### `schemantic` - `v0.0.1-dev.4`


## 2026-01-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`schemantic` - `v0.0.1-dev.3`](#schemantic---v001-dev3)

---

#### `schemantic` - `v0.0.1-dev.3`


## 2026-01-15

### Changes

---

Packages with breaking changes:

 - [`genkit` - `v0.10.0-dev.3`](#genkit---v0100-dev3)
 - [`genkit_google_genai` - `v0.0.1-dev.3`](#genkit_google_genai---v001-dev3)
 - [`genkit_shelf` - `v0.0.1-dev.3`](#genkit_shelf---v001-dev3)
 - [`schemantic` - `v0.0.1-dev.2`](#schemantic---v001-dev2)

Packages with other changes:

 - There are no other changes in this release.

---

#### `genkit` - `v0.10.0-dev.3`

 - **FEAT**: bump analyzer dependency (#25).
 - **FEAT**: added support for schema refs/defs in the schema generator (#22).
 - **BREAKING** **REFACTOR**: renamed genkit_schema_builder package to schemantic (#26).

#### `genkit_google_genai` - `v0.0.1-dev.3`

 - **FEAT**: bump analyzer dependency (#25).
 - **FEAT**: added support for schema refs/defs in the schema generator (#22).
 - **BREAKING** **REFACTOR**: renamed genkit_schema_builder package to schemantic (#26).

#### `genkit_shelf` - `v0.0.1-dev.3`

 - **FEAT**: bump analyzer dependency (#25).
 - **FEAT**: added support for schema refs/defs in the schema generator (#22).
 - **BREAKING** **REFACTOR**: renamed genkit_schema_builder package to schemantic (#26).

#### `schemantic` - `v0.0.1-dev.2`

 - **BREAKING** **REFACTOR**: renamed genkit_schema_builder package to schemantic (#26).


## 2026-01-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`genkit` - `v0.10.0-dev.2`](#genkit---v0100-dev2)
 - [`genkit_google_genai` - `v0.0.1-dev.2`](#genkit_google_genai---v001-dev2)
 - [`genkit_shelf` - `v0.0.1-dev.2`](#genkit_shelf---v001-dev2)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `genkit_google_genai` - `v0.0.1-dev.2`
 - `genkit_shelf` - `v0.0.1-dev.2`

---

#### `genkit` - `v0.10.0-dev.2`

 - **FIX**: register generate action with the correct name.
 - **FEAT**: implemented live api using firebase ai logic (#19).

