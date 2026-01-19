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

extension type SharedChildSchema(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory SharedChildSchema.from({String? childId}) {
    return SharedChildSchema({'childId': childId});
  }

  String? get childId {
    return _json['childId'] as String?;
  }

  set childId(String? value) {
    _json['childId'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SharedChildSchemaTypeFactory extends SchemanticType<SharedChildSchema> {
  const _SharedChildSchemaTypeFactory();

  @override
  SharedChildSchema parse(Object? json) {
    return SharedChildSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SharedChildSchema',
    definition: Schema.object(properties: {'childId': Schema.string()}),
    dependencies: [],
  );
}

const sharedChildSchemaType = _SharedChildSchemaTypeFactory();
