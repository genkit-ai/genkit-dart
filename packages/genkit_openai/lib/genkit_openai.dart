// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'src/openai_plugin.dart';

export 'src/converters.dart' show GenkitConverter;
export 'src/models.dart' show defaultModelInfo, oSeriesModelInfo, supportsTools, supportsVision;

part 'genkit_openai.g.dart';

@Schematic()
abstract class $OpenAIOptionsSchema {
  /// Model version override (e.g., 'gpt-4o-2024-08-06')
  String? get version;

  /// Sampling temperature (0.0 - 2.0)
  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  /// Nucleus sampling (0.0 - 1.0)
  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  /// Maximum tokens to generate
  int? get maxTokens;

  /// Stop sequences
  List<String>? get stop;

  /// Presence penalty (-2.0 - 2.0)
  @DoubleField(minimum: -2.0, maximum: 2.0)
  double? get presencePenalty;

  /// Frequency penalty (-2.0 - 2.0)
  @DoubleField(minimum: -2.0, maximum: 2.0)
  double? get frequencyPenalty;

  /// Seed for deterministic sampling
  int? get seed;

  /// User identifier for abuse detection
  String? get user;

  /// JSON mode
  bool? get jsonMode;

  /// Visual detail level for images ('auto', 'low', 'high')
  @StringField(enumValues: ['auto', 'low', 'high'])
  String? get visualDetailLevel;
}

/// Custom model definition for registering models from compatible providers
class CustomModelDefinition {
  final String name;
  final ModelInfo? info;

  const CustomModelDefinition({
    required this.name,
    this.info,
  });
}

/// Public constant handle for OpenAI-compatible plugin
const OpenAICompatPluginHandle openAI = OpenAICompatPluginHandle();

/// Handle class for OpenAI-compatible plugin
class OpenAICompatPluginHandle {
  const OpenAICompatPluginHandle();

  /// Create the plugin instance
  GenkitPlugin call({
    String? apiKey,
    String? baseUrl,
    List<CustomModelDefinition>? models,
    Map<String, String>? headers,
  }) {
    return OpenAICompatPlugin(
      apiKey: apiKey,
      baseUrl: baseUrl,
      customModels: models ?? const [],
      headers: headers,
    );
  }

  /// Reference to a model
  ModelRef<OpenAIOptionsSchema> model(String name) {
    return modelRef('openai/$name', customOptions: OpenAIOptionsSchema.$schema);
  }

  // Pre-defined model references - GPT-5.x Series
  ModelRef<OpenAIOptionsSchema> get gpt5 => model('gpt-5');
  ModelRef<OpenAIOptionsSchema> get gpt520250807 => model('gpt-5-2025-08-07');
  ModelRef<OpenAIOptionsSchema> get gpt5ChatLatest => model('gpt-5-chat-latest');
  ModelRef<OpenAIOptionsSchema> get gpt5Mini => model('gpt-5-mini');
  ModelRef<OpenAIOptionsSchema> get gpt5Mini20250807 => model('gpt-5-mini-2025-08-07');
  ModelRef<OpenAIOptionsSchema> get gpt5Nano => model('gpt-5-nano');
  ModelRef<OpenAIOptionsSchema> get gpt5Nano20250807 => model('gpt-5-nano-2025-08-07');
  ModelRef<OpenAIOptionsSchema> get gpt5Pro => model('gpt-5-pro');
  ModelRef<OpenAIOptionsSchema> get gpt5Pro20251006 => model('gpt-5-pro-2025-10-06');

  ModelRef<OpenAIOptionsSchema> get gpt51 => model('gpt-5.1');
  ModelRef<OpenAIOptionsSchema> get gpt5120251113 => model('gpt-5.1-2025-11-13');
  ModelRef<OpenAIOptionsSchema> get gpt51ChatLatest => model('gpt-5.1-chat-latest');

  ModelRef<OpenAIOptionsSchema> get gpt52 => model('gpt-5.2');
  ModelRef<OpenAIOptionsSchema> get gpt5220251211 => model('gpt-5.2-2025-12-11');
  ModelRef<OpenAIOptionsSchema> get gpt52ChatLatest => model('gpt-5.2-chat-latest');
  ModelRef<OpenAIOptionsSchema> get gpt52Pro => model('gpt-5.2-pro');
  ModelRef<OpenAIOptionsSchema> get gpt52Pro20251211 => model('gpt-5.2-pro-2025-12-11');

  // GPT-4.x Series
  ModelRef<OpenAIOptionsSchema> get gpt4 => model('gpt-4');
  ModelRef<OpenAIOptionsSchema> get gpt40613 => model('gpt-4-0613');
  ModelRef<OpenAIOptionsSchema> get gpt41106Preview => model('gpt-4-1106-preview');
  ModelRef<OpenAIOptionsSchema> get gpt40125Preview => model('gpt-4-0125-preview');
  ModelRef<OpenAIOptionsSchema> get gpt4Turbo => model('gpt-4-turbo');
  ModelRef<OpenAIOptionsSchema> get gpt4TurboPreview => model('gpt-4-turbo-preview');
  ModelRef<OpenAIOptionsSchema> get gpt4Turbo20240409 => model('gpt-4-turbo-2024-04-09');

  ModelRef<OpenAIOptionsSchema> get gpt41 => model('gpt-4.1');
  ModelRef<OpenAIOptionsSchema> get gpt4120250414 => model('gpt-4.1-2025-04-14');
  ModelRef<OpenAIOptionsSchema> get gpt41Mini => model('gpt-4.1-mini');
  ModelRef<OpenAIOptionsSchema> get gpt41Mini20250414 => model('gpt-4.1-mini-2025-04-14');
  ModelRef<OpenAIOptionsSchema> get gpt41Nano => model('gpt-4.1-nano');
  ModelRef<OpenAIOptionsSchema> get gpt41Nano20250414 => model('gpt-4.1-nano-2025-04-14');

  // GPT-4o Series
  ModelRef<OpenAIOptionsSchema> get gpt4o => model('gpt-4o');
  ModelRef<OpenAIOptionsSchema> get gpt4o20240513 => model('gpt-4o-2024-05-13');
  ModelRef<OpenAIOptionsSchema> get gpt4o20240806 => model('gpt-4o-2024-08-06');
  ModelRef<OpenAIOptionsSchema> get gpt4o20241120 => model('gpt-4o-2024-11-20');
  ModelRef<OpenAIOptionsSchema> get chatgpt4oLatest => model('chatgpt-4o-latest');
  ModelRef<OpenAIOptionsSchema> get gpt4oMini => model('gpt-4o-mini');
  ModelRef<OpenAIOptionsSchema> get gpt4oMini20240718 => model('gpt-4o-mini-2024-07-18');

  // GPT-3.5 Series
  ModelRef<OpenAIOptionsSchema> get gpt35Turbo => model('gpt-3.5-turbo');
  ModelRef<OpenAIOptionsSchema> get gpt35Turbo16k => model('gpt-3.5-turbo-16k');
  ModelRef<OpenAIOptionsSchema> get gpt35Turbo1106 => model('gpt-3.5-turbo-1106');
  ModelRef<OpenAIOptionsSchema> get gpt35Turbo0125 => model('gpt-3.5-turbo-0125');

  // O-Series Models
  ModelRef<OpenAIOptionsSchema> get o1 => model('o1');
  ModelRef<OpenAIOptionsSchema> get o120241217 => model('o1-2024-12-17');
  ModelRef<OpenAIOptionsSchema> get o1Pro => model('o1-pro');
  ModelRef<OpenAIOptionsSchema> get o1Pro20250319 => model('o1-pro-2025-03-19');

  ModelRef<OpenAIOptionsSchema> get o3 => model('o3');
  ModelRef<OpenAIOptionsSchema> get o320250416 => model('o3-2025-04-16');
  ModelRef<OpenAIOptionsSchema> get o3Mini => model('o3-mini');
  ModelRef<OpenAIOptionsSchema> get o3Mini20250131 => model('o3-mini-2025-01-31');

  ModelRef<OpenAIOptionsSchema> get o4Mini => model('o4-mini');
  ModelRef<OpenAIOptionsSchema> get o4Mini20250416 => model('o4-mini-2025-04-16');
}
