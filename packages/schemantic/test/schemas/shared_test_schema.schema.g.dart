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

part of 'shared_test_schema.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class SharedChild implements SharedChildSchema {
  SharedChild(this._json);

  factory SharedChild.from({required String childId}) {
    return SharedChild({'childId': childId});
  }

  Map<String, dynamic> _json;

  @override
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
