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

import 'dart:async';

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;

import 'src/chat.dart' as chat;
import 'src/openai_plugin.dart';

export 'src/chat.dart' show OpenAIChatOptions, OpenAIOptions;
export 'src/converters.dart' show GenkitConverter;
export 'src/utils.dart'
    show
        defaultModelInfo,
        getModelType,
        modelInfoFor,
        oSeriesModelInfo,
        supportsTools,
        supportsVision;

/// Default plugin / namespace name used when no custom name is provided.
const String defaultOpenAINamespace = 'openai';

/// Custom model definition for registering models from compatible providers.
///
/// Use this to register models from OpenAI-compatible APIs (such as xAI/Grok,
/// DeepSeek, Together AI, Groq, etc.) that are not automatically discovered.
///
/// ```dart
/// openAI(
///   baseUrl: 'https://api.groq.com/openai/v1',
///   models: [
///     CustomModelDefinition(
///       name: 'llama-3.3-70b-versatile',
///       info: ModelInfo(label: 'Llama 3.3 70B'),
///     ),
///   ],
/// )
/// ```
class CustomModelDefinition {
  /// The model identifier, e.g. `'llama-3.3-70b-versatile'`.
  final String name;

  /// Optional metadata describing the model's capabilities.
  ///
  /// When `null`, default capability detection heuristics are used.
  final ModelInfo? info;

  /// Creates a custom model definition with the given [name] and optional
  /// [info].
  const CustomModelDefinition({required this.name, this.info});
}

/// Signature used to provide an API key (or bearer token) for requests.
typedef OpenAIApiKeyProvider = FutureOr<String> Function();

/// Public constant handle for the OpenAI-compatible plugin.
///
/// Use this to create the plugin and to reference models:
///
/// ```dart
/// // Create the plugin
/// final ai = Genkit(plugins: [
///   openAI(apiKey: Platform.environment['OPENAI_API_KEY']),
/// ]);
///
/// // Reference a model
/// final response = await ai.generate(
///   model: openAI.model('gpt-4o'),
///   prompt: 'Hello!',
/// );
/// ```
const OpenAICompatPluginHandle openAI = OpenAICompatPluginHandle();

/// Handle class for configuring and referencing OpenAI-compatible models.
///
/// Typically accessed via the top-level [openAI] constant rather than
/// instantiated directly.
class OpenAICompatPluginHandle {
  /// Creates a new [OpenAICompatPluginHandle].
  const OpenAICompatPluginHandle();

  /// Create the plugin instance.
  ///
  /// The [name] parameter allows uniquely identifying each plugin instance
  /// (e.g. `'openrouter'`, `'nanogpt'`). It defaults to
  /// [defaultOpenAINamespace] and is used as the namespace prefix for all
  /// models registered by this instance (e.g. `openrouter/gpt-4o`).
  GenkitPlugin call({
    String name = defaultOpenAINamespace,
    String? apiKey,
    OpenAIApiKeyProvider? apiKeyProvider,
    String? baseUrl,
    List<CustomModelDefinition>? models,
    Map<String, String>? headers,
    http.Client? httpClient,
  }) {
    return OpenAIPlugin(
      name: name,
      apiKey: apiKey,
      apiKeyProvider: apiKeyProvider,
      baseUrl: baseUrl,
      customModels: models ?? const [],
      headers: headers,
      httpClient: httpClient,
    );
  }

  /// Reference to a model.
  ///
  /// The optional [namespace] defaults to [defaultOpenAINamespace] and is the
  /// prefix used when looking up the model (e.g. `openai/gpt-4o`). Pass a
  /// custom value when the plugin was created with a custom name.
  ModelRef<chat.OpenAIChatOptions> model(
    String name, {
    String namespace = defaultOpenAINamespace,
  }) {
    return modelRef(
      '$namespace/$name',
      customOptions: chat.chatModelOptionsSchema(),
    );
  }
}
