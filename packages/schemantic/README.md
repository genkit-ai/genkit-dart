# Schemantic

A general-purpose Dart library for generating type-safe data classes and runtime-accessible JSON Schemas from abstract class definitions.

## Features

- **Type-Safe Data Classes**: Generates fully-typed Dart data classes from simple abstract definitions.
- **Runtime JSON Schema**: Access the standard JSON Schema for any generated type at runtime.
- **Serialization**: Built-in `toJson` and `parse` methods.
- **Validation**: Validate JSON data against the generated schema at runtime.
- **Recursive Schemas**: Easy support for recursive data structures (e.g., trees) using `$ref`.

## Installation

Add `schemantic` and `build_runner` to your `pubspec.yaml`:

```sh
dart pub add schemantic
dart pub add dev:build_runner
```

## Usage

### 1. Define your specific Schema

Create a Dart file (e.g., `user.dart`) and define your schema as an abstract class annotated with `@Schematic()`.

```dart
import 'package:schemantic/schemantic.dart';

part 'user.schema.g.dart';

@Schematic()
abstract class UserSchema {
  String get name;
  int? get age;
  bool get isAdmin;
}
```

### 2. Generate Code

Run the build runner to generate the implementation:

```sh
dart run build_runner build
```

This will generate a `user.schema.g.dart` file containing:
- `User`: The concrete data class.
- `UserType`: A utility class for parsing, schema access, and validation.

### 3. Use the Generated Types

You can now use the generated `User` class and `UserType` utility:

```dart
void main() async {
  // Create an instance using the generated class
  final user = User.from(
    name: 'Alice',
    age: 30,
    isAdmin: true,
  );

  // Serialize to JSON
  print(user.toJson()); 
  // Output: {name: Alice, age: 30, isAdmin: true}

  // Parse from JSON
  final parsed = UserType.parse({
    'name': 'Bob',
    'isAdmin': false,
  });
  print(parsed.name); // Bob

  // Access JSON Schema at runtime
  final schema = UserType.jsonSchema();
  print(schema.toJson()); 
  // Output: {type: object, properties: {name: {type: string}, ...}, required: [name, isAdmin]}
  
  // Validate data
  final validation = await schema.validate({'name': 'Charlie'}); // Missing 'isAdmin'
  if (validation.isNotEmpty) {
    print('Validation errors: $validation');
  }
}
```

## Advanced

### Recursive Schemas

For recursive structures like trees, use the `useRefs: true` option when generating the schema. This utilizes JSON Schema `$ref` to handle recursion.

```dart
@Schematic()
abstract class NodeSchema {
  String get id;
  List<NodeSchema>? get children;
}
```

```dart
void main() {
  // Must use useRefs: true for recursive schemas
  final schema = NodeType.jsonSchema(useRefs: true);
  
  print(schema.toJson());
  // Generates schema with "$ref": "#/$defs/Node"
}
```

### Basic & Dynamic Types

Schemantic provides a set of basic types and helpers for creating dynamic schemas without generating code.

#### Primitives
- `StringType`
- `IntType`
- `DoubleType`
- `BoolType`
- `VoidType`

#### `listType` and `mapType`

You can create strongly typed Lists and Maps dynamically:

```dart
void main() {
  // Define a List of Strings
  final stringList = listType(StringType);
  print(stringList.parse(['a', 'b'])); // ['a', 'b']

  // Define a Map with String keys and Integer values
  final scores = mapType(StringType, IntType);
  print(scores.parse({'Alice': 100, 'Bob': 80})); // {'Alice': 100, 'Bob': 80}

  // Nesting types
  final matrix = listType(listType(IntType));
  print(matrix.parse([[1, 2], [3, 4]])); // [[1, 2], [3, 4]]
  
  // JSON Schema generation works as expected
  print(scores.jsonSchema().toJson());
  // {type: object, additionalProperties: {type: integer}}
}
```

### 4. Customizing Fields

You can use the `@Field` annotation to customize the JSON key name and add a description to the generated schema.

```dart
@Schematic()
abstract class UserSchema {
  // Map 'age' to 'years_old' in JSON, and add a description
  @Field(name: 'years_old', description: 'Age of the user')
  int? get age;
}
```

