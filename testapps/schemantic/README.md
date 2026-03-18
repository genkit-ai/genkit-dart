# Bring Your Own Types (BYOT) Sample

This sample demonstrates how to use the Bring Your Own Types (BYOT) pattern to integrate external serialization libraries (like `json_serializable`) with Genkit Dart.

## Prerequisites

This sample uses `json_serializable` 6.13.0, which added support for JSON Schema generation.

## Setup

1.  Run `dart pub get`.
2.  Run `dart run build_runner build` to generate the `json_serializable` code and JSON Schemas.

## How it works

The `Person` class in `lib/person.dart` is annotated with `@JsonSerializable(createJsonSchema: true)`. This generates a `_$PersonJsonSchema` constant alongside the usual `fromJson`/`toJson` methods.

We then use `SchemanticType.from` to bridge it into Genkit:

```dart
static final schema = SchemanticType.from<Person>(
  jsonSchema: Person.jsonSchema,
  parse: (json) => Person.fromJson(json as Map<String, dynamic>),
);
```

## Running the sample

Run the main file:

```bash
dart run bin/main.dart
```

Or run the tests:

```bash
dart test
```
