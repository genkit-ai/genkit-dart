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

import 'package:genkit/genkit.dart';

/// Default model info for standard OpenAI models.
ModelInfo defaultModelInfo(String model) {
  return ModelInfo(
    label: model,
    supports: {
      'multiturn': true,
      'tools': supportsTools(model),
      'systemRole': true,
      'media': supportsVision(model),
    },
  );
}

/// Model info for O-series reasoning models (o1, o2, o3, o4, etc.).
ModelInfo oSeriesModelInfo(String model) {
  return ModelInfo(
    label: model,
    supports: {
      'multiturn': true,
      'tools': false, // O-series models don't support tools yet
      'systemRole': false, // O-series models use developer messages instead
      'media': true, // O-series models support vision/image inputs
    },
  );
}

/// Check if a model supports tools/function calling.
bool supportsTools(String model) {
  final id = model.toLowerCase();

  // ChatGPT-branded models don't support tools.
  if (id.startsWith('chatgpt-')) {
    return false;
  }

  // Legacy completion models don't support tools.
  if (id.contains('instruct') ||
      id.contains('davinci') ||
      id.contains('babbage') ||
      id.contains('ada-')) {
    return false;
  }

  // Specialized models that don't support tools.
  const nonToolKeywords = [
    'embedding',
    'tts',
    'whisper',
    'dall-e',
    'moderation',
    'sora',
    'search',
    'research',
  ];

  for (final keyword in nonToolKeywords) {
    if (id.contains(keyword)) {
      return false;
    }
  }

  // Standard GPT models support tools.
  final gptPattern = RegExp(r'^gpt-\d+(\.\d+)?(o)?(-|$)');
  if (gptPattern.hasMatch(id)) {
    return true;
  }

  // Default to true for unknown models (safer for chat models).
  return true;
}

/// Check if a model supports vision (image inputs).
bool supportsVision(String model) {
  final id = model.toLowerCase();

  // Explicitly named vision models.
  if (id.contains('vision')) {
    return true;
  }

  // GPT-4o variants (gpt-4o, gpt-4o-mini, etc.).
  if (id.contains('gpt-4o')) {
    return true;
  }

  // GPT-4 Turbo variants.
  if (id.contains('gpt-4-turbo') ||
      id.contains('gpt-4-1106') ||
      id.contains('gpt-4-0125')) {
    return true;
  }

  // Future GPT models with "o" suffix: gpt-5o, gpt-6o, gpt-10o, etc.
  final gptOPattern = RegExp(r'gpt-\d+(\.\d+)?o');
  if (gptOPattern.hasMatch(id)) {
    return true;
  }

  // O-series reasoning models (o1, o2, o3, etc.) support vision.
  final oSeriesPattern = RegExp(r'^o\d+(-|$)');
  if (oSeriesPattern.hasMatch(id)) {
    return true;
  }

  // ChatGPT models with vision indicators.
  if (id.startsWith('chatgpt-') &&
      (id.contains('4o') || id.contains('vision'))) {
    return true;
  }

  return false;
}

/// Determines the type of model based on its ID.
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
  final gptPattern = RegExp(r'^gpt-\d+(\.\d+)?(o)?(-|$)');
  if (gptPattern.hasMatch(id)) {
    return 'chat';
  }

  // O-series reasoning models: o1, o2, o3, o4, o5, etc.
  final oSeriesPattern = RegExp(r'^o\d+(-|$)');
  if (oSeriesPattern.hasMatch(id)) {
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
