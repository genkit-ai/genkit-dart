[![Pub](https://img.shields.io/pub/v/schemantic.svg)](https://pub.dev/packages/schemantic)

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

part 'user.g.dart';

@Schematic()
@Schematic()
abstract class $User {
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

This will generate a `user.g.dart` file containing:
- `User`: The concrete data class, which includes a static `$schema` field for accessing schema information.

### 3. Use the Generated Types

You can now use the generated `User` class:

```dart
void main() async {
  // Create an instance using the generated class
  final user = User(
    name: 'Alice',
    age: 30,
    isAdmin: true,
  );

  // Serialize to JSON
  print(user.toJson()); 
  // Output: {name: Alice, age: 30, isAdmin: true}

  // Parse from JSON
  final parsed = User.fromJson({
    'name': 'Bob',
    'isAdmin': false,
  });
  print(parsed.name); // Bob

  // Access JSON Schema at runtime
  final schema = User.$schema.jsonSchema;
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
abstract class $Node {
  String get id;
  List<$Node>? get children;
}
```

```dart
void main() {
  // Must use useRefs: true for recursive schemas
  final schema = Node.$schema.jsonSchema;
  
  print(schema.toJson());
  // Generates schema with "$ref": "#/$defs/Node"
}
```

### Basic & Dynamic Types

Schemantic provides a set of basic types and helpers for creating dynamic schemas without generating code.

#### Primitives
- `stringSchema()`
- `intSchema()`
- `doubleSchema(`
- `boolSchema()`
- `voidSchema()`

#### `listSchema` and `mapSchema`

You can create strongly typed Lists and Maps dynamically:

```dart
void main() {
  // Define a List of Strings
  final stringList = listSchema(stringSchema());
  print(stringList.parse(['a', 'b'])); // ['a', 'b']

  // Define a Map with String keys and Integer values
  final scores = mapSchema(stringSchema(), intSchema());
  print(scores.parse({'Alice': 100, 'Bob': 80})); // {'Alice': 100, 'Bob': 80}

  // Nesting types
  final matrix = listSchema(listSchema(intSchema()));
  print(matrix.parse([[1, 2], [3, 4]])); // [[1, 2], [3, 4]]
  
  // JSON Schema generation works as expected
  print(scores.jsonSchema().toJson());
  // {type: object, additionalProperties: {type: integer}}
}

## Schema Metadata

You can add a description to your generated schema using the `description` parameter in `@Schematic`:

```dart
@Schematic(description: 'Represents a user in the system')
abstract class $User {
  // ...
}
```

### Enhanced Collections

You can use `listSchema` and `mapSchema` to create collections with metadata and validation:

```dart
// A list of strings with description and size constraints.
final tags = listSchema(
  stringSchema(),
  description: 'A list of tags',
  minItems: 1,
  maxItems: 10,
  uniqueItems: true,
);

// A map with integer values.
final scores = mapSchema(
  stringSchema(),
  intSchema(),
  description: 'Player scores',
  minProperties: 1,
);
```

### Basic Types

Schemantic provides factories for basic types with optional metadata:

- `stringSchema({String? description, int? minLength, ...})`
- `intSchema({String? description, int? minimum, ...})`
- `doubleSchema({String? description, double? minimum, ...})`
- `boolSchema({String? description})`
- `dynamicSchema({String? description})`

Example:

final age = intSchema(
  description: 'Age in years',
  minimum: 0,
);

- `@Field`: Basic customization (name, description).
- `@StringField`: Constraints for strings (minLength, maxLength, pattern, format, enumValues).
- `@IntegerField`: Constraints for integers (minimum, maximum, multipleOf).
- `@DoubleField`: Constraints for doubles/numbers (minimum, maximum, multipleOf).

```dart
@Schematic()
abstract class $User {
  // Map 'age' to 'years_old' in JSON, and add validation
  @IntegerField(
    name: 'years_old', 
    description: 'Age of the user',
    minimum: 0,
    maximum: 120
  )
  int? get age;

  @DoubleField(minimum: 0.0, maximum: 100.0)
  double get score;

  @StringField(
    minLength: 2,
    maxLength: 50,
    pattern: r'^[a-zA-Z\s]+$',
    enumValues: ['user', 'admin'] // Mapped to 'enum' in JSON Schema
  )
  String get role;
}
```

Validation matches the Dart type (e.g., using `@StringField` on an `int` getter will throw a build-time error).

