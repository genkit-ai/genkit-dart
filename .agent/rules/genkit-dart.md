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
*   Apply license headers when adding new files: `dart run tools/apply_license.dart`.
*   Do not modify `pubspec.lock` manually; let `melos bootstrap` or `dart pub get` handle it.

# Schema Framework

Genkit uses a custom schema framework via `package:genkit/schema.dart` (exported by `package:genkit/genkit.dart`).

## Definition

Define schemas using the `@GenkitSchema()` annotation:

```dart
import 'package:genkit/genkit.dart';
// or import 'package:genkit/schema.dart';

part 'my_file.schema.g.dart';

@GenkitSchema()
abstract class MyObjSchema {
  String get name;
  MySubObjSchema get subObj;
}

@GenkitSchema()
abstract class MySubObjSchema {
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
  inputType: MyObjType,
  fn: (input, _) async {
    print(input.name); // Typed access
    ...
  }
);
```
