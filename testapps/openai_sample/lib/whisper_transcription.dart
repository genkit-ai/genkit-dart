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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

/// Defines a flow that transcribes base64 data URL audio using Whisper.
Flow<String, String, void, void> defineWhisperTranscriptionFlow(
  Genkit ai, {
  String model = 'whisper-1',
}) {
  return ai.defineFlow(
    name: 'whisperTranscribeDataUrl',
    inputSchema: .string(
      defaultValue: 'data:audio/wav;base64,<base64-audio-bytes>',
    ),
    outputSchema: .string(),
    fn: (audioDataUrl, _) async {
      final contentType = _extractAudioMimeTypeFromDataUrl(audioDataUrl);

      if (contentType == null) {
        throw ArgumentError(
          'Input must be a base64 audio data URL (data:audio/...;base64,...).',
        );
      }

      final response = await ai.generate(
        model: openAI.model(model),
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(
                text: 'Transcribe this audio. Return only the transcript text.',
              ),
              MediaPart(
                media: Media(url: audioDataUrl, contentType: contentType),
              ),
            ],
          ),
        ],
      );

      final text = response.text.trim();
      if (text.isEmpty) {
        throw StateError('Model returned empty transcription.');
      }
      return text;
    },
  );
}

/// Defines a flow that transcribes a local WAV/MP3 file via Whisper.
Flow<String, String, void, void> defineWhisperFileTranscriptionFlow(
  Genkit ai, {
  String model = 'whisper-1',
}) {
  return ai.defineFlow(
    name: 'whisperTranscribeFile',
    inputSchema: .string(defaultValue: './sample.wav'),
    outputSchema: .string(),
    fn: (audioPath, _) async {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw ArgumentError('Audio file not found: $audioPath');
      }

      final bytes = await file.readAsBytes();
      final mimeType = _audioMimeTypeFromPath(audioPath);
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final response = await ai.generate(
        model: openAI.model(model),
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(
                text: 'Transcribe this audio. Return only the transcript text.',
              ),
              MediaPart(
                media: Media(url: dataUrl, contentType: mimeType),
              ),
            ],
          ),
        ],
      );

      final text = response.text.trim();
      if (text.isEmpty) {
        throw StateError('Model returned empty transcription.');
      }
      return text;
    },
  );
}

void main() {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw StateError('OPENAI_API_KEY is required.');
  }

  final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);
  defineWhisperTranscriptionFlow(ai);
  defineWhisperFileTranscriptionFlow(ai);
}

String? _extractAudioMimeTypeFromDataUrl(String url) {
  final match = RegExp(
    r'^data:(audio\/[^;]+);base64,',
    caseSensitive: false,
  ).firstMatch(url);
  return match?.group(1);
}

String _audioMimeTypeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';

  throw ArgumentError(
    'Unsupported audio file extension for "$path". Expected .wav or .mp3.',
  );
}
