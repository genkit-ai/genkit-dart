<!--
Copyright 2025 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

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
