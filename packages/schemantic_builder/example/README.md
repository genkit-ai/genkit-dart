# schemantic_builder example

`schemantic_builder` is a development-time code generator used together with the
runtime [`schemantic`](https://pub.dev/packages/schemantic) package and
`build_runner`. You never import `schemantic_builder` directly; instead it runs
as part of the `build_runner` pipeline to generate the `*.g.dart` part files.

## 1. Add the dependencies

```sh
dart pub add schemantic
dart pub add dev:schemantic_builder
dart pub add dev:build_runner
```

## 2. Define a schema

Create `lib/user.dart` with an abstract class annotated with `@Schema`:

```dart
import 'package:schemantic/schemantic.dart';

part 'user.g.dart';

@Schema()
abstract class $User {
  @StringField(minLength: 1)
  String get name;
  int? get age;
  bool get isAdmin;
}
```

## 3. Run the generator

```sh
dart run build_runner build
```

This produces `lib/user.g.dart`, containing a concrete `User` class with
constructors, `toJson`/`parse`, and a runtime-accessible `User.$schema`.

## 4. Use the generated code

```dart
import 'user.dart';

void main() {
  final user = User(name: 'Alice', age: 30, isAdmin: true);
  print(user.toJson());

  // Access the generated JSON Schema at runtime.
  print(User.$schema.jsonSchema());
}
```

For a complete, runnable example of the generated runtime API, see the
[`schemantic` package example](https://pub.dev/packages/schemantic/example).
