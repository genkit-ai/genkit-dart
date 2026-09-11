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

final RegExp _oSeriesPattern = RegExp(r'^o\d+(?:-|$)');
final RegExp _gptPattern = RegExp(r'^gpt-\d+(\.\d+)?o?(?:-|$)');

/// Determines the type of model based on its ID.
///
/// This classifies a model's *modality*, which is what discovery filters on;
/// per-model capabilities come from the curated catalog in `known_models.dart`
/// rather than from this function.
///
/// Returns one of the following model types:
/// - 'chat': Chat completion models (gpt-4, gpt-4o, o1, etc.)
/// - 'embedding': Text embedding models
/// - 'audio': Audio processing models (TTS, transcription, realtime)
/// - 'image': Image generation models (DALL-E, gpt-image)
/// - 'video': Video generation models (Sora)
/// - 'moderation': Content moderation models
/// - 'completion': Legacy text completion models (instruct, davinci, babbage)
/// - 'code': Code generation models (codex)
/// - 'search': Search-specific models (search, deep-research)
/// - 'research': Research-specific models (research, deep-research)
/// - 'unknown': Unknown or unrecognized model type
String getModelType(String modelId) {
  final id = modelId.toLowerCase();

  // Video generation models.
  if (id.contains('sora')) {
    return 'video';
  }

  // Image generation models.
  if (id.contains('dall-e') || id.contains('image')) {
    return 'image';
  }

  // Embedding models.
  if (id.contains('embedding')) {
    return 'embedding';
  }

  // Moderation models.
  if (id.contains('moderation')) {
    return 'moderation';
  }

  // Code generation models.
  if (id.contains('codex')) {
    return 'code';
  }

  // Audio models (TTS, transcription, realtime, speech-to-text).
  if (id.contains('tts') ||
      id.contains('audio') ||
      id.contains('realtime') ||
      id.contains('transcribe') ||
      id.contains('whisper')) {
    return 'audio';
  }

  // Legacy completion models (not chat).
  if (id.contains('instruct') ||
      id.contains('davinci') ||
      id.contains('babbage')) {
    return 'completion';
  }

  // Research-specific models.
  if (id.contains('research')) {
    return 'research';
  }

  // Search-specific models.
  if (id.contains('search')) {
    return 'search';
  }

  // GPT-N pattern: matches gpt-3, gpt-4, gpt-5, gpt-6, etc.
  if (_gptPattern.hasMatch(id)) {
    return 'chat';
  }

  // O-series reasoning models: o1, o2, o3, o4, o5, etc.
  if (_oSeriesPattern.hasMatch(id)) {
    return 'chat';
  }

  // ChatGPT-branded models.
  if (id.startsWith('chatgpt-')) {
    // Special handling for non-chat ChatGPT variants.
    if (id.contains('image')) {
      return 'image';
    }
    return 'chat';
  }

  // Unknown model type.
  return 'unknown';
}
