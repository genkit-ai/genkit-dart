// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virtual_try_on.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class VirtualTryOnOptions {
  factory VirtualTryOnOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  VirtualTryOnOptions._(this._json);

  VirtualTryOnOptions({
    VirtualTryOnOutputOptions? outputOptions,
    int? sampleCount,
    String? storageUri,
    int? seed,
    int? baseSteps,
    String? safetySetting,
    String? personGeneration,
    bool? addWatermark,
    bool? enhancePrompt,
  }) {
    _json = {
      'outputOptions': ?outputOptions?.toJson(),
      'sampleCount': ?sampleCount,
      'storageUri': ?storageUri,
      'seed': ?seed,
      'baseSteps': ?baseSteps,
      'safetySetting': ?safetySetting,
      'personGeneration': ?personGeneration,
      'addWatermark': ?addWatermark,
      'enhancePrompt': ?enhancePrompt,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<VirtualTryOnOptions> $schema =
      _VirtualTryOnOptionsTypeFactory();

  VirtualTryOnOutputOptions? get outputOptions {
    return _json['outputOptions'] == null
        ? null
        : VirtualTryOnOutputOptions.fromJson(
            _json['outputOptions'] as Map<String, dynamic>,
          );
  }

  set outputOptions(VirtualTryOnOutputOptions? value) {
    if (value == null) {
      _json.remove('outputOptions');
    } else {
      _json['outputOptions'] = value;
    }
  }

  int? get sampleCount {
    return _json['sampleCount'] as int?;
  }

  set sampleCount(int? value) {
    if (value == null) {
      _json.remove('sampleCount');
    } else {
      _json['sampleCount'] = value;
    }
  }

  String? get storageUri {
    return _json['storageUri'] as String?;
  }

  set storageUri(String? value) {
    if (value == null) {
      _json.remove('storageUri');
    } else {
      _json['storageUri'] = value;
    }
  }

  int? get seed {
    return _json['seed'] as int?;
  }

  set seed(int? value) {
    if (value == null) {
      _json.remove('seed');
    } else {
      _json['seed'] = value;
    }
  }

  int? get baseSteps {
    return _json['baseSteps'] as int?;
  }

  set baseSteps(int? value) {
    if (value == null) {
      _json.remove('baseSteps');
    } else {
      _json['baseSteps'] = value;
    }
  }

  String? get safetySetting {
    return _json['safetySetting'] as String?;
  }

  set safetySetting(String? value) {
    if (value == null) {
      _json.remove('safetySetting');
    } else {
      _json['safetySetting'] = value;
    }
  }

  String? get personGeneration {
    return _json['personGeneration'] as String?;
  }

  set personGeneration(String? value) {
    if (value == null) {
      _json.remove('personGeneration');
    } else {
      _json['personGeneration'] = value;
    }
  }

  bool? get addWatermark {
    return _json['addWatermark'] as bool?;
  }

  set addWatermark(bool? value) {
    if (value == null) {
      _json.remove('addWatermark');
    } else {
      _json['addWatermark'] = value;
    }
  }

  bool? get enhancePrompt {
    return _json['enhancePrompt'] as bool?;
  }

  set enhancePrompt(bool? value) {
    if (value == null) {
      _json.remove('enhancePrompt');
    } else {
      _json['enhancePrompt'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _VirtualTryOnOptionsTypeFactory
    extends SchemanticType<VirtualTryOnOptions> {
  const _VirtualTryOnOptionsTypeFactory();

  @override
  VirtualTryOnOptions parse(Object? json) {
    return VirtualTryOnOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'VirtualTryOnOptions',
    definition: $Schema
        .object(
          properties: {
            'outputOptions': $Schema.fromMap({
              '\$ref': r'#/$defs/VirtualTryOnOutputOptions',
            }),
            'sampleCount': $Schema.integer(),
            'storageUri': $Schema.string(),
            'seed': $Schema.integer(),
            'baseSteps': $Schema.integer(),
            'safetySetting': $Schema.string(),
            'personGeneration': $Schema.string(),
            'addWatermark': $Schema.boolean(),
            'enhancePrompt': $Schema.boolean(),
          },
        )
        .value,
    dependencies: [VirtualTryOnOutputOptions.$schema],
  );
}

base class VirtualTryOnOutputOptions {
  factory VirtualTryOnOutputOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  VirtualTryOnOutputOptions._(this._json);

  VirtualTryOnOutputOptions({String? mimeType, int? compressionQuality}) {
    _json = {'mimeType': ?mimeType, 'compressionQuality': ?compressionQuality};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<VirtualTryOnOutputOptions> $schema =
      _VirtualTryOnOutputOptionsTypeFactory();

  String? get mimeType {
    return _json['mimeType'] as String?;
  }

  set mimeType(String? value) {
    if (value == null) {
      _json.remove('mimeType');
    } else {
      _json['mimeType'] = value;
    }
  }

  int? get compressionQuality {
    return _json['compressionQuality'] as int?;
  }

  set compressionQuality(int? value) {
    if (value == null) {
      _json.remove('compressionQuality');
    } else {
      _json['compressionQuality'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _VirtualTryOnOutputOptionsTypeFactory
    extends SchemanticType<VirtualTryOnOutputOptions> {
  const _VirtualTryOnOutputOptionsTypeFactory();

  @override
  VirtualTryOnOutputOptions parse(Object? json) {
    return VirtualTryOnOutputOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'VirtualTryOnOutputOptions',
    definition: $Schema
        .object(
          properties: {
            'mimeType': $Schema.string(),
            'compressionQuality': $Schema.integer(),
          },
        )
        .value,
    dependencies: [],
  );
}
