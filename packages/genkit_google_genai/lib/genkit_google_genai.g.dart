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

part of 'genkit_google_genai.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class GeminiOptions {
  factory GeminiOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiOptions._(this._json);

  factory GeminiOptions({
    String? apiKey,
    List<SafetySettings>? safetySettings,
    bool? codeExecution,
    FunctionCallingConfig? functionCallingConfig,
    ThinkingConfig? thinkingConfig,
    List<String>? responseModalities,
    GoogleSearchRetrieval? googleSearchRetrieval,
    FileSearch? fileSearch,
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
  }) {
    return GeminiOptions._({
      if (apiKey != null) 'apiKey': apiKey,
      if (safetySettings != null)
        'safetySettings': safetySettings.map((e) => e.toJson()).toList(),
      if (codeExecution != null) 'codeExecution': codeExecution,
      if (functionCallingConfig != null)
        'functionCallingConfig': functionCallingConfig.toJson(),
      if (thinkingConfig != null) 'thinkingConfig': thinkingConfig.toJson(),
      if (responseModalities != null) 'responseModalities': responseModalities,
      if (googleSearchRetrieval != null)
        'googleSearchRetrieval': googleSearchRetrieval.toJson(),
      if (fileSearch != null) 'fileSearch': fileSearch.toJson(),
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (topK != null) 'topK': topK,
      if (candidateCount != null) 'candidateCount': candidateCount,
      if (stopSequences != null) 'stopSequences': stopSequences,
      if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
      if (responseMimeType != null) 'responseMimeType': responseMimeType,
      if (responseLogprobs != null) 'responseLogprobs': responseLogprobs,
      if (logprobs != null) 'logprobs': logprobs,
      if (presencePenalty != null) 'presencePenalty': presencePenalty,
      if (frequencyPenalty != null) 'frequencyPenalty': frequencyPenalty,
      if (seed != null) 'seed': seed,
    });
  }

  Map<String, dynamic> _json;

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

  List<SafetySettings>? get safetySettings {
    return (_json['safetySettings'] as List?)
        ?.map((e) => SafetySettings.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set safetySettings(List<SafetySettings>? value) {
    if (value == null) {
      _json.remove('safetySettings');
    } else {
      _json['safetySettings'] = value.toList();
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

  GoogleSearchRetrieval? get googleSearchRetrieval {
    return _json['googleSearchRetrieval'] == null
        ? null
        : GoogleSearchRetrieval.fromJson(
            _json['googleSearchRetrieval'] as Map<String, dynamic>,
          );
  }

  set googleSearchRetrieval(GoogleSearchRetrieval? value) {
    if (value == null) {
      _json.remove('googleSearchRetrieval');
    } else {
      _json['googleSearchRetrieval'] = value;
    }
  }

  FileSearch? get fileSearch {
    return _json['fileSearch'] == null
        ? null
        : FileSearch.fromJson(_json['fileSearch'] as Map<String, dynamic>);
  }

  set fileSearch(FileSearch? value) {
    if (value == null) {
      _json.remove('fileSearch');
    } else {
      _json['fileSearch'] = value;
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
    return _json['logprobs'] as int?;
  }

  set logprobs(int? value) {
    if (value == null) {
      _json.remove('logprobs');
    } else {
      _json['logprobs'] = value;
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
    definition: Schema.object(
      properties: {
        'apiKey': Schema.string(),
        'safetySettings': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/SafetySettings'}),
        ),
        'codeExecution': Schema.boolean(),
        'functionCallingConfig': Schema.fromMap({
          '\$ref': r'#/$defs/FunctionCallingConfig',
        }),
        'thinkingConfig': Schema.fromMap({'\$ref': r'#/$defs/ThinkingConfig'}),
        'responseModalities': Schema.list(items: Schema.string()),
        'googleSearchRetrieval': Schema.fromMap({
          '\$ref': r'#/$defs/GoogleSearchRetrieval',
        }),
        'fileSearch': Schema.fromMap({'\$ref': r'#/$defs/FileSearch'}),
        'temperature': Schema.number(minimum: 0.0, maximum: 2.0),
        'topP': Schema.number(minimum: 0.0, maximum: 1.0),
        'topK': Schema.integer(),
        'candidateCount': Schema.integer(),
        'stopSequences': Schema.list(items: Schema.string()),
        'maxOutputTokens': Schema.integer(),
        'responseMimeType': Schema.string(),
        'responseLogprobs': Schema.boolean(),
        'logprobs': Schema.integer(),
        'presencePenalty': Schema.number(),
        'frequencyPenalty': Schema.number(),
        'seed': Schema.integer(),
      },
      required: [],
    ),
    dependencies: [
      SafetySettings.$schema,
      FunctionCallingConfig.$schema,
      ThinkingConfig.$schema,
      GoogleSearchRetrieval.$schema,
      FileSearch.$schema,
    ],
  );
}

class SafetySettings {
  factory SafetySettings.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SafetySettings._(this._json);

  factory SafetySettings({String? category, String? threshold}) {
    return SafetySettings._({
      if (category != null) 'category': category,
      if (threshold != null) 'threshold': threshold,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<SafetySettings> $schema =
      _SafetySettingsTypeFactory();

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SafetySettingsTypeFactory extends SchemanticType<SafetySettings> {
  const _SafetySettingsTypeFactory();

  @override
  SafetySettings parse(Object? json) {
    return SafetySettings._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SafetySettings',
    definition: Schema.object(
      properties: {
        'category': Schema.string(
          enumValues: [
            'HARM_CATEGORY_UNSPECIFIED',
            'HARM_CATEGORY_DEROGATORY',
            'HARM_CATEGORY_TOXICITY',
            'HARM_CATEGORY_VIOLENCE',
            'HARM_CATEGORY_SEXUAL',
            'HARM_CATEGORY_MEDICAL',
            'HARM_CATEGORY_DANGEROUS',
            'HARM_CATEGORY_HARASSMENT',
            'HARM_CATEGORY_HATE_SPEECH',
            'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'HARM_CATEGORY_DANGEROUS_CONTENT',
            'HARM_CATEGORY_CIVIC_INTEGRITY',
          ],
        ),
        'threshold': Schema.string(
          enumValues: [
            'HARM_BLOCK_THRESHOLD_UNSPECIFIED',
            'BLOCK_LOW_AND_ABOVE',
            'BLOCK_MEDIUM_AND_ABOVE',
            'BLOCK_ONLY_HIGH',
            'BLOCK_NONE',
            'OFF',
          ],
        ),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class ThinkingConfig {
  factory ThinkingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ThinkingConfig._(this._json);

  factory ThinkingConfig({bool? includeThoughts, int? thinkingBudget}) {
    return ThinkingConfig._({
      if (includeThoughts != null) 'includeThoughts': includeThoughts,
      if (thinkingBudget != null) 'thinkingBudget': thinkingBudget,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<ThinkingConfig> $schema =
      _ThinkingConfigTypeFactory();

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
    return _json['thinkingBudget'] as int?;
  }

  set thinkingBudget(int? value) {
    if (value == null) {
      _json.remove('thinkingBudget');
    } else {
      _json['thinkingBudget'] = value;
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
    definition: Schema.object(
      properties: {
        'includeThoughts': Schema.boolean(),
        'thinkingBudget': Schema.integer(),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class FunctionCallingConfig {
  factory FunctionCallingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  FunctionCallingConfig._(this._json);

  factory FunctionCallingConfig({
    String? mode,
    List<String>? allowedFunctionNames,
  }) {
    return FunctionCallingConfig._({
      if (mode != null) 'mode': mode,
      if (allowedFunctionNames != null)
        'allowedFunctionNames': allowedFunctionNames,
    });
  }

  Map<String, dynamic> _json;

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
    definition: Schema.object(
      properties: {
        'mode': Schema.string(
          enumValues: ['MODE_UNSPECIFIED', 'AUTO', 'ANY', 'NONE'],
        ),
        'allowedFunctionNames': Schema.list(items: Schema.string()),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class GoogleSearchRetrieval {
  factory GoogleSearchRetrieval.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GoogleSearchRetrieval._(this._json);

  factory GoogleSearchRetrieval({String? mode, double? dynamicThreshold}) {
    return GoogleSearchRetrieval._({
      if (mode != null) 'mode': mode,
      if (dynamicThreshold != null) 'dynamicThreshold': dynamicThreshold,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<GoogleSearchRetrieval> $schema =
      _GoogleSearchRetrievalTypeFactory();

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

  double? get dynamicThreshold {
    return _json['dynamicThreshold'] as double?;
  }

  set dynamicThreshold(double? value) {
    if (value == null) {
      _json.remove('dynamicThreshold');
    } else {
      _json['dynamicThreshold'] = value;
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

class _GoogleSearchRetrievalTypeFactory
    extends SchemanticType<GoogleSearchRetrieval> {
  const _GoogleSearchRetrievalTypeFactory();

  @override
  GoogleSearchRetrieval parse(Object? json) {
    return GoogleSearchRetrieval._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GoogleSearchRetrieval',
    definition: Schema.object(
      properties: {
        'mode': Schema.string(enumValues: ['MODE_UNSPECIFIED', 'MODE_DYNAMIC']),
        'dynamicThreshold': Schema.number(),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class FileSearch {
  factory FileSearch.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  FileSearch._(this._json);

  factory FileSearch({List<String>? fileSearchStoreNames}) {
    return FileSearch._({
      if (fileSearchStoreNames != null)
        'fileSearchStoreNames': fileSearchStoreNames,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<FileSearch> $schema = _FileSearchTypeFactory();

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _FileSearchTypeFactory extends SchemanticType<FileSearch> {
  const _FileSearchTypeFactory();

  @override
  FileSearch parse(Object? json) {
    return FileSearch._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'FileSearch',
    definition: Schema.object(
      properties: {'fileSearchStoreNames': Schema.list(items: Schema.string())},
      required: [],
    ),
    dependencies: [],
  );
}
