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
import 'package:genkit_google_genai/common.dart';
import 'package:schemantic/schemantic.dart';

typedef LyriaApiClientProvider =
    Future<GenerativeLanguageBaseClient> Function();
typedef LyriaExceptionHandler =
    GenkitException Function(Object error, StackTrace stackTrace);

final lyriaModelInfo = ModelInfo(supports: {'media': true}, label: 'Lyria');

base class LyriaOptions {
  factory LyriaOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  LyriaOptions._(this._json);

  LyriaOptions({String? negativePrompt, int? seed, int? sampleCount}) {
    _json = {
      'negativePrompt': ?negativePrompt,
      'seed': ?seed,
      'sampleCount': ?sampleCount,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<LyriaOptions> $schema =
      _LyriaOptionsTypeFactory();

  String? get negativePrompt => _json['negativePrompt'] as String?;
  int? get seed => _json['seed'] as int?;
  int? get sampleCount => _json['sampleCount'] as int?;

  Map<String, dynamic> toJson() => _json;
}

base class _LyriaOptionsTypeFactory extends SchemanticType<LyriaOptions> {
  const _LyriaOptionsTypeFactory();

  @override
  LyriaOptions parse(Object? json) {
    return LyriaOptions._((json as Map).cast<String, dynamic>());
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'LyriaOptions',
    definition: {
      'type': 'object',
      'properties': {
        'negativePrompt': {
          'type': 'string',
          'description': 'Description of audio elements to exclude.',
        },
        'seed': {
          'type': 'integer',
          'description':
              'Optional deterministic seed. Cannot be used with sampleCount.',
        },
        'sampleCount': {
          'type': 'integer',
          'minimum': 1,
          'description':
              'Optional number of audio samples. Cannot be used with seed.',
        },
      },
    },
  );
}

Model createLyriaModel({
  required String pluginName,
  required String modelName,
  required LyriaApiClientProvider getApiClient,
  required LyriaApiClientProvider getInteractionsApiClient,
  required LyriaExceptionHandler handleException,
  required bool closeClient,
}) {
  return Model(
    name: '$pluginName/$modelName',
    customOptions: LyriaOptions.$schema,
    metadata: {'model': lyriaModelInfo.toJson()},
    fn: (req, ctx) async {
      final modelRequest = req!;
      final options = modelRequest.config == null
          ? LyriaOptions()
          : LyriaOptions.$schema.parse(modelRequest.config!);
      final isLyria3 = modelName.startsWith('lyria-3-');
      final service = await (isLyria3
          ? getInteractionsApiClient()
          : getApiClient());

      try {
        if (isLyria3) {
          final response = await service.interactions(
            toLyriaInteractionsRequest(modelRequest, modelName),
          );
          return fromLyriaInteractionsResponse(response);
        } else {
          final response = await service.predict(
            toLyriaPredictRequest(modelRequest, options),
            model: 'models/$modelName',
          );
          return fromLyriaPredictResponse(response);
        }
      } catch (e, stack) {
        throw handleException(e, stack);
      } finally {
        if (closeClient) {
          service.client.close();
        }
      }
    },
  );
}

Map<String, dynamic> toLyriaPredictRequest(
  ModelRequest request,
  LyriaOptions options,
) {
  if (options.seed != null && options.sampleCount != null) {
    throw GenkitException(
      'Lyria seed and sampleCount cannot be used together.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final prompt = _promptFromMessages(request.messages);
  if (prompt.isEmpty) {
    throw GenkitException(
      'Lyria requires a text prompt.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  return {
    'instances': [
      {
        'prompt': prompt,
        'negative_prompt': ?options.negativePrompt,
        'seed': ?options.seed,
      },
    ],
    'parameters': {'sample_count': ?options.sampleCount},
  };
}

Map<String, dynamic> toLyriaInteractionsRequest(
  ModelRequest request,
  String modelName,
) {
  final input = _inputFromMessages(request.messages);
  if (input.isEmpty) {
    throw GenkitException(
      'Lyria requires a text prompt.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  return {'model': modelName, 'input': input};
}

ModelResponse fromLyriaPredictResponse(Map<String, dynamic> response) {
  final predictions = response['predictions'] as List?;
  if (predictions == null || predictions.isEmpty) {
    throw GenkitException('Lyria returned no predictions.');
  }

  final parts = predictions.map((prediction) {
    final predictionMap = prediction as Map<String, dynamic>;
    final audioContent = _extractAudioContent(predictionMap);
    if (audioContent == null || audioContent.isEmpty) {
      throw GenkitException(
        'Lyria prediction did not include audio content. '
        'Prediction keys: ${predictionMap.keys.join(', ')}. '
        'Prediction: ${jsonEncode(predictionMap)}',
      );
    }
    final mimeType = predictionMap['mimeType'] as String? ?? 'audio/wav';
    return MediaPart(
      media: Media(
        contentType: mimeType,
        url: 'data:$mimeType;base64,$audioContent',
      ),
    );
  }).toList();

  return ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(role: Role.model, content: parts),
    raw: response,
  );
}

ModelResponse fromLyriaInteractionsResponse(Map<String, dynamic> response) {
  final outputs = response['outputs'] as List?;
  if (outputs == null || outputs.isEmpty) {
    throw _filteredLyriaResponseException(response);
  }

  final outputMaps = outputs
      .map((output) => (output as Map).cast<String, dynamic>())
      .toList();
  final audioParts = outputMaps
      .map(_audioPartFromLyriaOutput)
      .nonNulls
      .toList();
  final textOutputs = _lyriaTextOutputs(outputMaps);
  final lyricsText = _lyriaLyricsText(textOutputs);

  if (audioParts.isEmpty) {
    final filteredReason = _filteredReason(response);
    if (filteredReason != null) {
      throw _filteredLyriaResponseException(response);
    }
    throw GenkitException(
      'Lyria returned no supported outputs. '
      'Output types: ${outputs.map((o) => (o as Map)['type']).join(', ')}.',
      details: jsonEncode(response),
    );
  }

  final content = [
    if (lyricsText != null) TextPart(text: lyricsText),
    ...audioParts,
  ];
  final additionalTextOutputs = _additionalTextOutputs(textOutputs);

  return ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(role: Role.model, content: content),
    custom: additionalTextOutputs.isEmpty
        ? null
        : {'additionalTextOutputs': additionalTextOutputs},
    raw: response,
  );
}

Part? _audioPartFromLyriaOutput(Map<String, dynamic> output) {
  final type = output['type'] as String?;
  if (type == 'audio') {
    final audioContent = _extractAudioContent(output);
    if (audioContent == null || audioContent.isEmpty) return null;
    final mimeType =
        output['mime_type'] as String? ??
        output['mimeType'] as String? ??
        'audio/mpeg';
    return MediaPart(
      media: Media(
        contentType: mimeType,
        url: 'data:$mimeType;base64,$audioContent',
      ),
    );
  }
  return null;
}

List<Map<String, dynamic>> _lyriaTextOutputs(
  List<Map<String, dynamic>> outputs,
) {
  return outputs.where((output) => output['type'] == 'text').where((output) {
    final text = output['text'] as String?;
    return text != null && text.isNotEmpty;
  }).toList();
}

String? _lyriaLyricsText(List<Map<String, dynamic>> textOutputs) {
  if (textOutputs.isEmpty) return null;
  return textOutputs.first['text'] as String?;
}

List<Map<String, dynamic>> _additionalTextOutputs(
  List<Map<String, dynamic>> textOutputs,
) {
  return textOutputs.skip(1).toList();
}

GenkitException _filteredLyriaResponseException(Map<String, dynamic> response) {
  final reason = _filteredReason(response);
  final reasonText = reason == null ? '' : ' Reason: $reason.';
  return GenkitException(
    'Lyria request was filtered and returned no outputs.$reasonText',
    status: StatusCodes.FAILED_PRECONDITION,
    details: jsonEncode(response),
  );
}

String? _filteredReason(Map<String, dynamic> response) {
  return _stringValue(response['blockReason']) ??
      _stringValue(response['blockedReason']) ??
      _stringValue(response['finishReason']) ??
      _stringValue(response['finishMessage']) ??
      _stringValue(response['statusMessage']) ??
      _stringValue(response['error']) ??
      _stringValue(response['promptFeedback']) ??
      _stringValue(response['safetyFeedback']) ??
      _stringValue(response['safetyRatings']);
}

String? _extractAudioContent(Map<String, dynamic> prediction) {
  return _stringValue(prediction['audioContent']) ??
      _stringValue(prediction['bytesBase64Encoded']) ??
      _stringValue(prediction['data']) ??
      _stringValue(prediction['audioBytes']) ??
      _stringValue(prediction['audio']);
}

String? _stringValue(Object? value) {
  if (value is String) return value;
  if (value is Map) {
    final map = value.cast<String, dynamic>();
    return _stringValue(map['message']) ??
        _stringValue(map['reason']) ??
        _stringValue(map['blockReason']) ??
        _stringValue(map['blockedReason']) ??
        _stringValue(map['finishReason']) ??
        _stringValue(map['finishMessage']) ??
        _stringValue(map['bytesBase64Encoded']) ??
        _stringValue(map['data']) ??
        _stringValue(map['audioContent']);
  }
  return null;
}

List<Map<String, dynamic>> _inputFromMessages(List<Message> messages) {
  final input = <Map<String, dynamic>>[];
  final userMessages = messages.where((message) => message.role == Role.user);
  final inputMessages = userMessages.isEmpty ? messages : userMessages;

  for (final message in inputMessages) {
    for (final part in message.content) {
      if (part.isText && part.text?.isNotEmpty == true) {
        input.add({'type': 'text', 'text': part.text});
      } else if (part.isMedia) {
        input.add(_mediaInput(part.media!));
      }
    }
  }

  return input;
}

Map<String, dynamic> _mediaInput(Media media) {
  final data = media.url.startsWith('data:') ? Uri.parse(media.url).data : null;
  final mimeType = media.contentType ?? data?.mimeType;

  if (mimeType == null || mimeType.isEmpty) {
    throw GenkitException(
      'Lyria image inputs require an image content type.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  if (!mimeType.startsWith('image/')) {
    throw GenkitException(
      'Lyria supports only image media inputs. Received $mimeType.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  if (media.url.startsWith('data:')) {
    if (data != null) {
      return {
        'type': 'image',
        'mime_type': mimeType,
        'data': base64Encode(data.contentAsBytes()),
      };
    }
  }
  return {'type': 'image', 'mime_type': mimeType, 'uri': media.url};
}

String _promptFromMessages(List<Message> messages) {
  final userMessages = messages.where((message) => message.role == Role.user);
  final promptMessages = userMessages.isEmpty ? messages : userMessages;
  return promptMessages
      .map(
        (message) => message.content
            .where((part) => part.isText)
            .map((part) => part.text)
            .join('\n'),
      )
      .where((text) => text.isNotEmpty)
      .join('\n');
}
