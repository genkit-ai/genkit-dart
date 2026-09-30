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
import 'src/known_deepseek_models.dart';
import 'src/known_xai_models.dart';
import 'src/openai_plugin.dart';
import 'src/provider.dart';
import 'src/speech.dart' as speech;
import 'src/transcription.dart' as transcription;

export 'src/chat.dart' show OpenAIChatOptions, OpenAIOptions;
export 'src/embed.dart' show OpenAIEmbedderOptions;
// The curated catalogs are internal metadata, not API: they only enrich
// names that resolve anyway, and entries come and go with the providers'
// model lists. Only the namespace defaults are public, because they are
// default values in public signatures.
export 'src/known_deepseek_models.dart' show defaultDeepSeekNamespace;
export 'src/known_xai_models.dart' show defaultXaiNamespace;
export 'src/speech.dart' show OpenAISpeechOptions;
export 'src/transcription.dart' show OpenAITranscriptionOptions;

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
  /// When `null`, the model takes the plugin's curated metadata if it has an
  /// entry for [name], and capabilities inferred from the name otherwise.
  final ModelInfo? info;

  /// Which API this model is served by, when its name does not say.
  ///
  /// When `null` the name decides: `*tts*` is speech, `*whisper*` and
  /// `*transcribe*` are transcription, everything else is chat. Set it for a
  /// compatible provider whose model is named differently - `info` cannot
  /// carry this, since `supports: {'media': true}` describes a vision chat
  /// model just as well as a transcription one.
  final OpenAIModelKind? kind;

  /// Creates a custom model definition with the given [name] and optional
  /// [info] and [kind].
  const CustomModelDefinition({required this.name, this.info, this.kind});
}

/// Which OpenAI API serves a model.
///
/// Names it for a [CustomModelDefinition] whose own name does not follow
/// OpenAI's conventions; discovered and curated models are classified by name.
// A class rather than an enum so that adding a kind (image, realtime) is not
// a breaking change for callers who switch over it.
final class OpenAIModelKind {
  const OpenAIModelKind._(this._name);

  final String _name;

  /// Chat completions, `POST /chat/completions`.
  static const chat = OpenAIModelKind._('chat');

  /// Text to speech, `POST /audio/speech`.
  static const speech = OpenAIModelKind._('speech');

  /// Speech to text, `POST /audio/transcriptions`.
  static const transcription = OpenAIModelKind._('transcription');

  @override
  String toString() => 'OpenAIModelKind.$_name';
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

  /// Reference to a text-to-speech model, e.g. `tts-1` or `gpt-4o-mini-tts`.
  ///
  /// Separate from [model] because speech models take
  /// `OpenAISpeechOptions` rather than `OpenAIChatOptions`, and return a
  /// single audio media part instead of text:
  ///
  /// ```dart
  /// final response = await ai.generate(
  ///   model: openAI.speechModel('gpt-4o-mini-tts'),
  ///   prompt: 'Genkit is an amazing AI framework.',
  ///   config: OpenAISpeechOptions(
  ///     voice: 'sage',
  ///     instructions: 'Speak in a calm, warm tone.',
  ///   ),
  /// );
  /// final audio = response.media; // data:audio/mpeg;base64,...
  /// ```
  ModelRef<speech.OpenAISpeechOptions> speechModel(
    String name, {
    String namespace = defaultOpenAINamespace,
  }) {
    return modelRef(
      '$namespace/$name',
      customOptions: speech.speechModelOptionsSchema(),
    );
  }

  /// Reference to a speech-to-text model, e.g. `whisper-1` or
  /// `gpt-4o-transcribe`.
  ///
  /// Transcription models read audio from the request and answer with text,
  /// so the audio goes in through `promptParts`:
  ///
  /// ```dart
  /// final response = await ai.generate(
  ///   model: openAI.transcriptionModel('whisper-1'),
  ///   promptParts: [MediaPart(media: recording)],
  ///   config: OpenAITranscriptionOptions(language: 'en'),
  /// );
  /// print(response.text);
  /// ```
  ///
  /// `whisper-1` also accepts `translate: true` to return English text for
  /// audio in any language.
  ModelRef<transcription.OpenAITranscriptionOptions> transcriptionModel(
    String name, {
    String namespace = defaultOpenAINamespace,
  }) {
    return modelRef(
      '$namespace/$name',
      customOptions: transcription.transcriptionModelOptionsSchema(),
    );
  }
}

/// Public constant handle for the DeepSeek plugin.
///
/// DeepSeek speaks the OpenAI Chat Completions API, so this is the same plugin
/// as [openAI] pointed at `https://api.deepseek.com` and told whose dialect it
/// is speaking — which key to read, which models to describe, and the couple
/// of request fields DeepSeek spells differently.
///
/// ```dart
/// final ai = Genkit(plugins: [deepSeek()]);
///
/// final response = await ai.generate(
///   model: deepSeek.model('deepseek-flash'),
///   prompt: 'Hello!',
/// );
/// ```
///
/// The key falls back to the `DEEPSEEK_API_KEY` environment variable. As with
/// [openAI], creating the plugin does no I/O and needs no key.
const DeepSeekPluginHandle deepSeek = DeepSeekPluginHandle();

/// Handle class for configuring and referencing DeepSeek models.
///
/// Typically accessed via the top-level [deepSeek] constant rather than
/// instantiated directly.
class DeepSeekPluginHandle {
  /// Creates a new [DeepSeekPluginHandle].
  const DeepSeekPluginHandle();

  /// Create the plugin instance.
  ///
  /// [name] is the namespace models register under, defaulting to
  /// [defaultDeepSeekNamespace]. [baseUrl] defaults to DeepSeek's own host;
  /// pointing it elsewhere — a gateway, a proxy — keeps DeepSeek's
  /// capabilities but drops its deployment details, exactly as a custom
  /// `baseUrl` does for [openAI].
  GenkitPlugin call({
    String name = defaultDeepSeekNamespace,
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
      provider: deepSeekProvider,
    );
  }

  /// Reference to a DeepSeek model.
  ModelRef<chat.OpenAIChatOptions> model(
    String name, {
    String namespace = defaultDeepSeekNamespace,
  }) {
    return modelRef(
      '$namespace/$name',
      customOptions: chat.chatModelOptionsSchema(),
    );
  }
}

/// Public constant handle for the xAI plugin.
///
/// Grok speaks the OpenAI Chat Completions API, so this is the same plugin as
/// [openAI] pointed at `https://api.x.ai/v1` with xAI's key and catalog. Of
/// the curated providers it is the closest to OpenAI: same request fields,
/// same `json_schema` structured outputs.
///
/// ```dart
/// final ai = Genkit(plugins: [xAI()]);
///
/// final response = await ai.generate(
///   model: xAI.model('grok-4.6'),
///   prompt: 'Hello!',
/// );
/// ```
///
/// The key falls back to the `XAI_API_KEY` environment variable.
const XaiPluginHandle xAI = XaiPluginHandle();

/// Handle class for configuring and referencing xAI models.
///
/// Typically accessed via the top-level [xAI] constant rather than
/// instantiated directly.
class XaiPluginHandle {
  /// Creates a new [XaiPluginHandle].
  const XaiPluginHandle();

  /// Create the plugin instance.
  ///
  /// [baseUrl] defaults to xAI's own host; pointing it elsewhere keeps Grok's
  /// capabilities but drops xAI's deployment details, as it does for [openAI].
  GenkitPlugin call({
    String name = defaultXaiNamespace,
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
      provider: xaiProvider,
    );
  }

  /// Reference to an xAI model.
  ModelRef<chat.OpenAIChatOptions> model(
    String name, {
    String namespace = defaultXaiNamespace,
  }) {
    return modelRef(
      '$namespace/$name',
      customOptions: chat.chatModelOptionsSchema(),
    );
  }
}
