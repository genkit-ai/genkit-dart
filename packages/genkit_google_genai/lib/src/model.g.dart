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
    GeminiUrlContext? urlContext,
    GeminiRetrievalConfig? retrievalConfig,
    List<Map<String, dynamic>>? tools,
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
    String? serviceTier,
    String? previousInteractionId,
    bool? store,
    String? location,
    Map<String, String>? labels,
    GeminiVertexRetrieval? vertexRetrieval,
    String? payGo,
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
      'urlContext': ?urlContext?.toJson(),
      'retrievalConfig': ?retrievalConfig?.toJson(),
      'tools': ?tools,
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
      'serviceTier': ?serviceTier,
      'previousInteractionId': ?previousInteractionId,
      'store': ?store,
      'location': ?location,
      'labels': ?labels,
      'vertexRetrieval': ?vertexRetrieval?.toJson(),
      'payGo': ?payGo,
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

  List<Map<String, dynamic>>? get tools {
    return (_json['tools'] as List?)?.cast<Map<String, dynamic>>();
  }

  set tools(List<Map<String, dynamic>>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value;
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

  String? get serviceTier {
    return _json['serviceTier'] as String?;
  }

  set serviceTier(String? value) {
    if (value == null) {
      _json.remove('serviceTier');
    } else {
      _json['serviceTier'] = value;
    }
  }

  String? get previousInteractionId {
    return _json['previousInteractionId'] as String?;
  }

  set previousInteractionId(String? value) {
    if (value == null) {
      _json.remove('previousInteractionId');
    } else {
      _json['previousInteractionId'] = value;
    }
  }

  bool? get store {
    return _json['store'] as bool?;
  }

  set store(bool? value) {
    if (value == null) {
      _json.remove('store');
    } else {
      _json['store'] = value;
    }
  }

  String? get location {
    return _json['location'] as String?;
  }

  set location(String? value) {
    if (value == null) {
      _json.remove('location');
    } else {
      _json['location'] = value;
    }
  }

  Map<String, String>? get labels {
    return (_json['labels'] as Map?)?.cast<String, String>();
  }

  set labels(Map<String, String>? value) {
    if (value == null) {
      _json.remove('labels');
    } else {
      _json['labels'] = value;
    }
  }

  GeminiVertexRetrieval? get vertexRetrieval {
    return _json['vertexRetrieval'] == null
        ? null
        : GeminiVertexRetrieval.fromJson(
            _json['vertexRetrieval'] as Map<String, dynamic>,
          );
  }

  set vertexRetrieval(GeminiVertexRetrieval? value) {
    if (value == null) {
      _json.remove('vertexRetrieval');
    } else {
      _json['vertexRetrieval'] = value.toJson();
    }
  }

  String? get payGo {
    return _json['payGo'] as String?;
  }

  set payGo(String? value) {
    if (value == null) {
      _json.remove('payGo');
    } else {
      _json['payGo'] = value;
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
        'urlContext': <String, Object?>{r'$ref': r'#/$defs/GeminiUrlContext'},
        'retrievalConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiRetrievalConfig',
        },
        'tools': <String, Object?>{
          'type': 'array',
          'description':
              'Built-in tools as maps, for tools without an option of their own (e.g. `{\'googleMaps\': {}}`, `{\'urlContext\': {}}`). A map with a `type` (e.g. `{\'type\': \'google_search\'}`) is passed through to models called through the Interactions API.',
          'items': <String, Object?>{
            'type': 'object',
            'additionalProperties': <String, Object?>{},
          },
        },
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
        'serviceTier': <String, Object?>{
          'type': 'string',
          'description':
              'Service tier for the Gemini API: standard, flex or priority. Other values are sent as given.',
        },
        'previousInteractionId': <String, Object?>{
          'type': 'string',
          'description':
              'The ID of the previous interaction, if any. Requires store: true. Only used by models called through the Interactions API.',
        },
        'store': <String, Object?>{
          'type': 'boolean',
          'description':
              'Interactions API models: whether to store the interaction for later retrieval (defaults to false). generateContent models: whether the server logs the request for the API key\'s project; sent only when set (otherwise the project\'s logging setting applies).',
        },
        'location': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. The Google Cloud location for this request (e.g. global, us, us-central1); overrides the plugin location.',
        },
        'labels': <String, Object?>{
          'type': 'object',
          'description':
              'vertexAI only. Key-value labels to attach to the request for cost tracking.',
          'additionalProperties': <String, Object?>{'type': 'string'},
        },
        'vertexRetrieval': <String, Object?>{
          'description':
              'vertexAI only. Retrieve from a Vertex AI Search data store for grounding generative responses.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiVertexRetrieval'},
          ],
        },
        'payGo': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. PayGo consumption options. Priority provides more consistent performance than Standard PayGo. Flex is a cost-effective option for non-critical workloads. The "-only" options use only PayGo and no Provisioned Throughput.',
          'enum': ['priority', 'priority-only', 'flex', 'flex-only'],
        },
      },
    },
    dependencies: [
      GeminiSafetySettings.$schema,
      GeminiFunctionCallingConfig.$schema,
      GeminiThinkingConfig.$schema,
      GeminiGoogleSearch.$schema,
      GeminiFileSearch.$schema,
      GeminiUrlContext.$schema,
      GeminiRetrievalConfig.$schema,
      GeminiSpeechConfig.$schema,
      GeminiVertexRetrieval.$schema,
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
    GeminiUrlContext? urlContext,
    GeminiRetrievalConfig? retrievalConfig,
    List<Map<String, dynamic>>? tools,
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
    String? serviceTier,
    String? previousInteractionId,
    bool? store,
    String? location,
    Map<String, String>? labels,
    GeminiVertexRetrieval? vertexRetrieval,
    String? payGo,
    GeminiAudioFormat? audioFormat,
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
      'urlContext': ?urlContext?.toJson(),
      'retrievalConfig': ?retrievalConfig?.toJson(),
      'tools': ?tools,
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
      'serviceTier': ?serviceTier,
      'previousInteractionId': ?previousInteractionId,
      'store': ?store,
      'location': ?location,
      'labels': ?labels,
      'vertexRetrieval': ?vertexRetrieval?.toJson(),
      'payGo': ?payGo,
      'audioFormat': ?audioFormat?.toJson(),
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

  List<Map<String, dynamic>>? get tools {
    return (_json['tools'] as List?)?.cast<Map<String, dynamic>>();
  }

  set tools(List<Map<String, dynamic>>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value;
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

  String? get serviceTier {
    return _json['serviceTier'] as String?;
  }

  set serviceTier(String? value) {
    if (value == null) {
      _json.remove('serviceTier');
    } else {
      _json['serviceTier'] = value;
    }
  }

  String? get previousInteractionId {
    return _json['previousInteractionId'] as String?;
  }

  set previousInteractionId(String? value) {
    if (value == null) {
      _json.remove('previousInteractionId');
    } else {
      _json['previousInteractionId'] = value;
    }
  }

  bool? get store {
    return _json['store'] as bool?;
  }

  set store(bool? value) {
    if (value == null) {
      _json.remove('store');
    } else {
      _json['store'] = value;
    }
  }

  String? get location {
    return _json['location'] as String?;
  }

  set location(String? value) {
    if (value == null) {
      _json.remove('location');
    } else {
      _json['location'] = value;
    }
  }

  Map<String, String>? get labels {
    return (_json['labels'] as Map?)?.cast<String, String>();
  }

  set labels(Map<String, String>? value) {
    if (value == null) {
      _json.remove('labels');
    } else {
      _json['labels'] = value;
    }
  }

  GeminiVertexRetrieval? get vertexRetrieval {
    return _json['vertexRetrieval'] == null
        ? null
        : GeminiVertexRetrieval.fromJson(
            _json['vertexRetrieval'] as Map<String, dynamic>,
          );
  }

  set vertexRetrieval(GeminiVertexRetrieval? value) {
    if (value == null) {
      _json.remove('vertexRetrieval');
    } else {
      _json['vertexRetrieval'] = value.toJson();
    }
  }

  String? get payGo {
    return _json['payGo'] as String?;
  }

  set payGo(String? value) {
    if (value == null) {
      _json.remove('payGo');
    } else {
      _json['payGo'] = value;
    }
  }

  GeminiAudioFormat? get audioFormat {
    return _json['audioFormat'] == null
        ? null
        : GeminiAudioFormat.fromJson(
            _json['audioFormat'] as Map<String, dynamic>,
          );
  }

  set audioFormat(GeminiAudioFormat? value) {
    if (value == null) {
      _json.remove('audioFormat');
    } else {
      _json['audioFormat'] = value.toJson();
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
        'urlContext': <String, Object?>{r'$ref': r'#/$defs/GeminiUrlContext'},
        'retrievalConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiRetrievalConfig',
        },
        'tools': <String, Object?>{
          'type': 'array',
          'description':
              'Built-in tools as maps, for tools without an option of their own (e.g. `{\'googleMaps\': {}}`, `{\'urlContext\': {}}`). A map with a `type` (e.g. `{\'type\': \'google_search\'}`) is passed through to models called through the Interactions API.',
          'items': <String, Object?>{
            'type': 'object',
            'additionalProperties': <String, Object?>{},
          },
        },
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
        'serviceTier': <String, Object?>{
          'type': 'string',
          'description':
              'Service tier for the Gemini API: standard, flex or priority. Other values are sent as given.',
        },
        'previousInteractionId': <String, Object?>{
          'type': 'string',
          'description':
              'The ID of the previous interaction, if any. Requires store: true. Only used by models called through the Interactions API.',
        },
        'store': <String, Object?>{
          'type': 'boolean',
          'description':
              'Interactions API models: whether to store the interaction for later retrieval (defaults to false). generateContent models: whether the server logs the request for the API key\'s project; sent only when set (otherwise the project\'s logging setting applies).',
        },
        'location': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. The Google Cloud location for this request (e.g. global, us, us-central1); overrides the plugin location.',
        },
        'labels': <String, Object?>{
          'type': 'object',
          'description':
              'vertexAI only. Key-value labels to attach to the request for cost tracking.',
          'additionalProperties': <String, Object?>{'type': 'string'},
        },
        'vertexRetrieval': <String, Object?>{
          'description':
              'vertexAI only. Retrieve from a Vertex AI Search data store for grounding generative responses.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiVertexRetrieval'},
          ],
        },
        'payGo': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. PayGo consumption options. Priority provides more consistent performance than Standard PayGo. Flex is a cost-effective option for non-critical workloads. The "-only" options use only PayGo and no Provisioned Throughput.',
          'enum': ['priority', 'priority-only', 'flex', 'flex-only'],
        },
        'audioFormat': <String, Object?>{r'$ref': r'#/$defs/GeminiAudioFormat'},
      },
    },
    dependencies: [
      GeminiSafetySettings.$schema,
      GeminiFunctionCallingConfig.$schema,
      GeminiThinkingConfig.$schema,
      GeminiGoogleSearch.$schema,
      GeminiFileSearch.$schema,
      GeminiUrlContext.$schema,
      GeminiRetrievalConfig.$schema,
      GeminiSpeechConfig.$schema,
      GeminiVertexRetrieval.$schema,
      GeminiAudioFormat.$schema,
    ],
  );
}

base class GeminiImageOptions {
  /// Creates a [GeminiImageOptions] from a JSON map.
  factory GeminiImageOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiImageOptions._(this._json);

  GeminiImageOptions({
    String? apiKey,
    List<GeminiSafetySettings>? safetySettings,
    bool? codeExecution,
    GeminiFunctionCallingConfig? functionCallingConfig,
    GeminiThinkingConfig? thinkingConfig,
    List<String>? responseModalities,
    GeminiGoogleSearch? googleSearch,
    GeminiFileSearch? fileSearch,
    GeminiUrlContext? urlContext,
    GeminiRetrievalConfig? retrievalConfig,
    List<Map<String, dynamic>>? tools,
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
    String? serviceTier,
    String? previousInteractionId,
    bool? store,
    String? location,
    Map<String, String>? labels,
    GeminiVertexRetrieval? vertexRetrieval,
    String? payGo,
    GeminiImageConfig? imageConfig,
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
      'urlContext': ?urlContext?.toJson(),
      'retrievalConfig': ?retrievalConfig?.toJson(),
      'tools': ?tools,
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
      'serviceTier': ?serviceTier,
      'previousInteractionId': ?previousInteractionId,
      'store': ?store,
      'location': ?location,
      'labels': ?labels,
      'vertexRetrieval': ?vertexRetrieval?.toJson(),
      'payGo': ?payGo,
      'imageConfig': ?imageConfig?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiImageOptions].
  static const SchemanticType<GeminiImageOptions> $schema =
      _GeminiImageOptionsTypeFactory();

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

  List<Map<String, dynamic>>? get tools {
    return (_json['tools'] as List?)?.cast<Map<String, dynamic>>();
  }

  set tools(List<Map<String, dynamic>>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value;
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

  String? get serviceTier {
    return _json['serviceTier'] as String?;
  }

  set serviceTier(String? value) {
    if (value == null) {
      _json.remove('serviceTier');
    } else {
      _json['serviceTier'] = value;
    }
  }

  String? get previousInteractionId {
    return _json['previousInteractionId'] as String?;
  }

  set previousInteractionId(String? value) {
    if (value == null) {
      _json.remove('previousInteractionId');
    } else {
      _json['previousInteractionId'] = value;
    }
  }

  bool? get store {
    return _json['store'] as bool?;
  }

  set store(bool? value) {
    if (value == null) {
      _json.remove('store');
    } else {
      _json['store'] = value;
    }
  }

  String? get location {
    return _json['location'] as String?;
  }

  set location(String? value) {
    if (value == null) {
      _json.remove('location');
    } else {
      _json['location'] = value;
    }
  }

  Map<String, String>? get labels {
    return (_json['labels'] as Map?)?.cast<String, String>();
  }

  set labels(Map<String, String>? value) {
    if (value == null) {
      _json.remove('labels');
    } else {
      _json['labels'] = value;
    }
  }

  GeminiVertexRetrieval? get vertexRetrieval {
    return _json['vertexRetrieval'] == null
        ? null
        : GeminiVertexRetrieval.fromJson(
            _json['vertexRetrieval'] as Map<String, dynamic>,
          );
  }

  set vertexRetrieval(GeminiVertexRetrieval? value) {
    if (value == null) {
      _json.remove('vertexRetrieval');
    } else {
      _json['vertexRetrieval'] = value.toJson();
    }
  }

  String? get payGo {
    return _json['payGo'] as String?;
  }

  set payGo(String? value) {
    if (value == null) {
      _json.remove('payGo');
    } else {
      _json['payGo'] = value;
    }
  }

  GeminiImageConfig? get imageConfig {
    return _json['imageConfig'] == null
        ? null
        : GeminiImageConfig.fromJson(
            _json['imageConfig'] as Map<String, dynamic>,
          );
  }

  set imageConfig(GeminiImageConfig? value) {
    if (value == null) {
      _json.remove('imageConfig');
    } else {
      _json['imageConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiImageOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiImageOptionsTypeFactory
    extends SchemanticType<GeminiImageOptions> {
  const _GeminiImageOptionsTypeFactory();

  @override
  GeminiImageOptions parse(Object? json) {
    return GeminiImageOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiImageOptions',
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
        'urlContext': <String, Object?>{r'$ref': r'#/$defs/GeminiUrlContext'},
        'retrievalConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiRetrievalConfig',
        },
        'tools': <String, Object?>{
          'type': 'array',
          'description':
              'Built-in tools as maps, for tools without an option of their own (e.g. `{\'googleMaps\': {}}`, `{\'urlContext\': {}}`). A map with a `type` (e.g. `{\'type\': \'google_search\'}`) is passed through to models called through the Interactions API.',
          'items': <String, Object?>{
            'type': 'object',
            'additionalProperties': <String, Object?>{},
          },
        },
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
        'serviceTier': <String, Object?>{
          'type': 'string',
          'description':
              'Service tier for the Gemini API: standard, flex or priority. Other values are sent as given.',
        },
        'previousInteractionId': <String, Object?>{
          'type': 'string',
          'description':
              'The ID of the previous interaction, if any. Requires store: true. Only used by models called through the Interactions API.',
        },
        'store': <String, Object?>{
          'type': 'boolean',
          'description':
              'Interactions API models: whether to store the interaction for later retrieval (defaults to false). generateContent models: whether the server logs the request for the API key\'s project; sent only when set (otherwise the project\'s logging setting applies).',
        },
        'location': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. The Google Cloud location for this request (e.g. global, us, us-central1); overrides the plugin location.',
        },
        'labels': <String, Object?>{
          'type': 'object',
          'description':
              'vertexAI only. Key-value labels to attach to the request for cost tracking.',
          'additionalProperties': <String, Object?>{'type': 'string'},
        },
        'vertexRetrieval': <String, Object?>{
          'description':
              'vertexAI only. Retrieve from a Vertex AI Search data store for grounding generative responses.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiVertexRetrieval'},
          ],
        },
        'payGo': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. PayGo consumption options. Priority provides more consistent performance than Standard PayGo. Flex is a cost-effective option for non-critical workloads. The "-only" options use only PayGo and no Provisioned Throughput.',
          'enum': ['priority', 'priority-only', 'flex', 'flex-only'],
        },
        'imageConfig': <String, Object?>{r'$ref': r'#/$defs/GeminiImageConfig'},
      },
    },
    dependencies: [
      GeminiSafetySettings.$schema,
      GeminiFunctionCallingConfig.$schema,
      GeminiThinkingConfig.$schema,
      GeminiGoogleSearch.$schema,
      GeminiFileSearch.$schema,
      GeminiUrlContext.$schema,
      GeminiRetrievalConfig.$schema,
      GeminiSpeechConfig.$schema,
      GeminiVertexRetrieval.$schema,
      GeminiImageConfig.$schema,
    ],
  );
}

/// Options for video generation models such as gemini-omni-1.1-flash.
/// See https://ai.google.dev/gemini-api/docs/omni
base class GeminiVideoOptions {
  /// Creates a [GeminiVideoOptions] from a JSON map.
  factory GeminiVideoOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiVideoOptions._(this._json);

  GeminiVideoOptions({
    String? apiKey,
    List<GeminiSafetySettings>? safetySettings,
    bool? codeExecution,
    GeminiFunctionCallingConfig? functionCallingConfig,
    GeminiThinkingConfig? thinkingConfig,
    List<String>? responseModalities,
    GeminiGoogleSearch? googleSearch,
    GeminiFileSearch? fileSearch,
    GeminiUrlContext? urlContext,
    GeminiRetrievalConfig? retrievalConfig,
    List<Map<String, dynamic>>? tools,
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
    String? serviceTier,
    String? previousInteractionId,
    bool? store,
    String? location,
    Map<String, String>? labels,
    GeminiVertexRetrieval? vertexRetrieval,
    String? payGo,
    GeminiVideoFormat? videoFormat,
    GeminiVideoConfig? videoConfig,
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
      'urlContext': ?urlContext?.toJson(),
      'retrievalConfig': ?retrievalConfig?.toJson(),
      'tools': ?tools,
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
      'serviceTier': ?serviceTier,
      'previousInteractionId': ?previousInteractionId,
      'store': ?store,
      'location': ?location,
      'labels': ?labels,
      'vertexRetrieval': ?vertexRetrieval?.toJson(),
      'payGo': ?payGo,
      'videoFormat': ?videoFormat?.toJson(),
      'videoConfig': ?videoConfig?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiVideoOptions].
  static const SchemanticType<GeminiVideoOptions> $schema =
      _GeminiVideoOptionsTypeFactory();

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

  List<Map<String, dynamic>>? get tools {
    return (_json['tools'] as List?)?.cast<Map<String, dynamic>>();
  }

  set tools(List<Map<String, dynamic>>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value;
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

  String? get serviceTier {
    return _json['serviceTier'] as String?;
  }

  set serviceTier(String? value) {
    if (value == null) {
      _json.remove('serviceTier');
    } else {
      _json['serviceTier'] = value;
    }
  }

  String? get previousInteractionId {
    return _json['previousInteractionId'] as String?;
  }

  set previousInteractionId(String? value) {
    if (value == null) {
      _json.remove('previousInteractionId');
    } else {
      _json['previousInteractionId'] = value;
    }
  }

  bool? get store {
    return _json['store'] as bool?;
  }

  set store(bool? value) {
    if (value == null) {
      _json.remove('store');
    } else {
      _json['store'] = value;
    }
  }

  String? get location {
    return _json['location'] as String?;
  }

  set location(String? value) {
    if (value == null) {
      _json.remove('location');
    } else {
      _json['location'] = value;
    }
  }

  Map<String, String>? get labels {
    return (_json['labels'] as Map?)?.cast<String, String>();
  }

  set labels(Map<String, String>? value) {
    if (value == null) {
      _json.remove('labels');
    } else {
      _json['labels'] = value;
    }
  }

  GeminiVertexRetrieval? get vertexRetrieval {
    return _json['vertexRetrieval'] == null
        ? null
        : GeminiVertexRetrieval.fromJson(
            _json['vertexRetrieval'] as Map<String, dynamic>,
          );
  }

  set vertexRetrieval(GeminiVertexRetrieval? value) {
    if (value == null) {
      _json.remove('vertexRetrieval');
    } else {
      _json['vertexRetrieval'] = value.toJson();
    }
  }

  String? get payGo {
    return _json['payGo'] as String?;
  }

  set payGo(String? value) {
    if (value == null) {
      _json.remove('payGo');
    } else {
      _json['payGo'] = value;
    }
  }

  GeminiVideoFormat? get videoFormat {
    return _json['videoFormat'] == null
        ? null
        : GeminiVideoFormat.fromJson(
            _json['videoFormat'] as Map<String, dynamic>,
          );
  }

  set videoFormat(GeminiVideoFormat? value) {
    if (value == null) {
      _json.remove('videoFormat');
    } else {
      _json['videoFormat'] = value.toJson();
    }
  }

  GeminiVideoConfig? get videoConfig {
    return _json['videoConfig'] == null
        ? null
        : GeminiVideoConfig.fromJson(
            _json['videoConfig'] as Map<String, dynamic>,
          );
  }

  set videoConfig(GeminiVideoConfig? value) {
    if (value == null) {
      _json.remove('videoConfig');
    } else {
      _json['videoConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiVideoOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiVideoOptionsTypeFactory
    extends SchemanticType<GeminiVideoOptions> {
  const _GeminiVideoOptionsTypeFactory();

  @override
  GeminiVideoOptions parse(Object? json) {
    return GeminiVideoOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiVideoOptions',
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
        'urlContext': <String, Object?>{r'$ref': r'#/$defs/GeminiUrlContext'},
        'retrievalConfig': <String, Object?>{
          r'$ref': r'#/$defs/GeminiRetrievalConfig',
        },
        'tools': <String, Object?>{
          'type': 'array',
          'description':
              'Built-in tools as maps, for tools without an option of their own (e.g. `{\'googleMaps\': {}}`, `{\'urlContext\': {}}`). A map with a `type` (e.g. `{\'type\': \'google_search\'}`) is passed through to models called through the Interactions API.',
          'items': <String, Object?>{
            'type': 'object',
            'additionalProperties': <String, Object?>{},
          },
        },
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
        'serviceTier': <String, Object?>{
          'type': 'string',
          'description':
              'Service tier for the Gemini API: standard, flex or priority. Other values are sent as given.',
        },
        'previousInteractionId': <String, Object?>{
          'type': 'string',
          'description':
              'The ID of the previous interaction, if any. Requires store: true. Only used by models called through the Interactions API.',
        },
        'store': <String, Object?>{
          'type': 'boolean',
          'description':
              'Interactions API models: whether to store the interaction for later retrieval (defaults to false). generateContent models: whether the server logs the request for the API key\'s project; sent only when set (otherwise the project\'s logging setting applies).',
        },
        'location': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. The Google Cloud location for this request (e.g. global, us, us-central1); overrides the plugin location.',
        },
        'labels': <String, Object?>{
          'type': 'object',
          'description':
              'vertexAI only. Key-value labels to attach to the request for cost tracking.',
          'additionalProperties': <String, Object?>{'type': 'string'},
        },
        'vertexRetrieval': <String, Object?>{
          'description':
              'vertexAI only. Retrieve from a Vertex AI Search data store for grounding generative responses.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiVertexRetrieval'},
          ],
        },
        'payGo': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. PayGo consumption options. Priority provides more consistent performance than Standard PayGo. Flex is a cost-effective option for non-critical workloads. The "-only" options use only PayGo and no Provisioned Throughput.',
          'enum': ['priority', 'priority-only', 'flex', 'flex-only'],
        },
        'videoFormat': <String, Object?>{r'$ref': r'#/$defs/GeminiVideoFormat'},
        'videoConfig': <String, Object?>{r'$ref': r'#/$defs/GeminiVideoConfig'},
      },
    },
    dependencies: [
      GeminiSafetySettings.$schema,
      GeminiFunctionCallingConfig.$schema,
      GeminiThinkingConfig.$schema,
      GeminiGoogleSearch.$schema,
      GeminiFileSearch.$schema,
      GeminiUrlContext.$schema,
      GeminiRetrievalConfig.$schema,
      GeminiSpeechConfig.$schema,
      GeminiVertexRetrieval.$schema,
      GeminiVideoFormat.$schema,
      GeminiVideoConfig.$schema,
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
      'description':
          'Lets the model read the web pages linked in the prompt (URL context). Set it (an empty object) to turn the tool on.',
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
      'description': 'Configuration for retrieval tools.',
      'properties': <String, Object?>{
        'latLng': <String, Object?>{
          'description':
              'The user location, used by the Google Maps tool (enable it with `tools: [{\'googleMaps\': {}}]`).',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiLatLng'},
          ],
        },
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
      'description': 'A location as latitude and longitude, in degrees.',
      'properties': <String, Object?>{
        'latitude': <String, Object?>{'type': 'number'},
        'longitude': <String, Object?>{'type': 'number'},
      },
    },
    dependencies: [],
  );
}

base class GeminiVertexRetrieval {
  /// Creates a [GeminiVertexRetrieval] from a JSON map.
  factory GeminiVertexRetrieval.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiVertexRetrieval._(this._json);

  GeminiVertexRetrieval({
    required GeminiVertexDatastore datastore,
    bool? disableAttribution,
  }) {
    _json = {
      'datastore': datastore.toJson(),
      'disableAttribution': ?disableAttribution,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiVertexRetrieval].
  static const SchemanticType<GeminiVertexRetrieval> $schema =
      _GeminiVertexRetrievalTypeFactory();

  GeminiVertexDatastore get datastore {
    return GeminiVertexDatastore.fromJson(
      _json['datastore'] as Map<String, dynamic>,
    );
  }

  set datastore(GeminiVertexDatastore value) {
    _json['datastore'] = value.toJson();
  }

  bool? get disableAttribution {
    return _json['disableAttribution'] as bool?;
  }

  set disableAttribution(bool? value) {
    if (value == null) {
      _json.remove('disableAttribution');
    } else {
      _json['disableAttribution'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiVertexRetrieval] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiVertexRetrievalTypeFactory
    extends SchemanticType<GeminiVertexRetrieval> {
  const _GeminiVertexRetrievalTypeFactory();

  @override
  GeminiVertexRetrieval parse(Object? json) {
    return GeminiVertexRetrieval._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiVertexRetrieval',
    definition: <String, Object?>{
      'type': 'object',
      'description':
          'Retrieve from a Vertex AI Search data store for grounding generative responses (vertexAI only).',
      'properties': <String, Object?>{
        'datastore': <String, Object?>{
          'description': 'Vertex AI Search data store details.',
          'allOf': [
            <String, Object?>{r'$ref': r'#/$defs/GeminiVertexDatastore'},
          ],
        },
        'disableAttribution': <String, Object?>{
          'type': 'boolean',
          'description':
              'Disable using the search data in detecting grounding attribution. This does not affect how the result is given to the model for generation.',
        },
      },
      'required': ['datastore'],
    },
    dependencies: [GeminiVertexDatastore.$schema],
  );
}

base class GeminiVertexDatastore {
  /// Creates a [GeminiVertexDatastore] from a JSON map.
  factory GeminiVertexDatastore.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiVertexDatastore._(this._json);

  GeminiVertexDatastore({
    String? projectId,
    String? location,
    required String dataStoreId,
  }) {
    _json = {
      'projectId': ?projectId,
      'location': ?location,
      'dataStoreId': dataStoreId,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiVertexDatastore].
  static const SchemanticType<GeminiVertexDatastore> $schema =
      _GeminiVertexDatastoreTypeFactory();

  String? get projectId {
    return _json['projectId'] as String?;
  }

  set projectId(String? value) {
    if (value == null) {
      _json.remove('projectId');
    } else {
      _json['projectId'] = value;
    }
  }

  String? get location {
    return _json['location'] as String?;
  }

  set location(String? value) {
    if (value == null) {
      _json.remove('location');
    } else {
      _json['location'] = value;
    }
  }

  String get dataStoreId {
    return _json['dataStoreId'] as String;
  }

  set dataStoreId(String value) {
    _json['dataStoreId'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiVertexDatastore] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiVertexDatastoreTypeFactory
    extends SchemanticType<GeminiVertexDatastore> {
  const _GeminiVertexDatastoreTypeFactory();

  @override
  GeminiVertexDatastore parse(Object? json) {
    return GeminiVertexDatastore._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiVertexDatastore',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Vertex AI Search data store details.',
      'properties': <String, Object?>{
        'projectId': <String, Object?>{
          'type': 'string',
          'description':
              'Google Cloud project ID. Defaults to the plugin project when not set.',
        },
        'location': <String, Object?>{
          'type': 'string',
          'description':
              'Data store location: global, us or eu. Defaults to the plugin location when not set.',
        },
        'dataStoreId': <String, Object?>{
          'type': 'string',
          'description':
              'The data store ID, when projectId and location are given separately. Alternatively, the full path to the data store: "projects/{project}/locations/{location}/collections/default_collection/dataStores/{data_store}".',
        },
      },
      'required': ['dataStoreId'],
    },
    dependencies: [],
  );
}

base class GeminiImageConfig {
  /// Creates a [GeminiImageConfig] from a JSON map.
  factory GeminiImageConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiImageConfig._(this._json);

  GeminiImageConfig({String? aspectRatio, String? imageSize}) {
    _json = {'aspectRatio': ?aspectRatio, 'imageSize': ?imageSize};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiImageConfig].
  static const SchemanticType<GeminiImageConfig> $schema =
      _GeminiImageConfigTypeFactory();

  String? get aspectRatio {
    return _json['aspectRatio'] as String?;
  }

  set aspectRatio(String? value) {
    if (value == null) {
      _json.remove('aspectRatio');
    } else {
      _json['aspectRatio'] = value;
    }
  }

  String? get imageSize {
    return _json['imageSize'] as String?;
  }

  set imageSize(String? value) {
    if (value == null) {
      _json.remove('imageSize');
    } else {
      _json['imageSize'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiImageConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiImageConfigTypeFactory
    extends SchemanticType<GeminiImageConfig> {
  const _GeminiImageConfigTypeFactory();

  @override
  GeminiImageConfig parse(Object? json) {
    return GeminiImageConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiImageConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Settings for generated images.',
      'properties': <String, Object?>{
        'aspectRatio': <String, Object?>{
          'type': 'string',
          'description':
              'Aspect ratio of the generated image: 1:1, 1:4, 1:8, 2:3, 3:2, 3:4, 4:1, 4:3, 4:5, 5:4, 8:1, 9:16, 16:9 or 21:9 (depends on the model).',
        },
        'imageSize': <String, Object?>{
          'type': 'string',
          'description':
              'Size of the generated image, e.g. 512, 1K, 2K or 4K (depends on the model).',
        },
      },
    },
    dependencies: [],
  );
}

base class GeminiAudioFormat {
  /// Creates a [GeminiAudioFormat] from a JSON map.
  factory GeminiAudioFormat.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiAudioFormat._(this._json);

  GeminiAudioFormat({String? mimeType, int? sampleRate}) {
    _json = {'mimeType': ?mimeType, 'sampleRate': ?sampleRate};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiAudioFormat].
  static const SchemanticType<GeminiAudioFormat> $schema =
      _GeminiAudioFormatTypeFactory();

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

  int? get sampleRate {
    return (_json['sampleRate'] as num?)?.toInt();
  }

  set sampleRate(int? value) {
    if (value == null) {
      _json.remove('sampleRate');
    } else {
      _json['sampleRate'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiAudioFormat] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiAudioFormatTypeFactory
    extends SchemanticType<GeminiAudioFormat> {
  const _GeminiAudioFormatTypeFactory();

  @override
  GeminiAudioFormat parse(Object? json) {
    return GeminiAudioFormat._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiAudioFormat',
    definition: <String, Object?>{
      'type': 'object',
      'description':
          'Format of the generated audio. Supported by models called through the Interactions API (e.g. gemini-3.8-flash-tts on googleAI) and by TTS models on vertexAI.',
      'properties': <String, Object?>{
        'mimeType': <String, Object?>{
          'type': 'string',
          'description':
              'Audio encoding: audio/wav, audio/l16, audio/mulaw or audio/alaw. Defaults to audio/wav (with a header) for non-streamed requests and audio/l16 (raw PCM, no header) for streamed requests.',
        },
        'sampleRate': <String, Object?>{
          'type': 'integer',
          'description': 'Sample rate in Hz, for example 24000, 16000 or 8000.',
        },
      },
    },
    dependencies: [],
  );
}

base class GeminiVideoFormat {
  /// Creates a [GeminiVideoFormat] from a JSON map.
  factory GeminiVideoFormat.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiVideoFormat._(this._json);

  GeminiVideoFormat({
    String? aspectRatio,
    String? resolution,
    String? delivery,
    String? gcsUri,
  }) {
    _json = {
      'aspectRatio': ?aspectRatio,
      'resolution': ?resolution,
      'delivery': ?delivery,
      'gcsUri': ?gcsUri,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiVideoFormat].
  static const SchemanticType<GeminiVideoFormat> $schema =
      _GeminiVideoFormatTypeFactory();

  String? get aspectRatio {
    return _json['aspectRatio'] as String?;
  }

  set aspectRatio(String? value) {
    if (value == null) {
      _json.remove('aspectRatio');
    } else {
      _json['aspectRatio'] = value;
    }
  }

  String? get resolution {
    return _json['resolution'] as String?;
  }

  set resolution(String? value) {
    if (value == null) {
      _json.remove('resolution');
    } else {
      _json['resolution'] = value;
    }
  }

  String? get delivery {
    return _json['delivery'] as String?;
  }

  set delivery(String? value) {
    if (value == null) {
      _json.remove('delivery');
    } else {
      _json['delivery'] = value;
    }
  }

  String? get gcsUri {
    return _json['gcsUri'] as String?;
  }

  set gcsUri(String? value) {
    if (value == null) {
      _json.remove('gcsUri');
    } else {
      _json['gcsUri'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiVideoFormat] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiVideoFormatTypeFactory
    extends SchemanticType<GeminiVideoFormat> {
  const _GeminiVideoFormatTypeFactory();

  @override
  GeminiVideoFormat parse(Object? json) {
    return GeminiVideoFormat._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiVideoFormat',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Format of the generated video.',
      'properties': <String, Object?>{
        'aspectRatio': <String, Object?>{
          'type': 'string',
          'description':
              'Aspect ratio of the generated video: 16:9 (default) or 9:16.',
        },
        'resolution': <String, Object?>{
          'type': 'string',
          'description':
              'Resolution of the generated video: 360p, 720p (default), 1080p or 4k. 1080p and 4k are upscaled.',
        },
        'delivery': <String, Object?>{
          'type': 'string',
          'description':
              'How the video is returned. Inline by default; "uri" returns a Files API URI instead, recommended for large videos (requires store: true). On vertexAI, "uri" stores it in Cloud Storage (set gcsUri).',
        },
        'gcsUri': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. The Cloud Storage URI to store the video in. Required when delivery is "uri".',
        },
      },
    },
    dependencies: [],
  );
}

base class GeminiVideoConfig {
  /// Creates a [GeminiVideoConfig] from a JSON map.
  factory GeminiVideoConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GeminiVideoConfig._(this._json);

  GeminiVideoConfig({String? task}) {
    _json = {'task': ?task};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GeminiVideoConfig].
  static const SchemanticType<GeminiVideoConfig> $schema =
      _GeminiVideoConfigTypeFactory();

  String? get task {
    return _json['task'] as String?;
  }

  set task(String? value) {
    if (value == null) {
      _json.remove('task');
    } else {
      _json['task'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GeminiVideoConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GeminiVideoConfigTypeFactory
    extends SchemanticType<GeminiVideoConfig> {
  const _GeminiVideoConfigTypeFactory();

  @override
  GeminiVideoConfig parse(Object? json) {
    return GeminiVideoConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GeminiVideoConfig',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Video generation settings.',
      'properties': <String, Object?>{
        'task': <String, Object?>{
          'type': 'string',
          'description':
              'The kind of generation: text_to_video, image_to_video, reference_to_video, edit or extend. If not set, the model infers it from the prompt and inputs. Setting it adds constraints, so only use it when prompting alone does not give the intended mode.',
        },
      },
    },
    dependencies: [],
  );
}

/// Options for the Lyria music generation models (e.g. lyria-3.5).
base class LyriaOptions {
  /// Creates a [LyriaOptions] from a JSON map.
  factory LyriaOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  LyriaOptions._(this._json);

  LyriaOptions({
    String? apiKey,
    List<String>? responseModalities,
    String? location,
  }) {
    _json = {
      'apiKey': ?apiKey,
      'responseModalities': ?responseModalities,
      'location': ?location,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [LyriaOptions].
  static const SchemanticType<LyriaOptions> $schema =
      _LyriaOptionsTypeFactory();

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

  String? get location {
    return _json['location'] as String?;
  }

  set location(String? value) {
    if (value == null) {
      _json.remove('location');
    } else {
      _json['location'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [LyriaOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _LyriaOptionsTypeFactory extends SchemanticType<LyriaOptions> {
  const _LyriaOptionsTypeFactory();

  @override
  LyriaOptions parse(Object? json) {
    return LyriaOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'LyriaOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'apiKey': <String, Object?>{
          'type': 'string',
          'description':
              'Overrides the plugin-configured API key, if specified.',
        },
        'responseModalities': <String, Object?>{
          'type': 'array',
          'description':
              'The modalities to be used in response: TEXT, IMAGE, AUDIO. When not set, Lyria returns AUDIO and TEXT (the music, plus the lyrics or caption).',
          'items': <String, Object?>{'type': 'string'},
        },
        'location': <String, Object?>{
          'type': 'string',
          'description':
              'vertexAI only. Lyria is only available in global. If the plugin uses a different location, set this to global.',
        },
      },
    },
    dependencies: [],
  );
}

/// Options for the Antigravity agent (e.g. antigravity-preview-09-2026).
base class AntigravityOptions {
  /// Creates a [AntigravityOptions] from a JSON map.
  factory AntigravityOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AntigravityOptions._(this._json);

  AntigravityOptions({
    String? apiKey,
    String? previousInteractionId,
    bool? store,
    Object? environment,
    List<String>? responseModalities,
    String? model,
    List<Map<String, dynamic>>? tools,
  }) {
    _json = {
      'apiKey': ?apiKey,
      'previousInteractionId': ?previousInteractionId,
      'store': ?store,
      'environment': ?environment,
      'responseModalities': ?responseModalities,
      'model': ?model,
      'tools': ?tools,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AntigravityOptions].
  static const SchemanticType<AntigravityOptions> $schema =
      _AntigravityOptionsTypeFactory();

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

  String? get previousInteractionId {
    return _json['previousInteractionId'] as String?;
  }

  set previousInteractionId(String? value) {
    if (value == null) {
      _json.remove('previousInteractionId');
    } else {
      _json['previousInteractionId'] = value;
    }
  }

  bool? get store {
    return _json['store'] as bool?;
  }

  set store(bool? value) {
    if (value == null) {
      _json.remove('store');
    } else {
      _json['store'] = value;
    }
  }

  Object? get environment {
    return _json['environment'] as Object?;
  }

  set environment(Object? value) {
    if (value == null) {
      _json.remove('environment');
    } else {
      _json['environment'] = value;
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

  String? get model {
    return _json['model'] as String?;
  }

  set model(String? value) {
    if (value == null) {
      _json.remove('model');
    } else {
      _json['model'] = value;
    }
  }

  List<Map<String, dynamic>>? get tools {
    return (_json['tools'] as List?)?.cast<Map<String, dynamic>>();
  }

  set tools(List<Map<String, dynamic>>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AntigravityOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AntigravityOptionsTypeFactory
    extends SchemanticType<AntigravityOptions> {
  const _AntigravityOptionsTypeFactory();

  @override
  AntigravityOptions parse(Object? json) {
    return AntigravityOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AntigravityOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'apiKey': <String, Object?>{
          'type': 'string',
          'description':
              'Overrides the plugin-configured API key, if specified.',
        },
        'previousInteractionId': <String, Object?>{
          'type': 'string',
          'description':
              'The ID of the previous interaction, if any. By default the agent continues the interaction of the last model message.',
        },
        'store': <String, Object?>{
          'type': 'boolean',
          'description':
              'Whether to store the response and request for later retrieval. Sent only when set: the agent needs stored interactions (the server rejects store: false).',
        },
        'environment': <String, Object?>{
          'description':
              'The sandbox environment: a string such as "remote" (a new sandbox), an environment ID, or a map with the environment configuration. A continued conversation reuses the previous environment.',
        },
        'responseModalities': <String, Object?>{
          'type': 'array',
          'description': 'The modalities to be used in response: TEXT, IMAGE.',
          'items': <String, Object?>{'type': 'string'},
        },
        'model': <String, Object?>{
          'type': 'string',
          'description':
              'The Gemini model the agent runs on (e.g. gemini-4-argon, gemini-3.8-flash). The server picks a default if not set.',
        },
        'tools': <String, Object?>{
          'type': 'array',
          'description':
              'Built-in tools as maps (e.g. `{\'googleSearch\': {}}` or `{\'type\': \'google_search\'}`), sent before the request\'s tools.',
          'items': <String, Object?>{
            'type': 'object',
            'additionalProperties': <String, Object?>{},
          },
        },
      },
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
