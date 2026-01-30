## 0.0.1-dev.11

> Note: This release has breaking changes.

 - **BREAKING**: Rename `NumberField` to `DoubleField` for consistency.

## 0.0.1-dev.10

- Add `anyOf` support.
- Allow header input for the `build_runner` builder.

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
