Chrome Built-in AI (Gemini Nano) plugin for Genkit Dart.

This plugin allows you to run Gemini Nano locally in Chrome, providing low-latency, offline-capable AI features directly in your web application.

## Prerequisites

To use this plugin, you must be running Chrome 128 or later and enable the necessary flags:

1.  Open `chrome://flags`
2.  Enable **"Prompt API for Gemini Nano"** (`chrome://flags/#prompt-api-for-gemini-nano`)
3.  Set **"Enables optimization guide on device"** (`chrome://flags/#optimization-guide-on-device-model`) to **"Enabled BypassPerfRequirement"**
4.  Relaunch Chrome.
5.  Open `chrome://components` and find **"Optimization Guide On Device Model"**. Click **"Check for update"** to download the model.

## Installation

```bash
dart pub add genkit_chrome
```

## Usage

### 1. Initialize Genkit

Add the `ChromeAIPlugin` to your Genkit configuration:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_chrome/genkit_chrome.dart';

void main() {
  final ai = Genkit(plugins: [ChromeAIPlugin()]);
}
```

### 2. Generate Text

Use the `chrome/gemini-nano` model to generate text:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_chrome/genkit_chrome.dart';

void main() async {
  final ai = Genkit(plugins: [ChromeAIPlugin()]);

  final response = await ai.generate(
    model: modelRef('chrome/gemini-nano'),
    prompt: 'Explain quantum computing in simple terms.',
  );

  print(response.text);
}
```

### 3. Streaming Responses

Stream text as it is generated:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_chrome/genkit_chrome.dart';

void main() async {
  final ai = Genkit(plugins: [ChromeAIPlugin()]);

  final stream = ai.generateStream(
    model: modelRef('chrome/gemini-nano'),
    prompt: 'Write a story about a robot.',
  );

  await for (final chunk in stream) {
    print(chunk.text);
  }
}
```

## Limitations

-   **Chrome Only**: This plugin currently only works in Google Chrome (and potentially other Chromium-based browsers that support the Prompt API).
-   **Text-Only**: The current implementation primarily supports text generation.
-   **Experimental**: The Chrome Prompt API is experimental and subject to change.
