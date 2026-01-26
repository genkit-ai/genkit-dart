// dart format width=80
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
  SharedChild(this._json);

  factory SharedChild.from({required String childId}) {
    return SharedChild({'childId': childId});
  }

  Map<String, dynamic> _json;

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
    return SharedChild(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SharedChild',
    definition: Schema.object(
      properties: {'childId': Schema.string()},
      required: ['childId'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const SharedChildType = _SharedChildTypeFactory();

class PartSchema {
  PartSchema(this._json);

  factory PartSchema.from() {
    return PartSchema({});
  }

  Map<String, dynamic> _json;

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _PartSchemaTypeFactory extends SchemanticType<PartSchema> {
  const _PartSchemaTypeFactory();

  @override
  PartSchema parse(Object? json) {
    return PartSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PartSchema',
    definition: Schema.object(properties: {}, required: []),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const PartSchemaType = _PartSchemaTypeFactory();

class TextPartSchema implements PartSchema {
  TextPartSchema(this._json);

  factory TextPartSchema.from({
    required String text,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    return TextPartSchema({
      'text': text,
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
    });
  }

  @override
  Map<String, dynamic> _json;

  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return _json['metadata'] as Map<String, dynamic>?;
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return _json['custom'] as Map<String, dynamic>?;
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

class _TextPartSchemaTypeFactory extends SchemanticType<TextPartSchema> {
  const _TextPartSchemaTypeFactory();

  @override
  TextPartSchema parse(Object? json) {
    return TextPartSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TextPartSchema',
    definition: Schema.object(
      properties: {
        'text': Schema.string(),
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['text'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const TextPartSchemaType = _TextPartSchemaTypeFactory();
