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

part of 'iterative_refinement.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class IterativeRefinementInput {
  factory IterativeRefinementInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  IterativeRefinementInput._(this._json);

  IterativeRefinementInput({required String topic}) {
    _json = {'topic': topic};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<IterativeRefinementInput> $schema =
      _IterativeRefinementInputTypeFactory();

  String get topic {
    return _json['topic'] as String;
  }

  set topic(String value) {
    _json['topic'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _IterativeRefinementInputTypeFactory
    extends SchemanticType<IterativeRefinementInput> {
  const _IterativeRefinementInputTypeFactory();

  @override
  IterativeRefinementInput parse(Object? json) {
    return IterativeRefinementInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
        name: 'IterativeRefinementInput',
        definition: Schema.object(
          properties: {'topic': Schema.string()},
          required: ['topic'],
        ),
        dependencies: [],
      );
}

class Evaluation {
  factory Evaluation.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Evaluation._(this._json);

  Evaluation({required String critique, required bool satisfied}) {
    _json = {'critique': critique, 'satisfied': satisfied};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Evaluation> $schema = _EvaluationTypeFactory();

  String get critique {
    return _json['critique'] as String;
  }

  set critique(String value) {
    _json['critique'] = value;
  }

  bool get satisfied {
    return _json['satisfied'] as bool;
  }

  set satisfied(bool value) {
    _json['satisfied'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _EvaluationTypeFactory extends SchemanticType<Evaluation> {
  const _EvaluationTypeFactory();

  @override
  Evaluation parse(Object? json) {
    return Evaluation._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
        name: 'Evaluation',
        definition: Schema.object(
          properties: {
            'critique': Schema.string(),
            'satisfied': Schema.boolean()
          },
          required: ['critique', 'satisfied'],
        ),
        dependencies: [],
      );
}
