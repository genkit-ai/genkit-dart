# Genkit Schema Framework Design

## Motivation

The Genkit Dart framework requires a compact and powerful way to define data schemas, similar to what [Zod](https://zod.dev/) provides for TypeScript or [Pydantic](https://docs.pydantic.dev/) for Python. These schemas are fundamental to defining the inputs and outputs of AI flows and tools.

The Genkit schema framework is designed to meet three core requirements for Genkit:

1.  **Language-Level Strong Typing**: Provide static type safety for JSON objects. The generated type ensures that developers get compile-time checks and code completion when working with what would otherwise be a simple `Map<String, dynamic>`.

2.  **Convenient Marshalling**: Offer a seamless way to convert (marshall and unmarshall) between raw JSON and strongly-typed Dart objects. The generated `parse()` method handles this conversion effortlessly.

3.  **JSON Schema Generation**: Automatically generate a [JSON Schema](https://json-schema.org/) representation for each type. This is crucial for Genkit, as it allows the framework to understand and validate the data structures passed to and from models and tools, ensuring interoperability with external systems and APIs.

## Core Concepts

### 1. Schema Definition

The schema for a JSON object is defined using an abstract Dart class annotated with `@Schema()`. Each getter in the abstract class defines a field in the JSON object.

**Example:**
```dart
@Schema()
abstract class RecipeSchema {
  String get title;
  List<IngredientSchema> get ingredients;
  int get servings;
}
```

#### Alternative: Declarative, Builder-Style API

An alternative and more flexible approach, inspired by libraries like Zod and Pydantic, is to define schemas using a declarative, builder-style API. This method offers clearer composition and easier integration of modifiers and validation rules.

**Example:**

```dart
// 1. Define the schema using a builder API
final ingredientSchema = GSchema.object({
  'name': GSchema.string(),
  'quantity': GSchema.string(),
});

final recipeSchema = GSchema.object({
  'title': GSchema.string(),
  'ingredients': GSchema.list(ingredientSchema),
  'servings': GSchema.number(),
  'isDeleted': GSchema.boolean().optional(),
});

// 2. Infer the Dart type from the schema definition
// (This would be a generated type)
typedef Recipe = InferType<typeof recipeSchema>;
```

**Trade-offs:**

*   **Pros**: This approach provides a single, first-class schema object that handles parsing, validation, and introspection. It is highly extensible, allowing for chained modifiers like `.optional()`, `.default('value')`, and validation rules.
*   **Cons**: It requires a more sophisticated generator to parse the declarative structure and infer the static types. The `abstract class` approach is simpler to implement initially as it leans more heavily on Dart's built-in static analysis capabilities.

### 2. Generated Code

For each `...Schema` class, the generator can produce code using one of two strategies, along with a `TypeFactory`.

#### a. Strategy 1: Extension Types (Lightweight View)

This strategy generates an `extension type` that provides a zero-overhead, type-safe wrapper around the raw `Map<String, dynamic>`. It's ideal when you only need to read or write properties without the need for custom methods or object identity (`hashCode`, `==`).

**Generated Code Example:**
```dart
extension type Recipe(Map<String, dynamic> _json) implements RecipeSchema {
  // ... getters and setters ...
}
```

#### b. Strategy 2: Concrete Classes (`json_serializable`-style)

This strategy generates a traditional Dart `class` with `fromJson` and `toJson` methods. It's a better fit when you need to add custom methods to the class, override `hashCode`/`==`, or require a distinct object instance that is separate from the raw JSON map.

**Generated Code Example:**
```dart
class Recipe implements RecipeSchema {
  @override
  String title;
  
  @override
  List<Ingredient> ingredients;

  // ... other fields ...

  Recipe({required this.title, required this.ingredients, ...});

  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);
  Map<String, dynamic> toJson() => _$RecipeToJson(this);
}
```

#### c. Type Factory

A factory class (e.g., `RecipeTypeFactory`) is generated to provide utility methods for working with the JSON data. A singleton instance of this factory is also created for convenience (e.g., `RecipeType`).

The factory provides:
- **`parse(Map<String, dynamic> json)`**: A method to wrap a JSON map in the generated extension type.
- **`jsonSchema`**: A getter that returns a JSON Schema representation of the data structure, which is useful for validation and interoperability.

**Generated Code Example:**
```dart
class RecipeTypeFactory {
  const RecipeTypeFactory();

  Recipe parse(Map<String, dynamic> json) => Recipe(json);

  Map<String, dynamic> get jsonSchema => const {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      // ...
    },
  };
}

const RecipeType = RecipeTypeFactory();
```

## Usage

1.  **Define a schema** using an abstract class and annotate it with `@Schema()`.
2.  **Run the generator** to create the `*.g.dart` file.
3.  **Use the generated `...Type` factory** to parse JSON and interact with the data in a type-safe way.

```dart
// Decode a JSON string into a Map
final jsonMap = jsonDecode(recipeJsonString) as Map<String, dynamic>;

// Use the factory to parse the map into our type-safe extension type
final recipe = RecipeType.parse(jsonMap);

// Access and modify data
print(recipe.title);
recipe.servings = 6;
```

## Genkit Integration

The primary use case for this framework is defining the types for Genkit `Flow`s. The generated `...Type` object serves as a first-class type definition that can be passed to the flow constructor.

This allows Genkit to understand the input and output schemas of a flow, enabling automatic validation, documentation, and tooling integration.

**Example:**

```dart
  final myFlow = Flow(
    inputType: RecipeType,
    outputType: StringType, // A built-in type for strings
    fn: (input) async {
      // 'input' is a strongly-typed Recipe object
      return "Title: ${input.title}";
    },
  );

  // Genkit can now validate this input against the RecipeType's JSON schema
  // before executing the flow.
  await myFlow.run(recipe);
```

## Generator Logic (High-Level)

The build runner generator will:
1.  Find all classes annotated with `@Schema`.
2.  For each `...Schema` class:
    a. Create an `extension type` with the same name (minus the "Schema" suffix).
    b. For each getter in the schema, generate a corresponding getter and setter in the extension type that reads from and writes to the underlying map.
    c. Handle nested schemas by recursively using the appropriate generated types.
    d. Generate a `...TypeFactory` class with `parse` and `jsonSchema` methods.
    e. Create a `const` instance of the factory.
