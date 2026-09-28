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

import 'known_models.dart' show OpenAIModelStage;

/// Default plugin / namespace name for the DeepSeek handle.
const String defaultDeepSeekNamespace = 'deepseek';

// Capability presets for DeepSeek's catalog.
//
// Deliberately not shared with the OpenAI presets, which claim `constrained`
// for everything current. DeepSeek's `response_format` vocabulary is `text`
// and `json_object` only — it can be asked for JSON but not handed a schema —
// so no DeepSeek model advertises constrained generation.
// See https://api-docs.deepseek.com/guides/json_mode.

const _chatCore = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': true,
  'toolChoice': true,
  'output': ['text', 'json'],
};

/// Chat, image input, tool calling, and JSON mode.
const deepSeekVisionSupports = <String, dynamic>{..._chatCore, 'media': true};

/// [deepSeekVisionSupports] without image input.
const deepSeekTextSupports = <String, dynamic>{..._chatCore, 'media': false};

/// DeepSeek models the plugin curates capability metadata for.
///
/// Mirrors `KnownOpenAIModel`: a bare [id], a display [label], a capability
/// preset, the [snapshots] that route to the same model, and a lifecycle
/// [stage]. As there, this is not the set of usable models — any name still
/// resolves, taking [dynamicDeepSeekModelInfo] when it is absent here.
///
/// DeepSeek renames aggressively. `deepseek-chat` and `deepseek-reasoner` were
/// the whole lineup for two years, were announced for discontinuation on
/// 2026-07-24, and now select the non-thinking and thinking modes of
/// `deepseek-flash`. Both still answer, so they are curated as
/// [OpenAIModelStage.legacy] - listed, with the shutdown announced - rather
/// than dropped or marked `deprecated`.
///
/// No entry says whether a model thinks. On DeepSeek that is a request-time
/// mode, not a property of the name: `deepseek-chat` is Flash with thinking
/// off by default, and it still honours a `reasoningEffort` asking for it.
///
/// Catalog: https://api-docs.deepseek.com/quick_start/pricing
enum KnownDeepSeekModel {
  /// DeepSeek-V4.1-Flash: 1M context, vision, thinking on by default.
  deepseekFlash(
    'deepseek-flash',
    'DeepSeek Flash',
    deepSeekVisionSupports,
    // Both older spellings are temporarily routed to V4.1 Flash by DeepSeek
    // itself, so they are legacy names for this model rather than models.
    snapshots: ['deepseek-v4-flash', 'deepseek-v4-flash-vision-exp'],
  ),

  /// DeepSeek-V4-Pro-0813. No image input.
  deepseekV4Pro('deepseek-v4-pro', 'DeepSeek V4 Pro', deepSeekTextSupports),

  /// The former chat alias, now `deepseek-flash` with thinking off.
  ///
  /// `legacy`, not `deprecated`: DeepSeek announced the discontinuation but
  /// still serves the name, routing it to Flash. That is what `legacy` means
  /// here - served, with a shutdown announced - so it stays in the listing
  /// until the name actually stops answering.
  deepseekChat(
    'deepseek-chat',
    'DeepSeek Chat',
    deepSeekVisionSupports,
    stage: OpenAIModelStage.legacy,
  ),

  /// The former reasoning alias, now `deepseek-flash` with thinking on.
  deepseekReasoner(
    'deepseek-reasoner',
    'DeepSeek Reasoner',
    deepSeekVisionSupports,
    stage: OpenAIModelStage.legacy,
  );

  const KnownDeepSeekModel(
    this.id,
    this.label,
    this.supports, {
    this.snapshots = const [],
    this.stage = OpenAIModelStage.stable,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Capability map registered for this model.
  final Map<String, dynamic> supports;

  /// Other names DeepSeek routes to this model, excluding [id] itself.
  final List<String> snapshots;

  /// Lifecycle stage, in the same vocabulary the OpenAI catalog uses.
  final OpenAIModelStage stage;

  /// Every name that resolves to this model.
  List<String> get versions => [id, ...snapshots];

  /// Capability metadata registered for this model.
  ModelInfo get info => _curatedInfo[this]!;
}

final _curatedInfo = <KnownDeepSeekModel, ModelInfo>{
  for (final model in KnownDeepSeekModel.values)
    model: ModelInfo(
      label: model.label,
      supports: Map.unmodifiable(model.supports),
      versions: List.unmodifiable(model.versions),
      stage: model.stage.wireName,
    ),
};

/// Curated capability metadata for known DeepSeek models, keyed by bare model
/// name (no plugin prefix).
final Map<String, ModelInfo> knownDeepSeekModels = Map.unmodifiable({
  for (final model in KnownDeepSeekModel.values) model.id: model.info,
});

/// DeepSeek chat models the plugin lists without network access.
///
/// [OpenAIModelStage.legacy] entries are listed — DeepSeek still serves them —
/// while `deprecated` ones would not be, the same rule the OpenAI catalog
/// follows.
final List<String> knownDeepSeekChatModels = List.unmodifiable([
  for (final model in KnownDeepSeekModel.values)
    if (model.stage != OpenAIModelStage.deprecated) model.id,
]);

final _knownDeepSeekModelsByName = <String, KnownDeepSeekModel>{
  for (final model in KnownDeepSeekModel.values)
    for (final name in model.versions) name.toLowerCase(): model,
};

/// Returns the curated entry for [modelName], or `null` when the name is not
/// curated. Matching is case-insensitive.
KnownDeepSeekModel? knownDeepSeekModelFor(String modelName) =>
    _knownDeepSeekModelsByName[modelName.toLowerCase()];

/// Capability metadata for a DeepSeek model with no curated entry.
///
/// Claims only what every DeepSeek chat model has had: multi-turn, a system
/// role, tools, and JSON mode. Image input is withheld because only the Flash
/// line has it, and `constrained` because no DeepSeek model takes a schema —
/// the OpenAI fallback would claim both.
final ModelInfo dynamicDeepSeekModelInfo = ModelInfo(
  supports: Map.unmodifiable(deepSeekTextSupports),
);

/// Capability metadata for any DeepSeek model name.
ModelInfo deepSeekModelInfoFor(String model) =>
    knownDeepSeekModelFor(model)?.info ?? dynamicDeepSeekModelInfo;

final _compatInfo = <KnownDeepSeekModel, ModelInfo>{
  for (final model in KnownDeepSeekModel.values)
    model: ModelInfo(supports: model.info.supports),
};

/// Capability metadata for [modelName] on a host that serves DeepSeek's models
/// without being DeepSeek.
///
/// Splits the way `compatModelInfo` does: capabilities carry over, because a
/// gateway serving `deepseek-flash` is serving that model, while the label,
/// lifecycle stage and routing aliases describe DeepSeek's own deployment.
ModelInfo compatDeepSeekModelInfo(String modelName) {
  final curated = knownDeepSeekModelFor(modelName);
  return curated != null ? _compatInfo[curated]! : dynamicDeepSeekModelInfo;
}
