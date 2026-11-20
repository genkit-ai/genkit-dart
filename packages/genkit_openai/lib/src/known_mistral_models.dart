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

import 'known_embedders.dart' show curatedEmbedderInfo;
import 'known_models.dart' show OpenAIModelStage, multimodalSupports;

/// Default plugin / namespace name for the Mistral handle.
const String defaultMistralNamespace = 'mistral';

/// [multimodalSupports] without image input.
///
/// Every curated text model takes `json_schema` structured outputs and
/// function calling (both are listed per model on Mistral's model cards), so
/// `constrained` stays: the only axis the catalog differs on is vision.
const mistralTextSupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
  'constrained': true,
};

/// What an uncurated Mistral model is described as: chat with a system role,
/// and nothing else.
///
/// Mistral lists structured outputs and function calling per model card, not
/// API-wide, so neither is claimed for a name the catalog does not know.
const mistralUnknownSupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': false,
  'media': false,
  'output': ['text'],
};

/// Mistral models the plugin curates capability metadata for.
///
/// Curated by their `-latest` aliases, which are what Mistral's own samples
/// use. `mistral-large-latest` points at Large 4. `mistral-medium-latest`
/// points at Medium 3.5, which Mistral has deprecated, with retirement
/// announced for 2027-04-30; it is curated as [OpenAIModelStage.legacy] until
/// then. Any other name still resolves, taking [dynamicMistralModelInfo].
///
/// [efforts] are the `reasoning_effort` levels the model takes, and empty for
/// a model that takes none: Mistral answers "reasoning_effort is not enabled
/// for this model" for those. Each reasoning model takes its own set, and
/// Mistral answers any other level with a 400.
///
/// Catalog: https://docs.mistral.ai/models
enum KnownMistralModel {
  /// Mistral Large, currently Large 4. Image input.
  ///
  /// Thinks before every answer, with or without a `reasoning_effort`, which
  /// defaults to `high` and cannot be `none`.
  mistralLarge(
    'mistral-large-latest',
    'Mistral Large',
    multimodalSupports,
    efforts: {'low', 'medium', 'high'},
  ),

  /// Mistral Small, currently Small 4. Image input.
  ///
  /// Thinks only when given a `reasoning_effort` of `high`.
  mistralSmall(
    'mistral-small-latest',
    'Mistral Small',
    multimodalSupports,
    efforts: {'none', 'high'},
  ),

  /// Ministral 3 14B. Image input.
  ministral14b('ministral-14b-latest', 'Ministral 14B', multimodalSupports),

  /// Ministral 3 8B. Image input.
  ministral8b('ministral-8b-latest', 'Ministral 8B', multimodalSupports),

  /// Ministral 3 3B. Image input.
  ministral3b('ministral-3b-latest', 'Ministral 3B', multimodalSupports),

  /// Codestral, the coding model. Text only.
  codestral('codestral-latest', 'Codestral', mistralTextSupports),

  /// Mistral Medium 3.5, which this alias points at. Image input.
  ///
  /// Deprecated by Mistral, still served until its announced retirement.
  /// Thinks only when given a `reasoning_effort` of `high`.
  mistralMedium(
    'mistral-medium-latest',
    'Mistral Medium',
    multimodalSupports,
    efforts: {'none', 'high'},
    stage: OpenAIModelStage.legacy,
  );

  const KnownMistralModel(
    this.id,
    this.label,
    this.supports, {
    this.efforts = const {},
    this.stage = OpenAIModelStage.stable,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Capability map registered for this model.
  final Map<String, dynamic> supports;

  /// The `reasoning_effort` levels the model takes, per
  /// https://docs.mistral.ai/inference/conversations/reasoning.
  final Set<String> efforts;

  /// Whether the model takes a `reasoning_effort` at all.
  bool get reasons => efforts.isNotEmpty;

  /// Lifecycle stage, in the same vocabulary the OpenAI catalog uses.
  ///
  /// What Mistral calls deprecated (still served, retirement announced) is
  /// [OpenAIModelStage.legacy] here. [OpenAIModelStage.deprecated] is for a
  /// model Mistral no longer serves, which drops it from the listing.
  final OpenAIModelStage stage;

  /// Capability metadata registered for this model.
  ModelInfo get info => _curatedInfo[this]!;
}

final _curatedInfo = <KnownMistralModel, ModelInfo>{
  for (final model in KnownMistralModel.values)
    model: ModelInfo(
      label: model.label,
      supports: Map.unmodifiable(model.supports),
      versions: List.unmodifiable([model.id]),
      stage: model.stage.wireName,
    ),
};

/// Curated capability metadata for known Mistral models, keyed by bare model
/// name.
final Map<String, ModelInfo> knownMistralModels = Map.unmodifiable({
  for (final model in KnownMistralModel.values) model.id: model.info,
});

/// Mistral chat models the plugin lists without network access.
final List<String> knownMistralChatModels = List.unmodifiable([
  for (final model in KnownMistralModel.values)
    if (model.stage != OpenAIModelStage.deprecated) model.id,
]);

/// Mistral embedders the plugin curates, with the length of the vector each
/// returns by default.
///
/// Listed so that `resolve` serves them: a provider with no curated embedders
/// declines every embedder lookup, and Mistral's `/models` reports these
/// anyway.
enum KnownMistralEmbedder {
  /// General-purpose text embeddings.
  mistralEmbed('mistral-embed', 'Mistral Embed', 1024),

  /// Code embeddings.
  codestralEmbed('codestral-embed', 'Codestral Embed', 1536);

  const KnownMistralEmbedder(this.id, this.label, this.dimensions);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Length of the returned vector.
  final int dimensions;
}

/// Mistral embedders the plugin lists without network access.
final List<String> knownMistralEmbedderModels = List.unmodifiable([
  for (final embedder in KnownMistralEmbedder.values) embedder.id,
]);

final _knownMistralEmbeddersByName = <String, KnownMistralEmbedder>{
  for (final embedder in KnownMistralEmbedder.values)
    embedder.id.toLowerCase(): embedder,
};

/// Embedder metadata for [embedderName], in the shape the OpenAI catalog uses.
///
/// On a gateway ([compat]) the vector length carries over and the label does
/// not, as for the OpenAI embedders. An uncurated name claims no length.
Map<String, dynamic> mistralEmbedderInfoFor(
  String embedderName, {
  required bool compat,
}) {
  final curated = _knownMistralEmbeddersByName[embedderName.toLowerCase()];
  return curatedEmbedderInfo(
    label: compat ? null : curated?.label,
    dimensions: curated?.dimensions,
  );
}

final _knownMistralModelsByName = <String, KnownMistralModel>{
  for (final model in KnownMistralModel.values) model.id.toLowerCase(): model,
};

/// Returns the curated entry for [modelName], or `null` when the name is not
/// curated. Matching is case-insensitive.
KnownMistralModel? knownMistralModelFor(String modelName) =>
    _knownMistralModelsByName[modelName.toLowerCase()];

/// Capability metadata for a Mistral model with no curated entry.
///
/// See [mistralUnknownSupports].
final ModelInfo dynamicMistralModelInfo = ModelInfo(
  supports: Map.unmodifiable(mistralUnknownSupports),
);

/// Capability metadata for any Mistral model name, as `modelInfoFor` does for
/// OpenAI. The result follows the curated list and can change between
/// releases.
ModelInfo mistralModelInfoFor(String model) =>
    knownMistralModelFor(model)?.info ?? dynamicMistralModelInfo;

final _compatInfo = <KnownMistralModel, ModelInfo>{
  for (final model in KnownMistralModel.values)
    model: ModelInfo(supports: model.info.supports),
};

/// Capability metadata for [modelName] on a host that serves Mistral's models
/// without being Mistral: capabilities carry over, deployment details do not.
ModelInfo compatMistralModelInfo(String modelName) {
  final curated = knownMistralModelFor(modelName);
  return curated != null ? _compatInfo[curated]! : dynamicMistralModelInfo;
}
