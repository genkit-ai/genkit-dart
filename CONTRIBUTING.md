# Contributing

## Setup
1. Install the [Dart SDK](https://dart.dev/get-dart) (^3.8.0).
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
- **Code Generation**: Run `dart run build_runner build` in packages that use it (e.g. `genkit`).

## Requirements
- All tests must pass.
- Code must be formatted and lint-free.
