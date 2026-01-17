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

extension type GeminiOptions(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory GeminiOptions.from({
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
    return GeminiOptions({
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
        ?.map((e) => SafetySettings(e as Map<String, dynamic>))
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
        : FunctionCallingConfig(
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
        : ThinkingConfig(_json['thinkingConfig'] as Map<String, dynamic>);
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
        : GoogleSearchRetrieval(
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
        : FileSearch(_json['fileSearch'] as Map<String, dynamic>);
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _GeminiOptionsTypeFactory extends JsonExtensionType<GeminiOptions> {
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
      SafetySettingsType,
      FunctionCallingConfigType,
      ThinkingConfigType,
      GoogleSearchRetrievalType,
      FileSearchType,
    ],
  );
}

// ignore: constant_identifier_names
const GeminiOptionsType = _GeminiOptionsTypeFactory();

extension type SafetySettings(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory SafetySettings.from({String? category, String? threshold}) {
    return SafetySettings({
      if (category != null) 'category': category,
      if (threshold != null) 'threshold': threshold,
    });
  }

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SafetySettingsTypeFactory extends JsonExtensionType<SafetySettings> {
  const _SafetySettingsTypeFactory();

  @override
  SafetySettings parse(Object? json) {
    return SafetySettings(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const SafetySettingsType = _SafetySettingsTypeFactory();

extension type ThinkingConfig(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory ThinkingConfig.from({bool? includeThoughts, int? thinkingBudget}) {
    return ThinkingConfig({
      if (includeThoughts != null) 'includeThoughts': includeThoughts,
      if (thinkingBudget != null) 'thinkingBudget': thinkingBudget,
    });
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ThinkingConfigTypeFactory extends JsonExtensionType<ThinkingConfig> {
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
        'includeThoughts': Schema.boolean(),
        'thinkingBudget': Schema.integer(),
      },
      required: [],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const ThinkingConfigType = _ThinkingConfigTypeFactory();

extension type FunctionCallingConfig(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory FunctionCallingConfig.from({
    String? mode,
    List<String>? allowedFunctionNames,
  }) {
    return FunctionCallingConfig({
      if (mode != null) 'mode': mode,
      if (allowedFunctionNames != null)
        'allowedFunctionNames': allowedFunctionNames,
    });
  }

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _FunctionCallingConfigTypeFactory
    extends JsonExtensionType<FunctionCallingConfig> {
  const _FunctionCallingConfigTypeFactory();

  @override
  FunctionCallingConfig parse(Object? json) {
    return FunctionCallingConfig(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const FunctionCallingConfigType = _FunctionCallingConfigTypeFactory();

extension type GoogleSearchRetrieval(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory GoogleSearchRetrieval.from({String? mode, double? dynamicThreshold}) {
    return GoogleSearchRetrieval({
      if (mode != null) 'mode': mode,
      if (dynamicThreshold != null) 'dynamicThreshold': dynamicThreshold,
    });
  }

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _GoogleSearchRetrievalTypeFactory
    extends JsonExtensionType<GoogleSearchRetrieval> {
  const _GoogleSearchRetrievalTypeFactory();

  @override
  GoogleSearchRetrieval parse(Object? json) {
    return GoogleSearchRetrieval(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const GoogleSearchRetrievalType = _GoogleSearchRetrievalTypeFactory();

extension type FileSearch(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory FileSearch.from({List<String>? fileSearchStoreNames}) {
    return FileSearch({
      if (fileSearchStoreNames != null)
        'fileSearchStoreNames': fileSearchStoreNames,
    });
  }

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _FileSearchTypeFactory extends JsonExtensionType<FileSearch> {
  const _FileSearchTypeFactory();

  @override
  FileSearch parse(Object? json) {
    return FileSearch(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const FileSearchType = _FileSearchTypeFactory();
