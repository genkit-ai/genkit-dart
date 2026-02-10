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

export 'src/converters.dart'
    show
        fromOpenAIAssistantMessage,
        mapFinishReason,
        toOpenAIContentPart,
        toOpenAIMessage,
        toOpenAIMessages,
        toOpenAITool;
export 'src/models.dart' show defaultModelInfo, o1ModelInfo, supportsVision;

part 'genkit_openai_compat.g.dart';

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
    String? baseURL,
    List<CustomModelDefinition>? models,
    Map<String, String>? headers,
  }) {
    return OpenAICompatPlugin(
      apiKey: apiKey,
      baseURL: baseURL,
      customModels: models ?? const [],
      headers: headers,
    );
  }

  /// Reference to a model
  ModelRef<OpenAIOptionsSchema> model(String name) {
    return modelRef('openai_compat/$name', customOptions: OpenAIOptionsSchema.$schema);
  }

  // Pre-defined model references
  ModelRef<OpenAIOptionsSchema> get gpt4o => model('gpt-4o');
  ModelRef<OpenAIOptionsSchema> get gpt4oMini => model('gpt-4o-mini');
  ModelRef<OpenAIOptionsSchema> get gpt4Turbo => model('gpt-4-turbo');
  ModelRef<OpenAIOptionsSchema> get gpt35Turbo => model('gpt-3.5-turbo');
  ModelRef<OpenAIOptionsSchema> get o1 => model('o1');
  ModelRef<OpenAIOptionsSchema> get o1Mini => model('o1-mini');
  ModelRef<OpenAIOptionsSchema> get o3Mini => model('o3-mini');
}
