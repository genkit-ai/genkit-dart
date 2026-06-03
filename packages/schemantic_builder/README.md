[![Pub](https://img.shields.io/pub/v/schemantic_builder.svg)](https://pub.dev/packages/schemantic_builder)

The code generator for [`schemantic`](https://pub.dev/packages/schemantic). It
generates type-safe data classes and runtime-accessible JSON Schemas from
abstract class definitions annotated with `@Schema`.

This package is a development-time dependency. The runtime API lives in the
`schemantic` package.

## Installation

Add `schemantic` as a regular dependency, and `schemantic_builder` plus
`build_runner` as dev dependencies:

```sh
dart pub add schemantic
dart pub add dev:schemantic_builder
dart pub add dev:build_runner
```

## Usage

1. Define your schema using the `@Schema` annotation from `package:schemantic`:

```dart
import 'package:schemantic/schemantic.dart';

part 'user.g.dart';

@Schema()
abstract class $User {
  String get name;
  int? get age;
  bool get isAdmin;
}
```

2. Run the build runner to generate the implementation:

```sh
dart run build_runner build
```

See the [`schemantic` README](https://pub.dev/packages/schemantic) for full
documentation on the generated APIs.
