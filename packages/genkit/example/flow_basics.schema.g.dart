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

part of 'flow_basics.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type Subject(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Subject.from({required String subject}) {
    return Subject({'subject': subject});
  }

  String get subject {
    return _json['subject'] as String;
  }

  set subject(String value) {
    _json['subject'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class SubjectTypeFactory extends JsonExtensionType<Subject> {
  const SubjectTypeFactory();

  @override
  Subject parse(Object json) {
    return Subject(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Subject',
    definition: Schema.object(
      properties: {'subject': Schema.string()},
      required: ['subject'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const SubjectType = SubjectTypeFactory();

extension type Count(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Count.from({required int count}) {
    return Count({'count': count});
  }

  int get count {
    return _json['count'] as int;
  }

  set count(int value) {
    _json['count'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class CountTypeFactory extends JsonExtensionType<Count> {
  const CountTypeFactory();

  @override
  Count parse(Object json) {
    return Count(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Count',
    definition: Schema.object(
      properties: {'count': Schema.integer()},
      required: ['count'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const CountType = CountTypeFactory();
