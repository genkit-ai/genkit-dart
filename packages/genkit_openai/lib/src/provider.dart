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
import 'known_mistral_models.dart';
import 'known_models.dart';
import 'known_xai_models.dart';
import 'speech.dart' show knownSpeechModels;
import 'transcription.dart' show knownTranscriptionModels;

/// Provider-specific credentials, model metadata and request behaviour for an
/// OpenAI-compatible API.
///
/// Only the differences the plugin cannot avoid having an opinion about: it
/// writes the request and reads the environment before anyone else gets a say.
/// Everything else a compat host answers for itself.
final class OpenAIProvider {
  /// Plugin name, and so the action namespace, when the caller names none.
  final String defaultNamespace;

  /// Host to dial when the caller names none. `null` means OpenAI's own,
  /// which the SDK supplies.
  final String? defaultBaseUrl;

  /// Every host that is this provider's own API, or null when that is only
  /// [defaultBaseUrl]'s.
  ///
  /// For a provider that serves the same API from more than one host, such as
  /// Mistral's regional ones. A base URL on any of them gets the provider's
  /// catalog and request checks, where any other host is treated as a
  /// gateway.
  final Set<String>? ownHosts;

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

  /// The `reasoningEffort` levels the named model takes, or null when any
  /// level the plugin knows is left to the host.
  ///
  /// For a provider whose reasoning models each take their own set, such as
  /// Mistral's, so a level the model would answer with a 400 is refused with
  /// the levels it does take. Checked only where [reasonsFor] is: on the
  /// provider's own host, for a model the caller did not declare.
  final Set<String>? Function(String model)? reasoningEffortsFor;

  /// Whether the host needs previous turns' reasoning replayed on a request
  /// that carries tools.
  ///
  /// DeepSeek concatenates it into the context and loses it otherwise. OpenAI
  /// never asked for the field, so it is not sent there at all.
  final bool replaysReasoning;

  /// The `reasoningSource` this provider's reasoning parts are marked with,
  /// or null for a host whose reasoning is never sent back.
  ///
  /// Set, every reasoning part read from a reply is marked with it and holds
  /// its own signature, one part per reasoning entry, and on later turns the
  /// reasoning parts so marked are carried to [rewriteChatBody] as
  /// `reasoning_details` for it to put where the host reads them. Reasoning
  /// another model left in the history has a different mark, or none, and is
  /// dropped. The mark matches the JS and Python plugins'.
  ///
  /// Unset, reasoning is read as before: one part of joined text, with no
  /// metadata.
  final String? reasoningSource;

  /// Rewrites an encoded chat-completions body, or null when the request the
  /// SDK builds is already the one the host reads.
  ///
  /// The escape hatch of last resort — see [ChatBodyClient] for why it has to
  /// happen after encoding rather than on the request object.
  final Map<String, dynamic> Function(Map<String, dynamic> body)?
  rewriteChatBody;

  /// Rewrites a decoded chat-completions reply - a whole completion, or one
  /// streamed chunk - into the shape `openai_dart` parses, or null when the
  /// host already replies in OpenAI's.
  ///
  /// Applied before the SDK sees the reply, for the same reason
  /// [rewriteChatBody] is applied after it encodes the request.
  final Map<String, dynamic> Function(Map<String, dynamic> reply)?
  rewriteChatReply;

  /// Rewrites an encoded `/embeddings` body, or null when the request the
  /// SDK builds is already the one the host reads. See [rewriteChatBody].
  final Map<String, dynamic> Function(Map<String, dynamic> body)?
  rewriteEmbeddingBody;

  /// Whether the host reads `max_tokens` rather than `max_completion_tokens`.
  ///
  /// OpenAI deprecated the former for the latter; most compatible hosts never
  /// followed, and a host that reads only `max_tokens` silently ignores a
  /// limit sent under the newer name rather than rejecting it.
  final bool usesLegacyMaxTokens;

  /// Model ids listed without network access, when the plugin is pointed at
  /// this provider's own host.
  final List<String> catalogIds;

  /// Embedder metadata for [embedderIds] and any other name, split on
  /// `compat` the way [infoFor] is. Null means the OpenAI catalog's.
  final Map<String, dynamic> Function(String embedder, {required bool compat})?
  embedderInfoFor;

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

  /// Whether a discovered model id is one this plugin can actually serve.
  ///
  /// Discovery reports what the host lists, which is not the same as what
  /// chat completions will accept: xAI lists `grok-4.20-multi-agent-0309` and
  /// then answers "Multi Agent requests are not allowed on chat completions"
  /// for it. Leaving such a name out of the curated catalog is not enough,
  /// since discovery puts it back. Names this rejects are dropped from the
  /// listing; `resolve` still serves any id named explicitly.
  final bool Function(String model) servesModel;

  /// What a `GET /models` entry says about whether chat completions serve
  /// it: true or false when the entry says, null when it does not, or null
  /// for a host whose listing carries nothing beyond OpenAI's fields.
  ///
  /// Set, it decides ahead of every name rule in discovery: an entry it calls
  /// chat is listed as a chat model, one it rules out is listed only if its
  /// name is an embedder's, and only a null answer falls through to the name
  /// rules and [servesModel]. `resolve` still serves any id named explicitly.
  final bool? Function(Map<String, dynamic> listing)? chatFromListing;

  /// Capability metadata a `GET /models` entry gives for a model, or null to
  /// leave the model to [infoFor].
  ///
  /// Only consulted for a model discovery lists as chat. A curated model keeps
  /// its curated metadata, so this answers null for one; it is for the models
  /// the catalog does not know, which would otherwise claim nothing beyond
  /// text. The info is used for the listing and for the action resolved under
  /// that name afterwards.
  final ModelInfo? Function(String model, Map<String, dynamic> listing)?
  infoFromListing;

  /// Whether the host takes OpenAI's `file` content part, which carries a
  /// non-image document such as a PDF inline.
  ///
  /// A host without it would reject the whole request, so such a part is
  /// refused before the request goes out.
  final bool acceptsFileParts;

  /// Whether the host can be handed a JSON *schema*, rather than only being
  /// asked for JSON.
  ///
  /// `response_format: json_schema` is an OpenAI extension. A host without it
  /// takes `json_object` and obeys the schema only as far as the prompt
  /// carries it.
  final bool supportsJsonSchema;

  /// Whether the host takes a `json_schema` response format only when its
  /// root is `type: "object"`.
  ///
  /// OpenAI answers any other root (an array, enum or scalar) with a 400. For
  /// such a host the schema goes out wrapped as the `value` property of an
  /// object, and the reply is unwrapped before Genkit parses it.
  final bool objectSchemaRoot;

  const OpenAIProvider({
    required this.defaultNamespace,
    required this.defaultBaseUrl,
    required this.apiKeyEnvVar,
    required this.infoFor,
    required this.catalogIds,
    required this.reasonsFor,
    this.reasoningEffortsFor,
    this.ownHosts,
    this.embedderIds = const [],
    this.embedderInfoFor,
    this.speechIds = const [],
    this.transcriptionIds = const [],
    this.replaysReasoning = false,
    this.reasoningSource,
    this.rewriteChatBody,
    this.rewriteChatReply,
    this.rewriteEmbeddingBody,
    this.usesLegacyMaxTokens = false,
    this.supportsJsonSchema = true,
    this.objectSchemaRoot = false,
    this.acceptsFileParts = true,
    this.servesModel = _servesAnyModel,
    this.chatFromListing,
    this.infoFromListing,
  });
}

/// Every model a host lists is servable, unless a provider says otherwise.
bool _servesAnyModel(String model) => true;

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
  objectSchemaRoot: true,
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

/// xAI, which is the closest of the curated providers to OpenAI: the same
/// request fields, the same `json_schema` structured outputs, a different host
/// and key.
///
/// The reasoning vocabulary varies per model there - 4.3 takes `none` and
/// defaults to `low`, 4.6 takes neither - and which pairing works is left to
/// the API, as it is for most hosts.
final xaiProvider = OpenAIProvider(
  defaultNamespace: defaultXaiNamespace,
  defaultBaseUrl: 'https://api.x.ai/v1',
  apiKeyEnvVar: 'XAI_API_KEY',
  infoFor: (model, {required compat}) =>
      compat ? compatXaiModelInfo(model) : xaiModelInfoFor(model),
  catalogIds: knownXaiChatModels,
  reasonsFor: (model) => knownXaiModelFor(model)?.reasons,
  servesModel: (model) => !model.toLowerCase().contains('multi-agent'),
);

/// Mistral, which takes OpenAI's request shape with a handful of fields
/// renamed or missing.
///
/// Mistral's request schema is closed: a field it does not define is a 422
/// validation error, not something it ignores. So the token limit goes out as `max_tokens`, and
/// [mistralChatBody] renames or drops what the SDK writes in OpenAI's spelling.
/// `json_schema`, tools and image input are sent unchanged. A non-image
/// document is refused locally: Mistral's `file` part takes only the id of an
/// uploaded file, not OpenAI's inline `file_data`.
///
/// A model that thinks replies with `content` as an array of `thinking` and
/// `text` chunks, which [mistralChatReply] turns into the reasoning fields the
/// SDK reads.
final mistralProvider = OpenAIProvider(
  defaultNamespace: defaultMistralNamespace,
  defaultBaseUrl: 'https://api.mistral.ai/v1',
  ownHosts: mistralHosts,
  apiKeyEnvVar: 'MISTRAL_API_KEY',
  infoFor: (model, {required compat}) =>
      compat ? compatMistralModelInfo(model) : mistralModelInfoFor(model),
  catalogIds: knownMistralChatModels,
  reasonsFor: (model) => knownMistralModelFor(model)?.reasons,
  reasoningEffortsFor: (model) => knownMistralModelFor(model)?.efforts,
  reasoningSource: mistralReasoningSource,
  embedderIds: knownMistralEmbedderModels,
  embedderInfoFor: mistralEmbedderInfoFor,
  // Each `/models` entry says whether it serves chat completions, which rules
  // out OCR, moderation, transcription and speech models alike.
  chatFromListing: mistralServesChat,
  // An uncurated model takes tools and image input from the same entry.
  infoFromListing: mistralInfoFromListing,
  // For a listing without capabilities: the OCR models are served by
  // `/v1/ocr`, not chat completions. `resolve` still serves any id named
  // explicitly.
  servesModel: (model) => !model.toLowerCase().contains('ocr'),
  rewriteChatBody: mistralChatBody,
  rewriteChatReply: mistralChatReply,
  rewriteEmbeddingBody: mistralEmbeddingBody,
  usesLegacyMaxTokens: true,
  acceptsFileParts: false,
);

/// Rewrites the fields Mistral spells differently or does not define.
///
/// - `seed` goes out as `random_seed`, Mistral's name for it.
/// - `user` and `verbosity` are dropped: Mistral has neither field.
/// - `stream_options` is dropped. The plugin always asks for
///   `include_usage` on a stream, and Mistral reports usage on the last
///   streamed chunk without being asked.
/// - An assistant message's `reasoning_details`, which carry the Mistral
///   reasoning of that turn (see [OpenAIProvider.reasoningSource]), go back as
///   leading `thinking` chunks in its `content`, one per entry with its
///   signature, ahead of the text. Mistral asks for the whole assistant
///   message, thinking included, on later turns. No message keeps a
///   `reasoning_details` or `reasoning_content` field: Mistral defines neither.
///
/// Everything else passes through untouched.
///
/// https://docs.mistral.ai/api/#tag/chat/operation/chat_completion_v1_chat_completions_post
/// https://docs.mistral.ai/inference/conversations/reasoning
Map<String, dynamic> mistralChatBody(Map<String, dynamic> body) {
  final seed = body['seed'];
  final messages = body['messages'];
  return {
    for (final entry in body.entries)
      if (!_mistralDroppedFields.contains(entry.key)) entry.key: entry.value,
    'random_seed': ?seed,
    if (messages is List)
      'messages': [for (final message in messages) _mistralMessage(message)],
  };
}

/// [mistralChatBody] for one message.
Object? _mistralMessage(Object? message) {
  if (message is! Map) return message;
  final details = message['reasoning_details'];
  final rest = {
    for (final entry in message.entries)
      if (!_mistralDroppedMessageFields.contains(entry.key))
        entry.key as String: entry.value,
  };
  if (message['role'] != 'assistant' || details is! List || details.isEmpty) {
    return rest;
  }
  final content = rest['content'];
  return {
    ...rest,
    'content': [
      for (final detail in details.whereType<Map>())
        {
          'type': 'thinking',
          'thinking': [
            {'type': 'text', 'text': detail['text'] as String? ?? ''},
          ],
          if (detail['signature'] is String) 'signature': detail['signature'],
        },
      if (content is String && content.isNotEmpty)
        {'type': 'text', 'text': content},
    ],
  };
}

/// The `reasoningSource` Mistral's reasoning parts are marked with, the same
/// mark the JS and Python plugins use.
const mistralReasoningSource = 'mistral';

/// Whether a Mistral `/models` entry serves chat completions, from its
/// `capabilities.completion_chat`, or null when it carries no capabilities.
///
/// https://docs.mistral.ai/api/#tag/models
bool? mistralServesChat(Map<String, dynamic> listing) {
  final capabilities = listing['capabilities'];
  if (capabilities is! Map) return null;
  return capabilities['completion_chat'] == true;
}

/// Capability metadata for an uncurated Mistral model from its `/models`
/// entry: tools from `capabilities.function_calling`, image input from
/// `capabilities.vision`, as the JS plugin reads them. Output stays text only,
/// since the entry does not say whether the model takes a JSON schema.
///
/// Null for a curated model, which keeps its curated metadata, and for an
/// entry with no capabilities, which leaves the model to
/// [dynamicMistralModelInfo].
///
/// https://docs.mistral.ai/api/#tag/models
ModelInfo? mistralInfoFromListing(String model, Map<String, dynamic> listing) {
  if (knownMistralModelFor(model) != null) return null;
  final capabilities = listing['capabilities'];
  if (capabilities is! Map) return null;
  final tools = capabilities['function_calling'] == true;
  return ModelInfo(
    supports: Map.unmodifiable({
      ...mistralUnknownSupports,
      'tools': tools,
      'toolChoice': tools,
      'media': capabilities['vision'] == true,
    }),
  );
}

/// Rewrites an embeddings request into the fields Mistral defines.
///
/// - `dimensions` goes out as `output_dimension`, Mistral's name for it.
/// - `user` is dropped: Mistral has no such field.
///
/// Mistral's `EmbeddingRequest` is closed like its chat request, so either
/// field under its OpenAI name is a 422.
///
/// https://docs.mistral.ai/api/#tag/embeddings
Map<String, dynamic> mistralEmbeddingBody(Map<String, dynamic> body) {
  final dimensions = body['dimensions'];
  return {
    for (final entry in body.entries)
      if (entry.key != 'dimensions' && entry.key != 'user')
        entry.key: entry.value,
    'output_dimension': ?dimensions,
  };
}

/// Mistral's API hosts: global, EU and US, and `codestral.mistral.ai`, which
/// serves Codestral-only keys.
const mistralHosts = {
  'api.mistral.ai',
  'api.eu.mistral.ai',
  'api.us.mistral.ai',
  'codestral.mistral.ai',
};

/// Rewrites a Mistral reply whose `content` is an array of chunks into the
/// shape `openai_dart` reads, where `content` is a string.
///
/// A model that thinks answers with a `thinking` chunk ahead of its `text`
/// chunks, in a whole completion's `message` and in a streamed chunk's
/// `delta` alike. The text chunks are joined into `content`. Each thinking
/// chunk becomes a `reasoning.text` entry in `reasoning_details`, the field
/// the SDK already parses for OpenRouter, with its `signature` when Mistral
/// sent one; each entry is then read as its own reasoning part (see
/// [OpenAIProvider.reasoningSource]). Chunk types the plugin cannot represent, such as references, are
/// dropped.
///
/// A `finish_reason` of `model_length` is rewritten to `length`.
///
/// Anything else, including a string `content`, passes through untouched.
///
/// https://docs.mistral.ai/capabilities/reasoning
Map<String, dynamic> mistralChatReply(Map<String, dynamic> reply) {
  final choices = reply['choices'];
  if (choices is! List) return reply;
  return {
    ...reply,
    'choices': [
      for (final choice in choices)
        if (choice is Map<String, dynamic>)
          {
            for (final entry in choice.entries)
              entry.key: switch (entry.key) {
                'message' || 'delta' => _flattenChunks(entry.value),
                // Mistral's reason for a reply cut off at the model's context
                // length. The SDK knows no such value and would read it as
                // unknown; it is a length stop like any other.
                'finish_reason' when entry.value == 'model_length' => 'length',
                _ => entry.value,
              },
          }
        else
          choice,
    ],
  };
}

/// [mistralChatReply] for one message or delta.
Object? _flattenChunks(Object? message) {
  if (message is! Map<String, dynamic>) return message;
  final content = message['content'];
  if (content is! List) return message;

  final text = StringBuffer();
  final details = <Map<String, dynamic>>[];
  for (final chunk in content) {
    if (chunk is! Map) continue;
    switch (chunk['type']) {
      case 'text':
        text.write(chunk['text'] as String? ?? '');
      case 'thinking':
        final thinking = _thinkingText(chunk['thinking']);
        final signature = chunk['signature'];
        if (thinking.isEmpty && signature is! String) continue;
        details.add({
          'type': 'reasoning.text',
          'text': thinking,
          if (signature is String) 'signature': signature,
        });
    }
  }

  return {
    for (final entry in message.entries)
      if (entry.key != 'content') entry.key: entry.value,
    // A delta made only of thinking carries no text, and an empty string
    // would be streamed as an empty text chunk.
    'content': text.isEmpty && details.isNotEmpty ? null : text.toString(),
    if (details.isNotEmpty) 'reasoning_details': details,
  };
}

/// The text of a thinking chunk's `thinking`, which is a list of text chunks.
String _thinkingText(Object? thinking) {
  if (thinking is String) return thinking;
  if (thinking is! List) return '';
  return thinking
      .whereType<Map>()
      .where((chunk) => chunk['type'] == 'text')
      .map((chunk) => chunk['text'] as String? ?? '')
      .join();
}

/// Request fields that never reach Mistral under their OpenAI names.
const _mistralDroppedFields = {'seed', 'user', 'verbosity', 'stream_options'};

/// Message fields Mistral does not define. A turn's reasoning goes back in its
/// `content` instead.
const _mistralDroppedMessageFields = {
  'reasoning_details',
  'reasoning_content',
  'reasoning',
};

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
