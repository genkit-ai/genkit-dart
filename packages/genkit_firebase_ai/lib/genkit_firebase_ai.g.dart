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

  GeminiOptions(this._json);

  factory GeminiOptions.from({
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
  }) {
    return GeminiOptions({
      if (stopSequences != null) 'stopSequences': stopSequences,
      if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (topK != null) 'topK': topK,
      if (presencePenalty != null) 'presencePenalty': presencePenalty,
      if (frequencyPenalty != null) 'frequencyPenalty': frequencyPenalty,
      if (responseModalities != null) 'responseModalities': responseModalities,
      if (responseMimeType != null) 'responseMimeType': responseMimeType,
      if (responseSchema != null) 'responseSchema': responseSchema,
      if (responseJsonSchema != null) 'responseJsonSchema': responseJsonSchema,
      if (thinkingConfig != null) 'thinkingConfig': thinkingConfig.toJson(),
    });
  }

  Map<String, dynamic> _json;

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
    return _json['temperature'] as double?;
  }

  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  double? get topP {
    return _json['topP'] as double?;
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
    return _json['presencePenalty'] as double?;
  }

  set presencePenalty(double? value) {
    if (value == null) {
      _json.remove('presencePenalty');
    } else {
      _json['presencePenalty'] = value;
    }
  }

  double? get frequencyPenalty {
    return _json['frequencyPenalty'] as double?;
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
    return _json['responseSchema'] as Map<String, dynamic>?;
  }

  set responseSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('responseSchema');
    } else {
      _json['responseSchema'] = value;
    }
  }

  Map<String, dynamic>? get responseJsonSchema {
    return _json['responseJsonSchema'] as Map<String, dynamic>?;
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
        : ThinkingConfig(_json['thinkingConfig'] as Map<String, dynamic>);
  }

  set thinkingConfig(ThinkingConfig? value) {
    if (value == null) {
      _json.remove('thinkingConfig');
    } else {
      _json['thinkingConfig'] = value;
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
    return GeminiOptions(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiOptions',
    definition: Schema.object(
      properties: {
        'stopSequences': Schema.list(items: Schema.string()),
        'maxOutputTokens': Schema.integer(),
        'temperature': Schema.number(),
        'topP': Schema.number(),
        'topK': Schema.integer(),
        'presencePenalty': Schema.number(),
        'frequencyPenalty': Schema.number(),
        'responseModalities': Schema.list(items: Schema.string()),
        'responseMimeType': Schema.string(),
        'responseSchema': Schema.object(additionalProperties: Schema.any()),
        'responseJsonSchema': Schema.object(additionalProperties: Schema.any()),
        'thinkingConfig': Schema.fromMap({'\$ref': r'#/$defs/ThinkingConfig'}),
      },
      required: [],
    ),
    dependencies: [ThinkingConfig.$schema],
  );
}

class ThinkingConfig {
  factory ThinkingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ThinkingConfig(this._json);

  factory ThinkingConfig.from({int? thinkingBudget, bool? includeThoughts}) {
    return ThinkingConfig({
      if (thinkingBudget != null) 'thinkingBudget': thinkingBudget,
      if (includeThoughts != null) 'includeThoughts': includeThoughts,
    });
  }

  Map<String, dynamic> _json;

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
    return ThinkingConfig(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ThinkingConfig',
    definition: Schema.object(
      properties: {
        'thinkingBudget': Schema.integer(),
        'includeThoughts': Schema.boolean(),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class PrebuiltVoiceConfig {
  factory PrebuiltVoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  PrebuiltVoiceConfig(this._json);

  factory PrebuiltVoiceConfig.from({String? voiceName}) {
    return PrebuiltVoiceConfig({if (voiceName != null) 'voiceName': voiceName});
  }

  Map<String, dynamic> _json;

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
    return PrebuiltVoiceConfig(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PrebuiltVoiceConfig',
    definition: Schema.object(
      properties: {'voiceName': Schema.string()},
      required: [],
    ),
    dependencies: [],
  );
}

class VoiceConfig {
  factory VoiceConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  VoiceConfig(this._json);

  factory VoiceConfig.from({PrebuiltVoiceConfig? prebuiltVoiceConfig}) {
    return VoiceConfig({
      if (prebuiltVoiceConfig != null)
        'prebuiltVoiceConfig': prebuiltVoiceConfig.toJson(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<VoiceConfig> $schema = _VoiceConfigTypeFactory();

  PrebuiltVoiceConfig? get prebuiltVoiceConfig {
    return _json['prebuiltVoiceConfig'] == null
        ? null
        : PrebuiltVoiceConfig(
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
    return VoiceConfig(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'VoiceConfig',
    definition: Schema.object(
      properties: {
        'prebuiltVoiceConfig': Schema.fromMap({
          '\$ref': r'#/$defs/PrebuiltVoiceConfig',
        }),
      },
      required: [],
    ),
    dependencies: [PrebuiltVoiceConfig.$schema],
  );
}

class SpeechConfig {
  factory SpeechConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SpeechConfig(this._json);

  factory SpeechConfig.from({VoiceConfig? voiceConfig}) {
    return SpeechConfig({
      if (voiceConfig != null) 'voiceConfig': voiceConfig.toJson(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<SpeechConfig> $schema =
      _SpeechConfigTypeFactory();

  VoiceConfig? get voiceConfig {
    return _json['voiceConfig'] == null
        ? null
        : VoiceConfig(_json['voiceConfig'] as Map<String, dynamic>);
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
    return SpeechConfig(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SpeechConfig',
    definition: Schema.object(
      properties: {
        'voiceConfig': Schema.fromMap({'\$ref': r'#/$defs/VoiceConfig'}),
      },
      required: [],
    ),
    dependencies: [VoiceConfig.$schema],
  );
}

class LiveGenerationConfig {
  factory LiveGenerationConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  LiveGenerationConfig(this._json);

  factory LiveGenerationConfig.from({
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
    return LiveGenerationConfig({
      if (responseModalities != null) 'responseModalities': responseModalities,
      if (speechConfig != null) 'speechConfig': speechConfig.toJson(),
      if (stopSequences != null) 'stopSequences': stopSequences,
      if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (topK != null) 'topK': topK,
      if (presencePenalty != null) 'presencePenalty': presencePenalty,
      if (frequencyPenalty != null) 'frequencyPenalty': frequencyPenalty,
    });
  }

  Map<String, dynamic> _json;

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
        : SpeechConfig(_json['speechConfig'] as Map<String, dynamic>);
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
    return _json['temperature'] as double?;
  }

  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  double? get topP {
    return _json['topP'] as double?;
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
    return _json['presencePenalty'] as double?;
  }

  set presencePenalty(double? value) {
    if (value == null) {
      _json.remove('presencePenalty');
    } else {
      _json['presencePenalty'] = value;
    }
  }

  double? get frequencyPenalty {
    return _json['frequencyPenalty'] as double?;
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
    return LiveGenerationConfig(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'LiveGenerationConfig',
    definition: Schema.object(
      properties: {
        'responseModalities': Schema.list(items: Schema.string()),
        'speechConfig': Schema.fromMap({'\$ref': r'#/$defs/SpeechConfig'}),
        'stopSequences': Schema.list(items: Schema.string()),
        'maxOutputTokens': Schema.integer(),
        'temperature': Schema.number(),
        'topP': Schema.number(),
        'topK': Schema.integer(),
        'presencePenalty': Schema.number(),
        'frequencyPenalty': Schema.number(),
      },
      required: [],
    ),
    dependencies: [SpeechConfig.$schema],
  );
}
