[![Pub](https://img.shields.io/pub/v/genkit_anthropic.svg)](https://pub.dev/packages/genkit_anthropic)

Anthropic plugin for Genkit Dart.

## Usage

### Initialization

```dart
import 'dart:io';
import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';

void main() async {
  // Initialize Genkit with the Anthropic plugin
  // Make sure ANTHROPIC_API_KEY is allowed in your environment
  final ai = Genkit(
    plugins: [anthropic(apiKey: Platform.environment['ANTHROPIC_API_KEY']!)],
  );
}
```

### Basic Generation

```dart
final response = await ai.generate(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'Tell me a joke about a developer.',
);
print(response.text);
```

### Streaming

```dart
final stream = ai.generateStream(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'Count to 5',
);

await for (final chunk in stream) {
  print(chunk.text);
}

final response = await stream.onResult;
print('Full response: ${response.text}');
```

### Tool Calling

```dart
import 'package:schemantic/schemantic.dart';

part 'main.g.dart';

@Schema()
abstract class $CalculatorInput {
  int get a;
  int get b;
}

// ... inside main ...

ai.defineTool(
  name: 'calculator',
  description: 'Multiplies two numbers',
  inputSchema: CalculatorInput.$schema,
  outputSchema: .integer(),
  fn: (input, context) async => .response(input.a * input.b),
);

final response = await ai.generate(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'What is 123 * 456?',
  toolNames: ['calculator'],
);

print(response.text);
```

### Thinking

```dart
final response = await ai.generate(
  model: anthropic.model('claude-sonnet-5'),
  prompt: 'Solve this 24 game: 2, 3, 10, 10',
  config: AnthropicOptions(
    // Uses the model's compatible default thinking mode.
    thinking: ThinkingConfig(),
    outputConfig: AnthropicOutputConfig(effort: 'high'),
  ),
);

// The thinking content is available in the message parts
print(response.message?.content);
```

An omitted thinking type resolves to the model's own default: Claude 4.6 and
newer default to `adaptive`, while Claude 4.5 models default to `enabled`,
which uses a manual token budget. You can also select a mode explicitly with
`ThinkingConfig(type: 'enabled', budgetTokens: 2048)`. For model names outside
the curated catalog, set `thinking.type` explicitly so the plugin does not
guess an incompatible mode.

### Structured Output

```dart
@Schema()
abstract class $Person {
  String get name;
  int get age;
}

// ... inside main ...

final response = await ai.generate(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'Generate a person named John Doe, age 30',
  outputSchema: Person.$schema,
);

final person = response.output; // Typed Person object
print('Name: ${person.name}, Age: ${person.age}');
```

Models on Anthropic's Structured Outputs list are sent the schema natively, so
structured output composes with extended thinking. Other models fall back to a
tool the model is forced to call; that fallback cannot be combined with manual
thinking, and the plugin reports an `INVALID_ARGUMENT` error rather than letting
the API reject the request.

### Stable and beta APIs

Requests go to Anthropic's stable API by default. Set `apiVersion` to `'beta'`
to reach beta-gated features, either for a single request or for every request:

```dart
// Per request.
final response = await ai.generate(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'Hello',
  config: AnthropicOptions(apiVersion: 'beta'),
);

// Or as the plugin-wide default; a request's own apiVersion still wins.
final ai = Genkit(plugins: [anthropic(apiVersion: 'beta')]);
```

Beta requests send a curated `anthropic-beta` feature list. To opt into a beta
the plugin does not know about yet, set `betas` to replace that list:

```dart
config: AnthropicOptions(
  apiVersion: 'beta',
  betas: ['some-new-beta-2026-01-01'],
),
```
