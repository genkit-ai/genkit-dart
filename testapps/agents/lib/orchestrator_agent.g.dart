// Copyright 2026 Google LLC
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

part of 'orchestrator_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

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
              description: 'The task or question to hand to the sub-agent.',
            ),
          },
          required: ['task'],
        )
        .value,
    dependencies: [],
  );
}
