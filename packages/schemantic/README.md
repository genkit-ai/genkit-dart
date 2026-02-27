[![Pub](https://img.shields.io/pub/v/schemantic.svg)](https://pub.dev/packages/schemantic)

A general-purpose Dart library for generating type-safe data classes and runtime-accessible JSON Schemas from abstract class definitions.

## Features

- **Type-Safe Data Classes**: Generates fully-typed Dart data classes from simple abstract definitions.
- **First-Class Schemas**: Schemas are first-class citizens: pass them as values (`SchemanticType<T>`), compose them, and inspect them at runtime—all while maintaining full static type safety.
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

### 1. Basic & Dynamic Types

Schemantic provides a set of basic types and helpers for creating dynamic schemas without generating code.

#### Primitives
- `SchemanticType.string({String? description, int? minLength, ...})`
- `SchemanticType.integer({String? description, int? minimum, ...})`
- `SchemanticType.doubleSchema({String? description, double? minimum, ...})`
- `SchemanticType.boolean({String? description})`
- `SchemanticType.voidSchema({String? description})`
- `SchemanticType.dynamicSchema({String? description})`

Example:

```dart
final age = SchemanticType.integer(
  description: 'Age in years',
  minimum: 0,
  defaultValue: 18,
);
```

#### Collections

You can create strongly typed Lists and Maps dynamically:

```dart
void main() {
  // Define a List of Strings
  final stringList = SchemanticType.list(.string());
  print(stringList.parse(['a', 'b'])); // ['a', 'b']

  // Define a Map with String keys and Integer values
  final scores = SchemanticType.map(.string(), .integer());
  print(scores.parse({'Alice': 100, 'Bob': 80})); // {'Alice': 100, 'Bob': 80}

  // Nesting types
  final matrix = SchemanticType.list(.list(.integer()));
  print(matrix.parse([[1, 2], [3, 4]])); // [[1, 2], [3, 4]]
  
  // JSON Schema generation works as expected
  print(scores.jsonSchema().toJson());
  // {type: object, additionalProperties: {type: integer}}
}
```

### 2. Generated Schemas

#### 1. Define your specific Schema

Create a Dart file (e.g., `user.dart`) and define your schema as an abstract class annotated with `@Schematic()`.

```dart
import 'package:schemantic/schemantic.dart';

part 'user.g.dart';

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


### Union Types (AnyOf)

Schemantic supports union types using the `@AnyOf` annotation. This allows a field to accept multiple types.

```dart
@Schematic()
abstract class $Poly {
  @AnyOf([int, String, $User])
  Object? get id;
}
```

#### Generated Helpers

For `AnyOf` fields, Schemantic generates a specific helper class to handle type safety. The helper class is named using the convention `ParentNameFieldName` (e.g., `PolyId` for field `id` in `Poly`).

```dart
// Usage
final poly = Poly(
  // Use the helper class factories to set values
  id: PolyId.int(123),
);

final poly2 = Poly(
  id: PolyId.string('abc'),
);

final poly3 = Poly(
  // You can also use Schema types
  id: PolyId.user(User(name: 'Alice', isAdmin: true)),
);
```

On the generated class, the setter takes the helper class, while the getter returns `Object?` (the raw JSON value).

```dart
// The setter enforces strict typing via the helper
poly.id = PolyId.int(456);

// The getter returns the raw value
print(poly.id); // 456
```

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
final tags = SchemanticType.list(
  .string(),
  description: 'A list of tags',
  minItems: 1,
  maxItems: 10,
  uniqueItems: true,
);

// A map with integer values.
final scores = SchemanticType.map(
  .string(),
  .int(),
  description: 'Player scores',
  minProperties: 1,
);
```

### Field Annotations

Schemantic provides specialized annotations for defining schema constraints:

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
    maximum: 120,
    defaultValue: 18,
  )
  int? get age;

  @DoubleField(minimum: 0.0, maximum: 100.0, defaultValue: 0.0)
  double get score;

  @StringField(
    minLength: 2,
    maxLength: 50,
    pattern: r'^[a-zA-Z\s]+$',
    enumValues: ['user', 'admin'], // Mapped to 'enum' in JSON Schema
    defaultValue: 'user'
  )
  String get role;
}
```

Validation matches the Dart type (e.g., using `@StringField` on an `int` getter will throw a build-time error).

