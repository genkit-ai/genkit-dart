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

part of 'embed.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Options for OpenAI embedding models.
///
/// `encoding_format` is deliberately absent: the only alternative to the
/// default is `base64`, which returns the vector as a string the SDK's
/// response model cannot parse, so offering it would only let a caller break
/// the call.
base class OpenAIEmbedderOptions {
  /// Creates a [OpenAIEmbedderOptions] from a JSON map.
  factory OpenAIEmbedderOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OpenAIEmbedderOptions._(this._json);

  OpenAIEmbedderOptions({int? dimensions, String? user}) {
    _json = {'dimensions': ?dimensions, 'user': ?user};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OpenAIEmbedderOptions].
  static const SchemanticType<OpenAIEmbedderOptions> $schema =
      _OpenAIEmbedderOptionsTypeFactory();

  /// Length of the returned vector.
  ///
  /// Only the `text-embedding-3-*` models accept this, and only to shorten:
  /// they are trained so that a prefix of the vector is still a usable
  /// embedding. Defaults to the model's full size.
  int? get dimensions {
    return _json['dimensions'] as int?;
  }

  /// Length of the returned vector.
  ///
  /// Only the `text-embedding-3-*` models accept this, and only to shorten:
  /// they are trained so that a prefix of the vector is still a usable
  /// embedding. Defaults to the model's full size.
  set dimensions(int? value) {
    if (value == null) {
      _json.remove('dimensions');
    } else {
      _json['dimensions'] = value;
    }
  }

  /// User identifier for abuse detection.
  String? get user {
    return _json['user'] as String?;
  }

  /// User identifier for abuse detection.
  set user(String? value) {
    if (value == null) {
      _json.remove('user');
    } else {
      _json['user'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OpenAIEmbedderOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OpenAIEmbedderOptionsTypeFactory
    extends SchemanticType<OpenAIEmbedderOptions> {
  const _OpenAIEmbedderOptionsTypeFactory();

  @override
  OpenAIEmbedderOptions parse(Object? json) {
    return OpenAIEmbedderOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OpenAIEmbedderOptions',
    definition: $Schema
        .object(
          properties: {
            'dimensions': $Schema.integer(),
            'user': $Schema.string(),
          },
        )
        .value,
    dependencies: [],
  );
}
