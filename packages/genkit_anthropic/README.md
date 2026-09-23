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

How the schema travels depends on the API surface, because the feature does:

- On the **beta** surface, a model on Anthropic's Structured Outputs list is
  sent the schema natively, as `output_config.format`. Nothing is added to the
  request and no `tool_choice` is pinned, so structured output composes with
  extended thinking and with your own tools. Those models advertise
  `constrained: true`.
- On the **stable** surface, that field does not exist, so the schema travels
  as a tool the model is forced to call. Pinning `tool_choice` makes your own
  tools unreachable, so those models advertise `constrained: 'no-tools'` and
  Genkit puts the schema in the prompt instead whenever a request carries
  tools. The forced tool also cannot be combined with manual thinking; the
  plugin reports an `INVALID_ARGUMENT` error rather than letting the API
  reject the request.
- A model the plugin does not curate advertises neither, on either surface:
  the Structured Outputs list is per-model, and not every Claude accepts a
  forced `tool_choice`. Genkit simulates instead, putting the schema in the
  prompt, which works everywhere.

The advertised claim follows the plugin's own `apiVersion`, since that is what
Genkit reads when deciding whether to simulate. Overriding `apiVersion` on a
single request is still fine — a request that asks for beta may be simulated
where the native path would have served it, which costs a longer prompt — but
overriding it to `'stable'` for a structured request that also carries tools is
refused, because neither mechanism can serve it.

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
