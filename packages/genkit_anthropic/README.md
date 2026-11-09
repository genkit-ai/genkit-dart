[![Pub](https://img.shields.io/pub/v/genkit_anthropic.svg)](https://pub.dev/packages/genkit_anthropic)

Anthropic plugin for Genkit Dart.

> **Building with a coding agent? Install the Genkit Dart skill first.**
>
> ```bash
> npx skills add genkit-ai/skills --skill developing-genkit-dart
> ```
>
> It teaches your agent the current Genkit Dart APIs and common gotchas.
> Source, manual install and skills for other languages:
> [genkit-ai/skills](https://github.com/genkit-ai/skills).

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

To route requests through your own `http.Client` (a proxy, logging, retries,
or a mock in tests), pass `httpClient`. The plugin never closes a client you
provide, so close it yourself when you are done:

```dart
import 'package:http/http.dart' as http;

final httpClient = http.Client();
final ai = Genkit(plugins: [anthropic(httpClient: httpClient)]);
// ...
httpClient.close();
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
    thinking: AnthropicThinkingConfig(),
    outputConfig: AnthropicOutputConfig(effort: 'high'),
  ),
);

// The thinking content is available in the message parts
print(response.message?.content);
```

An omitted thinking type resolves to the model's own default: Claude 4.6 and
newer default to `adaptive`, while Claude 4.5 models default to `enabled`,
which uses a manual token budget. You can also select a mode explicitly with
`AnthropicThinkingConfig(type: 'enabled', budgetTokens: 2048)`. For model names outside
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

Every Claude model is sent the schema natively, as Anthropic's
[structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
(`output_config.format`), on either API surface and with no beta header. That
includes model names the plugin does not curate: every active Claude model
supports it. Nothing is added to the request and no `tool_choice` is pinned, so
structured output composes with extended thinking and with your own tools.

To opt out of the constraint, pass `outputConstrained: false`. The plugin then
sends no schema at all, so describe the shape yourself if you still want it:

```dart
final response = await ai.generate(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'Generate a person named John Doe, age 30',
  outputSchema: Person.$schema,
  outputConstrained: false,
  outputInstructions: 'Reply with JSON: {"name": string, "age": integer}.',
);
```

Anthropic accepts a subset of JSON Schema, so the plugin rewrites what it can:

- `oneOf` is rejected, so it is rewritten to `anyOf`. `SchemanticType.nullable()`
  emits `oneOf`, which would otherwise make every optional field a 400.
- Validation keywords (`minimum`, `maxLength`, `pattern`, ...) are stripped,
  since the validator rejects them on a constrained schema.

Three shapes cannot be constrained at all, and the plugin puts the schema in
the system prompt for those requests rather than sending a constraint that
would change what the schema means:

- a `dynamic` or `Object?` field, which compiles to an empty schema. Anthropic
  rejects it outright, and every concrete stand-in it does accept turns an
  object value into a string of JSON.
- a `Map<String, T>` field. `additionalProperties` may only be `false`, which
  would close the map and leave the model able to answer only `{}`.
- a recursive type, such as `class Node { List<Node> children; }`. Anthropic
  does not support recursive schemas.

Those requests still go out and still return the right shape; they are simply
not enforced by the API.

Anthropic also limits schema complexity per request: at most 24 optional
properties and 16 properties with union types, counted across the output
schema and any `strict` tools. A nullable field counts as a union, so a type
with many nullable fields can hit the limit and get a 400 ("Schema is too
complex for compilation"). Making fields required where you can is the usual
fix.

### Stable and beta APIs

Requests go to Anthropic's stable API by default. Set `apiVersion` to `'beta'`
to reach beta-gated features, either for a single request or for every request.
Structured output is not one of them — it is served on both surfaces:

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
