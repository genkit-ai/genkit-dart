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
  factory ImagenOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ImagenOptions._(this._json);

  ImagenOptions({
    String? apiKey,
    int? numberOfImages,
    String? aspectRatio,
    String? personGeneration,
  }) {
    _json = {
      'apiKey': ?apiKey,
      'numberOfImages': ?numberOfImages,
      'aspectRatio': ?aspectRatio,
      'personGeneration': ?personGeneration,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ImagenOptions> $schema =
      _ImagenOptionsTypeFactory();

  String? get apiKey {
    return _json['apiKey'] as String?;
  }

  set apiKey(String? value) {
    if (value == null) {
      _json.remove('apiKey');
    } else {
      _json['apiKey'] = value;
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

  @override
  String toString() {
    return _json.toString();
  }

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
        'apiKey': $Schema.string(),
        'numberOfImages': $Schema.integer(
          description:
              'The number of images to generate, from 1 to 4 inclusive. Defaults to 1.',
          minimum: 1,
          maximum: 4,
        ),
        'aspectRatio': $Schema.string(
          description: 'Desired aspect ratio of the output image.',
          enumValues: ['1:1', '9:16', '16:9', '3:4', '4:3'],
        ),
        'personGeneration': $Schema.string(
          description: 'Control if and how images of people are generated.',
          enumValues: ['dont_allow', 'allow_adult', 'allow_all'],
        ),
      },
      'additionalProperties': true,
    }).value,
    dependencies: [],
  );
}
