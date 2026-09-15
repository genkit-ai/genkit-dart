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

import 'known_models.dart' show OpenAIModelStage;

/// Input modalities every OpenAI embedding model accepts.
///
/// `POST /v1/embeddings` takes text (or pre-tokenised text) and nothing else —
/// OpenAI has no multimodal embedder — so this is a constant rather than a
/// per-entry field. It is the `supports.input` vocabulary JS `EmbedderInfo`
/// and Go `ai.EmbedderOptions` use.
const _textInput = <String, dynamic>{
  'input': ['text'],
};

/// OpenAI embedding models the plugin curates metadata for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label] and the size of the vector it returns. This is not the set of
/// usable embedders: any name still resolves, and one with no entry here is
/// simply described without [dimensions].
///
/// Per-model behaviour belongs on this enum rather than in a name-matching
/// branch at the call site, the same way `KnownOpenAIModel` carries chat
/// capabilities.
///
/// Catalog: https://developers.openai.com/api/docs/guides/embeddings
enum KnownOpenAIEmbedder {
  /// The default: the same 8191-token context as the large model at a
  /// fraction of the cost.
  textEmbedding3Small(
    'text-embedding-3-small',
    'OpenAI text-embedding-3-small',
    dimensions: 1536,
  ),

  /// The highest-scoring OpenAI embedder, at 3072 dimensions.
  textEmbedding3Large(
    'text-embedding-3-large',
    'OpenAI text-embedding-3-large',
    dimensions: 3072,
  ),

  /// The second-generation embedder, superseded by the `-3-` pair.
  ///
  /// Predates Matryoshka training, so its vector length is fixed: it rejects
  /// the `dimensions` parameter rather than truncating.
  textEmbeddingAda002(
    'text-embedding-ada-002',
    'OpenAI text-embedding-ada-002',
    dimensions: 1536,
    dimensionsReducible: false,
    stage: OpenAIModelStage.legacy,
  );

  const KnownOpenAIEmbedder(
    this.id,
    this.label, {
    required this.dimensions,
    this.dimensionsReducible = true,
    this.stage = OpenAIModelStage.stable,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Length of the vector this model returns when asked for no particular
  /// size.
  final int dimensions;

  /// Whether the model honours a smaller `dimensions` than [dimensions].
  ///
  /// The `-3-` models are trained with Matryoshka Representation Learning, so
  /// a prefix of the vector is still a usable embedding and the API will
  /// truncate on request. Earlier models 400 instead.
  final bool dimensionsReducible;

  /// Lifecycle stage, in the same vocabulary `KnownOpenAIModel` uses.
  final OpenAIModelStage stage;

  /// Metadata registered for this embedder.
  ///
  /// One instance per entry, shared by every resolution of the embedder, so
  /// the maps it carries are unmodifiable: mutating action metadata in place
  /// must fail loudly rather than corrupt the catalog.
  Map<String, dynamic> get info => _curatedInfo[this]!;
}

/// The shape core will grow a type for in #327.
///
/// Until `Embedder` / `embedderMetadata()` carry an `EmbedderInfo` of their
/// own, this rides in the `model` metadata map that both already merge —
/// alongside the `label` they write there — so the Dev UI has something to
/// read and the values do not have to be invented twice later. The keys are
/// JS `EmbedderInfo`'s: `label`, `dimensions`, `supports.input`.
Map<String, dynamic> _info({String? label, int? dimensions, String? stage}) =>
    Map.unmodifiable(<String, dynamic>{
      'label': ?label,
      'dimensions': ?dimensions,
      'stage': ?stage,
      'supports': Map<String, dynamic>.unmodifiable(_textInput),
    });

final _curatedInfo = <KnownOpenAIEmbedder, Map<String, dynamic>>{
  for (final embedder in KnownOpenAIEmbedder.values)
    embedder: _info(
      label: embedder.label,
      dimensions: embedder.dimensions,
      stage: embedder.stage.wireName,
    ),
};

/// Curated metadata for known OpenAI embedders, keyed by bare model name (no
/// plugin prefix).
///
/// Derived from [KnownOpenAIEmbedder]; other names still resolve, they just
/// take [dynamicEmbedderInfo] instead of a curated entry.
final Map<String, Map<String, dynamic>> knownOpenAIEmbedders = Map.unmodifiable(
  {
    for (final embedder in KnownOpenAIEmbedder.values)
      embedder.id: embedder.info,
  },
);

/// Embedders the plugin lists without network access.
///
/// Listed alongside whatever `GET /models` reports, for the same reason
/// `knownChatModels` is: discovery needs both connectivity and a valid key,
/// and neither is guaranteed. [OpenAIModelStage.deprecated] entries are
/// excluded — OpenAI no longer serves them.
final List<String> knownEmbedderModels = List.unmodifiable([
  for (final embedder in KnownOpenAIEmbedder.values)
    if (embedder.stage != OpenAIModelStage.deprecated) embedder.id,
]);

final _knownOpenAIEmbeddersByName = <String, KnownOpenAIEmbedder>{
  for (final embedder in KnownOpenAIEmbedder.values)
    embedder.id.toLowerCase(): embedder,
};

/// Returns the curated entry for [embedderName], or `null` when the name is
/// not curated.
///
/// Matching is case-insensitive; the OpenAI catalog is lower-case. Unlike the
/// chat models, OpenAI has never shipped a dated snapshot of an embedder, so
/// there is no suffix to strip.
KnownOpenAIEmbedder? knownOpenAIEmbedderFor(String embedderName) =>
    _knownOpenAIEmbeddersByName[embedderName.toLowerCase()];

/// Metadata for an embedder with no curated entry.
///
/// Every OpenAI embedding endpoint takes text, so that much is safe to claim.
/// The vector length is not: it is a property of the specific model, it is
/// what a caller sizes a vector store on, and guessing 1536 because two of the
/// three curated models return it would be a number this plugin made up.
/// Omitting it says "ask the model", which is what a caller can actually do.
final Map<String, dynamic> dynamicEmbedderInfo = _info();

/// Metadata for any OpenAI embedder name: the curated entry when there is one,
/// [dynamicEmbedderInfo] otherwise.
Map<String, dynamic> embedderInfoFor(String embedderName) =>
    knownOpenAIEmbedderFor(embedderName)?.info ?? dynamicEmbedderInfo;

final _compatInfo = <KnownOpenAIEmbedder, Map<String, dynamic>>{
  for (final embedder in KnownOpenAIEmbedder.values)
    embedder: _info(dimensions: embedder.dimensions),
};

/// Metadata for [embedderName] on an OpenAI-compatible backend that is not
/// OpenAI itself.
///
/// Splits the same way `compatModelInfo` does: the vector length is a property
/// of the model, so a gateway routing `text-embedding-3-small` to OpenAI still
/// returns 1536 dimensions, but OpenAI's label and retirement schedule
/// describe OpenAI's deployment and not the backend's.
Map<String, dynamic> compatEmbedderInfo(String embedderName) {
  final curated = knownOpenAIEmbedderFor(embedderName);
  return curated != null ? _compatInfo[curated]! : dynamicEmbedderInfo;
}
