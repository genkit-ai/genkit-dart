// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'genkit_firebase_ai.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type GeminiOptions(Map<String, dynamic> _json) {
  factory GeminiOptions.from({
    int? candidateCount,
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
      if (candidateCount != null) 'candidateCount': candidateCount,
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
      if (thinkingConfig != null) 'thinkingConfig': thinkingConfig?.toJson(),
    });
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GeminiOptionsTypeFactory implements JsonExtensionType<GeminiOptions> {
  const GeminiOptionsTypeFactory();

  @override
  GeminiOptions parse(Object json) {
    return GeminiOptions(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'candidateCount': Schema.integer(),
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
        'thinkingConfig': ThinkingConfigType.jsonSchema,
      },
      required: [],
    );
  }
}

// ignore: constant_identifier_names
const GeminiOptionsType = GeminiOptionsTypeFactory();

extension type ThinkingConfig(Map<String, dynamic> _json) {
  factory ThinkingConfig.from({int? thinkingBudget, bool? includeThoughts}) {
    return ThinkingConfig({
      if (thinkingBudget != null) 'thinkingBudget': thinkingBudget,
      if (includeThoughts != null) 'includeThoughts': includeThoughts,
    });
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ThinkingConfigTypeFactory implements JsonExtensionType<ThinkingConfig> {
  const ThinkingConfigTypeFactory();

  @override
  ThinkingConfig parse(Object json) {
    return ThinkingConfig(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'thinkingBudget': Schema.integer(),
        'includeThoughts': Schema.boolean(),
      },
      required: [],
    );
  }
}

// ignore: constant_identifier_names
const ThinkingConfigType = ThinkingConfigTypeFactory();

extension type LiveGenerationConfig(Map<String, dynamic> _json) {
  factory LiveGenerationConfig.from({List<String>? responseModalities}) {
    return LiveGenerationConfig({
      if (responseModalities != null) 'responseModalities': responseModalities,
    });
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class LiveGenerationConfigTypeFactory
    implements JsonExtensionType<LiveGenerationConfig> {
  const LiveGenerationConfigTypeFactory();

  @override
  LiveGenerationConfig parse(Object json) {
    return LiveGenerationConfig(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'responseModalities': Schema.list(items: Schema.string())},
      required: [],
    );
  }
}

// ignore: constant_identifier_names
const LiveGenerationConfigType = LiveGenerationConfigTypeFactory();
