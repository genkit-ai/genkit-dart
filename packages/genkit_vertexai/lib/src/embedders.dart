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
      .where((m) {
        final modelMap = m as Map<String, dynamic>;
        final name = modelMap['name'] as String?;
        return name != null && name.contains('embedding');
      })
      .map((m) {
        final modelMap = m as Map<String, dynamic>;
        final modelName = (modelMap['name'] as String).split('/').last;
        return embedderMetadata(
          '$pluginName/$modelName',
          customOptions: google.TextEmbedderOptions.$schema,
        );
      })
      .toList();
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

        // Handle each input document separately, because Vertex embedders do
        // not all use the same request shape.
        final futures = req.input.map(
          (doc) => _runEmbedderRequest(
            service: service,
            embedderName: embedderName,
            doc: doc,
            options: options,
          ),
        );
        return EmbedResponse(embeddings: await Future.wait(futures));
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

Future<Embedding> _runEmbedderRequest({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required DocumentData doc,
  required google.TextEmbedderOptions? options,
}) async {
  // Choose the request style from the model family.
  return switch (_requestShapeFor(embedderName)) {
    _VertexEmbedderRequestShape.geminiEmbedding => _runGeminiEmbeddingRequest(
      service: service,
      embedderName: embedderName,
      doc: doc,
      options: options,
    ),
    _VertexEmbedderRequestShape.multimodalPredict =>
      _runMultimodalPredictRequest(
        service: service,
        embedderName: embedderName,
        doc: doc,
        options: options,
      ),
    _VertexEmbedderRequestShape.textPredict => _runTextPredictRequest(
      service: service,
      embedderName: embedderName,
      doc: doc,
      options: options,
    ),
  };
}

Future<Embedding> _runGeminiEmbeddingRequest({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required DocumentData doc,
  required google.TextEmbedderOptions? options,
}) async {
  try {
    // Try the newer Gemini embedding API first.
    return await _runEmbedContentRequest(
      service: service,
      embedderName: embedderName,
      doc: doc,
      options: options,
    );
  } on GenkitException catch (e) {
    if (!_shouldFallbackToTextPredict(e)) {
      rethrow;
    }
  }

  // Some older Gemini embedding models still need the predict API.
  return _runTextPredictRequest(
    service: service,
    embedderName: embedderName,
    doc: doc,
    options: options,
  );
}

Future<Embedding> _runEmbedContentRequest({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required DocumentData doc,
  required google.TextEmbedderOptions? options,
}) async {
  final text = _documentText(doc);
  final content = google.Content(parts: [google.Part(text: text)]);
  final res = await service.embedContent(
    google.EmbedContentRequest(
      content: content,
      outputDimensionality: options?.outputDimensionality,
      taskType: options?.taskType,
      title: options?.title,
    ),
    model: 'models/$embedderName',
  );
  return Embedding(embedding: res.embedding?.values ?? []);
}

Future<Embedding> _runMultimodalPredictRequest({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required DocumentData doc,
  required google.TextEmbedderOptions? options,
}) async {
  // Multimodal embedders use a different predict request and response shape.
  final instance = _toMultimodalInstance(doc);
  final parameters = <String, dynamic>{};
  if (options?.outputDimensionality != null) {
    parameters['dimension'] = options!.outputDimensionality;
  }

  final res = await service.predict({
    'instances': [instance.instance],
    if (parameters.isNotEmpty) 'parameters': parameters,
  }, model: 'models/$embedderName');

  final predictions = res['predictions'] as List;
  final prediction = predictions.single as Map<String, dynamic>;
  return Embedding(
    embedding: _multimodalPredictionEmbedding(
      prediction,
      expectedOutput: instance.expectedOutput,
    ),
  );
}

Future<Embedding> _runTextPredictRequest({
  required google.GenerativeLanguageBaseClient service,
  required String embedderName,
  required DocumentData doc,
  required google.TextEmbedderOptions? options,
}) async {
  // Older text embedders still use the predict payload shape.
  final instance = <String, dynamic>{'content': _documentText(doc)};
  if (options?.title != null) {
    instance['title'] = options!.title;
  }

  final parameters = <String, dynamic>{};
  if (options?.outputDimensionality != null) {
    parameters['outputDimensionality'] = options!.outputDimensionality;
  }
  if (options?.taskType != null) {
    parameters['taskType'] = options!.taskType;
  }

  final res = await service.predict({
    'instances': [instance],
    if (parameters.isNotEmpty) 'parameters': parameters,
  }, model: 'models/$embedderName');

  final predictions = res['predictions'] as List;
  final prediction = predictions.single as Map<String, dynamic>;
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

bool _shouldFallbackToTextPredict(GenkitException error) {
  return error.status == StatusCodes.INVALID_ARGUMENT &&
      error.message.contains('not supported in the embedContent API');
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
