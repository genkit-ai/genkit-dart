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
import 'package:openai_dart/openai_dart.dart' as sdk;
import 'package:schemantic/schemantic.dart';

import 'known_embedders.dart';

part 'embed.g.dart';

/// Options for OpenAI embedding models.
///
/// `encoding_format` is deliberately absent: the only alternative to the
/// default is `base64`, which returns the vector as a string the SDK's
/// response model cannot parse, so offering it would only let a caller break
/// the call.
@Schema()
abstract class $OpenAIEmbedderOptions {
  /// Length of the returned vector.
  ///
  /// Only the `text-embedding-3-*` models accept this, and only to shorten:
  /// they are trained so that a prefix of the vector is still a usable
  /// embedding. Defaults to the model's full size.
  int? get dimensions;

  /// User identifier for abuse detection.
  String? get user;
}

/// Returns the custom options schema for embedders.
SchemanticType<OpenAIEmbedderOptions> embedderOptionsSchema() =>
    OpenAIEmbedderOptions.$schema;

/// Parses embedder options from action config.
OpenAIEmbedderOptions parseEmbedderOptions(Map<String, dynamic>? config) {
  return config != null
      ? OpenAIEmbedderOptions.$schema.parse(config)
      : OpenAIEmbedderOptions();
}

/// Maximum inputs OpenAI accepts in one `POST /v1/embeddings` call.
///
/// A larger `embedMany` is split across requests rather than rejected, since a
/// corpus of more than 2048 documents is an ordinary thing to embed.
///
/// The array limit is the only one enforced here. A request is also capped at
/// 300,000 tokens across all of its inputs, which cannot be checked without
/// tokenising; a batch that trips it surfaces as OpenAI's own error.
const maxEmbeddingInputs = 2048;

/// Splits [inputs] into batches OpenAI will accept in a single request.
Iterable<List<String>> embeddingBatches(List<String> inputs) sync* {
  for (var start = 0; start < inputs.length; start += maxEmbeddingInputs) {
    yield inputs.sublist(
      start,
      (start + maxEmbeddingInputs).clamp(0, inputs.length),
    );
  }
}

/// Flattens [documents] into the strings sent as `input`.
///
/// A document's text parts are joined with newlines, the way the googleai and
/// vertexai embedders do it. Media parts are dropped: OpenAI has no
/// multimodal embedder, so there is nowhere to send them.
///
/// A document that carries no text is rejected rather than sent as `""`.
/// OpenAI answers an empty string with a 400 naming only the input index, and
/// an all-media document reaching a text embedder is a caller mistake worth
/// naming.
List<String> embeddingInputs(List<DocumentData> documents) {
  return [
    for (var i = 0; i < documents.length; i++)
      _documentText(documents[i], index: i),
  ];
}

String _documentText(DocumentData document, {required int index}) {
  final text = document.content
      .where((part) => part.isText)
      .map((part) => part.text)
      .join('\n');
  if (text.trim().isEmpty) {
    throw GenkitException(
      'Document at index $index has no text content to embed. OpenAI '
      'embedders accept text only.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  return text;
}

/// Validates a requested [dimensions] against the curated catalog.
///
/// Both failures are 400s from OpenAI if sent, but the API reports them
/// against the raw parameter; the catalog knows which model the caller named
/// and what it would have returned. Only curated models are checked — an
/// uncurated name has no claim to check against, so its request goes through
/// and OpenAI has the last word either way.
///
/// The caller decides when the catalog is authoritative enough to reject on:
/// it describes OpenAI's models, and a compatible host serving one of those
/// names may not have the same limits.
void validateEmbedderDimensions(String embedderName, int? dimensions) {
  if (dimensions == null) return;
  final curated = knownOpenAIEmbedderFor(embedderName);
  if (curated == null) return;

  if (!curated.dimensionsReducible) {
    throw GenkitException(
      '${curated.id} does not support the dimensions option; it always '
      'returns ${curated.dimensions} dimensions.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  if (dimensions < 1 || dimensions > curated.dimensions) {
    throw GenkitException(
      '${curated.id} returns between 1 and ${curated.dimensions} dimensions; '
      'got $dimensions.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
}

/// Converts an OpenAI embeddings response into Genkit [Embedding]s.
///
/// Ordered by the `index` OpenAI stamps on each vector rather than by
/// position, because the caller's list order is the only thing tying a vector
/// back to its document and the response is not documented to preserve it.
List<Embedding> toGenkitEmbeddings(
  sdk.EmbeddingResponse response, {
  required int expectedCount,
}) {
  if (response.data.length != expectedCount) {
    throw GenkitException(
      'OpenAI returned ${response.data.length} embeddings for $expectedCount '
      'input documents.',
      status: StatusCodes.INTERNAL,
    );
  }

  final ordered = [...response.data]
    ..sort((a, b) => a.index.compareTo(b.index));
  return [
    for (final embedding in ordered) Embedding(embedding: embedding.embedding),
  ];
}
