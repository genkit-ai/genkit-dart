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

part of 'genkit_firebase_ai.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class GeminiOptions {
  /// Creates a [GeminiOptions] from a JSON map.
  factory GeminiOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiOptions._(this._json);

  GeminiOptions({
    List<String>? stopSequences,
    int? maxOutputTokens,
    double? temperature,
    double? topP,
    int? topK,
    double? presencePenalty,
    double? frequencyPenalty,
    List<String>? responseModalities,
    String? responseMimeType,
    Map<String, dynamic>? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    ThinkingConfig? thinkingConfig,
    int? candidateCount,
    bool? codeExecution,
    FunctionCallingConfig? functionCallingConfig,
    List<GeminiSafetySettings>? safetySettings,
    GeminiGoogleSearch? googleSearch,
    GeminiUrlContext? urlContext,
    GeminiGoogleMaps? googleMaps,
    GeminiRetrievalConfig? retrievalConfig,
  }) {
    _json = {
      'stopSequences': ?stopSequences,
      'maxOutputTokens': ?maxOutputTokens,
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'presencePenalty': ?presencePenalty,
      'frequencyPenalty': ?frequencyPenalty,
      'responseModalities': ?responseModalities,
      'responseMimeType': ?responseMimeType,
      'responseSchema': ?responseSchema,
      'responseJsonSchema': ?responseJsonSchema,
      'thinkingConfig': ?thinkingConfig?.toJson(),
      'candidateCount': ?candidateCount,
      'codeExecution': ?codeExecution,
      'functionCallingConfig': ?functionCallingConfig?.toJson(),
      'safetySettings': ?safetySettings?.map((e) => e.toJson()).toList(),
      'googleSearch': ?googleSearch?.toJson(),
      'urlContext': ?urlContext?.toJson(),
      'googleMaps': ?googleMaps?.toJson(),
      'retrievalConfig': ?retrievalConfig?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiOptions].
  static const SchemanticType<GeminiOptions> $schema =
      _GeminiOptionsTypeFactory();

  List<String>? get stopSequences {
    return (_json['stopSequences'] as List?)?.cast<String>();
  }

  set stopSequences(List<String>? value) {
    if (value == null) {
      _json.remove('stopSequences');
    } else {
      _json['stopSequences'] = value;
    }
  }

  int? get maxOutputTokens {
    return (_json['maxOutputTokens'] as num?)?.toInt();
  }

  set maxOutputTokens(int? value) {
    if (value == null) {
      _json.remove('maxOutputTokens');
    } else {
      _json['maxOutputTokens'] = value;
    }
  }

  double? get temperature {
    return (_json['temperature'] as num?)?.toDouble();
  }

  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  double? get topP {
    return (_json['topP'] as num?)?.toDouble();
  }

  set topP(double? value) {
    if (value == null) {
      _json.remove('topP');
    } else {
      _json['topP'] = value;
    }
  }

  int? get topK {
    return (_json['topK'] as num?)?.toInt();
  }

  set topK(int? value) {
    if (value == null) {
      _json.remove('topK');
    } else {
      _json['topK'] = value;
    }
  }

  double? get presencePenalty {
    return (_json['presencePenalty'] as num?)?.toDouble();
  }

  set presencePenalty(double? value) {
    if (value == null) {
      _json.remove('presencePenalty');
    } else {
      _json['presencePenalty'] = value;
    }
  }

  double? get frequencyPenalty {
    return (_json['frequencyPenalty'] as num?)?.toDouble();
  }

  set frequencyPenalty(double? value) {
    if (value == null) {
      _json.remove('frequencyPenalty');
    } else {
      _json['frequencyPenalty'] = value;
    }
  }

  List<String>? get responseModalities {
    return (_json['responseModalities'] as List?)?.cast<String>();
  }

  set responseModalities(List<String>? value) {
    if (value == null) {
      _json.remove('responseModalities');
    } else {
      _json['responseModalities'] = value;
    }
  }

  String? get responseMimeType {
    return _json['responseMimeType'] as String?;
  }

  set responseMimeType(String? value) {
    if (value == null) {
      _json.remove('responseMimeType');
    } else {
      _json['responseMimeType'] = value;
    }
  }

  Map<String, dynamic>? get responseSchema {
    return (_json['responseSchema'] as Map?)?.cast<String, dynamic>();
  }

  set responseSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('responseSchema');
    } else {
      _json['responseSchema'] = value;
    }
  }

  Map<String, dynamic>? get responseJsonSchema {
    return (_json['responseJsonSchema'] as Map?)?.cast<String, dynamic>();
  }

  set responseJsonSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('responseJsonSchema');
    } else {
      _json['responseJsonSchema'] = value;
    }
  }

  ThinkingConfig? get thinkingConfig {
    return _json['thinkingConfig'] == null
        ? null
        : ThinkingConfig.fromJson(
            _json['thinkingConfig'] as Map<String, dynamic>,
          );
  }

  set thinkingConfig(ThinkingConfig? value) {
    if (value == null) {
      _json.remove('thinkingConfig');
    } else {
      _json['thinkingConfig'] = value.toJson();
    }
  }

  int? get candidateCount {
    return (_json['candidateCount'] as num?)?.toInt();
  }

  set candidateCount(int? value) {
    if (value == null) {
      _json.remove('candidateCount');
    } else {
      _json['candidateCount'] = value;
    }
  }

  bool? get codeExecution {
    return _json['codeExecution'] as bool?;
  }

  set codeExecution(bool? value) {
    if (value == null) {
      _json.remove('codeExecution');
    } else {
      _json['codeExecution'] = value;
    }
  }

  FunctionCallingConfig? get functionCallingConfig {
    return _json['functionCallingConfig'] == null
        ? null
        : FunctionCallingConfig.fromJson(
            _json['functionCallingConfig'] as Map<String, dynamic>,
          );
  }

  set functionCallingConfig(FunctionCallingConfig? value) {
    if (value == null) {
      _json.remove('functionCallingConfig');
    } else {
      _json['functionCallingConfig'] = value.toJson();
    }
  }

  List<GeminiSafetySettings>? get safetySettings {
    return (_json['safetySettings'] as List?)
        ?.map((e) => GeminiSafetySettings.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set safetySettings(List<GeminiSafetySettings>? value) {
    if (value == null) {
      _json.remove('safetySettings');
    } else {
      _json['safetySettings'] = value.map((e) => e.toJson()).toList();
    }
  }

  GeminiGoogleSearch? get googleSearch {
    return _json['googleSearch'] == null
        ? null
        : GeminiGoogleSearch.fromJson(
            _json['googleSearch'] as Map<String, dynamic>,
          );
  }

  set googleSearch(GeminiGoogleSearch? value) {
    if (value == null) {
      _json.remove('googleSearch');
    } else {
      _json['googleSearch'] = value.toJson();
    }
  }

  GeminiUrlContext? get urlContext {
    return _json['urlContext'] == null
        ? null
        : GeminiUrlContext.fromJson(
            _json['urlContext'] as Map<String, dynamic>,
          );
  }

  set urlContext(GeminiUrlContext? value) {
    if (value == null) {
      _json.remove('urlContext');
    } else {
      _json['urlContext'] = value.toJson();
    }
  }

  GeminiGoogleMaps? get googleMaps {
    return _json['googleMaps'] == null
        ? null
        : GeminiGoogleMaps.fromJson(
            _json['googleMaps'] as Map<String, dynamic>,
          );
  }

  set googleMaps(GeminiGoogleMaps? value) {
    if (value == null) {
      _json.remove('googleMaps');
    } else {
      _json['googleMaps'] = value.toJson();
    }
  }

  GeminiRetrievalConfig? get retrievalConfig {
    return _json['retrievalConfig'] == null
        ? null
        : GeminiRetrievalConfig.fromJson(
            _json['retrievalConfig'] as Map<String, dynamic>,
          );
  }

  set retrievalConfig(GeminiRetrievalConfig? value) {
    if (value == null) {
      _json.remove('retrievalConfig');
    } else {
      _json['retrievalConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiOptionsTypeFactory extends SchemanticType<GeminiOptions> {
  const _GeminiOptionsTypeFactory();

  @override
  GeminiOptions parse(Object? json) {
    return GeminiOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'stopSequences': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'maxOutputTokens': <String, Object?>{'type': 'integer'},
        'temperature': <String, Object?>{'type': 'number'},
        'topP': <String, Object?>{'type': 'number'},
        'topK': <String, Object?>{'type': 'integer'},
        'presencePenalty': <String, Object?>{'type': 'number'},
        'frequencyPenalty': <String, Object?>{'type': 'number'},
        'responseModalities': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'responseMimeType': <String, Object?>{'type': 'string'},
        'responseSchema': <String, Object?>{
          'type': 'object',
          'description':
              'OpenAPI-subset schema the response must conform to. Ignored when responseJsonSchema is set or the request has a constrained JSON output schema.',
          'additionalProperties': <String, Object?>{},
        },
        'responseJsonSchema': <String, Object?>{
          'type': 'object',
          'description':
              'JSON Schema the response must conform to, sent to Gemini unchanged. Requires responseMimeType "application/json". Takes precedence over responseSchema when both are set. Ignored when the request has a constrained JSON output schema, which is sent instead.',
          'additionalProperties': <String, Object?>{},
        },
        'thinkingConfig': <String, Object?>{r'$ref': r'#/$defs/ThinkingConfig'},
        'candidateCount': <String, Object?>{'type': 'integer'},
        'codeExecution': <String, Object?>{'type': 'boolean'},
        'functionCallingConfig': <String, Object?>{
          r'$ref': r'#/$defs/FunctionCallingConfig',
        },
        'safetySettings': <String, Object?>{
          'type': 'array',
          'description':
              'Per-category thresholds for blocking harmful content. Each entry needs a category and a threshold.',
          'items': <String, Object?>{r'$ref': r'#/$defs/GeminiSafetySettings'},
        },
        'googleSearch': <String, Object?>{
          'description': 'Grounds responses in Google Search results.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiGoogleSearch'},
          ],
        },
        'urlContext': <String, Object?>{
          'description': 'Lets the model read the URLs given in the prompt.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiUrlContext'},
          ],
        },
        'googleMaps': <String, Object?>{
          'description':
              'Grounds responses in Google Maps data. Pass the user location in retrievalConfig.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiGoogleMaps'},
          ],
        },
        'retrievalConfig': <String, Object?>{
          'description': 'Location and language for Google Maps grounding.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiRetrievalConfig'},
          ],
        },
      },
    },
    dependencies: [
      ThinkingConfig.$schema,
      FunctionCallingConfig.$schema,
      GeminiSafetySettings.$schema,
      GeminiGoogleSearch.$schema,
      GeminiUrlContext.$schema,
      GeminiGoogleMaps.$schema,
      GeminiRetrievalConfig.$schema,
    ],
  );
}

base class GeminiGoogleSearch {
  /// Creates a [GeminiGoogleSearch] from a JSON map.
  factory GeminiGoogleSearch.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiGoogleSearch._(this._json);

  GeminiGoogleSearch() {
    _json = {};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiGoogleSearch].
  static const SchemanticType<GeminiGoogleSearch> $schema =
      _GeminiGoogleSearchTypeFactory();

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiGoogleSearch] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiGoogleSearchTypeFactory
    extends SchemanticType<GeminiGoogleSearch> {
  const _GeminiGoogleSearchTypeFactory();

  @override
  GeminiGoogleSearch parse(Object? json) {
    return GeminiGoogleSearch._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiGoogleSearch',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
    },
    dependencies: [],
  );
}

base class GeminiUrlContext {
  /// Creates a [GeminiUrlContext] from a JSON map.
  factory GeminiUrlContext.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiUrlContext._(this._json);

  GeminiUrlContext() {
    _json = {};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiUrlContext].
  static const SchemanticType<GeminiUrlContext> $schema =
      _GeminiUrlContextTypeFactory();

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiUrlContext] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiUrlContextTypeFactory
    extends SchemanticType<GeminiUrlContext> {
  const _GeminiUrlContextTypeFactory();

  @override
  GeminiUrlContext parse(Object? json) {
    return GeminiUrlContext._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiUrlContext',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
    },
    dependencies: [],
  );
}

base class GeminiGoogleMaps {
  /// Creates a [GeminiGoogleMaps] from a JSON map.
  factory GeminiGoogleMaps.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiGoogleMaps._(this._json);

  GeminiGoogleMaps() {
    _json = {};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiGoogleMaps].
  static const SchemanticType<GeminiGoogleMaps> $schema =
      _GeminiGoogleMapsTypeFactory();

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiGoogleMaps] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiGoogleMapsTypeFactory
    extends SchemanticType<GeminiGoogleMaps> {
  const _GeminiGoogleMapsTypeFactory();

  @override
  GeminiGoogleMaps parse(Object? json) {
    return GeminiGoogleMaps._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiGoogleMaps',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
    },
    dependencies: [],
  );
}

base class GeminiRetrievalConfig {
  /// Creates a [GeminiRetrievalConfig] from a JSON map.
  factory GeminiRetrievalConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiRetrievalConfig._(this._json);

  GeminiRetrievalConfig({GeminiLatLng? latLng, String? languageCode}) {
    _json = {'latLng': ?latLng?.toJson(), 'languageCode': ?languageCode};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiRetrievalConfig].
  static const SchemanticType<GeminiRetrievalConfig> $schema =
      _GeminiRetrievalConfigTypeFactory();

  GeminiLatLng? get latLng {
    return _json['latLng'] == null
        ? null
        : GeminiLatLng.fromJson(_json['latLng'] as Map<String, dynamic>);
  }

  set latLng(GeminiLatLng? value) {
    if (value == null) {
      _json.remove('latLng');
    } else {
      _json['latLng'] = value.toJson();
    }
  }

  String? get languageCode {
    return _json['languageCode'] as String?;
  }

  set languageCode(String? value) {
    if (value == null) {
      _json.remove('languageCode');
    } else {
      _json['languageCode'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiRetrievalConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiRetrievalConfigTypeFactory
    extends SchemanticType<GeminiRetrievalConfig> {
  const _GeminiRetrievalConfigTypeFactory();

  @override
  GeminiRetrievalConfig parse(Object? json) {
    return GeminiRetrievalConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiRetrievalConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'latLng': <String, Object?>{r'$ref': r'#/$defs/GeminiLatLng'},
        'languageCode': <String, Object?>{'type': 'string'},
      },
    },
    dependencies: [GeminiLatLng.$schema],
  );
}

base class GeminiLatLng {
  /// Creates a [GeminiLatLng] from a JSON map.
  factory GeminiLatLng.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiLatLng._(this._json);

  GeminiLatLng({double? latitude, double? longitude}) {
    _json = {'latitude': ?latitude, 'longitude': ?longitude};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiLatLng].
  static const SchemanticType<GeminiLatLng> $schema =
      _GeminiLatLngTypeFactory();

  double? get latitude {
    return (_json['latitude'] as num?)?.toDouble();
  }

  set latitude(double? value) {
    if (value == null) {
      _json.remove('latitude');
    } else {
      _json['latitude'] = value;
    }
  }

  double? get longitude {
    return (_json['longitude'] as num?)?.toDouble();
  }

  set longitude(double? value) {
    if (value == null) {
      _json.remove('longitude');
    } else {
      _json['longitude'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiLatLng] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiLatLngTypeFactory extends SchemanticType<GeminiLatLng> {
  const _GeminiLatLngTypeFactory();

  @override
  GeminiLatLng parse(Object? json) {
    return GeminiLatLng._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiLatLng',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'latitude': <String, Object?>{'type': 'number'},
        'longitude': <String, Object?>{'type': 'number'},
      },
    },
    dependencies: [],
  );
}

base class GeminiSafetySettings {
  /// Creates a [GeminiSafetySettings] from a JSON map.
  factory GeminiSafetySettings.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiSafetySettings._(this._json);

  GeminiSafetySettings({String? category, String? threshold, String? method}) {
    _json = {'category': ?category, 'threshold': ?threshold, 'method': ?method};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiSafetySettings].
  static const SchemanticType<GeminiSafetySettings> $schema =
      _GeminiSafetySettingsTypeFactory();

  String? get category {
    return _json['category'] as String?;
  }

  set category(String? value) {
    if (value == null) {
      _json.remove('category');
    } else {
      _json['category'] = value;
    }
  }

  String? get threshold {
    return _json['threshold'] as String?;
  }

  set threshold(String? value) {
    if (value == null) {
      _json.remove('threshold');
    } else {
      _json['threshold'] = value;
    }
  }

  String? get method {
    return _json['method'] as String?;
  }

  set method(String? value) {
    if (value == null) {
      _json.remove('method');
    } else {
      _json['method'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiSafetySettings] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiSafetySettingsTypeFactory
    extends SchemanticType<GeminiSafetySettings> {
  const _GeminiSafetySettingsTypeFactory();

  @override
  GeminiSafetySettings parse(Object? json) {
    return GeminiSafetySettings._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiSafetySettings',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'category': <String, Object?>{
          'type': 'string',
          'description':
              'The HARM_CATEGORY_IMAGE_* categories are Agent Platform only; the Gemini Developer API rejects them.',
          'enum': [
            'HARM_CATEGORY_HARASSMENT',
            'HARM_CATEGORY_HATE_SPEECH',
            'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'HARM_CATEGORY_DANGEROUS_CONTENT',
            'HARM_CATEGORY_IMAGE_HATE',
            'HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT',
            'HARM_CATEGORY_IMAGE_HARASSMENT',
            'HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT',
          ],
        },
        'threshold': <String, Object?>{
          'type': 'string',
          'enum': [
            'BLOCK_LOW_AND_ABOVE',
            'BLOCK_MEDIUM_AND_ABOVE',
            'BLOCK_ONLY_HIGH',
            'BLOCK_NONE',
            'OFF',
          ],
        },
        'method': <String, Object?>{
          'type': 'string',
          'description':
              'Whether the threshold applies to the probability or the severity score. Agent Platform only; the Gemini Developer API rejects it.',
          'enum': ['SEVERITY', 'PROBABILITY'],
        },
      },
    },
    dependencies: [],
  );
}

base class FunctionCallingConfig {
  /// Creates a [FunctionCallingConfig] from a JSON map.
  factory FunctionCallingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  FunctionCallingConfig._(this._json);

  FunctionCallingConfig({String? mode, List<String>? allowedFunctionNames}) {
    _json = {'mode': ?mode, 'allowedFunctionNames': ?allowedFunctionNames};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [FunctionCallingConfig].
  static const SchemanticType<FunctionCallingConfig> $schema =
      _FunctionCallingConfigTypeFactory();

  String? get mode {
    return _json['mode'] as String?;
  }

  set mode(String? value) {
    if (value == null) {
      _json.remove('mode');
    } else {
      _json['mode'] = value;
    }
  }

  List<String>? get allowedFunctionNames {
    return (_json['allowedFunctionNames'] as List?)?.cast<String>();
  }

  set allowedFunctionNames(List<String>? value) {
    if (value == null) {
      _json.remove('allowedFunctionNames');
    } else {
      _json['allowedFunctionNames'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [FunctionCallingConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _FunctionCallingConfigTypeFactory
    extends SchemanticType<FunctionCallingConfig> {
  const _FunctionCallingConfigTypeFactory();

  @override
  FunctionCallingConfig parse(Object? json) {
    return FunctionCallingConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'FunctionCallingConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'mode': <String, Object?>{
          'type': 'string',
          'enum': ['MODE_UNSPECIFIED', 'AUTO', 'ANY', 'NONE'],
        },
        'allowedFunctionNames': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
      },
    },
    dependencies: [],
  );
}

base class ThinkingConfig {
  /// Creates a [ThinkingConfig] from a JSON map.
  factory ThinkingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ThinkingConfig._(this._json);

  ThinkingConfig({
    int? thinkingBudget,
    bool? includeThoughts,
    String? thinkingLevel,
  }) {
    _json = {
      'thinkingBudget': ?thinkingBudget,
      'includeThoughts': ?includeThoughts,
      'thinkingLevel': ?thinkingLevel,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ThinkingConfig].
  static const SchemanticType<ThinkingConfig> $schema =
      _ThinkingConfigTypeFactory();

  int? get thinkingBudget {
    return (_json['thinkingBudget'] as num?)?.toInt();
  }

  set thinkingBudget(int? value) {
    if (value == null) {
      _json.remove('thinkingBudget');
    } else {
      _json['thinkingBudget'] = value;
    }
  }

  bool? get includeThoughts {
    return _json['includeThoughts'] as bool?;
  }

  set includeThoughts(bool? value) {
    if (value == null) {
      _json.remove('includeThoughts');
    } else {
      _json['includeThoughts'] = value;
    }
  }

  String? get thinkingLevel {
    return _json['thinkingLevel'] as String?;
  }

  set thinkingLevel(String? value) {
    if (value == null) {
      _json.remove('thinkingLevel');
    } else {
      _json['thinkingLevel'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ThinkingConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ThinkingConfigTypeFactory extends SchemanticType<ThinkingConfig> {
  const _ThinkingConfigTypeFactory();

  @override
  ThinkingConfig parse(Object? json) {
    return ThinkingConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ThinkingConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'thinkingBudget': <String, Object?>{'type': 'integer'},
        'includeThoughts': <String, Object?>{'type': 'boolean'},
        'thinkingLevel': <String, Object?>{
          'type': 'string',
          'description':
              'Thinking level for Gemini 3 and newer models, which use it in place of thinkingBudget. Cannot be set together with thinkingBudget.',
          'enum': ['MINIMAL', 'LOW', 'MEDIUM', 'HIGH'],
        },
      },
    },
    dependencies: [],
  );
}

base class PrebuiltVoiceConfig {
  /// Creates a [PrebuiltVoiceConfig] from a JSON map.
  factory PrebuiltVoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  PrebuiltVoiceConfig._(this._json);

  PrebuiltVoiceConfig({String? voiceName}) {
    _json = {'voiceName': ?voiceName};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [PrebuiltVoiceConfig].
  static const SchemanticType<PrebuiltVoiceConfig> $schema =
      _PrebuiltVoiceConfigTypeFactory();

  String? get voiceName {
    return _json['voiceName'] as String?;
  }

  set voiceName(String? value) {
    if (value == null) {
      _json.remove('voiceName');
    } else {
      _json['voiceName'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [PrebuiltVoiceConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _PrebuiltVoiceConfigTypeFactory
    extends SchemanticType<PrebuiltVoiceConfig> {
  const _PrebuiltVoiceConfigTypeFactory();

  @override
  PrebuiltVoiceConfig parse(Object? json) {
    return PrebuiltVoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PrebuiltVoiceConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'voiceName': <String, Object?>{'type': 'string'},
      },
    },
    dependencies: [],
  );
}

base class VoiceConfig {
  /// Creates a [VoiceConfig] from a JSON map.
  factory VoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  VoiceConfig._(this._json);

  VoiceConfig({PrebuiltVoiceConfig? prebuiltVoiceConfig}) {
    _json = {'prebuiltVoiceConfig': ?prebuiltVoiceConfig?.toJson()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [VoiceConfig].
  static const SchemanticType<VoiceConfig> $schema = _VoiceConfigTypeFactory();

  PrebuiltVoiceConfig? get prebuiltVoiceConfig {
    return _json['prebuiltVoiceConfig'] == null
        ? null
        : PrebuiltVoiceConfig.fromJson(
            _json['prebuiltVoiceConfig'] as Map<String, dynamic>,
          );
  }

  set prebuiltVoiceConfig(PrebuiltVoiceConfig? value) {
    if (value == null) {
      _json.remove('prebuiltVoiceConfig');
    } else {
      _json['prebuiltVoiceConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [VoiceConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _VoiceConfigTypeFactory extends SchemanticType<VoiceConfig> {
  const _VoiceConfigTypeFactory();

  @override
  VoiceConfig parse(Object? json) {
    return VoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'VoiceConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'prebuiltVoiceConfig': <String, Object?>{
          r'$ref': r'#/$defs/PrebuiltVoiceConfig',
        },
      },
    },
    dependencies: [PrebuiltVoiceConfig.$schema],
  );
}

base class SpeechConfig {
  /// Creates a [SpeechConfig] from a JSON map.
  factory SpeechConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SpeechConfig._(this._json);

  SpeechConfig({VoiceConfig? voiceConfig}) {
    _json = {'voiceConfig': ?voiceConfig?.toJson()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [SpeechConfig].
  static const SchemanticType<SpeechConfig> $schema =
      _SpeechConfigTypeFactory();

  VoiceConfig? get voiceConfig {
    return _json['voiceConfig'] == null
        ? null
        : VoiceConfig.fromJson(_json['voiceConfig'] as Map<String, dynamic>);
  }

  set voiceConfig(VoiceConfig? value) {
    if (value == null) {
      _json.remove('voiceConfig');
    } else {
      _json['voiceConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [SpeechConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _SpeechConfigTypeFactory extends SchemanticType<SpeechConfig> {
  const _SpeechConfigTypeFactory();

  @override
  SpeechConfig parse(Object? json) {
    return SpeechConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SpeechConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'voiceConfig': <String, Object?>{r'$ref': r'#/$defs/VoiceConfig'},
      },
    },
    dependencies: [VoiceConfig.$schema],
  );
}

base class LiveGenerationConfig {
  /// Creates a [LiveGenerationConfig] from a JSON map.
  factory LiveGenerationConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  LiveGenerationConfig._(this._json);

  LiveGenerationConfig({
    List<String>? responseModalities,
    SpeechConfig? speechConfig,
    List<String>? stopSequences,
    int? maxOutputTokens,
    double? temperature,
    double? topP,
    int? topK,
    double? presencePenalty,
    double? frequencyPenalty,
  }) {
    _json = {
      'responseModalities': ?responseModalities,
      'speechConfig': ?speechConfig?.toJson(),
      'stopSequences': ?stopSequences,
      'maxOutputTokens': ?maxOutputTokens,
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'presencePenalty': ?presencePenalty,
      'frequencyPenalty': ?frequencyPenalty,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [LiveGenerationConfig].
  static const SchemanticType<LiveGenerationConfig> $schema =
      _LiveGenerationConfigTypeFactory();

  List<String>? get responseModalities {
    return (_json['responseModalities'] as List?)?.cast<String>();
  }

  set responseModalities(List<String>? value) {
    if (value == null) {
      _json.remove('responseModalities');
    } else {
      _json['responseModalities'] = value;
    }
  }

  SpeechConfig? get speechConfig {
    return _json['speechConfig'] == null
        ? null
        : SpeechConfig.fromJson(_json['speechConfig'] as Map<String, dynamic>);
  }

  set speechConfig(SpeechConfig? value) {
    if (value == null) {
      _json.remove('speechConfig');
    } else {
      _json['speechConfig'] = value.toJson();
    }
  }

  List<String>? get stopSequences {
    return (_json['stopSequences'] as List?)?.cast<String>();
  }

  set stopSequences(List<String>? value) {
    if (value == null) {
      _json.remove('stopSequences');
    } else {
      _json['stopSequences'] = value;
    }
  }

  int? get maxOutputTokens {
    return (_json['maxOutputTokens'] as num?)?.toInt();
  }

  set maxOutputTokens(int? value) {
    if (value == null) {
      _json.remove('maxOutputTokens');
    } else {
      _json['maxOutputTokens'] = value;
    }
  }

  double? get temperature {
    return (_json['temperature'] as num?)?.toDouble();
  }

  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  double? get topP {
    return (_json['topP'] as num?)?.toDouble();
  }

  set topP(double? value) {
    if (value == null) {
      _json.remove('topP');
    } else {
      _json['topP'] = value;
    }
  }

  int? get topK {
    return (_json['topK'] as num?)?.toInt();
  }

  set topK(int? value) {
    if (value == null) {
      _json.remove('topK');
    } else {
      _json['topK'] = value;
    }
  }

  double? get presencePenalty {
    return (_json['presencePenalty'] as num?)?.toDouble();
  }

  set presencePenalty(double? value) {
    if (value == null) {
      _json.remove('presencePenalty');
    } else {
      _json['presencePenalty'] = value;
    }
  }

  double? get frequencyPenalty {
    return (_json['frequencyPenalty'] as num?)?.toDouble();
  }

  set frequencyPenalty(double? value) {
    if (value == null) {
      _json.remove('frequencyPenalty');
    } else {
      _json['frequencyPenalty'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [LiveGenerationConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _LiveGenerationConfigTypeFactory
    extends SchemanticType<LiveGenerationConfig> {
  const _LiveGenerationConfigTypeFactory();

  @override
  LiveGenerationConfig parse(Object? json) {
    return LiveGenerationConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'LiveGenerationConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'responseModalities': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'speechConfig': <String, Object?>{r'$ref': r'#/$defs/SpeechConfig'},
        'stopSequences': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'maxOutputTokens': <String, Object?>{'type': 'integer'},
        'temperature': <String, Object?>{'type': 'number'},
        'topP': <String, Object?>{'type': 'number'},
        'topK': <String, Object?>{'type': 'integer'},
        'presencePenalty': <String, Object?>{'type': 'number'},
        'frequencyPenalty': <String, Object?>{'type': 'number'},
      },
    },
    dependencies: [SpeechConfig.$schema],
  );
}
