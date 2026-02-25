// Copyright 2025 Google LLC
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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

/// Defines a flow that generates speech audio from text using OpenAI.
///
/// Returns audio as [Media] with a base64 data URI in `media.url`.
Flow<String, Media, void, void> defineTextToSpeechFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'textToSpeech',
    inputSchema: stringSchema(
      defaultValue: 'Genkit Dart supports OpenAI text to speech.',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: openAI.model('gpt-4o-mini-tts'),
        prompt: prompt,
        config: OpenAIOptions(audioVoice: 'alloy', audioFormat: 'mp3'),
      );

      final media = response.media;
      if (media == null) {
        throw StateError('Model returned no audio media.');
      }
      return media;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [openAI(apiKey: Platform.environment['OPENAI_API_KEY'])],
  );

  defineTextToSpeechFlow(ai);
}
