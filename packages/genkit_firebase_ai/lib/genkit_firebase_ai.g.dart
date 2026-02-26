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

class GeminiOptions {
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
    bool? responseLogprobs,
    int? logprobs,
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
      'responseLogprobs': ?responseLogprobs,
      'logprobs': ?logprobs,
    };
  }

  late final Map<String, dynamic> _json;

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
    return _json['maxOutputTokens'] as int?;
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
    return _json['topK'] as int?;
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
      _json['thinkingConfig'] = value;
    }
  }

  int? get candidateCount {
    return _json['candidateCount'] as int?;
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
      _json['functionCallingConfig'] = value;
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
    return _json['logprobs'] as int?;
  }

  set logprobs(int? value) {
    if (value == null) {
      _json.remove('logprobs');
    } else {
      _json['logprobs'] = value;
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

class _GeminiOptionsTypeFactory extends SchemanticType<GeminiOptions> {
  const _GeminiOptionsTypeFactory();

  @override
  GeminiOptions parse(Object? json) {
    return GeminiOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiOptions',
    definition: $Schema
        .object(
          properties: {
            'stopSequences': $Schema.list(items: $Schema.string()),
            'maxOutputTokens': $Schema.integer(),
            'temperature': $Schema.number(),
            'topP': $Schema.number(),
            'topK': $Schema.integer(),
            'presencePenalty': $Schema.number(),
            'frequencyPenalty': $Schema.number(),
            'responseModalities': $Schema.list(items: $Schema.string()),
            'responseMimeType': $Schema.string(),
            'responseSchema': $Schema.object(
              additionalProperties: $Schema.any(),
            ),
            'responseJsonSchema': $Schema.object(
              additionalProperties: $Schema.any(),
            ),
            'thinkingConfig': $Schema.fromMap({
              '\$ref': r'#/$defs/ThinkingConfig',
            }),
            'candidateCount': $Schema.integer(),
            'codeExecution': $Schema.boolean(),
            'functionCallingConfig': $Schema.fromMap({
              '\$ref': r'#/$defs/FunctionCallingConfig',
            }),
            'responseLogprobs': $Schema.boolean(),
            'logprobs': $Schema.integer(),
          },
          required: [],
        )
        .value,
    dependencies: [ThinkingConfig.$schema, FunctionCallingConfig.$schema],
  );
}

class FunctionCallingConfig {
  factory FunctionCallingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  FunctionCallingConfig._(this._json);

  FunctionCallingConfig({String? mode, List<String>? allowedFunctionNames}) {
    _json = {'mode': ?mode, 'allowedFunctionNames': ?allowedFunctionNames};
  }

  late final Map<String, dynamic> _json;

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _FunctionCallingConfigTypeFactory
    extends SchemanticType<FunctionCallingConfig> {
  const _FunctionCallingConfigTypeFactory();

  @override
  FunctionCallingConfig parse(Object? json) {
    return FunctionCallingConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'FunctionCallingConfig',
    definition: $Schema
        .object(
          properties: {
            'mode': $Schema.string(
              enumValues: ['MODE_UNSPECIFIED', 'AUTO', 'ANY', 'NONE'],
            ),
            'allowedFunctionNames': $Schema.list(items: $Schema.string()),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

class ThinkingConfig {
  factory ThinkingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ThinkingConfig._(this._json);

  ThinkingConfig({int? thinkingBudget, bool? includeThoughts}) {
    _json = {
      'thinkingBudget': ?thinkingBudget,
      'includeThoughts': ?includeThoughts,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ThinkingConfig> $schema =
      _ThinkingConfigTypeFactory();

  int? get thinkingBudget {
    return _json['thinkingBudget'] as int?;
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ThinkingConfigTypeFactory extends SchemanticType<ThinkingConfig> {
  const _ThinkingConfigTypeFactory();

  @override
  ThinkingConfig parse(Object? json) {
    return ThinkingConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ThinkingConfig',
    definition: $Schema
        .object(
          properties: {
            'thinkingBudget': $Schema.integer(),
            'includeThoughts': $Schema.boolean(),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

class PrebuiltVoiceConfig {
  factory PrebuiltVoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  PrebuiltVoiceConfig._(this._json);

  PrebuiltVoiceConfig({String? voiceName}) {
    _json = {'voiceName': ?voiceName};
  }

  late final Map<String, dynamic> _json;

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _PrebuiltVoiceConfigTypeFactory
    extends SchemanticType<PrebuiltVoiceConfig> {
  const _PrebuiltVoiceConfigTypeFactory();

  @override
  PrebuiltVoiceConfig parse(Object? json) {
    return PrebuiltVoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PrebuiltVoiceConfig',
    definition: $Schema
        .object(properties: {'voiceName': $Schema.string()}, required: [])
        .value,
    dependencies: [],
  );
}

class VoiceConfig {
  factory VoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  VoiceConfig._(this._json);

  VoiceConfig({PrebuiltVoiceConfig? prebuiltVoiceConfig}) {
    _json = {'prebuiltVoiceConfig': ?prebuiltVoiceConfig?.toJson()};
  }

  late final Map<String, dynamic> _json;

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
      _json['prebuiltVoiceConfig'] = value;
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

class _VoiceConfigTypeFactory extends SchemanticType<VoiceConfig> {
  const _VoiceConfigTypeFactory();

  @override
  VoiceConfig parse(Object? json) {
    return VoiceConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'VoiceConfig',
    definition: $Schema
        .object(
          properties: {
            'prebuiltVoiceConfig': $Schema.fromMap({
              '\$ref': r'#/$defs/PrebuiltVoiceConfig',
            }),
          },
          required: [],
        )
        .value,
    dependencies: [PrebuiltVoiceConfig.$schema],
  );
}

class SpeechConfig {
  factory SpeechConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SpeechConfig._(this._json);

  SpeechConfig({VoiceConfig? voiceConfig}) {
    _json = {'voiceConfig': ?voiceConfig?.toJson()};
  }

  late final Map<String, dynamic> _json;

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
      _json['voiceConfig'] = value;
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

class _SpeechConfigTypeFactory extends SchemanticType<SpeechConfig> {
  const _SpeechConfigTypeFactory();

  @override
  SpeechConfig parse(Object? json) {
    return SpeechConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SpeechConfig',
    definition: $Schema
        .object(
          properties: {
            'voiceConfig': $Schema.fromMap({'\$ref': r'#/$defs/VoiceConfig'}),
          },
          required: [],
        )
        .value,
    dependencies: [VoiceConfig.$schema],
  );
}

class LiveGenerationConfig {
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
      _json['speechConfig'] = value;
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
    return _json['maxOutputTokens'] as int?;
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
    return _json['topK'] as int?;
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _LiveGenerationConfigTypeFactory
    extends SchemanticType<LiveGenerationConfig> {
  const _LiveGenerationConfigTypeFactory();

  @override
  LiveGenerationConfig parse(Object? json) {
    return LiveGenerationConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'LiveGenerationConfig',
    definition: $Schema
        .object(
          properties: {
            'responseModalities': $Schema.list(items: $Schema.string()),
            'speechConfig': $Schema.fromMap({'\$ref': r'#/$defs/SpeechConfig'}),
            'stopSequences': $Schema.list(items: $Schema.string()),
            'maxOutputTokens': $Schema.integer(),
            'temperature': $Schema.number(),
            'topP': $Schema.number(),
            'topK': $Schema.integer(),
            'presencePenalty': $Schema.number(),
            'frequencyPenalty': $Schema.number(),
          },
          required: [],
        )
        .value,
    dependencies: [SpeechConfig.$schema],
  );
}
