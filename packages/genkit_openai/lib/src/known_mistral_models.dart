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

/// Default plugin / namespace name for the Mistral handle.
const String defaultMistralNamespace = 'mistral';

/// [multimodalSupports] without image input.
///
/// Mistral takes `json_schema` structured outputs on every chat model, so
/// `constrained` stays: the only axis its catalog differs on is vision.
const mistralTextSupports = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
  'constrained': true,
};

/// Mistral models the plugin curates capability metadata for.
///
/// Curated by their `-latest` aliases, which Mistral repoints at each new
/// release, rather than by dated snapshot: the aliases are what Mistral's own
/// samples use, and they do not go stale the way a snapshot list does. Any
/// other name still resolves, taking [dynamicMistralModelInfo].
///
/// The Magistral reasoning models are deliberately absent. They answer with
/// `content` as an array of `thinking` and `text` chunks, which the plugin
/// does not read yet, so listing them would offer models whose every reply
/// fails to parse.
///
/// Catalog: https://docs.mistral.ai/getting-started/models
enum KnownMistralModel {
  /// Mistral's flagship general-purpose model. Image input.
  mistralLarge('mistral-large-latest', 'Mistral Large', multimodalSupports),

  /// Mistral Medium. Image input.
  mistralMedium('mistral-medium-latest', 'Mistral Medium', multimodalSupports),

  /// Mistral Small. Image input.
  mistralSmall('mistral-small-latest', 'Mistral Small', multimodalSupports),

  /// Codestral, the coding model. Text only.
  codestral('codestral-latest', 'Codestral', mistralTextSupports);

  const KnownMistralModel(this.id, this.label, this.supports);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Capability map registered for this model.
  final Map<String, dynamic> supports;

  /// Lifecycle stage, in the same vocabulary the OpenAI catalog uses.
  ///
  /// Not a constructor parameter: an alias never retires, it is repointed.
  OpenAIModelStage get stage => OpenAIModelStage.stable;

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

/// Mistral embedders the plugin lists without network access.
///
/// Listed so that `resolve` serves them: a provider with no curated embedders
/// declines every embedder lookup, and Mistral's `/models` reports these
/// anyway.
const List<String> knownMistralEmbedderModels = [
  'mistral-embed',
  'codestral-embed',
];

final _knownMistralModelsByName = <String, KnownMistralModel>{
  for (final model in KnownMistralModel.values) model.id.toLowerCase(): model,
};

/// Returns the curated entry for [modelName], or `null` when the name is not
/// curated. Matching is case-insensitive.
KnownMistralModel? knownMistralModelFor(String modelName) =>
    _knownMistralModelsByName[modelName.toLowerCase()];

/// Capability metadata for a Mistral model with no curated entry.
///
/// Claims only what every Mistral chat model has: multi-turn, a system role,
/// tools, and JSON schema output. Image input is withheld because the coding
/// and edge models lack it.
final ModelInfo dynamicMistralModelInfo = ModelInfo(
  supports: Map.unmodifiable(mistralTextSupports),
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
