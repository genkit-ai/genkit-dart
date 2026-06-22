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
import 'src/ollama_plugin.dart';

export 'src/chat.dart' show OllamaChatOptions;
export 'src/converters.dart' show GenkitConverter;
export 'src/ollama_plugin.dart' show OllamaPlugin, defaultOllamaBaseUrl;
export 'src/utils.dart'
    show
        embeddingDimensionsFromShow,
        genericModelInfo,
        isEmbedderShow,
        modelInfoFromShow;

/// Default plugin / namespace name used when no custom name is provided.
const String defaultOllamaNamespace = 'ollama';

/// Signature for an async callback that returns HTTP headers per request.
///
/// Use this to inject short-lived auth tokens when talking to a remote or
/// proxied Ollama deployment.
typedef OllamaHeadersProvider = FutureOr<Map<String, String>> Function();

/// Defines a model to register eagerly with optional capability metadata.
///
/// On-demand resolution (via [OllamaPluginHandle.model]) covers most cases;
/// use this to pin a model and its [info] at init time.
class CustomModelDefinition {
  /// The model identifier, e.g. `'llama3.2'`.
  final String name;

  /// Optional capability metadata. When null, a generic profile is used.
  final ModelInfo? info;

  /// Creates a custom model definition.
  const CustomModelDefinition({required this.name, this.info});
}

/// Defines an embedder to register eagerly.
class OllamaEmbedderDefinition {
  /// The embedding model identifier, e.g. `'nomic-embed-text'`.
  final String name;

  /// Optional embedding dimension. When null, it is discovered via `/api/show`
  /// during [OllamaPluginHandle.call]'s `list()`, or left unset.
  final int? dimensions;

  /// Creates an embedder definition.
  const OllamaEmbedderDefinition({required this.name, this.dimensions});
}

/// Public constant handle for the Ollama plugin.
///
/// ```dart
/// final ai = Genkit(plugins: [ollama()]);
///
/// final response = await ai.generate(
///   model: ollama.model('llama3.2'),
///   prompt: 'Hello!',
/// );
/// ```
const OllamaPluginHandle ollama = OllamaPluginHandle();

/// Handle class for configuring and referencing Ollama models and embedders.
///
/// Typically accessed via the top-level [ollama] constant.
class OllamaPluginHandle {
  /// Creates a new [OllamaPluginHandle].
  const OllamaPluginHandle();

  /// Creates the plugin instance.
  ///
  /// [baseUrl] defaults to a local server (`http://localhost:11434`). Provide
  /// [headers] for static headers, or [headersProvider] for per-request auth.
  GenkitPlugin call({
    String name = defaultOllamaNamespace,
    String? baseUrl,
    Map<String, String>? headers,
    OllamaHeadersProvider? headersProvider,
    List<CustomModelDefinition>? models,
    List<OllamaEmbedderDefinition>? embedders,
    http.Client? httpClient,
  }) {
    return OllamaPlugin(
      name: name,
      baseUrl: baseUrl,
      headers: headers,
      headersProvider: headersProvider,
      customModels: models ?? const [],
      customEmbedders: embedders ?? const [],
      httpClient: httpClient,
    );
  }

  /// Returns a reference to an Ollama chat model.
  ///
  /// The [namespace] defaults to [defaultOllamaNamespace]; pass a custom value
  /// when the plugin was created with a custom name.
  ModelRef<chat.OllamaChatOptions> model(
    String name, {
    String namespace = defaultOllamaNamespace,
  }) {
    return modelRef(
      '$namespace/$name',
      customOptions: chat.chatModelOptionsSchema(),
    );
  }

  /// Returns a reference to an Ollama embedder.
  EmbedderRef<dynamic> embedder(
    String name, {
    String namespace = defaultOllamaNamespace,
  }) {
    return embedderRef('$namespace/$name');
  }
}
