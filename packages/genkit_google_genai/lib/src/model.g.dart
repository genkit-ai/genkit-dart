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

part of 'model.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class GeminiOptions {
  /// Creates a [GeminiOptions] from a JSON map.
  factory GeminiOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiOptions._(this._json);

  GeminiOptions({
    String? apiKey,
    List<GeminiSafetySettings>? safetySettings,
    bool? codeExecution,
    GeminiFunctionCallingConfig? functionCallingConfig,
    GeminiThinkingConfig? thinkingConfig,
    List<String>? responseModalities,
    GeminiGoogleSearch? googleSearch,
    GeminiFileSearch? fileSearch,
    double? temperature,
    double? topP,
    int? topK,
    int? candidateCount,
    List<String>? stopSequences,
    int? maxOutputTokens,
    String? responseMimeType,
    bool? responseLogprobs,
    int? logprobs,
    double? presencePenalty,
    double? frequencyPenalty,
    int? seed,
    GeminiSpeechConfig? speechConfig,
  }) {
    _json = {
      'apiKey': ?apiKey,
      'safetySettings': ?safetySettings?.map((e) => e.toJson()).toList(),
      'codeExecution': ?codeExecution,
      'functionCallingConfig': ?functionCallingConfig?.toJson(),
      'thinkingConfig': ?thinkingConfig?.toJson(),
      'responseModalities': ?responseModalities,
      'googleSearch': ?googleSearch?.toJson(),
      'fileSearch': ?fileSearch?.toJson(),
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'candidateCount': ?candidateCount,
      'stopSequences': ?stopSequences,
      'maxOutputTokens': ?maxOutputTokens,
      'responseMimeType': ?responseMimeType,
      'responseLogprobs': ?responseLogprobs,
      'logprobs': ?logprobs,
      'presencePenalty': ?presencePenalty,
      'frequencyPenalty': ?frequencyPenalty,
      'seed': ?seed,
      'speechConfig': ?speechConfig?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiOptions].
  static const SchemanticType<GeminiOptions> $schema =
      _GeminiOptionsTypeFactory();

  String? get apiKey {
    return _json['apiKey'] as String?;
  }

  set apiKey(String? value) {
    if (value == null) {
      _json.remove('apiKey');
    } else {
      _json['apiKey'] = value;
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

  GeminiFunctionCallingConfig? get functionCallingConfig {
    return _json['functionCallingConfig'] == null
        ? null
        : GeminiFunctionCallingConfig.fromJson(
            _json['functionCallingConfig'] as Map<String, dynamic>,
          );
  }

  set functionCallingConfig(GeminiFunctionCallingConfig? value) {
    if (value == null) {
      _json.remove('functionCallingConfig');
    } else {
      _json['functionCallingConfig'] = value.toJson();
    }
  }

  GeminiThinkingConfig? get thinkingConfig {
    return _json['thinkingConfig'] == null
        ? null
        : GeminiThinkingConfig.fromJson(
            _json['thinkingConfig'] as Map<String, dynamic>,
          );
  }

  set thinkingConfig(GeminiThinkingConfig? value) {
    if (value == null) {
      _json.remove('thinkingConfig');
    } else {
      _json['thinkingConfig'] = value.toJson();
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

  GeminiFileSearch? get fileSearch {
    return _json['fileSearch'] == null
        ? null
        : GeminiFileSearch.fromJson(
            _json['fileSearch'] as Map<String, dynamic>,
          );
  }

  set fileSearch(GeminiFileSearch? value) {
    if (value == null) {
      _json.remove('fileSearch');
    } else {
      _json['fileSearch'] = value.toJson();
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

  bool? get responseLogprobs {
    return _json['responseLogprobs'] as bool?;
  }

  set responseLogprobs(bool? value) {
    if (value == null) {
      _json.remove('responseLogprobs');
    } else {
      _json['responseLogprobs'] = value;
    }
  }

  int? get logprobs {
    return (_json['logprobs'] as num?)?.toInt();
  }

  set logprobs(int? value) {
    if (value == null) {
      _json.remove('logprobs');
    } else {
      _json['logprobs'] = value;
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

  int? get seed {
    return (_json['seed'] as num?)?.toInt();
  }

  set seed(int? value) {
    if (value == null) {
      _json.remove('seed');
    } else {
      _json['seed'] = value;
    }
  }

  GeminiSpeechConfig? get speechConfig {
    return _json['speechConfig'] == null
        ? null
        : GeminiSpeechConfig.fromJson(
            _json['speechConfig'] as Map<String, dynamic>,
          );
  }

  set speechConfig(GeminiSpeechConfig? value) {
    if (value == null) {
      _json.remove('speechConfig');
    } else {
      _json['speechConfig'] = value.toJson();
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
        'apiKey': <String, Object?>{'type': 'string'},
        'safetySettings': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{r'$ref': r'#/$defs/GeminiSafetySettings'},
        },
        'codeExecution': <String, Object?>{'type': 'boolean'},
        'functionCallingConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiFunctionCallingConfig',
        },
        'thinkingConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiThinkingConfig',
        },
        'responseModalities': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'googleSearch': <String, Object?>{
          r'$ref': r'#/$defs/GeminiGoogleSearch',
        },
        'fileSearch': <String, Object?>{r'$ref': r'#/$defs/GeminiFileSearch'},
        'temperature': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
          'maximum': 2.0,
        },
        'topP': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
          'maximum': 1.0,
        },
        'topK': <String, Object?>{'type': 'integer'},
        'candidateCount': <String, Object?>{'type': 'integer'},
        'stopSequences': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'maxOutputTokens': <String, Object?>{'type': 'integer'},
        'responseMimeType': <String, Object?>{'type': 'string'},
        'responseLogprobs': <String, Object?>{'type': 'boolean'},
        'logprobs': <String, Object?>{'type': 'integer'},
        'presencePenalty': <String, Object?>{'type': 'number'},
        'frequencyPenalty': <String, Object?>{'type': 'number'},
        'seed': <String, Object?>{'type': 'integer'},
        'speechConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiSpeechConfig',
        },
      },
    },
    dependencies: [
      GeminiSafetySettings.$schema,
      GeminiFunctionCallingConfig.$schema,
      GeminiThinkingConfig.$schema,
      GeminiGoogleSearch.$schema,
      GeminiFileSearch.$schema,
      GeminiSpeechConfig.$schema,
    ],
  );
}

base class GeminiSafetySettings {
  /// Creates a [GeminiSafetySettings] from a JSON map.
  factory GeminiSafetySettings.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiSafetySettings._(this._json);

  GeminiSafetySettings({String? category, String? threshold}) {
    _json = {'category': ?category, 'threshold': ?threshold};
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
          'enum': [
            'HARM_CATEGORY_UNSPECIFIED',
            'HARM_CATEGORY_HATE_SPEECH',
            'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'HARM_CATEGORY_HARASSMENT',
            'HARM_CATEGORY_DANGEROUS_CONTENT',
            'HARM_CATEGORY_CIVIC_INTEGRITY',
          ],
        },
        'threshold': <String, Object?>{
          'type': 'string',
          'enum': [
            'BLOCK_LOW_AND_ABOVE',
            'BLOCK_MEDIUM_AND_ABOVE',
            'BLOCK_ONLY_HIGH',
            'BLOCK_NONE',
          ],
        },
      },
    },
    dependencies: [],
  );
}

base class GeminiThinkingConfig {
  /// Creates a [GeminiThinkingConfig] from a JSON map.
  factory GeminiThinkingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiThinkingConfig._(this._json);

  GeminiThinkingConfig({
    bool? includeThoughts,
    int? thinkingBudget,
    String? thinkingLevel,
  }) {
    _json = {
      'includeThoughts': ?includeThoughts,
      'thinkingBudget': ?thinkingBudget,
      'thinkingLevel': ?thinkingLevel,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiThinkingConfig].
  static const SchemanticType<GeminiThinkingConfig> $schema =
      _GeminiThinkingConfigTypeFactory();

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

  /// Serializes this [GeminiThinkingConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiThinkingConfigTypeFactory
    extends SchemanticType<GeminiThinkingConfig> {
  const _GeminiThinkingConfigTypeFactory();

  @override
  GeminiThinkingConfig parse(Object? json) {
    return GeminiThinkingConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiThinkingConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'includeThoughts': <String, Object?>{
          'type': 'boolean',
          'description':
              'Indicates whether to include thoughts in the response.If true, thoughts are returned only when available.',
        },
        'thinkingBudget': <String, Object?>{
          'type': 'integer',
          'description':
              'The thinking budget parameter gives the model guidance on the number of thinking tokens it can use when generating a response. A greater number of tokens is typically associated with more detailed thinking, which is needed for solving more complex tasks. Setting the thinking budget to 0 disables thinking.',
          'minimum': 0,
          'maximum': 24576,
        },
        'thinkingLevel': <String, Object?>{
          'type': 'string',
          'description':
              'For Gemini 3.0 - Indicates the thinking level. A higher level is associated with more detailed thinking, which is needed for solving more complex tasks.',
          'enum': ['MINIMAL', 'LOW', 'MEDIUM', 'HIGH'],
        },
      },
    },
    dependencies: [],
  );
}

base class GeminiFunctionCallingConfig {
  /// Creates a [GeminiFunctionCallingConfig] from a JSON map.
  factory GeminiFunctionCallingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiFunctionCallingConfig._(this._json);

  GeminiFunctionCallingConfig({
    String? mode,
    List<String>? allowedFunctionNames,
  }) {
    _json = {'mode': ?mode, 'allowedFunctionNames': ?allowedFunctionNames};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiFunctionCallingConfig].
  static const SchemanticType<GeminiFunctionCallingConfig> $schema =
      _GeminiFunctionCallingConfigTypeFactory();

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

  /// Serializes this [GeminiFunctionCallingConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiFunctionCallingConfigTypeFactory
    extends SchemanticType<GeminiFunctionCallingConfig> {
  const _GeminiFunctionCallingConfigTypeFactory();

  @override
  GeminiFunctionCallingConfig parse(Object? json) {
    return GeminiFunctionCallingConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiFunctionCallingConfig',
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

base class GeminiFileSearch {
  /// Creates a [GeminiFileSearch] from a JSON map.
  factory GeminiFileSearch.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiFileSearch._(this._json);

  GeminiFileSearch({List<String>? fileSearchStoreNames}) {
    _json = {'fileSearchStoreNames': ?fileSearchStoreNames};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiFileSearch].
  static const SchemanticType<GeminiFileSearch> $schema =
      _GeminiFileSearchTypeFactory();

  List<String>? get fileSearchStoreNames {
    return (_json['fileSearchStoreNames'] as List?)?.cast<String>();
  }

  set fileSearchStoreNames(List<String>? value) {
    if (value == null) {
      _json.remove('fileSearchStoreNames');
    } else {
      _json['fileSearchStoreNames'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiFileSearch] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiFileSearchTypeFactory
    extends SchemanticType<GeminiFileSearch> {
  const _GeminiFileSearchTypeFactory();

  @override
  GeminiFileSearch parse(Object? json) {
    return GeminiFileSearch._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiFileSearch',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'fileSearchStoreNames': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
      },
    },
    dependencies: [],
  );
}

base class GeminiTtsOptions {
  /// Creates a [GeminiTtsOptions] from a JSON map.
  factory GeminiTtsOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiTtsOptions._(this._json);

  GeminiTtsOptions({
    String? apiKey,
    List<GeminiSafetySettings>? safetySettings,
    bool? codeExecution,
    GeminiFunctionCallingConfig? functionCallingConfig,
    GeminiThinkingConfig? thinkingConfig,
    List<String>? responseModalities,
    GeminiGoogleSearch? googleSearch,
    GeminiFileSearch? fileSearch,
    double? temperature,
    double? topP,
    int? topK,
    int? candidateCount,
    List<String>? stopSequences,
    int? maxOutputTokens,
    String? responseMimeType,
    bool? responseLogprobs,
    int? logprobs,
    double? presencePenalty,
    double? frequencyPenalty,
    int? seed,
    GeminiSpeechConfig? speechConfig,
  }) {
    _json = {
      'apiKey': ?apiKey,
      'safetySettings': ?safetySettings?.map((e) => e.toJson()).toList(),
      'codeExecution': ?codeExecution,
      'functionCallingConfig': ?functionCallingConfig?.toJson(),
      'thinkingConfig': ?thinkingConfig?.toJson(),
      'responseModalities': ?responseModalities,
      'googleSearch': ?googleSearch?.toJson(),
      'fileSearch': ?fileSearch?.toJson(),
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'candidateCount': ?candidateCount,
      'stopSequences': ?stopSequences,
      'maxOutputTokens': ?maxOutputTokens,
      'responseMimeType': ?responseMimeType,
      'responseLogprobs': ?responseLogprobs,
      'logprobs': ?logprobs,
      'presencePenalty': ?presencePenalty,
      'frequencyPenalty': ?frequencyPenalty,
      'seed': ?seed,
      'speechConfig': ?speechConfig?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiTtsOptions].
  static const SchemanticType<GeminiTtsOptions> $schema =
      _GeminiTtsOptionsTypeFactory();

  String? get apiKey {
    return _json['apiKey'] as String?;
  }

  set apiKey(String? value) {
    if (value == null) {
      _json.remove('apiKey');
    } else {
      _json['apiKey'] = value;
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

  GeminiFunctionCallingConfig? get functionCallingConfig {
    return _json['functionCallingConfig'] == null
        ? null
        : GeminiFunctionCallingConfig.fromJson(
            _json['functionCallingConfig'] as Map<String, dynamic>,
          );
  }

  set functionCallingConfig(GeminiFunctionCallingConfig? value) {
    if (value == null) {
      _json.remove('functionCallingConfig');
    } else {
      _json['functionCallingConfig'] = value.toJson();
    }
  }

  GeminiThinkingConfig? get thinkingConfig {
    return _json['thinkingConfig'] == null
        ? null
        : GeminiThinkingConfig.fromJson(
            _json['thinkingConfig'] as Map<String, dynamic>,
          );
  }

  set thinkingConfig(GeminiThinkingConfig? value) {
    if (value == null) {
      _json.remove('thinkingConfig');
    } else {
      _json['thinkingConfig'] = value.toJson();
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

  GeminiFileSearch? get fileSearch {
    return _json['fileSearch'] == null
        ? null
        : GeminiFileSearch.fromJson(
            _json['fileSearch'] as Map<String, dynamic>,
          );
  }

  set fileSearch(GeminiFileSearch? value) {
    if (value == null) {
      _json.remove('fileSearch');
    } else {
      _json['fileSearch'] = value.toJson();
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

  bool? get responseLogprobs {
    return _json['responseLogprobs'] as bool?;
  }

  set responseLogprobs(bool? value) {
    if (value == null) {
      _json.remove('responseLogprobs');
    } else {
      _json['responseLogprobs'] = value;
    }
  }

  int? get logprobs {
    return (_json['logprobs'] as num?)?.toInt();
  }

  set logprobs(int? value) {
    if (value == null) {
      _json.remove('logprobs');
    } else {
      _json['logprobs'] = value;
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

  int? get seed {
    return (_json['seed'] as num?)?.toInt();
  }

  set seed(int? value) {
    if (value == null) {
      _json.remove('seed');
    } else {
      _json['seed'] = value;
    }
  }

  GeminiSpeechConfig? get speechConfig {
    return _json['speechConfig'] == null
        ? null
        : GeminiSpeechConfig.fromJson(
            _json['speechConfig'] as Map<String, dynamic>,
          );
  }

  set speechConfig(GeminiSpeechConfig? value) {
    if (value == null) {
      _json.remove('speechConfig');
    } else {
      _json['speechConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiTtsOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiTtsOptionsTypeFactory
    extends SchemanticType<GeminiTtsOptions> {
  const _GeminiTtsOptionsTypeFactory();

  @override
  GeminiTtsOptions parse(Object? json) {
    return GeminiTtsOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiTtsOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'apiKey': <String, Object?>{'type': 'string'},
        'safetySettings': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{r'$ref': r'#/$defs/GeminiSafetySettings'},
        },
        'codeExecution': <String, Object?>{'type': 'boolean'},
        'functionCallingConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiFunctionCallingConfig',
        },
        'thinkingConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiThinkingConfig',
        },
        'responseModalities': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'googleSearch': <String, Object?>{
          r'$ref': r'#/$defs/GeminiGoogleSearch',
        },
        'fileSearch': <String, Object?>{r'$ref': r'#/$defs/GeminiFileSearch'},
        'temperature': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
          'maximum': 2.0,
        },
        'topP': <String, Object?>{
          'type': 'number',
          'minimum': 0.0,
          'maximum': 1.0,
        },
        'topK': <String, Object?>{'type': 'integer'},
        'candidateCount': <String, Object?>{'type': 'integer'},
        'stopSequences': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'maxOutputTokens': <String, Object?>{'type': 'integer'},
        'responseMimeType': <String, Object?>{'type': 'string'},
        'responseLogprobs': <String, Object?>{'type': 'boolean'},
        'logprobs': <String, Object?>{'type': 'integer'},
        'presencePenalty': <String, Object?>{'type': 'number'},
        'frequencyPenalty': <String, Object?>{'type': 'number'},
        'seed': <String, Object?>{'type': 'integer'},
        'speechConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiSpeechConfig',
        },
      },
    },
    dependencies: [
      GeminiSafetySettings.$schema,
      GeminiFunctionCallingConfig.$schema,
      GeminiThinkingConfig.$schema,
      GeminiGoogleSearch.$schema,
      GeminiFileSearch.$schema,
      GeminiSpeechConfig.$schema,
    ],
  );
}

base class GeminiSpeechConfig {
  /// Creates a [GeminiSpeechConfig] from a JSON map.
  factory GeminiSpeechConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiSpeechConfig._(this._json);

  GeminiSpeechConfig({
    GeminiVoiceConfig? voiceConfig,
    GeminiMultiSpeakerVoiceConfig? multiSpeakerVoiceConfig,
  }) {
    _json = {
      'voiceConfig': ?voiceConfig?.toJson(),
      'multiSpeakerVoiceConfig': ?multiSpeakerVoiceConfig?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiSpeechConfig].
  static const SchemanticType<GeminiSpeechConfig> $schema =
      _GeminiSpeechConfigTypeFactory();

  GeminiVoiceConfig? get voiceConfig {
    return _json['voiceConfig'] == null
        ? null
        : GeminiVoiceConfig.fromJson(
            _json['voiceConfig'] as Map<String, dynamic>,
          );
  }

  set voiceConfig(GeminiVoiceConfig? value) {
    if (value == null) {
      _json.remove('voiceConfig');
    } else {
      _json['voiceConfig'] = value.toJson();
    }
  }

  GeminiMultiSpeakerVoiceConfig? get multiSpeakerVoiceConfig {
    return _json['multiSpeakerVoiceConfig'] == null
        ? null
        : GeminiMultiSpeakerVoiceConfig.fromJson(
            _json['multiSpeakerVoiceConfig'] as Map<String, dynamic>,
          );
  }

  set multiSpeakerVoiceConfig(GeminiMultiSpeakerVoiceConfig? value) {
    if (value == null) {
      _json.remove('multiSpeakerVoiceConfig');
    } else {
      _json['multiSpeakerVoiceConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiSpeechConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiSpeechConfigTypeFactory
    extends SchemanticType<GeminiSpeechConfig> {
  const _GeminiSpeechConfigTypeFactory();

  @override
  GeminiSpeechConfig parse(Object? json) {
    return GeminiSpeechConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiSpeechConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Speech generation config',
      'properties': <String, Object?>{
        'voiceConfig': <String, Object?>{r'$ref': r'#/$defs/GeminiVoiceConfig'},
        'multiSpeakerVoiceConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiMultiSpeakerVoiceConfig',
        },
      },
    },
    dependencies: [
      GeminiVoiceConfig.$schema,
      GeminiMultiSpeakerVoiceConfig.$schema,
    ],
  );
}

base class GeminiMultiSpeakerVoiceConfig {
  /// Creates a [GeminiMultiSpeakerVoiceConfig] from a JSON map.
  factory GeminiMultiSpeakerVoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiMultiSpeakerVoiceConfig._(this._json);

  GeminiMultiSpeakerVoiceConfig({
    required List<GeminiSpeakerVoiceConfig> speakerVoiceConfigs,
  }) {
    _json = {
      'speakerVoiceConfigs': speakerVoiceConfigs
          .map((e) => e.toJson())
          .toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiMultiSpeakerVoiceConfig].
  static const SchemanticType<GeminiMultiSpeakerVoiceConfig> $schema =
      _GeminiMultiSpeakerVoiceConfigTypeFactory();

  List<GeminiSpeakerVoiceConfig> get speakerVoiceConfigs {
    return (_json['speakerVoiceConfigs'] as List)
        .map(
          (e) => GeminiSpeakerVoiceConfig.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  set speakerVoiceConfigs(List<GeminiSpeakerVoiceConfig> value) {
    _json['speakerVoiceConfigs'] = value.map((e) => e.toJson()).toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiMultiSpeakerVoiceConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiMultiSpeakerVoiceConfigTypeFactory
    extends SchemanticType<GeminiMultiSpeakerVoiceConfig> {
  const _GeminiMultiSpeakerVoiceConfigTypeFactory();

  @override
  GeminiMultiSpeakerVoiceConfig parse(Object? json) {
    return GeminiMultiSpeakerVoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiMultiSpeakerVoiceConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Configuration for multi-speaker setup',
      'properties': <String, Object?>{
        'speakerVoiceConfigs': <String, Object?>{
          'type': 'array',
          'description': 'Configuration for all the enabled speaker voices',
          'items': <String, Object?>{
            r'$ref': r'#/$defs/GeminiSpeakerVoiceConfig',
          },
        },
      },
      'required': ['speakerVoiceConfigs'],
    },
    dependencies: [GeminiSpeakerVoiceConfig.$schema],
  );
}

base class GeminiSpeakerVoiceConfig {
  /// Creates a [GeminiSpeakerVoiceConfig] from a JSON map.
  factory GeminiSpeakerVoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiSpeakerVoiceConfig._(this._json);

  GeminiSpeakerVoiceConfig({
    required String speaker,
    required GeminiVoiceConfig voiceConfig,
  }) {
    _json = {'speaker': speaker, 'voiceConfig': voiceConfig.toJson()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiSpeakerVoiceConfig].
  static const SchemanticType<GeminiSpeakerVoiceConfig> $schema =
      _GeminiSpeakerVoiceConfigTypeFactory();

  String get speaker {
    return _json['speaker'] as String;
  }

  set speaker(String value) {
    _json['speaker'] = value;
  }

  GeminiVoiceConfig get voiceConfig {
    return GeminiVoiceConfig.fromJson(
      _json['voiceConfig'] as Map<String, dynamic>,
    );
  }

  set voiceConfig(GeminiVoiceConfig value) {
    _json['voiceConfig'] = value.toJson();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiSpeakerVoiceConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiSpeakerVoiceConfigTypeFactory
    extends SchemanticType<GeminiSpeakerVoiceConfig> {
  const _GeminiSpeakerVoiceConfigTypeFactory();

  @override
  GeminiSpeakerVoiceConfig parse(Object? json) {
    return GeminiSpeakerVoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiSpeakerVoiceConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description':
          'Configuration for a single speaker in a multi speaker setup',
      'properties': <String, Object?>{
        'speaker': <String, Object?>{
          'type': 'string',
          'description': 'Name of the speaker to use',
        },
        'voiceConfig': <String, Object?>{r'$ref': r'#/$defs/GeminiVoiceConfig'},
      },
      'required': ['speaker', 'voiceConfig'],
    },
    dependencies: [GeminiVoiceConfig.$schema],
  );
}

base class GeminiVoiceConfig {
  /// Creates a [GeminiVoiceConfig] from a JSON map.
  factory GeminiVoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiVoiceConfig._(this._json);

  GeminiVoiceConfig({GeminiPrebuiltVoiceConfig? prebuiltVoiceConfig}) {
    _json = {'prebuiltVoiceConfig': ?prebuiltVoiceConfig?.toJson()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiVoiceConfig].
  static const SchemanticType<GeminiVoiceConfig> $schema =
      _GeminiVoiceConfigTypeFactory();

  GeminiPrebuiltVoiceConfig? get prebuiltVoiceConfig {
    return _json['prebuiltVoiceConfig'] == null
        ? null
        : GeminiPrebuiltVoiceConfig.fromJson(
            _json['prebuiltVoiceConfig'] as Map<String, dynamic>,
          );
  }

  set prebuiltVoiceConfig(GeminiPrebuiltVoiceConfig? value) {
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

  /// Serializes this [GeminiVoiceConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiVoiceConfigTypeFactory
    extends SchemanticType<GeminiVoiceConfig> {
  const _GeminiVoiceConfigTypeFactory();

  @override
  GeminiVoiceConfig parse(Object? json) {
    return GeminiVoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiVoiceConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Configuration for the voice to use',
      'properties': <String, Object?>{
        'prebuiltVoiceConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiPrebuiltVoiceConfig',
        },
      },
    },
    dependencies: [GeminiPrebuiltVoiceConfig.$schema],
  );
}

base class GeminiPrebuiltVoiceConfig {
  /// Creates a [GeminiPrebuiltVoiceConfig] from a JSON map.
  factory GeminiPrebuiltVoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiPrebuiltVoiceConfig._(this._json);

  GeminiPrebuiltVoiceConfig({String? voiceName}) {
    _json = {'voiceName': ?voiceName};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiPrebuiltVoiceConfig].
  static const SchemanticType<GeminiPrebuiltVoiceConfig> $schema =
      _GeminiPrebuiltVoiceConfigTypeFactory();

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

  /// Serializes this [GeminiPrebuiltVoiceConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiPrebuiltVoiceConfigTypeFactory
    extends SchemanticType<GeminiPrebuiltVoiceConfig> {
  const _GeminiPrebuiltVoiceConfigTypeFactory();

  @override
  GeminiPrebuiltVoiceConfig parse(Object? json) {
    return GeminiPrebuiltVoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiPrebuiltVoiceConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Configuration for the prebuilt speaker to use',
      'properties': <String, Object?>{
        'voiceName': <String, Object?>{
          'type': 'string',
          'description':
              'Name of the preset voice to use. Known values: Zephyr, Puck, Charon, Kore, Fenrir, Leda, Orus, Aoede, Callirrhoe, Autonoe, Enceladus, Iapetus, Umbriel, Algieba, Despina, Erinome, Algenib, Rasalgethi, Laomedeia, Achernar, Alnilam, Schedar, Gacrux, Pulcherrima, Achird, Zubenelgenubi, Vindemiatrix, Sadachbia, Sadaltager, Sulafat',
        },
      },
    },
    dependencies: [],
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

base class GoogleGenAiEmbedderOptions {
  /// Creates a [GoogleGenAiEmbedderOptions] from a JSON map.
  factory GoogleGenAiEmbedderOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GoogleGenAiEmbedderOptions._(this._json);

  GoogleGenAiEmbedderOptions({
    int? outputDimensionality,
    String? taskType,
    String? title,
  }) {
    _json = {
      'outputDimensionality': ?outputDimensionality,
      'taskType': ?taskType,
      'title': ?title,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GoogleGenAiEmbedderOptions].
  static const SchemanticType<GoogleGenAiEmbedderOptions> $schema =
      _GoogleGenAiEmbedderOptionsTypeFactory();

  int? get outputDimensionality {
    return (_json['outputDimensionality'] as num?)?.toInt();
  }

  set outputDimensionality(int? value) {
    if (value == null) {
      _json.remove('outputDimensionality');
    } else {
      _json['outputDimensionality'] = value;
    }
  }

  String? get taskType {
    return _json['taskType'] as String?;
  }

  set taskType(String? value) {
    if (value == null) {
      _json.remove('taskType');
    } else {
      _json['taskType'] = value;
    }
  }

  String? get title {
    return _json['title'] as String?;
  }

  set title(String? value) {
    if (value == null) {
      _json.remove('title');
    } else {
      _json['title'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GoogleGenAiEmbedderOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GoogleGenAiEmbedderOptionsTypeFactory
    extends SchemanticType<GoogleGenAiEmbedderOptions> {
  const _GoogleGenAiEmbedderOptionsTypeFactory();

  @override
  GoogleGenAiEmbedderOptions parse(Object? json) {
    return GoogleGenAiEmbedderOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GoogleGenAiEmbedderOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'outputDimensionality': <String, Object?>{
          'type': 'integer',
          'description':
              'Optional. reduced dimension for the output embedding. If set, excessive values in the output embedding are truncated from the end.',
        },
        'taskType': <String, Object?>{
          'type': 'string',
          'description':
              'Optional. Optional task type for which the embedding will be used. Can only be set for models/text-embedding-004.',
          'enum': [
            'TASK_TYPE_UNSPECIFIED',
            'RETRIEVAL_QUERY',
            'RETRIEVAL_DOCUMENT',
            'SEMANTIC_SIMILARITY',
            'CLASSIFICATION',
            'CLUSTERING',
            'QUESTION_ANSWERING',
            'FACT_VERIFICATION',
            'CODE_RETRIEVAL_QUERY',
          ],
        },
        'title': <String, Object?>{'type': 'string'},
      },
    },
    dependencies: [],
  );
}
