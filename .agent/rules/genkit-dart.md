---
trigger: always_on
---

This is the Genkit Dart monorepo.

# Structure

The repository is managed using [Melos](https://melos.invertase.dev/).

*   `packages/`: Contains all published packages.
    *   `genkit`: Core framework.
        *   `lib/src`: Internal implementation. It's split into core, ai
        *   `lib/genkit.dart`: Main entrypoint.
    *   `genkit_...`: First-party "plugins" (e.g., `genkit_google_genai`, `genkit_firebase_ai`, `genkit_shelf`).
    * `schemantic`: Zod or pydantic like library for Dart. It's considered general purpose and not Genkit specific, treat it as such.
    * `_schema_generator`: generates schemantic schemas from Genkit types (defined as JSON schema) into packages/genkit/lib/src/types.dart
*   `testapps/`: Integration tests and specific test applications.
*   `melos.yaml`: Workspace configuration.
*   `tools/`: Helper scripts (e.g. license headers).

# Development

*   **Formatting**: Run `dart format .` or use your IDE.
*   **Analysis**: Run `melos run analyze` or `dart analyze` for individual packages .
*   **Code Generation**: Genkit uses `build_runner` for serialization and schemas.
    *   Whole repo: `melos run build-gen` (runs in order: core -> plugins -> apps)
    *   Single package: `dart run build_runner build`

# Best Practices

*   Always run `melos run analyze` and  `melos run test` to verify code health at the end.
*   Apply license headers when adding new files: `dart run tools/apply_license.dart`.
*   Do not modify `pubspec.lock` manually; let `melos bootstrap` or `dart pub get` handle it.

# Schemantic

Using `schemantic` package (see packages/schemantic). Defines schemas using the `@Schematic()` annotation,the abstract class name must start with $.

If ever encountering schemantic schemas (classes starting with $ or Blah.$schema) check out packages/schemantic/README.md

## Basic usage

```dart
import 'package:schemantic/schemantic.dart';

part 'my_file.g.dart';

@Schematic()
abstract class $MyObj {
  String get name;
  $MySubObj get subObj;
}

@Schematic()
abstract class $MySubObj {
  String get foo;
}
```

in addition to beinable to generate object schemas from abstract classes schemantic has conveninent helpers for basic types: stringSchema, voidSchema, dynamicSchema, listSchema, mapSchema.

## Generation

Run the generator:
```bash
dart run build_runner build
```

This generates `MyObj` (data class), which has `MyObj.$schema` (`SchemanticType<MyObj>`) schema definitions which can be used to get json schema (`MyObj.$schema.jsonSchema()` which returns json_schema_builder Schema extension type). `MyObj` has a regular constructor (`MyObj(name: 'blah', subObj: MySubObj(foo: 'blah'))`) and a factory `MyObj.fromJson({..json.})`.

## Usage

Use the generated `$schema` when defining flows, actions, or tools, etc.:

```dart
ai.defineFlow(
  name: 'my-flow',
  inputSchema: MyObj.$schema,
  outputSchema: stringSchema(),
  fn: (input, _) async {
    print(input.name); // Typed access
    ...
  }
);
```