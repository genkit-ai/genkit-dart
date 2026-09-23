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

/// Defines a flow that transcribes audio supplied as a base64 `data:` URL.
///
/// Audio goes in through `promptParts` as a [MediaPart]; the transcript comes
/// back as ordinary response text.
Flow<String, String, void, void> defineTranscribeFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'transcribeAudio',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (dataUrl, _) async {
      if (!dataUrl.startsWith('data:')) {
        throw Exception(
          'Expected a base64 data URL, e.g. data:audio/mpeg;base64,...',
        );
      }

      final response = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [
          MediaPart(
            media: Media(
              contentType: Uri.parse(dataUrl).data?.mimeType,
              url: dataUrl,
            ),
          ),
        ],
        config: OpenAITranscriptionOptions(language: 'en'),
      );

      return response.text;
    },
  );
}

/// Defines a flow that speaks a sentence and then transcribes it back.
///
/// Self-contained: it needs no audio file, which also makes it the easiest way
/// to exercise the transcription path from the Dev UI.
Flow<String, String, void, void> defineSpeechRoundTripFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'speechRoundTrip',
    inputSchema: .string(
      defaultValue: 'The quick brown fox jumps over the lazy dog.',
    ),
    outputSchema: .string(),
    fn: (sentence, _) async {
      final spoken = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: sentence,
        config: OpenAISpeechOptions(voice: 'nova'),
      );

      final audio = spoken.media;
      if (audio == null) {
        throw Exception('No audio generated');
      }

      final heard = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [MediaPart(media: audio)],
        config: OpenAITranscriptionOptions(language: 'en'),
      );

      return heard.text;
    },
  );
}

/// Defines a flow that returns SRT subtitles for spoken audio.
///
/// `srt` and `vtt` return subtitle markup rather than a JSON object; the
/// plugin hands the body back untouched as the response text.
Flow<String, String, void, void> defineSubtitlesFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'subtitles',
    inputSchema: .string(defaultValue: 'Genkit Dart now listens.'),
    outputSchema: .string(),
    fn: (sentence, _) async {
      final spoken = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: sentence,
      );

      final subtitles = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [MediaPart(media: spoken.media!)],
        config: OpenAITranscriptionOptions(responseFormat: 'srt'),
      );

      return subtitles.text;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [openAI(apiKey: Platform.environment['OPENAI_API_KEY'])],
  );

  defineTranscribeFlow(ai);
  defineSpeechRoundTripFlow(ai);
  defineSubtitlesFlow(ai);
}
