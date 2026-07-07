// Copyright 2025 Google LLC
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

import 'dart:convert';

import 'package:genkit/plugin.dart';
import 'package:genkit_google_genai/common.dart' as google;

List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>> listVertexEmbedders({
  required String pluginName,
  required List<dynamic> publisherModels,
}) {
  return publisherModels
      .whereType<Map>()
      .where((modelMap) {
        final name = modelMap['name'] as String?;
        return name != null && name.contains('embedding');
      })
      .map((modelMap) {
        final modelName = (modelMap['name'] as String).split('/').last;
        return _vertexEmbedderMetadata('$pluginName/$modelName');
      })
      .toList();
}

ActionMetadata<dynamic, dynamic, dynamic, dynamic> _vertexEmbedderMetadata(
  String name,
) {
  final metadata = embedderMetadata(
    name,
    customOptions: google.TextEmbedderOptions.$schema,
  );
  return ActionMetadata(
    name: metadata.name,
    description: metadata.description,
    actionType: metadata.actionType,
    inputSchema: EmbedRequest.$schema,
    outputSchema: EmbedResponse.$schema,
    metadata: metadata.metadata,
  );
}

Embedder createVertexEmbedder({
  required String pluginName,
  required String embedderName,
  required Future<google.GenerativeLanguageBaseClient> Function() getApiClient,
  required GenkitException Function(Object, StackTrace) handleException,
  required bool closeService,
}) {
  return Embedder(
    name: '$pluginName/$embedderName',
    fn: (req, ctx) async {
      if (req == null || req.input.isEmpty) {
        return EmbedResponse(embeddings: []);
      }

      final service = await getApiClient();
      try {
        final options = req.options != null
            ? google.TextEmbedderOptions.fromJson(req.options!)
            : null;

        final embeddings = switch (_requestShapeFor(embedderName)) {
          _VertexEmbedderRequestShape.multimodalPredict =>
            _runMultimodalPredictRequests(
              service: service,
              embedderName: embedderName,
              docs: req.input,
              options: options,
            ),
          _VertexEmbedderRequestShape.textPredict => _runTextPredictRequests(
            service: service,
            embedderName: embedderName,
            docs: req.input,
            options: options,
          ),
        };
        return EmbedResponse(embeddings: await embeddings);
      } catch (e, stack) {
        throw handleException(e, stack);
      } finally {
        if (closeService) {
          service.client.close();
        }
      }
    },
  );
}

String _documentText(DocumentData doc) {
  return doc.content.where((p) => p.isText).map((p) => p.text).join('\n');
}

List<Map<String, dynamic>> _requirePredictions(
  Object? rawPredictions, {
  required int expectedCount,
}) {
  if (rawPredictions is! List || rawPredictions.isEmpty) {
    throw GenkitException(
      'Vertex AI returned no predictions.',
      status: StatusCodes.INTERNAL,
    );
  }
  if (rawPredictions.length != expectedCount) {
    throw GenkitException(
      'Vertex AI returned ${rawPredictions.length} predictions for $expectedCount input documents.',
      status: StatusCodes.INTERNAL,
    );
  }

  return rawPredictions.map((prediction) {
    if (prediction is! Map) {
      throw GenkitException(
        'Vertex AI returned an invalid prediction payload.',
        status: StatusCodes.INTERNAL,
      );
    }
    return prediction.cast<String, dynamic>();
  }).toList();
}

/// Embeds [docs] with a multimodal model (e.g. `multimodalembedding`), which
/// uses a different `:predict` request and response shape than text embedders.
///
/// Unlike text embedders, a multimodal model returns **one embedding per
/// modality per document**, not one per document: a document with both text and
/// an image yields two embeddings, and a video yields one embedding per segment.
/// The returned `List<Embedding>` is therefore **not** positionally aligned with
/// [docs]; callers must group by the `documentIndex` metadata rather than zip by
/// list index.
///
/// Each returned [Embedding] carries metadata identifying its source:
/// - `documentIndex`: index into [docs] this embedding came from.
/// - `modality`: `'text'`, `'image'`, or `'video'`.
/// - `partIndex` (image/video): index of the source [Part] within the document.
/// - `partIndices` (text): indices of the non-empty text parts that were
///   concatenated into the embedded text.
/// - `segmentIndex` (video): the segment ordinal, plus `startOffsetSec` /
///   `endOffsetSec` when the API returns them.
Future<List<Embedding>> _runMultimodalPredictRequests({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required List<DocumentData> docs,
  required google.TextEmbedderOptions? options,
}) async {
  final instances = [
    for (var i = 0; i < docs.length; i++)
      _toMultimodalInstance(docs[i], documentIndex: i),
  ];
  final parameters = <String, dynamic>{};
  final outputDimensionality = options?.outputDimensionality;
  if (outputDimensionality != null) {
    // Multimodal predict expects `parameters.dimension`, not
    // `outputDimensionality`.
    parameters['dimension'] = outputDimensionality;
  }

  final res = await service.predict({
    'instances': instances.map((instance) => instance.instance).toList(),
    if (parameters.isNotEmpty) 'parameters': parameters,
  }, model: 'models/$embedderName');

  final predictions = _requirePredictions(
    res['predictions'],
    expectedCount: instances.length,
  );
  return [
    for (var i = 0; i < predictions.length; i++)
      ..._multimodalPredictionEmbeddings(
        predictions[i],
        expectedOutputs: instances[i].expectedOutputs,
      ),
  ];
}

Future<List<Embedding>> _runTextPredictRequests({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required List<DocumentData> docs,
  required google.TextEmbedderOptions? options,
}) async {
  // Older text embedders still use the predict payload shape.
  final title = options?.title;
  final taskType = options?.taskType;
  final instances = docs.map((doc) {
    final instance = <String, dynamic>{'content': _documentText(doc)};
    if (title != null) {
      instance['title'] = title;
    }
    if (taskType != null) {
      instance['task_type'] = taskType;
    }
    return instance;
  }).toList();

  final parameters = <String, dynamic>{};
  final outputDimensionality = options?.outputDimensionality;
  if (outputDimensionality != null) {
    parameters['outputDimensionality'] = outputDimensionality;
  }

  final res = await service.predict({
    'instances': instances,
    if (parameters.isNotEmpty) 'parameters': parameters,
  }, model: 'models/$embedderName');

  final predictions = _requirePredictions(
    res['predictions'],
    expectedCount: docs.length,
  );
  return predictions.map(_textPredictionEmbedding).toList();
}

Embedding _textPredictionEmbedding(Map<String, dynamic> prediction) {
  final embeddingData = prediction['embeddings'];
  final values = embeddingData is Map ? embeddingData['values'] : null;
  if (values is! List) {
    throw GenkitException(
      'Vertex AI returned an invalid prediction payload.',
      status: StatusCodes.INTERNAL,
    );
  }

  return Embedding(
    embedding: values.map((value) => (value as num).toDouble()).toList(),
  );
}

_MultimodalInstance _toMultimodalInstance(
  DocumentData doc, {
  required int documentIndex,
}) {
  final text = _documentText(doc).trim();
  final instance = <String, dynamic>{};
  final expectedOutputs = <_MultimodalExpectedOutput>[];

  if (text.isNotEmpty) {
    instance['text'] = text;
    expectedOutputs.add(
      _MultimodalExpectedOutput(
        output: _MultimodalOutput.text,
        metadata: {
          'documentIndex': documentIndex,
          'modality': 'text',
          'partIndices': [
            for (var i = 0; i < doc.content.length; i++)
              if (doc.content[i].isText &&
                  (doc.content[i].text?.trim().isNotEmpty ?? false))
                i,
          ],
        },
      ),
    );
  }

  for (var i = 0; i < doc.content.length; i++) {
    final part = doc.content[i];
    final media = part.media;
    if (!part.isMedia || media == null) continue;

    final mediaField = _toMultimodalMediaField(media);
    if (instance.containsKey(mediaField.key)) {
      throw GenkitException(
        'Vertex multimodalembedding supports at most one ${mediaField.key} part per input document.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    instance[mediaField.key] = mediaField.value;
    expectedOutputs.add(
      _MultimodalExpectedOutput(
        output: mediaField.key == 'image'
            ? _MultimodalOutput.image
            : _MultimodalOutput.video,
        metadata: {
          'documentIndex': documentIndex,
          'modality': mediaField.key,
          'partIndex': i,
        },
      ),
    );
  }

  if (instance.isEmpty) {
    throw GenkitException(
      'Vertex multimodalembedding requires text, image, or video input.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  return _MultimodalInstance(
    instance: instance,
    expectedOutputs: expectedOutputs,
  );
}

MapEntry<String, Map<String, dynamic>> _toMultimodalMediaField(Media media) {
  final mimeType = _mediaMimeType(media);
  final fieldName = _multimodalFieldName(mimeType);

  // Convert the media input into the format Vertex expects.
  if (media.url.startsWith('data:')) {
    final data = Uri.tryParse(media.url)?.data;
    if (data == null) {
      throw GenkitException(
        'Vertex multimodalembedding media inputs require a valid data URI.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    return MapEntry(fieldName, {
      'bytesBase64Encoded': base64Encode(data.contentAsBytes()),
      if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
    });
  }

  if (media.url.startsWith('gs://')) {
    return MapEntry(fieldName, {
      'gcsUri': media.url,
      if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
    });
  }

  throw GenkitException(
    'Vertex multimodalembedding media inputs must use gs:// URIs or inline data URIs.',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

String? _mediaMimeType(Media media) {
  if (media.contentType?.isNotEmpty == true) {
    return media.contentType;
  }

  if (media.url.startsWith('data:')) {
    return Uri.tryParse(media.url)?.data?.mimeType;
  }

  return null;
}

String _multimodalFieldName(String? mimeType) {
  if (mimeType == null || mimeType.isEmpty) {
    throw GenkitException(
      'Vertex multimodalembedding media inputs require a MIME type.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  if (mimeType.startsWith('image/')) {
    return 'image';
  }
  if (mimeType.startsWith('video/')) {
    return 'video';
  }

  throw GenkitException(
    'Unsupported Vertex multimodalembedding media MIME type: $mimeType',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

List<Embedding> _multimodalPredictionEmbeddings(
  Map<String, dynamic> prediction, {
  required List<_MultimodalExpectedOutput> expectedOutputs,
}) {
  final embeddings = <Embedding>[];
  for (final expectedOutput in expectedOutputs) {
    switch (expectedOutput.output) {
      case _MultimodalOutput.text:
        embeddings.add(
          _embeddingFromMultimodalValues(
            prediction['textEmbedding'] as List?,
            expectedOutput: expectedOutput,
          ),
        );
      case _MultimodalOutput.image:
        embeddings.add(
          _embeddingFromMultimodalValues(
            prediction['imageEmbedding'] as List?,
            expectedOutput: expectedOutput,
          ),
        );
      case _MultimodalOutput.video:
        final videoEmbeddings = prediction['videoEmbeddings'] as List?;
        if (videoEmbeddings == null || videoEmbeddings.isEmpty) {
          throw GenkitException(
            'Vertex multimodalembedding did not return a video embedding.',
            status: StatusCodes.INTERNAL,
          );
        }

        for (var i = 0; i < videoEmbeddings.length; i++) {
          final videoEmbedding = videoEmbeddings[i];
          if (videoEmbedding is! Map) {
            throw GenkitException(
              'Vertex multimodalembedding returned an invalid video embedding.',
              status: StatusCodes.INTERNAL,
            );
          }
          embeddings.add(
            _embeddingFromMultimodalValues(
              videoEmbedding['embedding'] as List?,
              expectedOutput: expectedOutput,
              metadata: {
                ...expectedOutput.metadata,
                'segmentIndex': i,
                if (videoEmbedding['startOffsetSec'] != null)
                  'startOffsetSec': videoEmbedding['startOffsetSec'],
                if (videoEmbedding['endOffsetSec'] != null)
                  'endOffsetSec': videoEmbedding['endOffsetSec'],
              },
            ),
          );
        }
    }
  }
  return embeddings;
}

Embedding _embeddingFromMultimodalValues(
  List? values, {
  required _MultimodalExpectedOutput expectedOutput,
  Map<String, dynamic>? metadata,
}) {
  if (values == null) {
    throw GenkitException(
      'Vertex multimodalembedding did not return a ${expectedOutput.output.name} embedding.',
      status: StatusCodes.INTERNAL,
    );
  }

  return Embedding(
    embedding: values.map((value) => (value as num).toDouble()).toList(),
    metadata: metadata ?? expectedOutput.metadata,
  );
}

_VertexEmbedderRequestShape _requestShapeFor(String modelName) {
  // Vertex AI exposes a single online embedding method: `:predict`. Multimodal
  // models take a distinct instance/response shape; every other text and Gemini
  // embedding model uses the text predict shape. (Vertex has no
  // `:batchEmbedContents` method, and `:embedContent` accepts only one input,
  // so `:predict` is the universal online path.)
  if (_isMultimodalEmbeddingFamily(modelName)) {
    return _VertexEmbedderRequestShape.multimodalPredict;
  }
  return _VertexEmbedderRequestShape.textPredict;
}

bool _isMultimodalEmbeddingFamily(String modelName) {
  return modelName.contains('multimodal') && modelName.contains('embedding');
}

class _MultimodalInstance {
  final Map<String, dynamic> instance;
  final List<_MultimodalExpectedOutput> expectedOutputs;

  _MultimodalInstance({required this.instance, required this.expectedOutputs});
}

class _MultimodalExpectedOutput {
  final _MultimodalOutput output;
  final Map<String, dynamic> metadata;

  _MultimodalExpectedOutput({required this.output, required this.metadata});
}

enum _MultimodalOutput { text, image, video }

enum _VertexEmbedderRequestShape { multimodalPredict, textPredict }
