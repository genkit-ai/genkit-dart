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
- New files must include license headers. Run:
  ```bash
  dart run tools/apply_license.dart
  ```

## Releasing

Versions, changelogs, and tags are produced by `tools/version.dart` from
conventional commits, usually through the "Version bump" GitHub workflow
(`.github/workflows/version.yml`), which takes the same options.

```bash
dart run tools/version.dart --rc rc --dry-run   # preview
dart run tools/version.dart --rc rc             # 1.2.0 -> 1.3.0-rc.1, then rc.2, ...
dart run tools/version.dart --graduate          # 1.3.0-rc.2 -> 1.3.0
dart run tools/version.dart                     # direct stable release
```

**Floors.** The `floors:` section of `packages.yaml` sets minimum versions. A
package below its floor is bumped to it (or to `<floor>-rc.1` with `--rc`) even
without new commits. This is how packages are moved to a new major, for example
0.x to 1.0.0. Once reached, a floor does nothing and can be deleted.

**Majors.** A breaking commit (`!` or `BREAKING CHANGE`) that touches a >=1.0
package would bump it to a new major. The tool refuses to do that unless
`--allow-major` is passed (the `allow-major` workflow input). Commits are
attributed by path, not scope, so check which commits it lists.
