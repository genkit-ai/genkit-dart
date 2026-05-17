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

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'imagen.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ImagenOptions {
  /// Creates a [ImagenOptions] from a JSON map.
  factory ImagenOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ImagenOptions._(this._json);

  ImagenOptions({
    String? outputGcsUri,
    String? negativePrompt,
    int? numberOfImages,
    String? imageSize,
    String? aspectRatio,
    double? guidanceScale,
    int? seed,
    String? safetyFilterLevel,
    String? personGeneration,
    bool? includeSafetyAttributes,
    bool? includeRaiReason,
    String? language,
    String? outputMimeType,
    int? outputCompressionQuality,
    bool? addWatermark,
    Map<String, String>? labels,
    bool? enhancePrompt,
  }) {
    _json = {
      'outputGcsUri': ?outputGcsUri,
      'negativePrompt': ?negativePrompt,
      'numberOfImages': ?numberOfImages,
      'imageSize': ?imageSize,
      'aspectRatio': ?aspectRatio,
      'guidanceScale': ?guidanceScale,
      'seed': ?seed,
      'safetyFilterLevel': ?safetyFilterLevel,
      'personGeneration': ?personGeneration,
      'includeSafetyAttributes': ?includeSafetyAttributes,
      'includeRaiReason': ?includeRaiReason,
      'language': ?language,
      'outputMimeType': ?outputMimeType,
      'outputCompressionQuality': ?outputCompressionQuality,
      'addWatermark': ?addWatermark,
      'labels': ?labels,
      'enhancePrompt': ?enhancePrompt,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ImagenOptions].
  static const SchemanticType<ImagenOptions> $schema =
      _ImagenOptionsTypeFactory();

  String? get outputGcsUri {
    return _json['outputGcsUri'] as String?;
  }

  set outputGcsUri(String? value) {
    if (value == null) {
      _json.remove('outputGcsUri');
    } else {
      _json['outputGcsUri'] = value;
    }
  }

  String? get negativePrompt {
    return _json['negativePrompt'] as String?;
  }

  set negativePrompt(String? value) {
    if (value == null) {
      _json.remove('negativePrompt');
    } else {
      _json['negativePrompt'] = value;
    }
  }

  int? get numberOfImages {
    return _json['numberOfImages'] as int?;
  }

  set numberOfImages(int? value) {
    if (value == null) {
      _json.remove('numberOfImages');
    } else {
      _json['numberOfImages'] = value;
    }
  }

  String? get imageSize {
    return _json['imageSize'] as String?;
  }

  set imageSize(String? value) {
    if (value == null) {
      _json.remove('imageSize');
    } else {
      _json['imageSize'] = value;
    }
  }

  String? get aspectRatio {
    return _json['aspectRatio'] as String?;
  }

  set aspectRatio(String? value) {
    if (value == null) {
      _json.remove('aspectRatio');
    } else {
      _json['aspectRatio'] = value;
    }
  }

  double? get guidanceScale {
    return (_json['guidanceScale'] as num?)?.toDouble();
  }

  set guidanceScale(double? value) {
    if (value == null) {
      _json.remove('guidanceScale');
    } else {
      _json['guidanceScale'] = value;
    }
  }

  int? get seed {
    return _json['seed'] as int?;
  }

  set seed(int? value) {
    if (value == null) {
      _json.remove('seed');
    } else {
      _json['seed'] = value;
    }
  }

  String? get safetyFilterLevel {
    return _json['safetyFilterLevel'] as String?;
  }

  set safetyFilterLevel(String? value) {
    if (value == null) {
      _json.remove('safetyFilterLevel');
    } else {
      _json['safetyFilterLevel'] = value;
    }
  }

  String? get personGeneration {
    return _json['personGeneration'] as String?;
  }

  set personGeneration(String? value) {
    if (value == null) {
      _json.remove('personGeneration');
    } else {
      _json['personGeneration'] = value;
    }
  }

  bool? get includeSafetyAttributes {
    return _json['includeSafetyAttributes'] as bool?;
  }

  set includeSafetyAttributes(bool? value) {
    if (value == null) {
      _json.remove('includeSafetyAttributes');
    } else {
      _json['includeSafetyAttributes'] = value;
    }
  }

  bool? get includeRaiReason {
    return _json['includeRaiReason'] as bool?;
  }

  set includeRaiReason(bool? value) {
    if (value == null) {
      _json.remove('includeRaiReason');
    } else {
      _json['includeRaiReason'] = value;
    }
  }

  String? get language {
    return _json['language'] as String?;
  }

  set language(String? value) {
    if (value == null) {
      _json.remove('language');
    } else {
      _json['language'] = value;
    }
  }

  String? get outputMimeType {
    return _json['outputMimeType'] as String?;
  }

  set outputMimeType(String? value) {
    if (value == null) {
      _json.remove('outputMimeType');
    } else {
      _json['outputMimeType'] = value;
    }
  }

  int? get outputCompressionQuality {
    return _json['outputCompressionQuality'] as int?;
  }

  set outputCompressionQuality(int? value) {
    if (value == null) {
      _json.remove('outputCompressionQuality');
    } else {
      _json['outputCompressionQuality'] = value;
    }
  }

  bool? get addWatermark {
    return _json['addWatermark'] as bool?;
  }

  set addWatermark(bool? value) {
    if (value == null) {
      _json.remove('addWatermark');
    } else {
      _json['addWatermark'] = value;
    }
  }

  Map<String, String>? get labels {
    return (_json['labels'] as Map?)?.cast<String, String>();
  }

  set labels(Map<String, String>? value) {
    if (value == null) {
      _json.remove('labels');
    } else {
      _json['labels'] = value;
    }
  }

  bool? get enhancePrompt {
    return _json['enhancePrompt'] as bool?;
  }

  set enhancePrompt(bool? value) {
    if (value == null) {
      _json.remove('enhancePrompt');
    } else {
      _json['enhancePrompt'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ImagenOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ImagenOptionsTypeFactory extends SchemanticType<ImagenOptions> {
  const _ImagenOptionsTypeFactory();

  @override
  ImagenOptions parse(Object? json) {
    return ImagenOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ImagenOptions',
    definition: $Schema.fromMap({
      'type': 'object',
      'properties': {
        'outputGcsUri': $Schema.string(
          description: 'Cloud Storage URI used to store the generated images.',
        ),
        'negativePrompt': $Schema.string(
          description:
              'Description of what to discourage in the generated images.',
        ),
        'numberOfImages': $Schema.integer(
          description:
              'The number of images to generate, from 1 to 4 inclusive. Defaults to 1.',
          minimum: 1,
          maximum: 4,
        ),
        'imageSize': $Schema.string(
          description:
              'The size of the generated image. Supported by Standard and Ultra models.',
          enumValues: ['1K', '2K'],
        ),
        'aspectRatio': $Schema.string(
          description: 'Desired aspect ratio of the output image.',
          enumValues: ['1:1', '9:16', '16:9', '3:4', '4:3'],
        ),
        'guidanceScale': $Schema.number(
          description:
              'Controls how much the model adheres to the text prompt. Large values increase output and prompt alignment, but may compromise image quality.',
        ),
        'seed': $Schema.integer(
          description:
              'Random seed for image generation. This is not available when addWatermark is set to true.',
        ),
        'safetyFilterLevel': $Schema.string(
          description: 'Filter level for safety filtering.',
          enumValues: [
            'BLOCK_LOW_AND_ABOVE',
            'BLOCK_MEDIUM_AND_ABOVE',
            'BLOCK_ONLY_HIGH',
            'BLOCK_NONE',
          ],
        ),
        'personGeneration': $Schema.string(
          description: 'Control if and how images of people are generated.',
          enumValues: ['dont_allow', 'allow_adult', 'allow_all'],
        ),
        'includeSafetyAttributes': $Schema.boolean(
          description:
              'Whether to report safety scores of each generated image and the positive prompt in the response.',
        ),
        'includeRaiReason': $Schema.boolean(
          description:
              'Whether to include the Responsible AI filter reason if the image is filtered out of the response.',
        ),
        'language': $Schema.string(
          description: 'Language of the text in the prompt.',
          enumValues: ['auto', 'en', 'ja', 'ko', 'hi', 'zh', 'pt', 'es'],
        ),
        'outputMimeType': $Schema.string(
          description: 'MIME type of the generated image.',
        ),
        'outputCompressionQuality': $Schema.integer(
          description:
              'Compression quality of the generated image, for image/jpeg only.',
          minimum: 0,
          maximum: 100,
        ),
        'addWatermark': $Schema.boolean(
          description: 'Whether to add a watermark to the generated images.',
        ),
        'labels': $Schema.object(
          description: 'User specified labels to track billing usage.',
          additionalProperties: $Schema.string(),
        ),
        'enhancePrompt': $Schema.boolean(
          description: 'Whether to use prompt rewriting logic.',
        ),
      },
      'additionalProperties': true,
    }).value,
    dependencies: [],
  );
}
