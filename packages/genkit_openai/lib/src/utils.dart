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

final RegExp _oSeriesPattern = RegExp(r'^o\d+(?:-|$)');
final RegExp _gptPattern = RegExp(r'^gpt-\d+(\.\d+)?o?(?:-|$)');
final RegExp _gptOPattern = RegExp(r'gpt-\d+(?:\.\d+)?o');

const List<String> _nonToolKeywords = [
  'embedding',
  'tts',
  'whisper',
  'dall-e',
  'moderation',
  'sora',
  'search',
  'research',
];

/// Encapsulates model capability rules so model families can override behavior.
abstract class _ModelCapabilities {
  final String modelId;

  const _ModelCapabilities(this.modelId);

  String get id => modelId.toLowerCase();

  bool get supportsMultiturn => true;
  bool get supportsTools => _supportsToolsByHeuristics(id);
  bool get supportsSystemRole => true;
  bool get supportsMedia => _supportsVisionByHeuristics(id);

  ModelInfo toModelInfo() {
    return ModelInfo(
      label: modelId,
      supports: {
        'multiturn': supportsMultiturn,
        'tools': supportsTools,
        'systemRole': supportsSystemRole,
        'media': supportsMedia,
      },
    );
  }

  static _ModelCapabilities forModel(String modelId) {
    if (_oSeriesPattern.hasMatch(modelId.toLowerCase())) {
      return _OSeriesModelCapabilities(modelId);
    }

    return _DefaultModelCapabilities(modelId);
  }
}

/// Default capability behavior for standard OpenAI models.
class _DefaultModelCapabilities extends _ModelCapabilities {
  const _DefaultModelCapabilities(super.modelId);
}

/// O-series reasoning models override key capability defaults.
class _OSeriesModelCapabilities extends _DefaultModelCapabilities {
  const _OSeriesModelCapabilities(super.modelId);

  @override
  bool get supportsTools => false;

  @override
  bool get supportsSystemRole => false;

  @override
  bool get supportsMedia => true;
}

bool _supportsToolsByHeuristics(String id) {
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
  for (final keyword in _nonToolKeywords) {
    if (id.contains(keyword)) {
      return false;
    }
  }

  // Standard GPT models support tools.
  if (_gptPattern.hasMatch(id)) {
    return true;
  }

  // Default to true for unknown models (safer for chat models).
  return true;
}

bool _supportsVisionByHeuristics(String id) {
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
  if (_gptOPattern.hasMatch(id)) {
    return true;
  }

  // O-series reasoning models (o1, o2, o3, etc.) support vision.
  if (_oSeriesPattern.hasMatch(id)) {
    return true;
  }

  // ChatGPT models with vision indicators.
  if (id.startsWith('chatgpt-') &&
      (id.contains('4o') || id.contains('vision'))) {
    return true;
  }

  return false;
}

/// Default model info for standard OpenAI models.
ModelInfo defaultModelInfo(String model) {
  return _DefaultModelCapabilities(model).toModelInfo();
}

/// Model info for O-series reasoning models (o1, o2, o3, o4, etc.).
ModelInfo oSeriesModelInfo(String model) {
  return _OSeriesModelCapabilities(model).toModelInfo();
}

/// Model info for any OpenAI model based on its model family.
ModelInfo modelInfoFor(String model) {
  return _ModelCapabilities.forModel(model).toModelInfo();
}

/// Check if a model supports tools/function calling.
bool supportsTools(String model) {
  return _ModelCapabilities.forModel(model).supportsTools;
}

/// Check if a model supports vision (image inputs).
bool supportsVision(String model) {
  return _ModelCapabilities.forModel(model).supportsMedia;
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
