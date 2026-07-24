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

part of 'a2ui_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Configuration for the [a2ui] middleware.
base class A2uiOptions {
  /// Creates a [A2uiOptions] from a JSON map.
  factory A2uiOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  A2uiOptions._(this._json);

  A2uiOptions({
    String? catalog,
    String? instructions,
    String? validate,
    String? surfaceId,
    String? version,
  }) {
    _json = {
      'catalog': ?catalog,
      'instructions': ?instructions,
      'validate': ?validate,
      'surfaceId': ?surfaceId,
      'version': ?version,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [A2uiOptions].
  static const SchemanticType<A2uiOptions> $schema = _A2uiOptionsTypeFactory();

  /// The id of the catalog describing what the agent may render. Defaults to
  /// `'basic'` (the bundled basic catalog). Register additional catalogs with
  /// `loadCatalog(registry, id: ..., catalog: ...)` and reference them by id.
  String? get catalog {
    return _json['catalog'] as String?;
  }

  /// The id of the catalog describing what the agent may render. Defaults to
  /// `'basic'` (the bundled basic catalog). Register additional catalogs with
  /// `loadCatalog(registry, id: ..., catalog: ...)` and reference them by id.
  set catalog(String? value) {
    if (value == null) {
      _json.remove('catalog');
    } else {
      _json['catalog'] = value;
    }
  }

  /// Where to inject the catalog's capabilities. `'system'` (default) appends
  /// A2UI instructions to the system prompt; `'none'` injects nothing (useful
  /// if you supply your own instructions).
  String? get instructions {
    return _json['instructions'] as String?;
  }

  /// Where to inject the catalog's capabilities. `'system'` (default) appends
  /// A2UI instructions to the system prompt; `'none'` injects nothing (useful
  /// if you supply your own instructions).
  set instructions(String? value) {
    if (value == null) {
      _json.remove('instructions');
    } else {
      _json['instructions'] = value;
    }
  }

  /// Validate emitted envelopes against the catalog. `'warn'` (default) logs a
  /// warning and drops the offending block/envelope, keeping the rest of the
  /// turn alive; `'strict'` throws on malformed JSON or unknown components
  /// (best during development); `'off'` passes them through unchecked.
  String? get validate {
    return _json['validate'] as String?;
  }

  /// Validate emitted envelopes against the catalog. `'warn'` (default) logs a
  /// warning and drops the offending block/envelope, keeping the rest of the
  /// turn alive; `'strict'` throws on malformed JSON or unknown components
  /// (best during development); `'off'` passes them through unchecked.
  set validate(String? value) {
    if (value == null) {
      _json.remove('validate');
    } else {
      _json['validate'] = value;
    }
  }

  /// Surface id policy. Provide a fixed id to reuse for every surface. Defaults
  /// to a fresh UUID per surface.
  String? get surfaceId {
    return _json['surfaceId'] as String?;
  }

  /// Surface id policy. Provide a fixed id to reuse for every surface. Defaults
  /// to a fresh UUID per surface.
  set surfaceId(String? value) {
    if (value == null) {
      _json.remove('surfaceId');
    } else {
      _json['surfaceId'] = value;
    }
  }

  /// Protocol version stamped on emitted envelopes. Defaults to `'v0.9'`.
  String? get version {
    return _json['version'] as String?;
  }

  /// Protocol version stamped on emitted envelopes. Defaults to `'v0.9'`.
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [A2uiOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _A2uiOptionsTypeFactory extends SchemanticType<A2uiOptions> {
  const _A2uiOptionsTypeFactory();

  @override
  A2uiOptions parse(Object? json) {
    return A2uiOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'A2uiOptions',
    definition: $Schema
        .object(
          properties: {
            'catalog': $Schema.string(),
            'instructions': $Schema.string(),
            'validate': $Schema.string(),
            'surfaceId': $Schema.string(),
            'version': $Schema.string(),
          },
        )
        .value,
    dependencies: [],
  );
}
