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

import 'package:genkit/plugin.dart';
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'common_plugin.dart';

part 'imagen.g.dart';

@Schema(additionalProperties: true)
abstract class $ImagenOptions {
  String? get apiKey;

  @IntegerField(
    minimum: 1,
    maximum: 4,
    description:
        'The number of images to generate, from 1 to 4 inclusive. '
        'Defaults to 1.',
  )
  int? get numberOfImages;

  @StringField(
    enumValues: ['1:1', '9:16', '16:9', '3:4', '4:3'],
    description: 'Desired aspect ratio of the output image.',
  )
  String? get aspectRatio;

  @StringField(
    enumValues: ['dont_allow', 'allow_adult', 'allow_all'],
    description: 'Control if and how images of people are generated.',
  )
  String? get personGeneration;
}

final imagenModelInfo = ModelInfo(
  supports: {
    'media': true,
    'multiturn': false,
    'tools': false,
    'toolChoice': false,
    'systemRole': false,
    'output': ['media'],
  },
);

Model<ImagenOptions> createImagenModel(
  CommonGoogleGenPlugin plugin,
  String modelName,
) {
  return Model(
    name: '${plugin.name}/$modelName',
    customOptions: ImagenOptions.$schema,
    metadata: {'model': imagenModelInfo.toJson()},
    fn: (req, ctx) async {
      if (ctx.streamingRequested) {
        throw GenkitException(
          'Streaming is not supported for Imagen models.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
      if (req == null) {
        throw GenkitException(
          'Imagen requires a generation request.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
      if (req.tools?.isNotEmpty ?? false) {
        throw GenkitException(
          'Tools are not supported for Imagen models.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }

      final options = req.config == null
          ? ImagenOptions()
          : ImagenOptions.$schema.parse(req.config!);
      final service = await plugin.getApiClient(options.apiKey);

      try {
        final prompt = extractImagenPrompt(req);
        if (prompt.isEmpty) {
          throw GenkitException(
            'Imagen requires a non-empty text prompt.',
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }
        final image = extractImagenImage(req);

        final response = await service.predict({
          'instances': [
            {'prompt': prompt, if (image != null) 'image': image},
          ],
          'parameters': toImagenParameters(options),
        }, model: 'models/$modelName');
        final predictions = response['predictions'] as List?;
        if (predictions == null || predictions.isEmpty) {
          throw GenkitException(
            'Model returned no predictions. Possibly due to content filters.',
            status: StatusCodes.FAILED_PRECONDITION,
          );
        }

        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: predictions.map(fromImagenPrediction).toList(),
          ),
          raw: response,
        );
      } catch (e, stack) {
        throw plugin.handleException(e, stack);
      } finally {
        service.client.close();
      }
    },
  );
}

@visibleForTesting
String extractImagenPrompt(ModelRequest request) {
  final buffer = StringBuffer();
  for (final message in request.messages) {
    if (message.role != Role.user) continue;
    for (final part in message.content) {
      if (part.isText) {
        buffer.write(part.text);
      }
    }
  }
  return buffer.toString();
}

@visibleForTesting
Map<String, dynamic>? extractImagenImage(ModelRequest request) {
  for (final message in request.messages.reversed) {
    for (final part in message.content) {
      final media = part.media;
      if (media == null) continue;
      final isImage =
          media.contentType?.startsWith('image/') ??
          media.url.startsWith('data:image/');
      if (!isImage) continue;

      final dataUrlParts = media.url.split(',');
      if (dataUrlParts.length < 2 || dataUrlParts.last.isEmpty) {
        return null;
      }
      return {'bytesBase64Encoded': dataUrlParts.last};
    }
  }
  return null;
}

@visibleForTesting
Map<String, dynamic> toImagenParameters(ImagenOptions options) {
  final params = <String, dynamic>{
    'sampleCount': options.numberOfImages ?? 1,
    ...options.toJson(),
  };
  params.remove('apiKey');
  params.remove('numberOfImages');
  params.removeWhere((_, value) => value == null);
  return params;
}

@visibleForTesting
MediaPart fromImagenPrediction(Object? prediction) {
  final predictionMap = prediction as Map<String, dynamic>;
  final b64Data = predictionMap['bytesBase64Encoded'] as String?;
  final mimeType = predictionMap['mimeType'] as String? ?? 'image/png';
  if (b64Data == null || b64Data.isEmpty) {
    throw GenkitException(
      'Imagen prediction did not include image bytes.',
      status: StatusCodes.INTERNAL,
    );
  }
  return MediaPart(
    media: Media(url: 'data:$mimeType;base64,$b64Data', contentType: mimeType),
  );
}

bool isImagenModelName(String name) => name.startsWith('imagen-');
