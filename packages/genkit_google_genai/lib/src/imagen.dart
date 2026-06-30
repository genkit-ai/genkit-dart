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
  @StringField(
    description: 'Cloud Storage URI used to store the generated images.',
  )
  String? get outputGcsUri;

  @StringField(
    description: 'Description of what to discourage in the generated images.',
  )
  String? get negativePrompt;

  @IntegerField(
    minimum: 1,
    maximum: 4,
    description:
        'The number of images to generate, from 1 to 4 inclusive. '
        'Defaults to 1.',
  )
  int? get numberOfImages;

  @StringField(
    enumValues: ['1K', '2K'],
    description:
        'The size of the generated image. Supported by Standard and Ultra '
        'models.',
  )
  String? get imageSize;

  @StringField(
    enumValues: ['1:1', '9:16', '16:9', '3:4', '4:3'],
    description: 'Desired aspect ratio of the output image.',
  )
  String? get aspectRatio;

  @DoubleField(
    description:
        'Controls how much the model adheres to the text prompt. Large values '
        'increase output and prompt alignment, but may compromise image '
        'quality.',
  )
  double? get guidanceScale;

  @IntegerField(
    description:
        'Random seed for image generation. This is not available when '
        'addWatermark is set to true.',
  )
  int? get seed;

  @StringField(
    enumValues: [
      'BLOCK_LOW_AND_ABOVE',
      'BLOCK_MEDIUM_AND_ABOVE',
      'BLOCK_ONLY_HIGH',
      'BLOCK_NONE',
    ],
    description: 'Filter level for safety filtering.',
  )
  String? get safetyFilterLevel;

  @StringField(
    enumValues: ['dont_allow', 'allow_adult', 'allow_all'],
    description: 'Control if and how images of people are generated.',
  )
  String? get personGeneration;

  @Field(
    description:
        'Whether to report safety scores of each generated image and the '
        'positive prompt in the response.',
  )
  bool? get includeSafetyAttributes;

  @Field(
    description:
        'Whether to include the Responsible AI filter reason if the image is '
        'filtered out of the response.',
  )
  bool? get includeRaiReason;

  @StringField(
    enumValues: ['auto', 'en', 'ja', 'ko', 'hi', 'zh', 'pt', 'es'],
    description: 'Language of the text in the prompt.',
  )
  String? get language;

  @StringField(description: 'MIME type of the generated image.')
  String? get outputMimeType;

  @IntegerField(
    minimum: 0,
    maximum: 100,
    description:
        'Compression quality of the generated image, for image/jpeg only.',
  )
  int? get outputCompressionQuality;

  @Field(description: 'Whether to add a watermark to the generated images.')
  bool? get addWatermark;

  @Field(description: 'User specified labels to track billing usage.')
  Map<String, String>? get labels;

  @Field(description: 'Whether to use prompt rewriting logic.')
  bool? get enhancePrompt;
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
      final service = await plugin.getApiClient();

      try {
        final prompt = extractImagenPrompt(req);
        if (prompt.isEmpty) {
          throw GenkitException(
            'Imagen requires a non-empty text prompt.',
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }

        final response = await service.predict({
          'instances': [
            {'prompt': prompt},
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
  final segments = <String>[];
  for (final message in request.messages) {
    if (message.role != Role.user) continue;
    for (final part in message.content) {
      if (part.isText) {
        final text = part.text?.trim();
        if (text?.isNotEmpty ?? false) {
          segments.add(text!);
        }
      }
    }
  }
  return segments.join(' ');
}

@visibleForTesting
Map<String, dynamic> toImagenParameters(ImagenOptions options) {
  final params = <String, dynamic>{
    'sampleCount': options.numberOfImages ?? 1,
    ...options.toJson(),
  };
  params.remove('numberOfImages');
  params.removeWhere((_, value) => value == null);
  return params;
}

@visibleForTesting
MediaPart fromImagenPrediction(Object? prediction) {
  if (prediction is! Map<String, dynamic>) {
    throw GenkitException(
      'Imagen prediction did not include a valid image map.',
      status: StatusCodes.INTERNAL,
    );
  }
  final predictionMap = prediction;
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
