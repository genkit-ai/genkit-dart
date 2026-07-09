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

part of 'agents_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Configuration options for the [agents] middleware.
base class AgentsOptions {
  /// Creates a [AgentsOptions] from a JSON map.
  factory AgentsOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentsOptions._(this._json);

  AgentsOptions({
    required List<String> agents,
    String? toolPrefix,
    int? maxDelegations,
    int? historyLength,
    String? artifactStrategy,
  }) {
    _json = {
      'agents': agents,
      'toolPrefix': ?toolPrefix,
      'maxDelegations': ?maxDelegations,
      'historyLength': ?historyLength,
      'artifactStrategy': ?artifactStrategy,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentsOptions].
  static const SchemanticType<AgentsOptions> $schema =
      _AgentsOptionsTypeFactory();

  List<String> get agents {
    return (_json['agents'] as List).cast<String>();
  }

  set agents(List<String> value) {
    _json['agents'] = value;
  }

  String? get toolPrefix {
    return _json['toolPrefix'] as String?;
  }

  set toolPrefix(String? value) {
    if (value == null) {
      _json.remove('toolPrefix');
    } else {
      _json['toolPrefix'] = value;
    }
  }

  int? get maxDelegations {
    return _json['maxDelegations'] as int?;
  }

  set maxDelegations(int? value) {
    if (value == null) {
      _json.remove('maxDelegations');
    } else {
      _json['maxDelegations'] = value;
    }
  }

  int? get historyLength {
    return _json['historyLength'] as int?;
  }

  set historyLength(int? value) {
    if (value == null) {
      _json.remove('historyLength');
    } else {
      _json['historyLength'] = value;
    }
  }

  String? get artifactStrategy {
    return _json['artifactStrategy'] as String?;
  }

  set artifactStrategy(String? value) {
    if (value == null) {
      _json.remove('artifactStrategy');
    } else {
      _json['artifactStrategy'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentsOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentsOptionsTypeFactory extends SchemanticType<AgentsOptions> {
  const _AgentsOptionsTypeFactory();

  @override
  AgentsOptions parse(Object? json) {
    return AgentsOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentsOptions',
    definition: $Schema
        .object(
          properties: {
            'agents': $Schema.list(
              description:
                  'Names of registered agents available for delegation. Each name gets a dedicated delegation tool.',
              items: $Schema.string(),
            ),
            'toolPrefix': $Schema.string(
              description:
                  'Prefix for generated delegation tool names. Defaults to "delegate_to" (tools become delegate_to_<agent>). Set to an empty string to use bare agent names.',
            ),
            'maxDelegations': $Schema.integer(
              description:
                  'Maximum sub-agent delegations allowed per generate call. Prevents runaway delegation loops.',
            ),
            'historyLength': $Schema.integer(
              description:
                  'Number of recent conversation messages (user/model only) to forward to sub-agents as additional context. 0 or omitted means only the task description is sent.',
            ),
            'artifactStrategy': $Schema.string(
              description:
                  'How sub-agent artifacts are handled: "inline" (default) includes artifact content in the delegation tool result AND merges artifacts into the parent session; "session" merges artifacts into the parent session only (the tool result mentions names but not content).',
            ),
          },
          required: ['agents'],
        )
        .value,
    dependencies: [],
  );
}

/// Input schema for a generated delegation tool.
base class DelegateInput {
  /// Creates a [DelegateInput] from a JSON map.
  factory DelegateInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  DelegateInput._(this._json);

  DelegateInput({required String task}) {
    _json = {'task': task};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [DelegateInput].
  static const SchemanticType<DelegateInput> $schema =
      _DelegateInputTypeFactory();

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

  /// Serializes this [DelegateInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _DelegateInputTypeFactory extends SchemanticType<DelegateInput> {
  const _DelegateInputTypeFactory();

  @override
  DelegateInput parse(Object? json) {
    return DelegateInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'DelegateInput',
    definition: $Schema
        .object(
          properties: {
            'task': $Schema.string(
              description:
                  'A clear, self-contained description of the task to delegate.',
            ),
          },
          required: ['task'],
        )
        .value,
    dependencies: [],
  );
}

/// An artifact reported back by a delegation tool.
base class AgentDelegationArtifact {
  /// Creates a [AgentDelegationArtifact] from a JSON map.
  factory AgentDelegationArtifact.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentDelegationArtifact._(this._json);

  AgentDelegationArtifact({String? name, String? content}) {
    _json = {'name': ?name, 'content': ?content};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentDelegationArtifact].
  static const SchemanticType<AgentDelegationArtifact> $schema =
      _AgentDelegationArtifactTypeFactory();

  String? get name {
    return _json['name'] as String?;
  }

  set name(String? value) {
    if (value == null) {
      _json.remove('name');
    } else {
      _json['name'] = value;
    }
  }

  String? get content {
    return _json['content'] as String?;
  }

  set content(String? value) {
    if (value == null) {
      _json.remove('content');
    } else {
      _json['content'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentDelegationArtifact] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentDelegationArtifactTypeFactory
    extends SchemanticType<AgentDelegationArtifact> {
  const _AgentDelegationArtifactTypeFactory();

  @override
  AgentDelegationArtifact parse(Object? json) {
    return AgentDelegationArtifact._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentDelegationArtifact',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(description: 'Name of the artifact.'),
            'content': $Schema.string(
              description:
                  'Text content of the artifact (inline strategy only).',
            ),
          },
        )
        .value,
    dependencies: [],
  );
}

/// Output schema for a generated delegation tool.
base class AgentDelegationResult {
  /// Creates a [AgentDelegationResult] from a JSON map.
  factory AgentDelegationResult.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentDelegationResult._(this._json);

  AgentDelegationResult({
    required String response,
    List<AgentDelegationArtifact>? artifacts,
  }) {
    _json = {
      'response': response,
      'artifacts': ?artifacts?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentDelegationResult].
  static const SchemanticType<AgentDelegationResult> $schema =
      _AgentDelegationResultTypeFactory();

  String get response {
    return _json['response'] as String;
  }

  set response(String value) {
    _json['response'] = value;
  }

  List<AgentDelegationArtifact>? get artifacts {
    return (_json['artifacts'] as List?)
        ?.map(
          (e) => AgentDelegationArtifact.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  set artifacts(List<AgentDelegationArtifact>? value) {
    if (value == null) {
      _json.remove('artifacts');
    } else {
      _json['artifacts'] = value.toList();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentDelegationResult] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentDelegationResultTypeFactory
    extends SchemanticType<AgentDelegationResult> {
  const _AgentDelegationResultTypeFactory();

  @override
  AgentDelegationResult parse(Object? json) {
    return AgentDelegationResult._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentDelegationResult',
    definition: $Schema
        .object(
          properties: {
            'response': $Schema.string(
              description: 'The sub-agent\'s text response.',
            ),
            'artifacts': $Schema.list(
              description: 'Artifacts produced by the sub-agent, if any.',
              items: $Schema.fromMap({
                '\$ref': r'#/$defs/AgentDelegationArtifact',
              }),
            ),
          },
          required: ['response'],
        )
        .value,
    dependencies: [AgentDelegationArtifact.$schema],
  );
}
