# Genkit Schema Builder

A builder for generating Genkit schema extension types.

## Installation

```yaml
dev_dependencies:
  genkit_schema_builder: any
  build_runner: ^2.8.0
```

## Usage

Annotate your schemas with `@GenkitSchema()` and run `dart run build_runner build`.

```dart
import 'package:genkit/genkit.dart';

part 'my_schema.g.dart';

@GenkitSchema()
abstract class MyInput {
  String get name;
  int? get age;
}

void main() {
  // Use the generated data class
  final input = MyInput.from(name: 'Alice', age: 30);
  print(input.name); // Alice
  
  // Serialize to JSON
  final json = input.toJson();
  print(json); // {name: Alice, age: 30}
  
  // Parse from JSON using the generated Type class
  final parsed = MyInputType.parse(json);
  print(parsed.name); // Alice
}
```

