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
    bool? repair,
  }) {
    _json = {
      'catalog': ?catalog,
      'instructions': ?instructions,
      'validate': ?validate,
      'surfaceId': ?surfaceId,
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

  /// Whether to ask the model to fix a block that failed to compile. Defaults
  /// to `true`.
  ///
  /// On a failure the middleware sends one small follow-up call containing the
  /// error, the relevant signatures, and the failed block, then compiles the
  /// reply. This costs an extra model call on the failure path only, and never
  /// runs for errors a rewrite cannot fix (an unknown component, say). Set
  /// `false` to disable it and drop bad blocks outright.
  bool? get repair {
    return _json['repair'] as bool?;
  }

  /// Whether to ask the model to fix a block that failed to compile. Defaults
  /// to `true`.
  ///
  /// On a failure the middleware sends one small follow-up call containing the
  /// error, the relevant signatures, and the failed block, then compiles the
  /// reply. This costs an extra model call on the failure path only, and never
  /// runs for errors a rewrite cannot fix (an unknown component, say). Set
  /// `false` to disable it and drop bad blocks outright.
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
    definition: $Schema
        .object(
          properties: {
            'catalog': $Schema.string(),
            'instructions': $Schema.string(),
            'validate': $Schema.string(),
            'surfaceId': $Schema.string(),
            'version': $Schema.string(),
            'repair': $Schema.boolean(),
          },
        )
        .value,
    dependencies: [],
  );
}
