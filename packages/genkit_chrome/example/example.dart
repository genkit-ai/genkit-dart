// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Runs Gemini Nano on-device through Chrome's built-in Prompt API.
///
/// This targets the web: compile it with `dart compile js` (or serve it with
/// `webdev`) and open it in a Chrome build that has the Prompt API enabled.
/// See the package README for the browser setup.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_chrome/genkit_chrome.dart';

Future<void> main() async {
  final ai = Genkit(plugins: [chromeAI()]);
  final model = modelRef('chrome/gemini-nano');

  // One-shot generation.
  final response = await ai.generate(
    model: model,
    prompt: 'Explain quantum computing in one sentence.',
  );
  print(response.text);

  // Streaming: each chunk is the next piece of text.
  final stream = ai.generateStream(
    model: model,
    prompt: 'Write a haiku about the browser.',
  );
  await for (final chunk in stream) {
    print(chunk.text);
  }
}
