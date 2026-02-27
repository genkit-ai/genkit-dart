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

part of 'autonomous_operation.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class ResearchAgentInput {
  factory ResearchAgentInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResearchAgentInput._(this._json);

  ResearchAgentInput({required String task}) {
    _json = {'task': task};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ResearchAgentInput> $schema =
      _ResearchAgentInputTypeFactory();

  String get task {
    return _json['task'] as String;
  }

  set task(String value) {
    _json['task'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ResearchAgentInputTypeFactory
    extends SchemanticType<ResearchAgentInput> {
  const _ResearchAgentInputTypeFactory();

  @override
  ResearchAgentInput parse(Object? json) {
    return ResearchAgentInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResearchAgentInput',
    definition: $Schema
        .object(properties: {'task': $Schema.string()}, required: ['task'])
        .value,
    dependencies: [],
  );
}

class AgentSearchInput {
  factory AgentSearchInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentSearchInput._(this._json);

  AgentSearchInput({required String query}) {
    _json = {'query': query};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<AgentSearchInput> $schema =
      _AgentSearchInputTypeFactory();

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

class _AgentSearchInputTypeFactory extends SchemanticType<AgentSearchInput> {
  const _AgentSearchInputTypeFactory();

  @override
  AgentSearchInput parse(Object? json) {
    return AgentSearchInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentSearchInput',
    definition: $Schema
        .object(properties: {'query': $Schema.string()}, required: ['query'])
        .value,
    dependencies: [],
  );
}

class AgentAskUserInput {
  factory AgentAskUserInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentAskUserInput._(this._json);

  AgentAskUserInput({required String question}) {
    _json = {'question': question};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<AgentAskUserInput> $schema =
      _AgentAskUserInputTypeFactory();

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

class _AgentAskUserInputTypeFactory extends SchemanticType<AgentAskUserInput> {
  const _AgentAskUserInputTypeFactory();

  @override
  AgentAskUserInput parse(Object? json) {
    return AgentAskUserInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentAskUserInput',
    definition: $Schema
        .object(
          properties: {'question': $Schema.string()},
          required: ['question'],
        )
        .value,
    dependencies: [],
  );
}
