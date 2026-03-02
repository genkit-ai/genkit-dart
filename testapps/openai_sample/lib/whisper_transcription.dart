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

/// Defines a flow that transcribes a local video file via Whisper.
Flow<String, String, void, void> defineWhisperVideoTranscriptionFlow(
  Genkit ai, {
  String model = 'whisper-1',
}) {
  return ai.defineFlow(
    name: 'whisperTranscribeVideo',
    inputSchema: .string(defaultValue: './sample.mp4'),
    outputSchema: .string(),
    fn: (videoPath, _) async {
      final file = File(videoPath);
      if (!await file.exists()) {
        throw ArgumentError('Video file not found: $videoPath');
      }

      final bytes = await file.readAsBytes();
      final mimeType = 'video/mp4';
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final response = await ai.generate(
        model: openAI.model(model),
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(
                text:
                    'Transcribe the audio in this MP4 file. Return only the transcript text.',
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
  defineWhisperVideoTranscriptionFlow(ai);
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
  if (lower.endsWith('.flac')) return 'audio/flac';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mpeg')) return 'video/mpeg';
  if (lower.endsWith('.mpga')) return 'audio/mpga';
  if (lower.endsWith('.m4a')) return 'audio/m4a';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.webm')) return 'audio/webm';

  throw ArgumentError(
    'Unsupported audio file extension for "$path". Supported extensions: .flac, .mp3, .mp4, .mpeg, .mpga, .m4a, .ogg, .wav, .webm.',
  );
}
