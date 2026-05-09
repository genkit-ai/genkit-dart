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
  final instances = docs.map(_toMultimodalInstance).toList();
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
      Embedding(
        embedding: _multimodalPredictionEmbedding(
          predictions[i],
          expectedOutput: instances[i].expectedOutput,
        ),
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

_MultimodalInstance _toMultimodalInstance(DocumentData doc) {
  final text = _documentText(doc).trim();
  final mediaParts = doc.content
      .where((part) => part.isMedia)
      .map((part) => part.media!)
      .toList();

  // A document can only contain one input type here.
  // Text, image, and video use different embedding fields in the Vertex
  // response, and this code needs one clear field to read for each document.
  if (text.isNotEmpty && mediaParts.isNotEmpty) {
    throw GenkitException(
      'Vertex multimodalembedding supports exactly one modality per input document in the embedder API. Provide text, one image, or one video.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  if (mediaParts.length > 1) {
    throw GenkitException(
      'Vertex multimodalembedding supports at most one media part per input document in the embedder API.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  if (text.isNotEmpty) {
    return _MultimodalInstance(
      instance: {'text': text},
      expectedOutput: _MultimodalOutput.text,
    );
  }

  if (mediaParts.isEmpty) {
    throw GenkitException(
      'Vertex multimodalembedding requires text, image, or video input.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final mediaField = _toMultimodalMediaField(mediaParts.single);
  return _MultimodalInstance(
    instance: {mediaField.key: mediaField.value},
    expectedOutput: mediaField.key == 'image'
        ? _MultimodalOutput.image
        : _MultimodalOutput.video,
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

List<double> _multimodalPredictionEmbedding(
  Map<String, dynamic> prediction, {
  required _MultimodalOutput expectedOutput,
}) {
  // Read the embedding field that matches the input type.
  final values = switch (expectedOutput) {
    _MultimodalOutput.text => prediction['textEmbedding'] as List?,
    _MultimodalOutput.image => prediction['imageEmbedding'] as List?,
    _MultimodalOutput.video =>
      ((prediction['videoEmbeddings'] as List?)?.firstOrNull
              as Map<String, dynamic>?)?['embedding']
          as List?,
  };

  if (values == null) {
    throw GenkitException(
      'Vertex multimodalembedding did not return a ${expectedOutput.name} embedding.',
      status: StatusCodes.INTERNAL,
    );
  }

  return values.map((value) => (value as num).toDouble()).toList();
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
  final _MultimodalOutput expectedOutput;

  _MultimodalInstance({required this.instance, required this.expectedOutput});
}

enum _MultimodalOutput { text, image, video }

enum _VertexEmbedderRequestShape {
  geminiEmbedding,
  multimodalPredict,
  textPredict,
}
