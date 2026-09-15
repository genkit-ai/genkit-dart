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
import 'src/embed.dart' as embed;
import 'src/known_embedders.dart';
import 'src/known_models.dart';
import 'src/openai_plugin.dart';

export 'src/chat.dart' show OpenAIChatOptions, OpenAIOptions;
export 'src/converters.dart' show GenkitConverter;
export 'src/embed.dart' show OpenAIEmbedderOptions;
// The embedder catalog is public for the same reason the model catalog is.
// `embedderInfoFor` and its compat variant are not: until core grows an
// `EmbedderInfo` (#327) they hand back a raw map whose shape is expected to
// change, and freezing that as API now would make the migration a breaking
// one.
export 'src/known_embedders.dart'
    show
        KnownOpenAIEmbedder,
        knownEmbedderModels,
        knownOpenAIEmbedderFor,
        knownOpenAIEmbedders;
// The catalog and the capability vocabulary are public: describing a model
// the plugin does not know is a supported thing to do, and a caller doing it
// should reach for the same presets the curated entries use.
//
// The resolution mechanics are not. `dynamicModelInfo`, `compatModelInfo`,
// `openAIModelAlias` and `openAIModelSpelling` are how `modelInfoFor` decides
// what a name means; they are reachable from `src/` for tests, but committing
// to them as API would freeze policy this plugin should stay free to change.
export 'src/known_models.dart'
    show
        KnownOpenAIModel,
        OpenAIModelStage,
        knownChatModels,
        knownOpenAIModelFor,
        knownOpenAIModels,
        modelInfoFor,
        multimodalLegacySupports,
        multimodalNoToolsSupports,
        multimodalSupports,
        reasoningPreviewSupports,
        reasoningSupports,
        reasoningTextOnlySupports,
        supportsTools,
        supportsVision,
        textOnlyLegacySupports,
        textOnlyNoJsonSupports;
export 'src/utils.dart' show getModelType;

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
  /// When `null`, the model takes its curated entry from [knownOpenAIModels]
  /// if it has one, and [dynamicModelInfo] otherwise.
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
/// // Create the plugin. The key falls back to the OPENAI_API_KEY
/// // environment variable when not passed explicitly.
/// final ai = Genkit(plugins: [openAI()]);
///
/// // Reference a model
/// final response = await ai.generate(
///   model: openAI.model('gpt-4o'),
///   prompt: 'Hello!',
/// );
/// ```
///
/// Creating the plugin does no I/O and needs no key: models resolve on demand,
/// and a missing or invalid key surfaces at generate time.
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
  ///
  /// If neither [apiKey] nor [apiKeyProvider] is given, the key is read from
  /// the `OPENAI_API_KEY` environment variable.
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

  /// Reference to an embedding model.
  ///
  /// Takes [namespace] for the same reason [model] does: it is the prefix the
  /// embedder is looked up under (e.g. `openai/text-embedding-3-small`), and a
  /// plugin registered with a custom name needs it passed.
  ///
  /// ```dart
  /// final vectors = await ai.embed(
  ///   embedder: openAI.embedder('text-embedding-3-small'),
  ///   document: DocumentData(content: [TextPart(text: 'hello')]),
  /// );
  /// ```
  EmbedderRef<embed.OpenAIEmbedderOptions> embedder(
    String name, {
    String namespace = defaultOpenAINamespace,
  }) {
    return embedderRef(
      '$namespace/$name',
      customOptions: embed.embedderOptionsSchema(),
    );
  }
}

/// Typed [ModelRef]s for the OpenAI models curated by the `openai` plugin.
///
/// Each entry is equivalent to `openAI.model('<name>')`, which remains the
/// escape hatch for models not listed here and for plugin instances registered
/// under a custom namespace.
///
/// Only models OpenAI still serves get a ref. A curated model whose stage is
/// [OpenAIModelStage.deprecated] is reachable by name — see
/// [KnownOpenAIModel] — but is not offered for autocomplete.
abstract final class OpenAIModels {
  // GPT-5.6.
  /// OpenAI GPT-5.6 Sol.
  static final ModelRef<chat.OpenAIChatOptions> gpt56Sol = openAI.model(
    KnownOpenAIModel.gpt56Sol.id,
  );

  /// OpenAI GPT-5.6 Terra.
  static final ModelRef<chat.OpenAIChatOptions> gpt56Terra = openAI.model(
    KnownOpenAIModel.gpt56Terra.id,
  );

  /// OpenAI GPT-5.6 Luna.
  static final ModelRef<chat.OpenAIChatOptions> gpt56Luna = openAI.model(
    KnownOpenAIModel.gpt56Luna.id,
  );

  // GPT-5.x.
  /// OpenAI GPT-5.5.
  static final ModelRef<chat.OpenAIChatOptions> gpt55 = openAI.model(
    KnownOpenAIModel.gpt55.id,
  );

  /// OpenAI GPT-5.4.
  static final ModelRef<chat.OpenAIChatOptions> gpt54 = openAI.model(
    KnownOpenAIModel.gpt54.id,
  );

  /// OpenAI GPT-5.4-mini.
  static final ModelRef<chat.OpenAIChatOptions> gpt54Mini = openAI.model(
    KnownOpenAIModel.gpt54Mini.id,
  );

  /// OpenAI GPT-5.4-nano.
  static final ModelRef<chat.OpenAIChatOptions> gpt54Nano = openAI.model(
    KnownOpenAIModel.gpt54Nano.id,
  );

  /// OpenAI GPT-5.2.
  static final ModelRef<chat.OpenAIChatOptions> gpt52 = openAI.model(
    KnownOpenAIModel.gpt52.id,
  );

  /// OpenAI GPT-5.1.
  static final ModelRef<chat.OpenAIChatOptions> gpt51 = openAI.model(
    KnownOpenAIModel.gpt51.id,
  );

  // GPT-5.
  /// OpenAI GPT-5.
  static final ModelRef<chat.OpenAIChatOptions> gpt5 = openAI.model(
    KnownOpenAIModel.gpt5.id,
  );

  /// OpenAI GPT-5-mini.
  static final ModelRef<chat.OpenAIChatOptions> gpt5Mini = openAI.model(
    KnownOpenAIModel.gpt5Mini.id,
  );

  /// OpenAI GPT-5-nano.
  static final ModelRef<chat.OpenAIChatOptions> gpt5Nano = openAI.model(
    KnownOpenAIModel.gpt5Nano.id,
  );

  /// OpenAI GPT-5 Chat, the ChatGPT-tuned snapshot. No function calling.
  static final ModelRef<chat.OpenAIChatOptions> gpt5ChatLatest = openAI.model(
    KnownOpenAIModel.gpt5ChatLatest.id,
  );

  // GPT-4.1.
  /// OpenAI GPT-4.1.
  static final ModelRef<chat.OpenAIChatOptions> gpt41 = openAI.model(
    KnownOpenAIModel.gpt41.id,
  );

  /// OpenAI GPT-4.1-mini.
  static final ModelRef<chat.OpenAIChatOptions> gpt41Mini = openAI.model(
    KnownOpenAIModel.gpt41Mini.id,
  );

  /// OpenAI GPT-4.1-nano.
  static final ModelRef<chat.OpenAIChatOptions> gpt41Nano = openAI.model(
    KnownOpenAIModel.gpt41Nano.id,
  );

  // GPT-4o.
  /// OpenAI GPT-4o.
  static final ModelRef<chat.OpenAIChatOptions> gpt4o = openAI.model(
    KnownOpenAIModel.gpt4o.id,
  );

  /// OpenAI GPT-4o-mini.
  static final ModelRef<chat.OpenAIChatOptions> gpt4oMini = openAI.model(
    KnownOpenAIModel.gpt4oMini.id,
  );

  // Reasoning models.
  /// OpenAI o3.
  static final ModelRef<chat.OpenAIChatOptions> o3 = openAI.model(
    KnownOpenAIModel.o3.id,
  );

  /// OpenAI o4-mini.
  static final ModelRef<chat.OpenAIChatOptions> o4Mini = openAI.model(
    KnownOpenAIModel.o4Mini.id,
  );

  /// OpenAI o3-mini. Text-only.
  static final ModelRef<chat.OpenAIChatOptions> o3Mini = openAI.model(
    KnownOpenAIModel.o3Mini.id,
  );

  /// OpenAI o1.
  static final ModelRef<chat.OpenAIChatOptions> o1 = openAI.model(
    KnownOpenAIModel.o1.id,
  );

  // Legacy models.
  /// OpenAI GPT-4-turbo.
  static final ModelRef<chat.OpenAIChatOptions> gpt4Turbo = openAI.model(
    KnownOpenAIModel.gpt4Turbo.id,
  );

  /// OpenAI GPT-4. Text-only.
  static final ModelRef<chat.OpenAIChatOptions> gpt4 = openAI.model(
    KnownOpenAIModel.gpt4.id,
  );

  /// OpenAI GPT-3.5-turbo. Text-only.
  static final ModelRef<chat.OpenAIChatOptions> gpt35Turbo = openAI.model(
    KnownOpenAIModel.gpt35Turbo.id,
  );

  /// Every ref above, in catalog order.
  ///
  /// Exists so the statics cannot silently fall behind [KnownOpenAIModel]: a
  /// test asserts this names exactly the models OpenAI still serves, and
  /// fails when an entry is added without a ref here.
  static final List<ModelRef<chat.OpenAIChatOptions>> all = [
    gpt56Sol,
    gpt56Terra,
    gpt56Luna,
    gpt55,
    gpt54,
    gpt54Mini,
    gpt54Nano,
    gpt52,
    gpt51,
    gpt5,
    gpt5Mini,
    gpt5Nano,
    gpt5ChatLatest,
    gpt41,
    gpt41Mini,
    gpt41Nano,
    gpt4o,
    gpt4oMini,
    o3,
    o4Mini,
    o3Mini,
    o1,
    gpt4Turbo,
    gpt4,
    gpt35Turbo,
  ];
}

/// Typed [EmbedderRef]s for the OpenAI embedders curated by the `openai`
/// plugin.
///
/// Each entry is equivalent to `openAI.embedder('<name>')`, which remains the
/// escape hatch for embedders not listed here and for plugin instances
/// registered under a custom namespace.
abstract final class OpenAIEmbedders {
  /// OpenAI text-embedding-3-small, 1536 dimensions.
  static final EmbedderRef<embed.OpenAIEmbedderOptions> textEmbedding3Small =
      openAI.embedder(KnownOpenAIEmbedder.textEmbedding3Small.id);

  /// OpenAI text-embedding-3-large, 3072 dimensions.
  static final EmbedderRef<embed.OpenAIEmbedderOptions> textEmbedding3Large =
      openAI.embedder(KnownOpenAIEmbedder.textEmbedding3Large.id);

  /// OpenAI text-embedding-ada-002, 1536 dimensions and no `dimensions`
  /// option.
  static final EmbedderRef<embed.OpenAIEmbedderOptions> textEmbeddingAda002 =
      openAI.embedder(KnownOpenAIEmbedder.textEmbeddingAda002.id);

  /// Every ref above, in catalog order.
  ///
  /// Exists so the statics cannot silently fall behind [KnownOpenAIEmbedder],
  /// the same way `OpenAIModels.all` guards the model refs.
  static final List<EmbedderRef<embed.OpenAIEmbedderOptions>> all = [
    textEmbedding3Small,
    textEmbedding3Large,
    textEmbeddingAda002,
  ];
}
