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

extension type SimpleObject(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory SimpleObject.from({
    required String name,
    required int count,
    required bool isActive,
  }) {
    return SimpleObject({'name': name, 'count': count, 'isActive': isActive});
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

class _SimpleObjectTypeFactory extends SchemanticType<SimpleObject> {
  const _SimpleObjectTypeFactory();

  @override
  SimpleObject parse(Object? json) {
    return SimpleObject(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SimpleObject',
    definition: simpleObject,
    dependencies: [],
  );
}

const simpleObjectType = _SimpleObjectTypeFactory();

extension type NestedObjectMetadata(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory NestedObjectMetadata.from({
    required String created,
    required List<String> tags,
  }) {
    return NestedObjectMetadata({'created': created, 'tags': tags});
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
extension type NestedObject(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory NestedObject.from({
    required String id,
    required NestedObjectMetadata metadata,
  }) {
    return NestedObject({'id': id, 'metadata': metadata});
  }

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  NestedObjectMetadata get metadata {
    return _json['metadata'] as NestedObjectMetadata;
  }

  set metadata(NestedObjectMetadata value) {
    _json['metadata'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _NestedObjectTypeFactory extends SchemanticType<NestedObject> {
  const _NestedObjectTypeFactory();

  @override
  NestedObject parse(Object? json) {
    return NestedObject(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'NestedObject',
    definition: nestedObject,
    dependencies: [],
  );
}

const nestedObjectType = _NestedObjectTypeFactory();

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

class _ArraySchemaTypeFactory extends SchemanticType<List<ArraySchemaItem>> {
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

extension type AllPrimitivesSchema(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory AllPrimitivesSchema.from({
    required String str,
    required int intNum,
    required num dblNum,
    required bool isTruth,
  }) {
    return AllPrimitivesSchema({
      'str': str,
      'intNum': intNum,
      'dblNum': dblNum,
      'isTruth': isTruth,
    });
  }

  String get str {
    return _json['str'] as String;
  }

  set str(String value) {
    _json['str'] = value;
  }

  int get intNum {
    return _json['intNum'] as int;
  }

  set intNum(int value) {
    _json['intNum'] = value;
  }

  num get dblNum {
    return _json['dblNum'] as num;
  }

  set dblNum(num value) {
    _json['dblNum'] = value;
  }

  bool get isTruth {
    return _json['isTruth'] as bool;
  }

  set isTruth(bool value) {
    _json['isTruth'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _AllPrimitivesSchemaTypeFactory
    extends SchemanticType<AllPrimitivesSchema> {
  const _AllPrimitivesSchemaTypeFactory();

  @override
  AllPrimitivesSchema parse(Object? json) {
    return AllPrimitivesSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AllPrimitivesSchema',
    definition: allPrimitivesSchema,
    dependencies: [],
  );
}

const allPrimitivesSchemaType = _AllPrimitivesSchemaTypeFactory();

extension type ComplexCollectionsSchemaObjectListItem(
  Map<String, dynamic> _json
)
    implements Map<String, dynamic> {
  factory ComplexCollectionsSchemaObjectListItem.from({required String id}) {
    return ComplexCollectionsSchemaObjectListItem({'id': id});
  }

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}
extension type ComplexCollectionsSchema(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory ComplexCollectionsSchema.from({
    required List<List<String>> matrix,
    required List<ComplexCollectionsSchemaObjectListItem> objectList,
  }) {
    return ComplexCollectionsSchema({
      'matrix': matrix,
      'objectList': objectList,
    });
  }

  List<List<String>> get matrix {
    return (_json['matrix'] as List)
        .map((e) => (e as List).cast<String>().toList())
        .toList();
  }

  set matrix(List<List<String>> value) {
    _json['matrix'] = value;
  }

  List<ComplexCollectionsSchemaObjectListItem> get objectList {
    return (_json['objectList'] as List)
        .cast<ComplexCollectionsSchemaObjectListItem>();
  }

  set objectList(List<ComplexCollectionsSchemaObjectListItem> value) {
    _json['objectList'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ComplexCollectionsSchemaTypeFactory
    extends SchemanticType<ComplexCollectionsSchema> {
  const _ComplexCollectionsSchemaTypeFactory();

  @override
  ComplexCollectionsSchema parse(Object? json) {
    return ComplexCollectionsSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ComplexCollectionsSchema',
    definition: complexCollectionsSchema,
    dependencies: [],
  );
}

const complexCollectionsSchemaType = _ComplexCollectionsSchemaTypeFactory();

extension type DeeplyNestedObjectLevel1Level2Level3(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory DeeplyNestedObjectLevel1Level2Level3.from({required String name}) {
    return DeeplyNestedObjectLevel1Level2Level3({'name': name});
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}
extension type DeeplyNestedObjectLevel1Level2(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory DeeplyNestedObjectLevel1Level2.from({
    required DeeplyNestedObjectLevel1Level2Level3 level3,
  }) {
    return DeeplyNestedObjectLevel1Level2({'level3': level3});
  }

  DeeplyNestedObjectLevel1Level2Level3 get level3 {
    return _json['level3'] as DeeplyNestedObjectLevel1Level2Level3;
  }

  set level3(DeeplyNestedObjectLevel1Level2Level3 value) {
    _json['level3'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}
extension type DeeplyNestedObjectLevel1(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory DeeplyNestedObjectLevel1.from({
    required DeeplyNestedObjectLevel1Level2 level2,
  }) {
    return DeeplyNestedObjectLevel1({'level2': level2});
  }

  DeeplyNestedObjectLevel1Level2 get level2 {
    return _json['level2'] as DeeplyNestedObjectLevel1Level2;
  }

  set level2(DeeplyNestedObjectLevel1Level2 value) {
    _json['level2'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}
extension type DeeplyNestedObject(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory DeeplyNestedObject.from({required DeeplyNestedObjectLevel1 level1}) {
    return DeeplyNestedObject({'level1': level1});
  }

  DeeplyNestedObjectLevel1 get level1 {
    return _json['level1'] as DeeplyNestedObjectLevel1;
  }

  set level1(DeeplyNestedObjectLevel1 value) {
    _json['level1'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _DeeplyNestedObjectTypeFactory
    extends SchemanticType<DeeplyNestedObject> {
  const _DeeplyNestedObjectTypeFactory();

  @override
  DeeplyNestedObject parse(Object? json) {
    return DeeplyNestedObject(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'DeeplyNestedObject',
    definition: deeplyNestedObject,
    dependencies: [],
  );
}

const deeplyNestedObjectType = _DeeplyNestedObjectTypeFactory();
