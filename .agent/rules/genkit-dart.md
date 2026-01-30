---
trigger: always_on
---

This is the Genkit Dart monorepo.

# Structure

The repository is managed using [Melos](https://melos.invertase.dev/).

*   `packages/`: Contains all published packages.
    *   `genkit`: Core framework.
        *   `lib/src`: Internal implementation.
        *   `lib/genkit.dart`: Main entrypoint.
    *   `genkit_...`: First-party plugins (e.g., `genkit_google_genai`, `genkit_firebase_ai`, `genkit_shelf`).
*   `testapps/`: Integration tests and specific test applications.
*   `melos.yaml`: Workspace configuration.
*   `tools/`: Helper scripts (e.g. license headers).

# Development

*   **Setup**: Run `melos bootstrap` to link packages.
*   **Testing**: Run `melos run test` to run all tests, or `dart test` inside a specific package.
*   **Formatting**: Run `dart format .` or use your IDE.
*   **Analysis**: Run `melos run analyze`.
*   **Code Generation**: Genkit uses `build_runner` for serialization and schemas.
    *   Whole repo: `melos run build-gen` (runs in order: core -> plugins -> apps)
    *   Single package: `dart run build_runner build`

# Best Practices

*   Always run `melos run analyze` to verify code health.
*   Do not modify `pubspec.lock` manually; let `melos bootstrap` or `dart pub get` handle it.

# Schema Framework

Genkit uses a custom schema framework via `package:genkit/schema.dart` (exported by `package:genkit/genkit.dart`).

## Definition

Using `schemantic` package (see packages/schemantic). Define schemas using the `@Schematic()` annotation:

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

## Generation

Run the generator:
```bash
dart run build_runner build
```

This generates `MyObj` (data class), `MyObjType` (type token), and schema definitions.

## Usage

Use the generated `*Type` classes when defining flows, actions, or tools:

```dart
ai.defineFlow(
  name: 'my-flow',
  inputSchema: MyObj.$schema,
  fn: (input, _) async {
    print(input.name); // Typed access
    ...
  }
);
```