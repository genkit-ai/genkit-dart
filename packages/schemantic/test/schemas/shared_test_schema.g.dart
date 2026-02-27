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
//
// GENERATED CODE BY schemantic - DO NOT MODIFY BY HAND
// To regenerate, run `dart run build_runner build -d`

part of 'shared_test_schema.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class SharedChild {
  factory SharedChild.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SharedChild._(this._json);

  SharedChild({required String childId}) {
    _json = {'childId': childId};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<SharedChild> $schema = _SharedChildTypeFactory();

  String get childId {
    return _json['childId'] as String;
  }

  set childId(String value) {
    _json['childId'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SharedChildTypeFactory extends SchemanticType<SharedChild> {
  const _SharedChildTypeFactory();

  @override
  SharedChild parse(Object? json) {
    return SharedChild._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SharedChild',
    definition: $Schema
        .object(
          properties: {'childId': $Schema.string()},
          required: ['childId'],
        )
        .value,
    dependencies: [],
  );
}

class Part {
  factory Part.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Part._(this._json);

  Part() {
    _json = {};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Part> $schema = _PartTypeFactory();

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _PartTypeFactory extends SchemanticType<Part> {
  const _PartTypeFactory();

  @override
  Part parse(Object? json) {
    return Part._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Part',
    definition: $Schema.object(properties: {}, required: []).value,
    dependencies: [],
  );
}

class TextPart implements Part {
  factory TextPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TextPart._(this._json);

  TextPart({
    required String text,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    _json = {
      'text': text,
      'data': ?data,
      'metadata': ?metadata,
      'custom': ?custom,
    };
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<TextPart> $schema = _TextPartTypeFactory();

  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
  }

  set custom(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _TextPartTypeFactory extends SchemanticType<TextPart> {
  const _TextPartTypeFactory();

  @override
  TextPart parse(Object? json) {
    return TextPart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TextPart',
    definition: $Schema
        .object(
          properties: {
            'text': $Schema.string(),
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['text'],
        )
        .value,
    dependencies: [],
  );
}
