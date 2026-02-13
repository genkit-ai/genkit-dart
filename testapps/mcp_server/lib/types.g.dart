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

class PromptInput {
  factory PromptInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  PromptInput._(this._json);

  PromptInput({required String input}) {
    _json = {'input': input};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<PromptInput> $schema = _PromptInputTypeFactory();

  String get input {
    return _json['input'] as String;
  }

  set input(String value) {
    _json['input'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _PromptInputTypeFactory extends SchemanticType<PromptInput> {
  const _PromptInputTypeFactory();

  @override
  PromptInput parse(Object? json) {
    return PromptInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PromptInput',
    definition: Schema.object(
      properties: {'input': Schema.string()},
      required: ['input'],
    ),
    dependencies: [],
  );
}
