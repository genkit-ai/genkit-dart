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

part of 'custom_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ModelCallBudgetOptions {
  /// Creates a [ModelCallBudgetOptions] from a JSON map.
  factory ModelCallBudgetOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ModelCallBudgetOptions._(this._json);

  ModelCallBudgetOptions({int? maxModelCalls, String? label}) {
    _json = {'maxModelCalls': ?maxModelCalls, 'label': ?label};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ModelCallBudgetOptions].
  static const SchemanticType<ModelCallBudgetOptions> $schema =
      _ModelCallBudgetOptionsTypeFactory();

  int? get maxModelCalls {
    return (_json['maxModelCalls'] as num?)?.toInt();
  }

  set maxModelCalls(int? value) {
    if (value == null) {
      _json.remove('maxModelCalls');
    } else {
      _json['maxModelCalls'] = value;
    }
  }

  String? get label {
    return _json['label'] as String?;
  }

  set label(String? value) {
    if (value == null) {
      _json.remove('label');
    } else {
      _json['label'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ModelCallBudgetOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ModelCallBudgetOptionsTypeFactory
    extends SchemanticType<ModelCallBudgetOptions> {
  const _ModelCallBudgetOptionsTypeFactory();

  @override
  ModelCallBudgetOptions parse(Object? json) {
    return ModelCallBudgetOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelCallBudgetOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'maxModelCalls': <String, Object?>{
          'type': 'integer',
          'description': 'Maximum number of model calls per generate call.',
        },
        'label': <String, Object?>{
          'type': 'string',
          'description': 'Prefix for log lines.',
        },
      },
    },
    dependencies: [],
  );
}
