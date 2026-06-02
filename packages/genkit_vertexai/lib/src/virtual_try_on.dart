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

part 'virtual_try_on.g.dart';

@Schema()
abstract class $VirtualTryOnOptions {
  $VirtualTryOnOutputOptions? get outputOptions;
  int? get sampleCount;
  String? get storageUri;
  int? get seed;
  int? get baseSteps;
  String? get safetySetting;
  String? get personGeneration;
  bool? get addWatermark;
  bool? get enhancePrompt;
}

@Schema()
abstract class $VirtualTryOnOutputOptions {
  String? get mimeType;
  int? get compressionQuality;
}

class VirtualTryOn {
  static const modelPrefix = 'virtual-try-on-';

  static final modelInfo = ModelInfo(
    supports: {
      'media': true,
      'multiturn': false,
      'tools': false,
      'toolChoice': false,
      'systemRole': false,
      'output': ['media'],
    },
  );

  static bool isModelName(String modelName) {
    return modelName.startsWith(modelPrefix);
  }

  static ActionMetadata actionMetadata(String pluginName, String modelName) {
    return modelMetadata(
      '$pluginName/$modelName',
      modelInfo: modelInfo,
      customOptions: VirtualTryOnOptions.$schema,
    );
  }

  static Model createModel({
    required String pluginName,
    required String modelName,
    required Future<GenerativeLanguageBaseClient> Function() getApiClient,
    required GenkitException Function(Object error, StackTrace stack)
    handleException,
    required bool shouldCloseClient,
  }) {
    return Model(
      name: '$pluginName/$modelName',
      customOptions: VirtualTryOnOptions.$schema,
      metadata: {'model': modelInfo.toJson()},
      fn: (req, ctx) async {
        if (ctx.streamingRequested) {
          throw GenkitException(
            'Virtual try-on does not support streaming.',
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }

        final service = await getApiClient();
        try {
          final res = await service.predict(
            _toPredictRequest(req!),
            model: 'models/$modelName',
          );
          return _fromPredictResponse(res);
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          if (shouldCloseClient) {
            service.client.close();
          }
        }
      },
    );
  }

  static Map<String, dynamic> _toPredictRequest(ModelRequest request) {
    final mediaParts = request.messages
        .expand((message) => message.content)
        .where((part) => part.isMedia)
        .map((part) => part.mediaPart!)
        .toList();

    final personImage =
        _findMediaPartByType(mediaParts, 'personImage') ??
        (mediaParts.isNotEmpty ? mediaParts.first : null);
    final productImagesByType = mediaParts
        .where((part) => part.metadata?['type'] == 'productImage')
        .toList();
    final productImages = productImagesByType.isNotEmpty
        ? productImagesByType
        : mediaParts.where((part) => part != personImage).toList();

    if (personImage == null || productImages.isEmpty) {
      throw GenkitException(
        'Virtual try-on requires a personImage media part and at least one productImage media part.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    return {
      'instances': [
        {
          'personImage': {'image': _toImage(personImage.media)},
          'productImages': productImages
              .map((part) => {'image': _toImage(part.media)})
              .toList(),
        },
      ],
      if (request.config != null) 'parameters': request.config,
    };
  }

  static MediaPart? _findMediaPartByType(List<MediaPart> parts, String type) {
    for (final part in parts) {
      if (part.metadata?['type'] == type) {
        return part;
      }
    }
    return null;
  }

  static Map<String, dynamic> _toImage(Media media) {
    final image = <String, dynamic>{
      if (media.contentType != null) 'mimeType': media.contentType,
    };

    if (media.url.startsWith('data:')) {
      final uri = Uri.parse(media.url);
      final data = uri.data;
      if (data == null) {
        throw GenkitException(
          'Invalid data URL for virtual try-on image.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
      image['mimeType'] ??= data.mimeType;
      image['bytesBase64Encoded'] = base64Encode(data.contentAsBytes());
      return image;
    }

    if (media.url.startsWith('gs://')) {
      image['gcsUri'] = media.url;
      return image;
    }

    if (media.url.startsWith('http://') || media.url.startsWith('https://')) {
      throw GenkitException(
        'Virtual try-on does not support http(s) image URIs. Use a data URL or a Cloud Storage URI.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final uri = Uri.tryParse(media.url);
    if (uri != null && uri.hasScheme) {
      throw GenkitException(
        'Unsupported URI scheme "${uri.scheme}" for virtual try-on image. Use a data URL or a Cloud Storage URI.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    image['bytesBase64Encoded'] = media.url;
    return image;
  }

  static ModelResponse _fromPredictResponse(Map<String, dynamic> response) {
    final predictions = response['predictions'] as List?;
    if (predictions == null || predictions.isEmpty) {
      throw GenkitException(
        'Virtual try-on returned no predictions.',
        status: StatusCodes.INTERNAL,
      );
    }

    final content = predictions.map((prediction) {
      final predictionMap = prediction as Map<String, dynamic>;
      final mimeType = predictionMap['mimeType'] as String? ?? 'image/png';
      final bytesBase64Encoded = predictionMap['bytesBase64Encoded'] as String?;
      final gcsUri = predictionMap['gcsUri'] as String?;
      if (bytesBase64Encoded == null && gcsUri == null) {
        throw GenkitException(
          'Virtual try-on prediction did not include image data.',
          status: StatusCodes.INTERNAL,
        );
      }
      return MediaPart(
        media: Media(
          contentType: mimeType,
          url: bytesBase64Encoded == null
              ? gcsUri!
              : 'data:$mimeType;base64,$bytesBase64Encoded',
        ),
      );
    }).toList();

    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(role: Role.model, content: content),
      raw: response,
      usage: GenerationUsage(
        outputImages: content.length.toDouble(),
        custom: {'generations': content.length},
      ),
    );
  }
}
