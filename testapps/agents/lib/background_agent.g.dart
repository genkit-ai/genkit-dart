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

part of 'background_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ResearchSectionInput {
  /// Creates a [ResearchSectionInput] from a JSON map.
  factory ResearchSectionInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResearchSectionInput._(this._json);

  ResearchSectionInput({required String section}) {
    _json = {'section': section};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ResearchSectionInput].
  static const SchemanticType<ResearchSectionInput> $schema =
      _ResearchSectionInputTypeFactory();

  String get section {
    return _json['section'] as String;
  }

  set section(String value) {
    _json['section'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ResearchSectionInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ResearchSectionInputTypeFactory
    extends SchemanticType<ResearchSectionInput> {
  const _ResearchSectionInputTypeFactory();

  @override
  ResearchSectionInput parse(Object? json) {
    return ResearchSectionInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResearchSectionInput',
    definition: $Schema
        .object(
          properties: {
            'section': $Schema.string(
              description:
                  'The section of the report to research (e.g. "Executive Summary").',
            ),
          },
          required: ['section'],
        )
        .value,
    dependencies: [],
  );
}
