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

part of 'integration_schema_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type SimpleObjectSchema(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory SimpleObjectSchema.from({
    required String name,
    required int count,
    required bool isActive,
  }) {
    return SimpleObjectSchema({
      'name': name,
      'count': count,
      'isActive': isActive,
    });
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  int get count {
    return _json['count'] as int;
  }

  set count(int value) {
    _json['count'] = value;
  }

  bool get isActive {
    return _json['isActive'] as bool;
  }

  set isActive(bool value) {
    _json['isActive'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SimpleObjectSchemaTypeFactory
    extends SchemanticType<SimpleObjectSchema> {
  const _SimpleObjectSchemaTypeFactory();

  @override
  SimpleObjectSchema parse(Object? json) {
    return SimpleObjectSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SimpleObjectSchema',
    definition: simpleObjectSchema,
    dependencies: [],
  );
}

const simpleObjectSchemaType = _SimpleObjectSchemaTypeFactory();

extension type NestedObjectSchemaMetadata(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory NestedObjectSchemaMetadata.from({
    required String created,
    required List<String> tags,
  }) {
    return NestedObjectSchemaMetadata({'created': created, 'tags': tags});
  }

  String get created {
    return _json['created'] as String;
  }

  set created(String value) {
    _json['created'] = value;
  }

  List<String> get tags {
    return (_json['tags'] as List).cast<String>();
  }

  set tags(List<String> value) {
    _json['tags'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}
extension type NestedObjectSchema(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory NestedObjectSchema.from({
    required String id,
    required NestedObjectSchemaMetadata metadata,
  }) {
    return NestedObjectSchema({'id': id, 'metadata': metadata});
  }

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  NestedObjectSchemaMetadata get metadata {
    return _json['metadata'] as NestedObjectSchemaMetadata;
  }

  set metadata(NestedObjectSchemaMetadata value) {
    _json['metadata'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _NestedObjectSchemaTypeFactory
    extends SchemanticType<NestedObjectSchema> {
  const _NestedObjectSchemaTypeFactory();

  @override
  NestedObjectSchema parse(Object? json) {
    return NestedObjectSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'NestedObjectSchema',
    definition: nestedObjectSchema,
    dependencies: [],
  );
}

const nestedObjectSchemaType = _NestedObjectSchemaTypeFactory();

extension type ArraySchemaItem(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory ArraySchemaItem.from({required int value}) {
    return ArraySchemaItem({'value': value});
  }

  int get value {
    return _json['value'] as int;
  }

  set value(int value) {
    _json['value'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ArraySchemaTypeFactory extends SchemanticType<List> {
  const _ArraySchemaTypeFactory();

  @override
  List<ArraySchemaItem> parse(Object? json) {
    return (json as List)
        .cast<Map<String, dynamic>>()
        .map((e) => ArraySchemaItem(e))
        .toList();
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ArraySchema',
    definition: arraySchema,
    dependencies: [],
  );
}

const arraySchemaType = _ArraySchemaTypeFactory();
