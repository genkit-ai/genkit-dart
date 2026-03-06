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

part of 'types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ServerFlowInput {
  factory ServerFlowInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ServerFlowInput._(this._json);

  ServerFlowInput({required String provider, required String prompt}) {
    _json = {'provider': provider, 'prompt': prompt};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ServerFlowInput> $schema =
      _ServerFlowInputTypeFactory();

  String get provider {
    return _json['provider'] as String;
  }

  set provider(String value) {
    _json['provider'] = value;
  }

  String get prompt {
    return _json['prompt'] as String;
  }

  set prompt(String value) {
    _json['prompt'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ServerFlowInputTypeFactory extends SchemanticType<ServerFlowInput> {
  const _ServerFlowInputTypeFactory();

  @override
  ServerFlowInput parse(Object? json) {
    return ServerFlowInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ServerFlowInput',
    definition: $Schema
        .object(
          properties: {
            'provider': $Schema.string(),
            'prompt': $Schema.string(),
          },
          required: ['provider', 'prompt'],
        )
        .value,
    dependencies: [],
  );
}
