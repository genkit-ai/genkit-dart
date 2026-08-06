# Contributing

## Setup
1. Install the [Dart SDK](https://dart.dev/get-dart) (^3.10.0).
2. Activate Melos:
   ```bash
   dart pub global activate melos
   ```
3. Bootstrap the workspace:
   ```bash
   melos bootstrap
   ```

## Development
- **Testing**: `melos run test`
- **Linting**: `melos run analyze`
- **Formatting**: `dart format .`
- **Code Generation**: Run `melos run build-gen` from the repository root. CI
  regenerates committed sources with the current stable Dart SDK; compatibility
  jobs test those committed sources without regenerating SDK-dependent output.

## Requirements
- All tests must pass.
- Code must be formatted and lint-free.
- New files must include license headers. Run:
  ```bash
  dart run tools/apply_license.dart
  ```
