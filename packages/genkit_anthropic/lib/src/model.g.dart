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

part of 'model.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class AnthropicOptions {
  factory AnthropicOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AnthropicOptions._(this._json);

  AnthropicOptions({
    String? apiKey,
    int? maxTokens,
    double? temperature,
    double? topP,
    int? topK,
    List<String>? stopSequences,
    ThinkingConfig? thinking,
  }) {
    _json = {
      'apiKey': ?apiKey,
      'maxTokens': ?maxTokens,
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'stopSequences': ?stopSequences,
      'thinking': ?thinking?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<AnthropicOptions> $schema =
      _AnthropicOptionsTypeFactory();

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

  int? get maxTokens {
    return _json['maxTokens'] as int?;
  }

  set maxTokens(int? value) {
    if (value == null) {
      _json.remove('maxTokens');
    } else {
      _json['maxTokens'] = value;
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

  ThinkingConfig? get thinking {
    return _json['thinking'] == null
        ? null
        : ThinkingConfig.fromJson(_json['thinking'] as Map<String, dynamic>);
  }

  set thinking(ThinkingConfig? value) {
    if (value == null) {
      _json.remove('thinking');
    } else {
      _json['thinking'] = value;
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

class _AnthropicOptionsTypeFactory extends SchemanticType<AnthropicOptions> {
  const _AnthropicOptionsTypeFactory();

  @override
  AnthropicOptions parse(Object? json) {
    return AnthropicOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AnthropicOptions',
    definition: Schema.object(
      properties: {
        'apiKey': Schema.string(),
        'maxTokens': Schema.integer(
          description:
              'The maximum number of tokens to generate before stopping.',
          minimum: 1,
        ),
        'temperature': Schema.number(
          description:
              'Amount of randomness injected into the response. Ranges from 0.0 to 1.0. Use temperature closer to 0.0 for analytical / multiple choice, and closer to 1.0 for creative and generative tasks.',
          minimum: 0.0,
          maximum: 1.0,
        ),
        'topP': Schema.number(
          description:
              'Use nucleus sampling. In nucleus sampling, we compute the cumulative distribution over all the options for each subsequent token in decreasing probability order and cut it off once it reaches a particular probability specified by top_p.',
          minimum: 0.0,
          maximum: 1.0,
        ),
        'topK': Schema.integer(
          description:
              'Only sample from the top K options for each subsequent token.',
          minimum: 0,
        ),
        'stopSequences': Schema.list(items: Schema.string()),
        'thinking': Schema.fromMap({'\$ref': r'#/$defs/ThinkingConfig'}),
      },
      required: [],
    ),
    dependencies: [ThinkingConfig.$schema],
  );
}

class ThinkingConfig {
  factory ThinkingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ThinkingConfig._(this._json);

  ThinkingConfig({required int budgetTokens}) {
    _json = {'budgetTokens': budgetTokens};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ThinkingConfig> $schema =
      _ThinkingConfigTypeFactory();

  int get budgetTokens {
    return _json['budgetTokens'] as int;
  }

  set budgetTokens(int value) {
    _json['budgetTokens'] = value;
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
        'budgetTokens': Schema.integer(
          description:
              'Determines how many tokens Claude can use for its internal reasoning process. Larger budgets allow for more extensive thought but increase latency and cost. The budget must be at least 1024 tokens and cannot exceed the model\'s max_tokens limit.',
          minimum: 1024,
        ),
      },
      required: ['budgetTokens'],
    ),
    dependencies: [],
  );
}
