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
    String? version,
    bool? repair,
  }) {
    _json = {
      'catalog': ?catalog,
      'instructions': ?instructions,
      'validate': ?validate,
      'version': ?version,
      'repair': ?repair,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [A2uiOptions].
  static const SchemanticType<A2uiOptions> $schema = _A2uiOptionsTypeFactory();

  /// The id of the catalog describing what the agent may render. Defaults to
  /// `'basic'` (the bundled basic catalog). Register additional catalogs with
  /// `loadCatalog(ai, id: ..., catalog: ...)` and reference them by id.
  String? get catalog {
    return _json['catalog'] as String?;
  }

  /// The id of the catalog describing what the agent may render. Defaults to
  /// `'basic'` (the bundled basic catalog). Register additional catalogs with
  /// `loadCatalog(ai, id: ..., catalog: ...)` and reference them by id.
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

  /// What to do with a block that fails to compile or validate. `'warn'`
  /// (default) logs a warning and drops the block, keeping the rest of the turn
  /// alive; `'strict'` throws (best during development); `'off'` skips the
  /// renderer-side checks (dangling references, missing `root`) and drops a
  /// block that does not compile without logging a warning.
  String? get validate {
    return _json['validate'] as String?;
  }

  /// What to do with a block that fails to compile or validate. `'warn'`
  /// (default) logs a warning and drops the block, keeping the rest of the turn
  /// alive; `'strict'` throws (best during development); `'off'` skips the
  /// renderer-side checks (dangling references, missing `root`) and drops a
  /// block that does not compile without logging a warning.
  set validate(String? value) {
    if (value == null) {
      _json.remove('validate');
    } else {
      _json['validate'] = value;
    }
  }

  /// Expected A2UI protocol version (`'1.0'` or `'v0.9'`).
  ///
  /// Optional: the catalog itself decides which version a turn emits (see
  /// `A2uiCatalog.protocolVersion`). Passing this asserts at call time that
  /// the resolved catalog targets that version.
  String? get version {
    return _json['version'] as String?;
  }

  /// Expected A2UI protocol version (`'1.0'` or `'v0.9'`).
  ///
  /// Optional: the catalog itself decides which version a turn emits (see
  /// `A2uiCatalog.protocolVersion`). Passing this asserts at call time that
  /// the resolved catalog targets that version.
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  /// Whether to ask the model to fix a block that failed to compile. Defaults
  /// to `true`.
  ///
  /// On a failure the middleware sends one small follow-up call containing the
  /// error, the Express contract, and the failed block, then compiles the
  /// reply. This costs an extra model call on the failure path only, and never
  /// runs for errors a rewrite cannot fix. Set `false` to drop bad blocks
  /// outright.
  bool? get repair {
    return _json['repair'] as bool?;
  }

  /// Whether to ask the model to fix a block that failed to compile. Defaults
  /// to `true`.
  ///
  /// On a failure the middleware sends one small follow-up call containing the
  /// error, the Express contract, and the failed block, then compiles the
  /// reply. This costs an extra model call on the failure path only, and never
  /// runs for errors a rewrite cannot fix. Set `false` to drop bad blocks
  /// outright.
  set repair(bool? value) {
    if (value == null) {
      _json.remove('repair');
    } else {
      _json['repair'] = value;
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
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'catalog': <String, Object?>{'type': 'string'},
        'instructions': <String, Object?>{'type': 'string'},
        'validate': <String, Object?>{'type': 'string'},
        'version': <String, Object?>{'type': 'string'},
        'repair': <String, Object?>{'type': 'boolean'},
      },
    },
    dependencies: [],
  );
}
