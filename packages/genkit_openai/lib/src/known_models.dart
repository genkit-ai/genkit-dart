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

import 'utils.dart';

// Capability presets shared by the catalog entries below.
//
// Structured outputs (`response_format: json_schema` with `strict`) arrived
// with the gpt-4o-mini and gpt-4o-2024-08-06 snapshots, so models predating
// them advertise no constrained generation. That is the only difference
// between the `*Supports` presets and their `*LegacySupports` counterparts.
//
// Descriptive, not load-bearing: nothing in `package:genkit` reads `supports`,
// so this changes what the Dev UI and `listActions` report, not what the
// generate path does. The plugin sends `response_format` off the request's own
// output config either way.
// See https://developers.openai.com/api/docs/guides/structured-outputs.

// A const map literal rejects duplicate keys, so the shared entries cannot be
// spread in and then overridden; each tier spells out what differs.
const _chatCore = <String, dynamic>{'multiturn': true, 'systemRole': true};

/// Chat, vision, tool calling with tool choice, and native constrained
/// generation. The default tier for current OpenAI chat models.
const multimodalSupports = <String, dynamic>{
  ..._chatCore,
  'tools': true,
  'toolChoice': true,
  'media': true,
  'output': ['text', 'json'],
  'constrained': true,
};

/// [multimodalSupports] for models that predate structured outputs.
const multimodalLegacySupports = <String, dynamic>{
  ..._chatCore,
  'tools': true,
  'toolChoice': true,
  'media': true,
  'output': ['text', 'json'],
};

/// [textOnlyLegacySupports] for models that predate `response_format`
/// altogether, so they cannot even be asked for a JSON object.
///
/// The `gpt-4` and `gpt-4-32k` aliases resolve to their `-0613` snapshots,
/// which 400 on `response_format`; JSON mode arrived with the `-1106`
/// generation. The Go catalog advertises `json` for these, JS does not — JS is
/// right.
const textOnlyNoJsonSupports = <String, dynamic>{
  ..._chatCore,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text'],
};

/// [multimodalLegacySupports] without image input.
const textOnlyLegacySupports = <String, dynamic>{
  ..._chatCore,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
};

/// [multimodalSupports] for reasoning models, which take a `developer`
/// message rather than a `system` one.
const reasoningSupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': true,
  'toolChoice': true,
  'media': true,
  'output': ['text', 'json'],
  'constrained': true,
};

/// [reasoningSupports] without image input.
const reasoningTextOnlySupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
  'constrained': true,
};

/// The first reasoning preview models: no function calling, no image input,
/// and no system message.
const reasoningPreviewSupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': false,
  'media': false,
  'output': ['text'],
};

/// Chat and vision but no function calling — the ChatGPT-tuned snapshots and
/// the `gpt-4-vision` previews.
const multimodalNoToolsSupports = <String, dynamic>{
  ..._chatCore,
  'tools': false,
  'media': true,
  'output': ['text'],
};

/// Capabilities advertised for a discovered model that is not a chat model.
///
/// Chat generation is the only modality this plugin serves, so an embedding,
/// audio, image, moderation, or legacy completion model claims none of it.
/// Embedders arrive with their own metadata; see issue #361.
const nonChatSupports = <String, dynamic>{
  'multiturn': false,
  'systemRole': false,
  'tools': false,
  'media': false,
  'output': ['text'],
};

/// Lifecycle stage of a curated model, in Genkit's `ModelInfo.stage`
/// vocabulary.
enum OpenAIModelStage {
  /// Generally available, with no announced shutdown.
  stable,

  /// Still served, but superseded and with a shutdown date announced.
  legacy,

  /// No longer served by OpenAI. Curated so the name still resolves with
  /// honest capabilities — for a proxy that keeps serving it, or a stored
  /// request that names it — but never registered as an action against the
  /// OpenAI endpoint, which would put a model that answers `model_not_found`
  /// in every model picker.
  deprecated;

  /// The `stage` string carried in [ModelInfo].
  String get wireName => name;
}

/// OpenAI chat models the plugin curates capability metadata for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label], a capability preset, and the dated snapshots that resolve to it.
/// This is not the set of usable models: any name still resolves, taking
/// [dynamicModelInfo] when it is absent here.
///
/// The catalog is the union of the JS and Go `compat_oai` catalogs, which have
/// diverged. Two kinds of model are deliberately absent. The "pro" tiers
/// (`gpt-5-pro`, `gpt-5.2-pro`, `gpt-5.4-pro`, `gpt-5.5-pro`, `o1-pro`,
/// `o3-pro`) are served only by the Responses API, and this plugin speaks Chat
/// Completions. Audio, image, realtime, transcription, embedding, and
/// moderation models are not chat models.
///
/// Per-model behaviour beyond capabilities belongs on this enum as another
/// field rather than in a name-matching branch at the call site — that is what
/// keeps `reasoning_effort` (#239) and the embedder catalog (#361) from each
/// growing their own copy of the model list.
///
/// Catalog: https://developers.openai.com/api/docs/models
/// Retirements: https://developers.openai.com/api/docs/deprecations
enum KnownOpenAIModel {
  // GPT-5.6, the current frontier family. No dated snapshots yet; the bare
  // `gpt-5.6` alias routes to sol and resolves dynamically.
  gpt56Sol(
    'gpt-5.6-sol',
    'OpenAI GPT-5.6 Sol',
    multimodalSupports,
    reasons: true,
  ),
  gpt56Terra(
    'gpt-5.6-terra',
    'OpenAI GPT-5.6 Terra',
    multimodalSupports,
    reasons: true,
  ),
  gpt56Luna(
    'gpt-5.6-luna',
    'OpenAI GPT-5.6 Luna',
    multimodalSupports,
    reasons: true,
  ),

  gpt55(
    'gpt-5.5',
    'OpenAI GPT-5.5',
    multimodalSupports,
    snapshots: ['gpt-5.5-2026-04-23'],
    reasons: true,
  ),
  gpt54(
    'gpt-5.4',
    'OpenAI GPT-5.4',
    multimodalSupports,
    snapshots: ['gpt-5.4-2026-03-05'],
    reasons: true,
  ),
  gpt54Mini(
    'gpt-5.4-mini',
    'OpenAI GPT-5.4-mini',
    multimodalSupports,
    snapshots: ['gpt-5.4-mini-2026-03-17'],
    reasons: true,
  ),
  gpt54Nano(
    'gpt-5.4-nano',
    'OpenAI GPT-5.4-nano',
    multimodalSupports,
    snapshots: ['gpt-5.4-nano-2026-03-17'],
    reasons: true,
  ),
  gpt52(
    'gpt-5.2',
    'OpenAI GPT-5.2',
    multimodalSupports,
    snapshots: ['gpt-5.2-2025-12-11'],
    reasons: true,
  ),
  gpt51(
    'gpt-5.1',
    'OpenAI GPT-5.1',
    multimodalSupports,
    snapshots: ['gpt-5.1-2025-11-13'],
    reasons: true,
  ),

  // GPT-5. The dated snapshots shut down 2026-12-11; the aliases stay.
  gpt5(
    'gpt-5',
    'OpenAI GPT-5',
    multimodalSupports,
    snapshots: ['gpt-5-2025-08-07'],
    reasons: true,
  ),
  gpt5Mini(
    'gpt-5-mini',
    'OpenAI GPT-5-mini',
    multimodalSupports,
    snapshots: ['gpt-5-mini-2025-08-07'],
    reasons: true,
  ),
  gpt5Nano(
    'gpt-5-nano',
    'OpenAI GPT-5-nano',
    multimodalSupports,
    snapshots: ['gpt-5-nano-2025-08-07'],
    reasons: true,
  ),
  // The ChatGPT-tuned GPT-5 snapshot: no function calling.
  gpt5ChatLatest(
    'gpt-5-chat-latest',
    'OpenAI GPT-5 Chat',
    multimodalNoToolsSupports,
  ),

  gpt41(
    'gpt-4.1',
    'OpenAI GPT-4.1',
    multimodalSupports,
    snapshots: ['gpt-4.1-2025-04-14'],
  ),
  gpt41Mini(
    'gpt-4.1-mini',
    'OpenAI GPT-4.1-mini',
    multimodalSupports,
    snapshots: ['gpt-4.1-mini-2025-04-14'],
  ),
  // Shuts down 2026-10-23, replaced by gpt-5.6-luna.
  gpt41Nano(
    'gpt-4.1-nano',
    'OpenAI GPT-4.1-nano',
    multimodalSupports,
    snapshots: ['gpt-4.1-nano-2025-04-14'],
    stage: OpenAIModelStage.legacy,
  ),

  // GPT-4.5, retired from the API. Curated because the JS catalog still
  // carries it and a proxy may keep serving the name; deprecated so the
  // plugin never registers it against OpenAI itself.
  gpt45(
    'gpt-4.5',
    'OpenAI GPT-4.5',
    multimodalSupports,
    snapshots: ['gpt-4.5-preview'],
    stage: OpenAIModelStage.deprecated,
  ),

  gpt4o(
    'gpt-4o',
    'OpenAI GPT-4o',
    multimodalSupports,
    // gpt-4o-2024-05-13 shuts down 2026-10-23.
    snapshots: ['gpt-4o-2024-11-20', 'gpt-4o-2024-08-06', 'gpt-4o-2024-05-13'],
  ),
  gpt4oMini(
    'gpt-4o-mini',
    'OpenAI GPT-4o-mini',
    multimodalSupports,
    snapshots: ['gpt-4o-mini-2024-07-18'],
  ),
  // The ChatGPT-tuned GPT-4o snapshot: no function calling. Retired along
  // with the rest of the 4o line.
  chatgpt4oLatest(
    'chatgpt-4o-latest',
    'OpenAI ChatGPT-4o',
    multimodalNoToolsSupports,
    stage: OpenAIModelStage.deprecated,
  ),

  // Reasoning models. o1, o3-mini, and o4-mini shut down 2026-10-23;
  // o3-2025-04-16 shuts down 2026-12-11.
  o3(
    'o3',
    'OpenAI o3',
    reasoningSupports,
    snapshots: ['o3-2025-04-16'],
    reasons: true,
  ),
  o4Mini(
    'o4-mini',
    'OpenAI o4-mini',
    reasoningSupports,
    snapshots: ['o4-mini-2025-04-16'],
    stage: OpenAIModelStage.legacy,
    reasons: true,
  ),
  o3Mini(
    'o3-mini',
    'OpenAI o3-mini',
    reasoningTextOnlySupports,
    snapshots: ['o3-mini-2025-01-31'],
    stage: OpenAIModelStage.legacy,
    reasons: true,
  ),
  o1(
    'o1',
    'OpenAI o1',
    reasoningSupports,
    snapshots: ['o1-2024-12-17'],
    stage: OpenAIModelStage.legacy,
    reasons: true,
  ),
  // o1-mini and o1-preview never had function calling on the chat API, and
  // predate `reasoning_effort` - they reason, but the level is not settable.
  // Both are retired; curated so the names still resolve honestly.
  o1Mini(
    'o1-mini',
    'OpenAI o1-mini',
    reasoningPreviewSupports,
    snapshots: ['o1-mini-2024-09-12'],
    stage: OpenAIModelStage.deprecated,
  ),
  o1Preview(
    'o1-preview',
    'OpenAI o1-preview',
    reasoningPreviewSupports,
    snapshots: ['o1-preview-2024-09-12'],
    stage: OpenAIModelStage.deprecated,
  ),

  // Legacy models, all shutting down 2026-10-23 except gpt-3.5-turbo-1106,
  // which goes 2026-09-28.
  gpt4Turbo(
    'gpt-4-turbo',
    'OpenAI GPT-4-turbo',
    multimodalLegacySupports,
    snapshots: ['gpt-4-turbo-2024-04-09', 'gpt-4-turbo-preview'],
    stage: OpenAIModelStage.legacy,
  ),
  // The GPT-4 previews are gone; the catalog keeps them so the names still
  // resolve, but they are never registered.
  gpt40125Preview(
    'gpt-4-0125-preview',
    'OpenAI GPT-4 0125 Preview',
    multimodalLegacySupports,
    stage: OpenAIModelStage.deprecated,
  ),
  gpt41106Preview(
    'gpt-4-1106-preview',
    'OpenAI GPT-4 1106 Preview',
    multimodalLegacySupports,
    stage: OpenAIModelStage.deprecated,
  ),
  // `gpt-4-vision` alone was never a deployed id — the JS catalog carries it,
  // the API only ever served these two — so the preview is the alias.
  gpt4VisionPreview(
    'gpt-4-vision-preview',
    'OpenAI GPT-4 Vision Preview',
    multimodalNoToolsSupports,
    snapshots: ['gpt-4-1106-vision-preview', 'gpt-4-vision'],
    stage: OpenAIModelStage.deprecated,
  ),
  // The undated `-0314` and `-16k` snapshots predate the `-YYYY-MM-DD`
  // convention, so openAIModelAlias cannot reach them: they resolve only by
  // being listed here.
  gpt4(
    'gpt-4',
    'OpenAI GPT-4',
    textOnlyNoJsonSupports,
    snapshots: ['gpt-4-0613', 'gpt-4-0314'],
    stage: OpenAIModelStage.legacy,
  ),
  gpt432k(
    'gpt-4-32k',
    'OpenAI GPT-4 32k',
    textOnlyNoJsonSupports,
    snapshots: ['gpt-4-32k-0613', 'gpt-4-32k-0314'],
    stage: OpenAIModelStage.deprecated,
  ),
  gpt35Turbo(
    'gpt-3.5-turbo',
    'OpenAI GPT-3.5-turbo',
    textOnlyLegacySupports,
    snapshots: [
      'gpt-3.5-turbo-0125',
      'gpt-3.5-turbo-1106',
      'gpt-3.5-turbo-0613',
      'gpt-3.5-turbo-16k',
      'gpt-3.5-turbo-16k-0613',
    ],
    stage: OpenAIModelStage.legacy,
  );

  const KnownOpenAIModel(
    this.id,
    this.label,
    this.supports, {
    this.snapshots = const [],
    this.stage = OpenAIModelStage.stable,
    this.reasons = false,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Capability map registered for this model.
  final Map<String, dynamic> supports;

  /// Dated snapshots that resolve to this model, excluding [id] itself.
  final List<String> snapshots;

  /// Lifecycle stage, which decides whether the plugin registers this model
  /// as an action as well as how it describes it.
  final OpenAIModelStage stage;

  /// Whether the model thinks before answering, and so accepts
  /// `reasoning_effort`.
  ///
  /// A model that does not reason rejects the parameter outright, which is
  /// the whole reason this is curated: setting an effort once in a shared
  /// config and then switching models is an easy mistake, and a 400 naming
  /// only the parameter does not say which of the two is wrong.
  ///
  /// Deliberately a flag and not a list of levels. Which levels a model takes
  /// moves with the generation, and enumerating that per entry would be
  /// guessing at values OpenAI can change under us; the value itself is left
  /// for the API to judge.
  final bool reasons;

  /// Every name that resolves to this model: the alias followed by its dated
  /// snapshots, newest first. Surfaced as `ModelInfo.versions`.
  List<String> get versions => [id, ...snapshots];

  /// Capability metadata registered for this model.
  ///
  /// One instance per entry, shared by every resolution of the model, so the
  /// maps it carries are unmodifiable: mutating action metadata in place must
  /// fail loudly rather than corrupt the catalog.
  ModelInfo get info => _curatedInfo[this]!;
}

final _curatedInfo = <KnownOpenAIModel, ModelInfo>{
  for (final model in KnownOpenAIModel.values)
    model: ModelInfo(
      label: model.label,
      supports: Map.unmodifiable(model.supports),
      versions: List.unmodifiable(model.versions),
      stage: model.stage.wireName,
    ),
};

/// Curated capability metadata for known OpenAI chat models, keyed by bare
/// model name (no plugin prefix).
///
/// Derived from [KnownOpenAIModel]; other names still resolve, they just take
/// [dynamicModelInfo] instead of a curated entry.
final Map<String, ModelInfo> knownOpenAIModels = Map.unmodifiable({
  for (final model in KnownOpenAIModel.values) model.id: model.info,
});

/// Chat models the plugin lists without network access, newest generation
/// first.
///
/// The plugin normally discovers models from `GET /models`, but that needs
/// both connectivity and a valid key. These are the ids listed when discovery
/// is unavailable, and they are merged with the discovered set when it is.
///
/// It is a convenience, never a gate: the plugin resolves any model id, so a
/// model absent from this list still works when named explicitly. That is
/// deliberate — it keeps just-released models usable without a plugin release.
///
/// Every id here carries curated capability metadata; see [knownOpenAIModels].
/// [OpenAIModelStage.deprecated] entries are excluded: OpenAI no longer serves
/// them, so listing them would offer a model picker names that 404.
final List<String> knownChatModels = List.unmodifiable([
  for (final model in KnownOpenAIModel.values)
    if (model.stage != OpenAIModelStage.deprecated) model.id,
]);

/// Every curated name — the alias and its dated snapshots — mapped to the
/// catalog entry that describes it.
final _knownOpenAIModelsByName = <String, KnownOpenAIModel>{
  for (final model in KnownOpenAIModel.values)
    for (final name in model.versions) name.toLowerCase(): model,
};

final _datedSuffixPattern = RegExp(r'-\d{4}-\d{2}-\d{2}$');
final _azureDottedPattern = RegExp(r'^gpt-(\d)(\d)-');

/// Rewrites a name into the spelling the catalog uses.
///
/// Azure drops the dot from a model's version, and its deployment names carry
/// the same undated snapshot suffixes OpenAI's do — `gpt-35-turbo`,
/// `gpt-35-turbo-0125`, `gpt-35-turbo-16k-0613`. Restoring the dot maps the
/// whole family at once, rather than listing each spelling.
String openAIModelSpelling(String modelName) => modelName.replaceFirstMapped(
  _azureDottedPattern,
  (m) => 'gpt-${m[1]}.${m[2]}-',
);

/// Strips a trailing dated-snapshot suffix (e.g. `gpt-5.6-sol-2026-06-01` ->
/// `gpt-5.6-sol`), so a snapshot released after this version of the plugin
/// still lands on its curated alias.
String openAIModelAlias(String modelName) =>
    modelName.replaceFirst(_datedSuffixPattern, '');

/// Returns the curated entry for [modelName], or `null` when the name is not
/// curated.
///
/// Tried in order: the name as given, its Azure-to-OpenAI spelling, and then
/// each of those with a dated snapshot suffix stripped. Matching is
/// case-insensitive; the OpenAI catalog is lower-case.
KnownOpenAIModel? knownOpenAIModelFor(String modelName) {
  final id = modelName.toLowerCase();
  for (final candidate in {
    id,
    openAIModelSpelling(id),
    openAIModelAlias(id),
    openAIModelAlias(openAIModelSpelling(id)),
  }) {
    final match = _knownOpenAIModelsByName[candidate];
    if (match != null) return match;
  }
  return null;
}

/// Capability metadata for a model with no curated entry.
///
/// Chat and unknown names take the current-generation [multimodalSupports]
/// defaults, so a model released after this version of the plugin works
/// without waiting for a catalog entry. Names [getModelType] classifies as
/// another modality take [nonChatSupports], since this plugin only serves chat
/// generation.
///
/// The one exception is the `chatgpt-` prefix, which OpenAI uses for the
/// ChatGPT-tuned snapshots of its chat models. None of them has ever accepted
/// tools, and the family gains members faster than this catalog does, so the
/// prefix — a naming commitment OpenAI makes, not an inference about a
/// capability — is enough to withhold the claim.
ModelInfo dynamicModelInfo(String modelName) {
  final id = modelName.toLowerCase();
  final type = getModelType(id);
  final Map<String, dynamic> supports;
  if (type != 'chat' && type != 'unknown') {
    supports = nonChatSupports;
  } else if (id.startsWith('chatgpt-')) {
    supports = multimodalNoToolsSupports;
  } else {
    supports = multimodalSupports;
  }
  return ModelInfo(supports: Map.unmodifiable(supports));
}

/// Capability metadata for any OpenAI model name: the curated entry when there
/// is one, [dynamicModelInfo] otherwise.
ModelInfo modelInfoFor(String model) =>
    knownOpenAIModelFor(model)?.info ?? dynamicModelInfo(model);

/// The curated entries with OpenAI's deployment details stripped off.
final _compatInfo = <KnownOpenAIModel, ModelInfo>{
  for (final model in KnownOpenAIModel.values)
    // Shares the already-unmodifiable map from the full curated entry.
    model: ModelInfo(supports: model.info.supports),
};

/// Capability metadata for [modelName] on an OpenAI-compatible backend that is
/// not OpenAI itself.
///
/// The capabilities carry over. A gateway or proxy that serves a name from
/// OpenAI's catalog is nearly always serving that model — Azure, Cloudflare AI
/// Gateway, LiteLLM and OpenRouter all route to OpenAI — so `gpt-3.5-turbo`
/// behind one is still text-only, and describing it as multimodal would invite
/// image parts the backend rejects.
///
/// OpenAI's *deployment* does not carry over: the label names OpenAI's
/// offering, the lifecycle stage tracks OpenAI's retirement schedule, and the
/// version list enumerates the snapshots OpenAI serves. A backend pinned to one
/// snapshot, or serving a fine-tune under a familiar name, satisfies none of
/// those. A `CustomModelDefinition` with explicit `info` overrides all of it.
ModelInfo compatModelInfo(String modelName) {
  final curated = knownOpenAIModelFor(modelName);
  return curated != null ? _compatInfo[curated]! : dynamicModelInfo(modelName);
}

/// Whether [model] supports tools / function calling.
bool supportsTools(String model) =>
    modelInfoFor(model).supports?['tools'] == true;

/// Whether [model] supports vision (image inputs).
bool supportsVision(String model) =>
    modelInfoFor(model).supports?['media'] == true;
