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

// This catalog and its DeepSeek, xAI and embedder siblings are internal
// metadata, not API: they only enrich names that resolve anyway, and entries
// are added, retired and removed with the providers' model lists in any
// release. Callers name models by string (`openAI.model('gpt-5.5')`).

// Capability presets shared by the catalog entries below.
//
// Descriptive, not load-bearing: core does not act on `supports`, so these
// change what the Dev UI and `listActions` report, not what the generate
// path does. The plugin sends `response_format` off the request's own output
// config either way; the `simulateConstrainedGeneration` middleware is the
// way to put the schema in the prompt for a model that rejects it (see #462).
//
// `dynamicModelInfo`'s fallback claims `constrained: true` for any
// unrecognised chat-shaped name, on the assumption it's an OpenAI snapshot
// newer than this catalog. `compatModelInfo` reuses that same fallback for a
// name it can't classify on a non-OpenAI backend, where the assumption does
// not hold (see #466).
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

/// Chat and vision but no function calling — the ChatGPT-tuned snapshots,
/// which [dynamicModelInfo] recognises by their `chatgpt-` prefix.
const multimodalNoToolsSupports = <String, dynamic>{
  ..._chatCore,
  'tools': false,
  'media': true,
  'output': ['text'],
};

/// [multimodalSupports] without function calling, for models that serve Chat
/// Completions but take tools only on the Responses API.
///
/// Unlike [multimodalNoToolsSupports], these keep structured outputs.
const multimodalNoChatToolsSupports = <String, dynamic>{
  ..._chatCore,
  'tools': false,
  'media': true,
  'output': ['text', 'json'],
  'constrained': true,
};

/// Web search models: no function calling, no image input, and no
/// `reasoning_effort`, but structured outputs.
const searchSupports = <String, dynamic>{
  ..._chatCore,
  'tools': false,
  'media': false,
  'output': ['text', 'json'],
  'constrained': true,
};

/// Capabilities advertised for a discovered model that is not a chat model.
///
/// Chat generation is the only modality this plugin serves *here*, so an
/// embedding, audio, image, moderation, or legacy completion model claims none
/// of it. An embedding model named as a model still lands on this - what the
/// plugin serves it as is an embedder, described by `known_embedders.dart`.
const nonChatSupports = <String, dynamic>{
  'multiturn': false,
  'systemRole': false,
  'tools': false,
  'media': false,
  'output': ['text'],
};

/// Lifecycle stage of a curated model, in Genkit's `ModelInfo.stage`
/// vocabulary.
///
/// Every stage is still served, so every curated model is listed: a model the
/// provider has shut down is removed from its catalog rather than staged.
enum OpenAIModelStage {
  /// Generally available, with no announced shutdown.
  stable,

  /// Still served, but superseded and no longer recommended for new work.
  legacy,

  /// Deprecated by the provider: still served, with a shutdown date
  /// announced. The entry is removed in a plugin release after that date.
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
/// Models OpenAI has shut down are absent; [compatModelInfo] keeps those for
/// other hosts. Two other kinds of model are deliberately absent. The "pro"
/// tiers are served only by the Responses API, and this plugin speaks Chat
/// Completions; [openAIChatCompletionsServes] keeps discovery from listing
/// them either. Audio, image, realtime, transcription, embedding, and
/// moderation models are not chat models.
///
/// Per-model behaviour beyond capabilities belongs on this enum as another
/// field rather than in a name-matching branch at the call site — that is what
/// keeps something like `reasoning_effort` (#239) from growing its own copy of
/// the model list. A different modality gets its own catalog instead; see
/// `KnownOpenAIEmbedder`.
///
/// Catalog: https://developers.openai.com/api/docs/models
/// Retirements: https://developers.openai.com/api/docs/deprecations
enum KnownOpenAIModel {
  // GPT-6. Chat Completions serves all five, but takes tools only on sol and
  // luna, and only with `reasoning_effort: none`; astra, 6.1-sol and
  // 6.1-terra take none. No dated snapshots yet.
  gpt61Sol(
    'gpt-6.1-sol',
    'OpenAI GPT-6.1 Sol',
    multimodalNoChatToolsSupports,
    reasons: true,
  ),
  gpt61Terra(
    'gpt-6.1-terra',
    'OpenAI GPT-6.1 Terra',
    multimodalNoChatToolsSupports,
    reasons: true,
  ),
  gpt6Astra(
    'gpt-6-astra',
    'OpenAI GPT-6 Astra',
    multimodalNoChatToolsSupports,
    reasons: true,
  ),
  gpt6Sol('gpt-6-sol', 'OpenAI GPT-6 Sol', multimodalSupports, reasons: true),
  gpt6Luna(
    'gpt-6-luna',
    'OpenAI GPT-6 Luna',
    multimodalSupports,
    reasons: true,
  ),

  // GPT-5.6. Like gpt-6-sol and gpt-6-luna, these take tools on Chat
  // Completions only with `reasoning_effort: none`, which is not their
  // default. No dated snapshots yet; the bare `gpt-5.6` alias routes to sol
  // and resolves dynamically.
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

  // GPT-5.5 and GPT-5.4 also take tools on Chat Completions only with
  // `reasoning_effort: none`, which is their default.
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
  // Shuts down 2027-04-01, replaced by gpt-6-luna.
  gpt54Nano(
    'gpt-5.4-nano',
    'OpenAI GPT-5.4-nano',
    multimodalSupports,
    snapshots: ['gpt-5.4-nano-2026-03-17'],
    stage: OpenAIModelStage.deprecated,
    reasons: true,
  ),
  gpt52(
    'gpt-5.2',
    'OpenAI GPT-5.2',
    multimodalSupports,
    snapshots: ['gpt-5.2-2025-12-11'],
    reasons: true,
  ),
  // Shuts down 2027-04-01, replaced by gpt-6-sol.
  gpt51(
    'gpt-5.1',
    'OpenAI GPT-5.1',
    multimodalSupports,
    snapshots: ['gpt-5.1-2025-11-13'],
    stage: OpenAIModelStage.deprecated,
    reasons: true,
  ),

  // GPT-5. The aliases and their dated snapshots shut down 2026-12-11,
  // replaced by gpt-6.1-sol, gpt-6.1-terra and gpt-6-luna respectively.
  gpt5(
    'gpt-5',
    'OpenAI GPT-5',
    multimodalSupports,
    snapshots: ['gpt-5-2025-08-07'],
    stage: OpenAIModelStage.deprecated,
    reasons: true,
  ),
  gpt5Mini(
    'gpt-5-mini',
    'OpenAI GPT-5-mini',
    multimodalSupports,
    snapshots: ['gpt-5-mini-2025-08-07'],
    stage: OpenAIModelStage.deprecated,
    reasons: true,
  ),
  gpt5Nano(
    'gpt-5-nano',
    'OpenAI GPT-5-nano',
    multimodalSupports,
    snapshots: ['gpt-5-nano-2025-08-07'],
    stage: OpenAIModelStage.deprecated,
    reasons: true,
  ),

  gpt5SearchApi(
    'gpt-5-search-api',
    'OpenAI GPT-5 Search API',
    searchSupports,
    snapshots: ['gpt-5-search-api-2025-10-14'],
  ),

  // GPT-4.1 and GPT-4o shut down 2027-01-14, replaced by gpt-6-luna. The
  // first GPT-4o snapshot, gpt-4o-2024-05-13, went 2026-10-23.
  gpt41(
    'gpt-4.1',
    'OpenAI GPT-4.1',
    multimodalSupports,
    snapshots: ['gpt-4.1-2025-04-14'],
    stage: OpenAIModelStage.deprecated,
  ),
  gpt41Mini(
    'gpt-4.1-mini',
    'OpenAI GPT-4.1-mini',
    multimodalSupports,
    snapshots: ['gpt-4.1-mini-2025-04-14'],
    stage: OpenAIModelStage.deprecated,
  ),
  gpt4o(
    'gpt-4o',
    'OpenAI GPT-4o',
    multimodalSupports,
    snapshots: ['gpt-4o-2024-11-20', 'gpt-4o-2024-08-06'],
    stage: OpenAIModelStage.deprecated,
  ),
  gpt4oMini(
    'gpt-4o-mini',
    'OpenAI GPT-4o-mini',
    multimodalSupports,
    snapshots: ['gpt-4o-mini-2024-07-18'],
    stage: OpenAIModelStage.deprecated,
  ),

  // The last o-series model. o3 and its snapshot shut down 2026-12-11,
  // replaced by gpt-6.1-sol.
  o3(
    'o3',
    'OpenAI o3',
    reasoningSupports,
    snapshots: ['o3-2025-04-16'],
    stage: OpenAIModelStage.deprecated,
    reasons: true,
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

  /// Lifecycle stage, carried into `ModelInfo.stage`. Every stage is listed.
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
/// [OpenAIModelStage.deprecated] entries are listed too: OpenAI serves them
/// until their shutdown date, and they leave the catalog in a plugin release
/// after it.
final List<String> knownChatModels = List.unmodifiable([
  for (final model in KnownOpenAIModel.values) model.id,
]);

/// Every curated name — the alias and its dated snapshots — mapped to the
/// catalog entry that describes it.
final _knownOpenAIModelsByName = <String, KnownOpenAIModel>{
  for (final model in KnownOpenAIModel.values)
    for (final name in model.versions) name.toLowerCase(): model,
};

final _datedSuffixPattern = RegExp(r'-\d{4}-\d{2}-\d{2}$');
final _gptGeneration = RegExp(r'^gpt-(\d+)(?:\.\d+)?(?:-|$)');
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
KnownOpenAIModel? knownOpenAIModelFor(String modelName) =>
    _lookUp(_knownOpenAIModelsByName, modelName);

T? _lookUp<T>(Map<String, T> byName, String modelName) {
  final id = modelName.toLowerCase();
  for (final candidate in {
    id,
    openAIModelSpelling(id),
    openAIModelAlias(id),
    openAIModelAlias(openAIModelSpelling(id)),
  }) {
    final match = byName[candidate];
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

/// Whether [modelName] thinks before answering, and so accepts
/// `reasoning_effort`; `null` when there is nothing to go on.
///
/// A curated or retired entry answers when there is one. Otherwise an
/// o-series name, or a GPT name from generation 5 on, is taken to reason:
/// every model OpenAI has shipped under those names since `reasoning_effort`
/// arrived accepts it. A `-chat` variant is left unclaimed, since the
/// ChatGPT-tuned GPT-5 snapshot did not reason.
bool? openAIModelReasons(String modelName) {
  final curated = knownOpenAIModelFor(modelName);
  if (curated != null) return curated.reasons;
  final retired = _lookUp(_retiredByName, modelName);
  if (retired != null) return retired.reasons;

  final id = openAIModelSpelling(modelName.toLowerCase());
  if (getModelType(id) != 'chat') return null;
  if (oSeriesPattern.hasMatch(id)) return true;
  final generation = _gptGeneration.firstMatch(id);
  if (generation != null &&
      int.parse(generation[1]!) >= 5 &&
      !id.contains('-chat')) {
    return true;
  }
  return null;
}

/// Models OpenAI's `GET /models` lists but Chat Completions does not serve,
/// beyond the `-pro` tiers [openAIChatCompletionsServes] catches by name.
///
/// Codex models need no entry: [getModelType] classifies them as code, so
/// discovery has dropped them before this is asked.
const _responsesOnlyModels = {
  'gpt-5.6-cyber',
  'gpt-6-rosalind',
  'gpt-oss-120b',
  'gpt-oss-20b',
  'gpt-rosalind-research',
};

/// Whether Chat Completions serves [modelName], for filtering what OpenAI's
/// `GET /models` lists.
///
/// The "pro" tiers, the `gpt-daybreak-` family and a handful of
/// special-purpose models are listed by the API but served only by the
/// Responses API, which this plugin does not speak; listing them would offer
/// a model picker names whose every call fails. A `-pro` suffix is OpenAI's
/// naming commitment for the tier, so it is matched by name, dated snapshots
/// included.
bool openAIChatCompletionsServes(String modelName) {
  final alias = openAIModelAlias(modelName.toLowerCase());
  return !alias.endsWith('-pro') &&
      !alias.startsWith('gpt-daybreak-') &&
      !_responsesOnlyModels.contains(alias);
}

/// Capability metadata for any OpenAI model name: the curated entry when there
/// is one, [dynamicModelInfo] otherwise.
///
/// Useful as a starting point for a model the plugin does not know by name:
///
/// ```dart
/// CustomModelDefinition(name: 'my-gpt-proxy', info: modelInfoFor('gpt-5.5'))
/// ```
///
/// The result follows the curated list, so it can change between releases as
/// models are added or retired.
ModelInfo modelInfoFor(String model) =>
    knownOpenAIModelFor(model)?.info ?? _uncuratedOpenAIInfo(model);

final _oSeriesInfo = ModelInfo(supports: Map.unmodifiable(reasoningSupports));

/// [dynamicModelInfo] for a name OpenAI itself serves, which can be read the
/// way OpenAI names its models.
///
/// An o-series name takes [reasoningSupports]: every o-series model OpenAI has
/// shipped takes a `developer` message rather than a `system` one, so a newer
/// one is described the same way. Kept out of [dynamicModelInfo] because that
/// also describes names on other hosts, where `o`-and-a-digit is no naming
/// commitment of OpenAI's.
ModelInfo _uncuratedOpenAIInfo(String model) {
  final id = model.toLowerCase();
  if (getModelType(id) == 'chat' && oSeriesPattern.hasMatch(id)) {
    return _oSeriesInfo;
  }
  return dynamicModelInfo(model);
}

/// The curated entries with OpenAI's deployment details stripped off.
final _compatInfo = <KnownOpenAIModel, ModelInfo>{
  for (final model in KnownOpenAIModel.values)
    // Shares the already-unmodifiable map from the full curated entry.
    model: ModelInfo(supports: model.info.supports),
};

/// [_multimodalLegacySupports] without image input.
const _textOnlyLegacySupports = <String, dynamic>{
  ..._chatCore,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
};

/// [_textOnlyLegacySupports] for models that 400 on `response_format`.
const _textOnlyNoJsonSupports = <String, dynamic>{
  ..._chatCore,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text'],
};

/// [multimodalSupports] for models that predate structured outputs.
const _multimodalLegacySupports = <String, dynamic>{
  ..._chatCore,
  'tools': true,
  'toolChoice': true,
  'media': true,
  'output': ['text', 'json'],
};

/// [reasoningSupports] without image input.
const _reasoningTextOnlySupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
  'constrained': true,
};

/// The first reasoning previews: no function calling, image input or system
/// message.
const _reasoningPreviewSupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': false,
  'media': false,
  'output': ['text'],
};

/// Chat models OpenAI has shut down, with the capabilities they had.
///
/// Read by [compatModelInfo], for a gateway that still serves the name, and
/// by [openAIModelReasons]. The OpenAI listing and [modelInfoFor] never see
/// these.
enum _RetiredOpenAIModel {
  gpt5ChatLatest('gpt-5-chat-latest', multimodalNoToolsSupports),
  gpt41Nano(
    'gpt-4.1-nano',
    multimodalSupports,
    snapshots: ['gpt-4.1-nano-2025-04-14'],
  ),
  gpt45('gpt-4.5', multimodalSupports, snapshots: ['gpt-4.5-preview']),
  chatgpt4oLatest('chatgpt-4o-latest', multimodalNoToolsSupports),
  o4Mini(
    'o4-mini',
    reasoningSupports,
    snapshots: ['o4-mini-2025-04-16'],
    reasons: true,
  ),
  o3Mini(
    'o3-mini',
    _reasoningTextOnlySupports,
    snapshots: ['o3-mini-2025-01-31'],
    reasons: true,
  ),
  o1('o1', reasoningSupports, snapshots: ['o1-2024-12-17'], reasons: true),
  o1Mini(
    'o1-mini',
    _reasoningPreviewSupports,
    snapshots: ['o1-mini-2024-09-12'],
  ),
  o1Preview(
    'o1-preview',
    _reasoningPreviewSupports,
    snapshots: ['o1-preview-2024-09-12'],
  ),
  gpt4Turbo(
    'gpt-4-turbo',
    _multimodalLegacySupports,
    snapshots: ['gpt-4-turbo-2024-04-09', 'gpt-4-turbo-preview'],
  ),
  gpt40125Preview('gpt-4-0125-preview', _multimodalLegacySupports),
  gpt41106Preview('gpt-4-1106-preview', _multimodalLegacySupports),
  gpt4VisionPreview(
    'gpt-4-vision-preview',
    multimodalNoToolsSupports,
    snapshots: ['gpt-4-1106-vision-preview', 'gpt-4-vision'],
  ),
  // The undated snapshots predate the `-YYYY-MM-DD` convention, so
  // openAIModelAlias cannot reach them.
  gpt4(
    'gpt-4',
    _textOnlyNoJsonSupports,
    snapshots: ['gpt-4-0613', 'gpt-4-0314'],
  ),
  gpt432k(
    'gpt-4-32k',
    _textOnlyNoJsonSupports,
    snapshots: ['gpt-4-32k-0613', 'gpt-4-32k-0314'],
  ),
  gpt35Turbo(
    'gpt-3.5-turbo',
    _textOnlyLegacySupports,
    snapshots: [
      'gpt-3.5-turbo-0125',
      'gpt-3.5-turbo-1106',
      'gpt-3.5-turbo-0613',
      'gpt-3.5-turbo-16k',
      'gpt-3.5-turbo-16k-0613',
    ],
  );

  const _RetiredOpenAIModel(
    this.id,
    this.supports, {
    this.snapshots = const [],
    this.reasons = false,
  });

  final String id;
  final Map<String, dynamic> supports;
  final List<String> snapshots;

  /// Whether the model accepts `reasoning_effort`.
  final bool reasons;
}

final _retiredByName = <String, _RetiredOpenAIModel>{
  for (final model in _RetiredOpenAIModel.values)
    for (final name in [model.id, ...model.snapshots]) name: model,
};

final _retiredInfoByName = <String, ModelInfo>{
  for (final MapEntry(:key, :value) in _retiredByName.entries)
    key: ModelInfo(supports: Map.unmodifiable(value.supports)),
};

/// Capability metadata for [modelName] on an OpenAI-compatible backend that is
/// not OpenAI itself.
///
/// The capabilities carry over. A gateway or proxy that serves a name from
/// OpenAI's catalog is nearly always serving that model — Azure, Cloudflare AI
/// Gateway, LiteLLM and OpenRouter all route to OpenAI — so `gpt-3.5-turbo`
/// behind one is still text-only, and describing it as multimodal would invite
/// image parts the backend rejects. Models OpenAI has shut down keep the
/// capabilities they had, since a gateway can outlive OpenAI's own shutdown.
///
/// OpenAI's *deployment* does not carry over: the label names OpenAI's
/// offering, the lifecycle stage tracks OpenAI's retirement schedule, and the
/// version list enumerates the snapshots OpenAI serves. A backend pinned to one
/// snapshot, or serving a fine-tune under a familiar name, satisfies none of
/// those. A `CustomModelDefinition` with explicit `info` overrides all of it.
ModelInfo compatModelInfo(String modelName) {
  final curated = knownOpenAIModelFor(modelName);
  if (curated != null) return _compatInfo[curated]!;
  return _lookUp(_retiredInfoByName, modelName) ?? dynamicModelInfo(modelName);
}

/// Whether [model] supports tools / function calling.
bool supportsTools(String model) =>
    modelInfoFor(model).supports?['tools'] == true;

/// Whether [model] supports vision (image inputs).
bool supportsVision(String model) =>
    modelInfoFor(model).supports?['media'] == true;
