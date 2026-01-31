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

part of 'agentic_rag.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class AgenticRagInput {
  factory AgenticRagInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgenticRagInput._(this._json);

  AgenticRagInput({required String question}) {
    _json = {'question': question};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<AgenticRagInput> $schema =
      _AgenticRagInputTypeFactory();

  String get question {
    return _json['question'] as String;
  }

  set question(String value) {
    _json['question'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _AgenticRagInputTypeFactory extends SchemanticType<AgenticRagInput> {
  const _AgenticRagInputTypeFactory();

  @override
  AgenticRagInput parse(Object? json) {
    return AgenticRagInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
        name: 'AgenticRagInput',
        definition: Schema.object(
          properties: {'question': Schema.string()},
          required: ['question'],
        ),
        dependencies: [],
      );
}

class MenuRagToolInput {
  factory MenuRagToolInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MenuRagToolInput._(this._json);

  MenuRagToolInput({required String query}) {
    _json = {'query': query};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<MenuRagToolInput> $schema =
      _MenuRagToolInputTypeFactory();

  String get query {
    return _json['query'] as String;
  }

  set query(String value) {
    _json['query'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MenuRagToolInputTypeFactory extends SchemanticType<MenuRagToolInput> {
  const _MenuRagToolInputTypeFactory();

  @override
  MenuRagToolInput parse(Object? json) {
    return MenuRagToolInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
        name: 'MenuRagToolInput',
        definition: Schema.object(
          properties: {'query': Schema.string()},
          required: ['query'],
        ),
        dependencies: [],
      );
}
