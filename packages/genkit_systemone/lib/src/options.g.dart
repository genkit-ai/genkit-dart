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

part of 'options.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// The per-request configuration of a decision model.
///
/// Preview: this API may change in any minor release.
base class SystemOneOptions {
  /// Creates a [SystemOneOptions] from a JSON map.
  factory SystemOneOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SystemOneOptions._(this._json);

  SystemOneOptions({bool? stateJSON, Map<String, dynamic>? extra}) {
    _json = {'stateJSON': ?stateJSON, 'extra': ?extra};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [SystemOneOptions].
  static const SchemanticType<SystemOneOptions> $schema =
      _SystemOneOptionsTypeFactory();

  /// Parses each text part of the state as JSON, so a prompt template that
  /// renders a JSON document produces an object state rather than a string
  /// one. A text that is not JSON is an error. A fallback to another model
  /// takes that model's config, so set it there too, or send the state as a
  /// data part, which needs no parsing.
  bool? get stateJSON {
    return _json['stateJSON'] as bool?;
  }

  /// Parses each text part of the state as JSON, so a prompt template that
  /// renders a JSON document produces an object state rather than a string
  /// one. A text that is not JSON is an error. A fallback to another model
  /// takes that model's config, so set it there too, or send the state as a
  /// data part, which needs no parsing.
  set stateJSON(bool? value) {
    if (value == null) {
      _json.remove('stateJSON');
    } else {
      _json['stateJSON'] = value;
    }
  }

  /// Merged into the top-level fields of the request body. It reaches fields
  /// this package does not model, such as a gateway's `session_id` or
  /// `trace`. It cannot name a field the request builds itself: model, state,
  /// questions, images, audio, or videos.
  Map<String, dynamic>? get extra {
    return (_json['extra'] as Map?)?.cast<String, dynamic>();
  }

  /// Merged into the top-level fields of the request body. It reaches fields
  /// this package does not model, such as a gateway's `session_id` or
  /// `trace`. It cannot name a field the request builds itself: model, state,
  /// questions, images, audio, or videos.
  set extra(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('extra');
    } else {
      _json['extra'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [SystemOneOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _SystemOneOptionsTypeFactory
    extends SchemanticType<SystemOneOptions> {
  const _SystemOneOptionsTypeFactory();

  @override
  SystemOneOptions parse(Object? json) {
    return SystemOneOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SystemOneOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'stateJSON': <String, Object?>{
          'type': 'boolean',
          'description':
              'Parse each text part of the state as JSON, so a template that renders JSON produces an object state.',
        },
        'extra': <String, Object?>{
          'type': 'object',
          'description':
              'Extra top-level request fields, such as a gateway\'s session_id. Cannot replace model, state, questions, images, audio, or videos.',
          'additionalProperties': <String, Object?>{},
        },
      },
    },
    dependencies: [],
  );
}
