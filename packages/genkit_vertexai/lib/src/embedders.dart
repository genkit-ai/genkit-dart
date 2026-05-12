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
// ignore: implementation_imports
import 'package:genkit_google_genai/src/generated/generativelanguage.dart'
    as google_types;

List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>> listVertexEmbedders({
  required String pluginName,
  required List<dynamic> publisherModels,
}) {
  return publisherModels
      .where((m) {
        final modelMap = m as Map<String, dynamic>;
        final name = modelMap['name'] as String?;
        return name != null && name.contains('embedding');
      })
      .map((m) {
        final modelMap = m as Map<String, dynamic>;
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
          _VertexEmbedderRequestShape.geminiEmbedding =>
            _runGeminiEmbeddingRequests(
              service: service,
              embedderName: embedderName,
              docs: req.input,
              options: options,
            ),
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

google_types.EmbedContentRequest _embedContentRequest(
  DocumentData doc,
  google.TextEmbedderOptions? options,
) {
  final text = _documentText(doc);
  return google_types.EmbedContentRequest(
    content: google_types.Content(parts: [google_types.Part(text: text)]),
    outputDimensionality: options?.outputDimensionality,
    taskType: options?.taskType,
    title: options?.title,
  );
}

Future<List<Embedding>> _runGeminiEmbeddingRequests({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required List<DocumentData> docs,
  required google.TextEmbedderOptions? options,
}) async {
  if (docs.length == 1) {
    return [
      await _runEmbedContentRequest(
        service: service,
        embedderName: embedderName,
        doc: docs.single,
        options: options,
      ),
    ];
  }

  final res = await service.batchEmbedContents(
    google_types.BatchEmbedContentsRequest(
      requests: docs.map((doc) => _embedContentRequest(doc, options)).toList(),
    ),
    model: 'models/$embedderName',
  );
  final embeddings = _requireBatchEmbeddings(
    res.embeddings,
    expectedCount: docs.length,
  );
  return embeddings
      .map((embedding) => Embedding(embedding: embedding.values ?? const []))
      .toList();
}

Future<Embedding> _runEmbedContentRequest({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required DocumentData doc,
  required google.TextEmbedderOptions? options,
}) async {
  final res = await service.embedContent(
    _embedContentRequest(doc, options),
    model: 'models/$embedderName',
  );
  return Embedding(embedding: res.embedding?.values ?? []);
}

List<google_types.ContentEmbedding> _requireBatchEmbeddings(
  List<google_types.ContentEmbedding>? embeddings, {
  required int expectedCount,
}) {
  if (embeddings == null || embeddings.isEmpty) {
    throw GenkitException(
      'Vertex AI returned no embeddings.',
      status: StatusCodes.INTERNAL,
    );
  }
  if (embeddings.length != expectedCount) {
    throw GenkitException(
      'Vertex AI returned ${embeddings.length} embeddings for $expectedCount input documents.',
      status: StatusCodes.INTERNAL,
    );
  }
  return embeddings;
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
    if (prediction is! Map<String, dynamic>) {
      throw GenkitException(
        'Vertex AI returned an invalid prediction payload.',
        status: StatusCodes.INTERNAL,
      );
    }
    return prediction;
  }).toList();
}

Future<List<Embedding>> _runMultimodalPredictRequests({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required List<DocumentData> docs,
  required google.TextEmbedderOptions? options,
}) async {
  // Multimodal embedders use a different predict request and response shape.
  final instances = [
    for (var i = 0; i < docs.length; i++)
      _toMultimodalInstance(docs[i], documentIndex: i),
  ];
  final parameters = <String, dynamic>{};
  if (options?.outputDimensionality != null) {
    parameters['dimension'] = options!.outputDimensionality;
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
  final instances = docs.map((doc) {
    final instance = <String, dynamic>{'content': _documentText(doc)};
    if (options?.title != null) {
      instance['title'] = options!.title;
    }
    if (options?.taskType != null) {
      instance['task_type'] = options!.taskType;
    }
    return instance;
  }).toList();

  final parameters = <String, dynamic>{};
  if (options?.outputDimensionality != null) {
    parameters['outputDimensionality'] = options!.outputDimensionality;
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
  final embeddingData = prediction['embeddings'] as Map<String, dynamic>;
  final values = embeddingData['values'] as List;
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
    if (!part.isMedia) continue;

    final mediaField = _toMultimodalMediaField(part.media!);
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
    final data = Uri.parse(media.url).data;
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
    return Uri.parse(media.url).data?.mimeType;
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
          final videoEmbedding = videoEmbeddings[i] as Map<String, dynamic>;
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

String _baseModelName(String modelName) {
  final atIndex = modelName.indexOf('@');
  if (atIndex == -1) return modelName;
  return modelName.substring(0, atIndex);
}

_VertexEmbedderRequestShape _requestShapeFor(String modelName) {
  final baseModelName = _baseModelName(modelName);
  // Check the broad model families in order.
  if (_isMultimodalEmbeddingFamily(baseModelName)) {
    return _VertexEmbedderRequestShape.multimodalPredict;
  }
  if (_usesLegacyGeminiPredictApi(baseModelName)) {
    return _VertexEmbedderRequestShape.textPredict;
  }
  if (_isGeminiEmbeddingFamily(baseModelName)) {
    return _VertexEmbedderRequestShape.geminiEmbedding;
  }
  return _VertexEmbedderRequestShape.textPredict;
}

bool _isMultimodalEmbeddingFamily(String modelName) {
  return modelName.contains('multimodal') && modelName.contains('embedding');
}

bool _isGeminiEmbeddingFamily(String modelName) {
  return modelName.startsWith('gemini-embedding-');
}

bool _usesLegacyGeminiPredictApi(String modelName) {
  return modelName == 'gemini-embedding-001';
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

enum _VertexEmbedderRequestShape {
  geminiEmbedding,
  multimodalPredict,
  textPredict,
}
