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

import 'known_models.dart' show OpenAIModelStage, multimodalSupports;

/// Default plugin / namespace name for the xAI handle.
const String defaultXaiNamespace = 'xai';

/// xAI models the plugin curates capability metadata for.
///
/// Every Grok text model accepts image input, calls tools, and takes a JSON
/// schema, so they all share [multimodalSupports] — the same preset OpenAI's
/// current generation uses. The one axis they differ on is whether they
/// reason, which is why that is the only per-entry flag here.
///
/// The image and video models (`grok-imagine-*`) are absent: this plugin
/// serves chat generation, and `getModelType` classifies them out of the
/// listing.
///
/// Catalog: https://docs.x.ai/docs/models
enum KnownXaiModel {
  /// Grok 4.6. 500k context, effort defaults to high.
  grok46('grok-4.6', 'xAI Grok 4.6', reasons: true),

  /// Grok 4.5. 500k context, effort defaults to high.
  grok45('grok-4.5', 'xAI Grok 4.5', reasons: true),

  /// Grok 4.3. 1M context, effort defaults to low and `none` is accepted.
  grok43('grok-4.3', 'xAI Grok 4.3', reasons: true),

  /// Grok 4.20, the reasoning build. 1M context.
  grok420Reasoning(
    'grok-4.20-0309-reasoning',
    'xAI Grok 4.20 (reasoning)',
    reasons: true,
  ),

  /// Grok 4.20, the non-reasoning build. 1M context.
  ///
  /// The only curated xAI model that takes no reasoning effort at all.
  grok420NonReasoning(
    'grok-4.20-0309-non-reasoning',
    'xAI Grok 4.20 (non-reasoning)',
  ),

  // `grok-4.20-multi-agent-0309` is deliberately absent: chat completions
  // refuses it - "Multi Agent requests are not allowed on chat completions" -
  // and this plugin speaks nothing else, so curating it would put a name in
  // the Dev UI that answers 400 the moment it is picked. Go omits it for the
  // same reason (`xai.go`). Naming it explicitly still resolves, since any
  // name does.

  /// Grok Build, xAI's coding and agentic-workflow model. 256k context.
  grokBuild('grok-build-0.1', 'xAI Grok Build 0.1', reasons: true);

  const KnownXaiModel(this.id, this.label, {this.reasons = false});

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Lifecycle stage, in the same vocabulary the OpenAI catalog uses.
  ///
  /// Not a constructor parameter yet: xAI has retired nothing this catalog
  /// curates. It becomes one the first time an id is superseded, which is what
  /// [knownXaiChatModels] is already written to expect.
  OpenAIModelStage get stage => OpenAIModelStage.stable;

  /// Whether the model thinks before answering, and so takes a
  /// `reasoning_effort`.
  ///
  /// Which levels it takes varies by model — 4.3 accepts `none` and defaults
  /// to `low`, 4.6 does neither — and xAI documents that the accepted set is
  /// per-model. The plugin checks the union and leaves the pairing to the API,
  /// rather than curating a set per entry that would go stale silently.
  final bool reasons;

  /// Capability metadata registered for this model.
  ModelInfo get info => _curatedInfo[this]!;
}

final _curatedInfo = <KnownXaiModel, ModelInfo>{
  for (final model in KnownXaiModel.values)
    model: ModelInfo(
      label: model.label,
      supports: Map.unmodifiable(multimodalSupports),
      versions: List.unmodifiable([model.id]),
      stage: model.stage.wireName,
    ),
};

/// Curated capability metadata for known xAI models, keyed by bare model name.
final Map<String, ModelInfo> knownXaiModels = Map.unmodifiable({
  for (final model in KnownXaiModel.values) model.id: model.info,
});

/// xAI chat models the plugin lists without network access.
final List<String> knownXaiChatModels = List.unmodifiable([
  for (final model in KnownXaiModel.values)
    if (model.stage != OpenAIModelStage.deprecated) model.id,
]);

final _knownXaiModelsByName = <String, KnownXaiModel>{
  for (final model in KnownXaiModel.values) model.id.toLowerCase(): model,
};

/// Returns the curated entry for [modelName], or `null` when the name is not
/// curated. Matching is case-insensitive.
KnownXaiModel? knownXaiModelFor(String modelName) =>
    _knownXaiModelsByName[modelName.toLowerCase()];

/// Capability metadata for an xAI model with no curated entry.
///
/// Every Grok text model released so far has taken images, tools and a JSON
/// schema, so a newer one is described the same way rather than being
/// under-claimed into uselessness.
final ModelInfo dynamicXaiModelInfo = ModelInfo(
  supports: Map.unmodifiable(multimodalSupports),
);

/// Capability metadata for any xAI model name.
ModelInfo xaiModelInfoFor(String model) =>
    knownXaiModelFor(model)?.info ?? dynamicXaiModelInfo;

final _compatInfo = <KnownXaiModel, ModelInfo>{
  for (final model in KnownXaiModel.values)
    model: ModelInfo(supports: model.info.supports),
};

/// Capability metadata for [modelName] on a host that serves xAI's models
/// without being xAI: capabilities carry over, deployment details do not.
ModelInfo compatXaiModelInfo(String modelName) {
  final curated = knownXaiModelFor(modelName);
  return curated != null ? _compatInfo[curated]! : dynamicXaiModelInfo;
}
