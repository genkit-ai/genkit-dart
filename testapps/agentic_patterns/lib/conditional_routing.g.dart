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

part of 'conditional_routing.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class RouterInput {
  factory RouterInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RouterInput._(this._json);

  RouterInput({required String query}) {
    _json = {'query': query};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<RouterInput> $schema = _RouterInputTypeFactory();

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

base class _RouterInputTypeFactory extends SchemanticType<RouterInput> {
  const _RouterInputTypeFactory();

  @override
  RouterInput parse(Object? json) {
    return RouterInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RouterInput',
    definition: $Schema
        .object(properties: {'query': $Schema.string()}, required: ['query'])
        .value,
    dependencies: [],
  );
}

base class IntentClassification {
  factory IntentClassification.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  IntentClassification._(this._json);

  IntentClassification({required String intent}) {
    _json = {'intent': intent};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<IntentClassification> $schema =
      _IntentClassificationTypeFactory();

  String get intent {
    return _json['intent'] as String;
  }

  set intent(String value) {
    _json['intent'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _IntentClassificationTypeFactory
    extends SchemanticType<IntentClassification> {
  const _IntentClassificationTypeFactory();

  @override
  IntentClassification parse(Object? json) {
    return IntentClassification._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'IntentClassification',
    definition: $Schema
        .object(properties: {'intent': $Schema.string()}, required: ['intent'])
        .value,
    dependencies: [],
  );
}
