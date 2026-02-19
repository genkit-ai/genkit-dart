## 0.0.1-dev.16

 - **FIX**: correct string interpolation in `FormatException` messages.
 - **FEAT**: implemented/fixed tools calling and structured output for firebase_ai (#138).

## 0.0.1-dev.15

 - **FEAT**: implemented interrupt restart (#124).

## 0.0.1-dev.14

 - **FEAT**: Added `nullable` that makes any schema nullable (#93).

## 0.0.1-dev.13

 - **FIX**: Coerce `num` values to `double` for generated double fields during JSON parsing. (#65).
 - **FEAT**: Add `$GenerateResponse` type, refine schema types, and update generated class constructors to use `late final` and regular constructors. (#66).

## 0.0.1-dev.12

 - **REFACTOR**: Identify schema types using a new `Type.isSchema` getter instead of string-based checks.
 - **FEAT**: updated AnyOf support for union types in Schemantic, including helper class generation and schema type handling. (#62).

## 0.0.1-dev.11

> Note: This release has breaking changes.

 - **REFACTOR**: reimplement schema generation from extension types to classes, enhance `PartExtension` getters, and simplify `GenerateResponse` and tool invocation. (#53).
 - **FEAT**: Add support for specifying default values for schema fields and types, and generate them in the JSON Schema. (#61).
 - **FEAT**: `AnyOf` support and simplified license headers (#59).
 - **FEAT**: use combining builder and header option (#52).
 - **FEAT**: allow referencing other schemas when using `Schema` schematic (#46).
 - **BREAKING** **REFACTOR**: removed support for generation from jsb Schema defs (#48).
 - **BREAKING** **FEAT**: implement Schemantic API redesign with $ prefixed schema definitions and static `$schema` for unified schema access. (#60).


## 0.0.1-dev.9

> Note: This release has breaking changes.

 - **FEAT**: Enable schema generation from final Schema variables (#45).
 - **BREAKING** **REFACTOR**: renamed JsonExtensionType to SchemanticType (#44).

## 0.0.1-dev.8

## 0.0.1-dev.7

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: Refactor basic types into factory functions to support schema constraints (#34).

## 0.0.1-dev.6

> Note: This release has breaking changes.

 - **REFACTOR**: move the package-specific schema generator into a peer package (#31).
 - **FEAT**: Add specialized `StringField`, `IntegerField`, and `NumberField` annotations for detailed JSON schema constraint generation with type validation. (#32).
 - **DOCS**: add dynamic list and map type demonstrations.
 - **BREAKING** **REFACTOR**: renamed @Key annotation to @Field (#30).

## 0.0.1-dev.5

 - **REFACTOR**: make generated JsonExtensionType factory classes (*TypeFactory) private (#29).
 - **FEAT**: added support for defining listType and mapType in schemantic (#28).

## 0.0.1-dev.4

## 0.0.1-dev.3

## 0.0.1-dev.2

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: renamed genkit_schema_builder package to schemantic (#26).

## 0.0.1-dev.1

- Initial release.
