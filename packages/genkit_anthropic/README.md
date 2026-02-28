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

### Claude on Vertex AI

You can route Anthropic Claude requests through Vertex AI by providing a
`vertex` config instead of an Anthropic API key.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';

void main() async {
  final ai = Genkit(
    plugins: [
      anthropic(
        vertex: AnthropicVertexConfig.adc(
          projectId: 'my-gcp-project',
          location: 'global',
        ),
      ),
    ],
  );

  final response = await ai.generate(
    model: anthropic.model('claude-sonnet-4-5'),
    prompt: 'Say hello from Vertex AI',
  );

  print(response.text);
}
```

Notes:
- `AnthropicVertexConfig.adc(...)` uses Google Application Default Credentials.
- ADC supports `GOOGLE_APPLICATION_CREDENTIALS`, local `gcloud` ADC login, and metadata server credentials (for Workload Identity / attached service accounts).
- For explicit service account keys, use `AnthropicVertexConfig.serviceAccount(...)`.
- ADC and service-account helper constructors are available on Dart IO runtimes.
- For fully custom auth, use `accessToken` or `accessTokenProvider` directly.
- Vertex model names are usually unversioned (for example `claude-sonnet-4-5`).
- Do not pass both `apiKey` and `vertex` at the same time.

Service account example:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';

void main() async {
  final keyJson = jsonDecode(
    File('service-account.json').readAsStringSync(),
  );

  final ai = Genkit(
    plugins: [
      anthropic(
        vertex: AnthropicVertexConfig.serviceAccount(
          projectId: 'my-gcp-project',
          location: 'global',
          credentialsJson: keyJson,
        ),
      ),
    ],
  );

  final response = await ai.generate(
    model: anthropic.model('claude-sonnet-4-5'),
    prompt: 'Say hello from Vertex AI',
  );

  print(response.text);
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

@Schematic()
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
  fn: (input, context) async => input.a * input.b,
);

final response = await ai.generate(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'What is 123 * 456?',
  toolNames: ['calculator'],
);

print(response.text);
```

### Thinking (Claude 3.7+)

```dart
final response = await ai.generate(
  model: anthropic.model('claude-sonnet-4-5'),
  prompt: 'Solve this 24 game: 2, 3, 10, 10',
  config: AnthropicOptions(thinking: ThinkingConfig(budgetTokens: 2048)),
);

// The thinking content is available in the message parts
print(response.message?.content);
```

### Structured Output

```dart
@Schematic()
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
