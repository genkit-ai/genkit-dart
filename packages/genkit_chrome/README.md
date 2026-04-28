Chrome Built-in AI (Gemini Nano) plugin for Genkit Dart.

This plugin allows you to run Gemini Nano locally in Chrome, providing low-latency, offline-capable AI features directly in your web application.

## Prerequisites

> **Note:** The API is expected to ship in Chrome 148.

### Local flags

To use this plugin, you must be running Chrome 128 or later and enable the necessary flags:

1.  Open `chrome://flags`
2.  Enable **"Prompt API for Gemini Nano"** (`chrome://flags/#prompt-api-for-gemini-nano`)
3.  Set **"Enables optimization guide on device"** (`chrome://flags/#optimization-guide-on-device-model`) to **"Enabled BypassPerfRequirement"**
4.  Relaunch Chrome.
5.  Open `chrome://components` and find **"Optimization Guide On Device Model"**. Click **"Check for update"** to download the model.

### Origin trial

You can also enable the [Prompt API origin trial](https://developer.chrome.com/origintrials/#/view_trial/2533837740349325313). Follow the
[instructions](https://developer.chrome.com/docs/web-platform/origin-trials) to register and get a token, then add it to your page:

```html
<meta http-equiv="origin-trial" content="TOKEN_HERE">
```

## Installation

```bash
dart pub add genkit_chrome
```

## Usage

### 1. Initialize Genkit

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_chrome/genkit_chrome.dart';

final ai = Genkit(plugins: [ChromeAIPlugin()]);
```

### 2. Generate Text

```dart
final response = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'Explain quantum computing in simple terms.',
);

print(response.text);
```

### 3. Streaming

Each chunk is an independent piece of text — concatenate them to build the full response:

```dart
final buffer = StringBuffer();

await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'Write a story about a robot.',
  onChunk: (chunk) => buffer.write(chunk.text),
);

print(buffer.toString());
```

### 4. Multi-turn Conversations

Pass a list of `Message` objects to maintain conversation history:

```dart
final history = <Message>[];

// First turn
history.add(Message(role: Role.user, content: [TextPart(text: 'Hello!')]));
final r1 = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  messages: history,
);
history.add(r1.message!);

// Second turn — model remembers the conversation
history.add(Message(role: Role.user, content: [TextPart(text: 'What did I just say?')]));
final r2 = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  messages: history,
);
print(r2.text);
```

### 5. System Prompt

Pass a `systemPrompt` string in config. It is automatically placed as the first entry in `initialPrompts` as required by the Prompt API:

```dart
final response = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'Hello!',
  config: {'systemPrompt': 'You are a pirate. Respond only in pirate speak.'},
);
```

> **Note:** Changing the system prompt mid-conversation requires starting a new session (i.e., clearing message history and calling `generate` again).

### 6. Aborting a Request

Use a `web.AbortController` from `package:web` to cancel an in-flight request:

```dart
import 'package:web/web.dart' as web;

final controller = web.AbortController();

// Cancel after 3 seconds
Future.delayed(Duration(seconds: 3), () => controller.abort());

try {
  await ai.generate(
    model: modelRef('chrome/gemini-nano'),
    prompt: 'Write a very long essay...',
    config: {'signal': controller.signal},
    onChunk: (chunk) => print(chunk.text),
  );
} catch (e) {
  print('Aborted or error: $e');
}
```

### 7. Response Constraints

Constrain the model's output to a JSON Schema or a regular expression by passing a JS object or JS RegExp as `responseConstraint`. This requires `dart:js_interop`:

```dart
import 'dart:js_interop';

// JSON Schema constraint
@JS('JSON.parse')
external JSAny jsonParse(JSString json);

final schema = jsonParse(
  '{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"]}'
  .toJS,
);

final response = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'What is 2 + 2?',
  config: {'responseConstraint': schema},
);

print(response.text); // e.g. {"answer":"4"}
```

### 8. Expected Input / Output Languages

Hint to the model which languages to expect:

```dart
final response = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'Hola, ¿cómo estás?',
  config: {
    'expectedInputs':  [{'type': 'text', 'languages': ['es']}],
    'expectedOutputs': [{'type': 'text', 'languages': ['en']}],
  },
);
```

> **Note:** Changing language settings mid-conversation requires starting a new session.

### 9. Model Download Progress

The model may need to be downloaded the first time it is used. Pass an `onDownloadProgress` callback to track progress:

```dart
final response = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'Hello!',
  config: {
    'onDownloadProgress': (int loaded, int total) {
      if (total > 0) {
        final pct = (loaded / total * 100).toStringAsFixed(0);
        print('Downloading: $pct%');
      } else {
        print('Downloading...');
      }
    },
  },
);
```

When `total` is `0`, the total size is unknown — show an indeterminate progress indicator.

### 10. Token Usage

The response includes context usage information. `inputTokens` is the number of tokens consumed by the current context, and `totalTokens` is the maximum context window size:

```dart
final response = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'Hello!',
);

final usage = response.usage;
if (usage != null) {
  print('Tokens used: ${usage.inputTokens} / ${usage.totalTokens}');
}
```

### 11. Model Parameters (with separateOrigin Trial)

`ChromeModel.getParams()` returns default and maximum values for `temperature` and `topK`. This is only available in an separate
[Prompt API Sampling Parameters origin trial](https://developer.chrome.com/origintrials/#/view_trial/4469259680211795969) — it
returns `null` on the open web:

```dart
final params = await ChromeModel.getParams();
if (params != null) {
  print('Default topK: ${params.defaultTopK}');
  print('Default temperature: ${params.defaultTemperature}');
}
```

`temperature` and `topK` can be passed in config and are currently available via an origin trial:

```dart
final response = await ai.generate(
  model: modelRef('chrome/gemini-nano'),
  prompt: 'Tell me a joke.',
  config: {'temperature': 1.2, 'topK': 3},
);
```

## Limitations

-   **Chrome/Edge Only**: This plugin works in Google Chrome and Microsoft Edge, but _not_ in other Chromium-based browsers.
-   **Text-Only**: Only text input and output are currently supported.
