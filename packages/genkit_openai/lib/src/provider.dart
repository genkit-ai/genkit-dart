// Copyright 2026 Google LLC
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

import 'package:genkit/plugin.dart';

import '../genkit_openai.dart' show defaultOpenAINamespace;
import 'chat_body_client.dart';
import 'known_deepseek_models.dart';
import 'known_embedders.dart';
import 'known_models.dart';
import 'known_xai_models.dart';
import 'speech.dart' show knownSpeechModels;
import 'transcription.dart' show knownTranscriptionModels;

/// The facts that differ between hosts speaking the OpenAI Chat Completions
/// API, gathered in one value.
///
/// `OpenAIPlugin` serves more than OpenAI: the same wire protocol reaches
/// DeepSeek, Groq, OpenRouter and the rest by pointing `baseUrl` elsewhere.
/// Most of those differences are none of the plugin's business — a compat host
/// is left to answer for itself. The ones collected here are the differences
/// the plugin cannot avoid having an opinion about, because it has to write the
/// request and read the environment before anyone else gets a say.
///
/// One value rather than a handful of constructor flags, so that adding the
/// next provider is a matter of describing it rather than threading another
/// parameter through the plugin. This is the same contract `KnownOpenAIModel`
/// states for per-model behaviour, one level up.
final class OpenAIProvider {
  /// Plugin name, and so the action namespace, when the caller names none.
  final String defaultNamespace;

  /// Host to dial when the caller names none. `null` means OpenAI's own,
  /// which the SDK supplies.
  final String? defaultBaseUrl;

  /// Environment variable consulted for the API key.
  final String apiKeyEnvVar;

  /// Capability metadata for a model served by this provider.
  ///
  /// `compat` is true when the caller pointed the plugin at some other host,
  /// in which case the provider's own deployment details — label, lifecycle
  /// stage, snapshot list — describe something the backend is not.
  final ModelInfo Function(String model, {required bool compat}) infoFor;

  /// Whether the named model thinks before answering, or `null` when the name
  /// is not curated and so has no claim to check.
  final bool? Function(String model) reasonsFor;

  /// Whether the host needs previous turns' reasoning replayed on a request
  /// that carries tools.
  ///
  /// DeepSeek concatenates it into the context and loses it otherwise. OpenAI
  /// never asked for the field, so it is not sent there at all.
  final bool replaysReasoning;

  /// Rewrites an encoded chat-completions body, or null when the request the
  /// SDK builds is already the one the host reads.
  ///
  /// The escape hatch of last resort — see [ChatBodyClient] for why it has to
  /// happen after encoding rather than on the request object.
  final Map<String, dynamic> Function(Map<String, dynamic> body)?
  rewriteChatBody;

  /// Whether the host reads `max_tokens` rather than `max_completion_tokens`.
  ///
  /// OpenAI deprecated the former for the latter; most compatible hosts never
  /// followed, and a host that reads only `max_tokens` silently ignores a
  /// limit sent under the newer name rather than rejecting it.
  final bool usesLegacyMaxTokens;

  /// Model ids listed without network access, when the plugin is pointed at
  /// this provider's own host.
  final List<String> catalogIds;

  /// Embedder ids listed the same way, or empty for a provider with no
  /// embeddings API.
  ///
  /// Empty also means `resolve` declines embedder lookups for this provider,
  /// rather than building one whose every call would 404.
  final List<String> embedderIds;

  /// Text-to-speech ids listed the same way, or empty for a provider with no
  /// `/audio/speech`.
  final List<String> speechIds;

  /// Transcription ids listed the same way, or empty for a provider with no
  /// `/audio/transcriptions`.
  ///
  /// Empty also keeps a name that merely *looks* like a transcription model
  /// from being routed to an endpoint this host does not serve.
  final List<String> transcriptionIds;

  /// Whether the host can be handed a JSON *schema*, rather than only being
  /// asked for JSON.
  ///
  /// `response_format: json_schema` is an OpenAI extension. A host without it
  /// takes `json_object` and obeys the schema only as far as the prompt
  /// carries it.
  final bool supportsJsonSchema;

  const OpenAIProvider({
    required this.defaultNamespace,
    required this.defaultBaseUrl,
    required this.apiKeyEnvVar,
    required this.infoFor,
    required this.catalogIds,
    required this.reasonsFor,
    this.embedderIds = const [],
    this.speechIds = const [],
    this.transcriptionIds = const [],
    this.replaysReasoning = false,
    this.rewriteChatBody,
    this.usesLegacyMaxTokens = false,
    this.supportsJsonSchema = true,
  });
}

/// OpenAI itself, and the default for any host the plugin is pointed at
/// without being told whose dialect it speaks.
final openAIProvider = OpenAIProvider(
  defaultNamespace: defaultOpenAINamespace,
  // The SDK's own default is api.openai.com, and leaving it null is what tells
  // the rest of the plugin that this instance is talking to OpenAI proper.
  defaultBaseUrl: null,
  apiKeyEnvVar: 'OPENAI_API_KEY',
  infoFor: (model, {required compat}) =>
      compat ? compatModelInfo(model) : modelInfoFor(model),
  catalogIds: knownChatModels,
  reasonsFor: (model) => knownOpenAIModelFor(model)?.reasons,
  embedderIds: knownEmbedderModels,
  speechIds: knownSpeechModels,
  transcriptionIds: knownTranscriptionModels,
);

/// DeepSeek, which speaks the same protocol with a few differences the plugin
/// has to know about: the key it reads, the token-limit field, the absence of
/// `json_schema`, and the `thinking` object that carries its mode.
final deepSeekProvider = OpenAIProvider(
  defaultNamespace: defaultDeepSeekNamespace,
  defaultBaseUrl: 'https://api.deepseek.com',
  apiKeyEnvVar: 'DEEPSEEK_API_KEY',
  infoFor: (model, {required compat}) =>
      compat ? compatDeepSeekModelInfo(model) : deepSeekModelInfoFor(model),
  catalogIds: knownDeepSeekChatModels,
  // No claim, ever. Thinking is a request-time mode on DeepSeek rather than a
  // model property: `deepseek-chat` is the non-thinking *default* of
  // `deepseek-flash`, and it answers a `reasoning_effort` of `high` with
  // reasoning tokens all the same. Whether a level applies is the host's call,
  // as it already is for a compat backend.
  reasonsFor: (_) => null,
  replaysReasoning: true,
  rewriteChatBody: deepSeekChatBody,
  usesLegacyMaxTokens: true,
  supportsJsonSchema: false,
);

/// xAI, which is the closest of the three to OpenAI: the same request fields,
/// the same `json_schema` structured outputs, a different host and key.
///
/// The reasoning vocabulary varies per model there - 4.3 takes `none` and
/// defaults to `low`, 4.6 takes neither - and which pairing works is left to
/// the API, as it is for every other host.
final xaiProvider = OpenAIProvider(
  defaultNamespace: defaultXaiNamespace,
  defaultBaseUrl: 'https://api.x.ai/v1',
  apiKeyEnvVar: 'XAI_API_KEY',
  infoFor: (model, {required compat}) =>
      compat ? compatXaiModelInfo(model) : xaiModelInfoFor(model),
  catalogIds: knownXaiChatModels,
  reasonsFor: (model) => knownXaiModelFor(model)?.reasons,
);

/// Moves `reasoning_effort` into the `thinking` object DeepSeek reads.
/// Adds the `thinking` object DeepSeek derives its mode from.
///
/// DeepSeek reads `reasoning_effort` where OpenAI does, at the top level, and
/// separately takes a `thinking` object that turns thinking on or off. The
/// vendor's own OpenAI-format samples send both, so both go out: the effort
/// stays where it was, and the toggle says which mode it applies to.
///
/// `none` is the exception in shape rather than in meaning. It is how a caller
/// asks for no thinking at all, which is what `thinking: {type: disabled}`
/// says; the effort itself is dropped, since there is no effort to spend.
///
/// Sends nothing when no effort was asked for: thinking is on by default for
/// the models that support it, and saying so explicitly would only risk
/// disagreeing with the default later.
///
/// https://api-docs.deepseek.com/api/create-chat-completion
Map<String, dynamic> deepSeekChatBody(Map<String, dynamic> body) {
  final effort = body['reasoning_effort'];
  if (effort == null) return body;

  if (effort == 'none') {
    return {
      for (final entry in body.entries)
        if (entry.key != 'reasoning_effort') entry.key: entry.value,
      'thinking': const {'type': 'disabled'},
    };
  }

  return {
    ...body,
    'thinking': const {'type': 'enabled'},
  };
}
