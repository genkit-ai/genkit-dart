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

/// Generation options specific to Anthropic models.
base class AnthropicOptions {
  /// Creates a [AnthropicOptions] from a JSON map.
  factory AnthropicOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AnthropicOptions._(this._json);

  AnthropicOptions({
    String? apiKey,
    String? apiVersion,
    List<String>? betas,
    int? maxTokens,
    double? temperature,
    double? topP,
    int? topK,
    List<String>? stopSequences,
    String? forceTool,
    ThinkingConfig? thinking,
    AnthropicOutputConfig? outputConfig,
  }) {
    _json = {
      'apiKey': ?apiKey,
      'apiVersion': ?apiVersion,
      'betas': ?betas,
      'maxTokens': ?maxTokens,
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'stopSequences': ?stopSequences,
      'forceTool': ?forceTool,
      'thinking': ?thinking?.toJson(),
      'outputConfig': ?outputConfig?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AnthropicOptions].
  static const SchemanticType<AnthropicOptions> $schema =
      _AnthropicOptionsTypeFactory();

  /// Custom API key to use for this specific request. Overrides plugin config.
  String? get apiKey {
    return _json['apiKey'] as String?;
  }

  /// Custom API key to use for this specific request. Overrides plugin config.
  set apiKey(String? value) {
    if (value == null) {
      _json.remove('apiKey');
    } else {
      _json['apiKey'] = value;
    }
  }

  String? get apiVersion {
    return _json['apiVersion'] as String?;
  }

  set apiVersion(String? value) {
    if (value == null) {
      _json.remove('apiVersion');
    } else {
      _json['apiVersion'] = value;
    }
  }

  /// Beta feature names sent in the `anthropic-beta` header.
  ///
  /// Only used when the request resolves to the beta API. Replaces the
  /// plugin's curated default list rather than adding to it, so a new beta can
  /// be opted into without waiting for a plugin release.
  List<String>? get betas {
    return (_json['betas'] as List?)?.cast<String>();
  }

  /// Beta feature names sent in the `anthropic-beta` header.
  ///
  /// Only used when the request resolves to the beta API. Replaces the
  /// plugin's curated default list rather than adding to it, so a new beta can
  /// be opted into without waiting for a plugin release.
  set betas(List<String>? value) {
    if (value == null) {
      _json.remove('betas');
    } else {
      _json['betas'] = value;
    }
  }

  int? get maxTokens {
    return (_json['maxTokens'] as num?)?.toInt();
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
    return (_json['topK'] as num?)?.toInt();
  }

  set topK(int? value) {
    if (value == null) {
      _json.remove('topK');
    } else {
      _json['topK'] = value;
    }
  }

  /// Stop sequences to use for this generation.
  List<String>? get stopSequences {
    return (_json['stopSequences'] as List?)?.cast<String>();
  }

  /// Stop sequences to use for this generation.
  set stopSequences(List<String>? value) {
    if (value == null) {
      _json.remove('stopSequences');
    } else {
      _json['stopSequences'] = value;
    }
  }

  /// Forces the model to call the tool with this name (Anthropic's
  /// `tool_choice: {type: tool}`).
  ///
  /// Takes precedence over the portable `toolChoice` generate option, which
  /// only covers `auto`, `required`, and `none`.
  String? get forceTool {
    return _json['forceTool'] as String?;
  }

  /// Forces the model to call the tool with this name (Anthropic's
  /// `tool_choice: {type: tool}`).
  ///
  /// Takes precedence over the portable `toolChoice` generate option, which
  /// only covers `auto`, `required`, and `none`.
  set forceTool(String? value) {
    if (value == null) {
      _json.remove('forceTool');
    } else {
      _json['forceTool'] = value;
    }
  }

  /// Extended thinking configuration for supported Anthropic models (like Claude 3.7 Sonnet).
  ThinkingConfig? get thinking {
    return _json['thinking'] == null
        ? null
        : ThinkingConfig.fromJson(_json['thinking'] as Map<String, dynamic>);
  }

  /// Extended thinking configuration for supported Anthropic models (like Claude 3.7 Sonnet).
  set thinking(ThinkingConfig? value) {
    if (value == null) {
      _json.remove('thinking');
    } else {
      _json['thinking'] = value.toJson();
    }
  }

  /// Anthropic-specific output behavior configuration.
  AnthropicOutputConfig? get outputConfig {
    return _json['outputConfig'] == null
        ? null
        : AnthropicOutputConfig.fromJson(
            _json['outputConfig'] as Map<String, dynamic>,
          );
  }

  /// Anthropic-specific output behavior configuration.
  set outputConfig(AnthropicOutputConfig? value) {
    if (value == null) {
      _json.remove('outputConfig');
    } else {
      _json['outputConfig'] = value.toJson();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AnthropicOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AnthropicOptionsTypeFactory
    extends SchemanticType<AnthropicOptions> {
  const _AnthropicOptionsTypeFactory();

  @override
  AnthropicOptions parse(Object? json) {
    return AnthropicOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AnthropicOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'apiKey': <String, Object?>{'type': 'string'},
        'apiVersion': <String, Object?>{
          'type': 'string',
          'description':
              'Which Anthropic API surface to use for this request. The beta surface also serves every stable feature. Overrides the plugin-level default, which is "stable".',
          'enum': ['stable', 'beta'],
        },
        'betas': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'maxTokens': <String, Object?>{
          'type': 'integer',
          'description':
              'The maximum number of tokens to generate before stopping.',
          'minimum': 1,
        },
        'temperature': <String, Object?>{
          'type': 'number',
          'description':
              'Amount of randomness injected into the response. Ranges from 0.0 to 1.0. Use temperature closer to 0.0 for analytical / multiple choice, and closer to 1.0 for creative and generative tasks.',
          'minimum': 0.0,
          'maximum': 1.0,
        },
        'topP': <String, Object?>{
          'type': 'number',
          'description':
              'Use nucleus sampling. In nucleus sampling, we compute the cumulative distribution over all the options for each subsequent token in decreasing probability order and cut it off once it reaches a particular probability specified by top_p.',
          'minimum': 0.0,
          'maximum': 1.0,
        },
        'topK': <String, Object?>{
          'type': 'integer',
          'description':
              'Only sample from the top K options for each subsequent token.',
          'minimum': 0,
        },
        'stopSequences': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
        'forceTool': <String, Object?>{'type': 'string'},
        'thinking': <String, Object?>{r'$ref': r'#/$defs/ThinkingConfig'},
        'outputConfig': <String, Object?>{
          r'$ref': r'#/$defs/AnthropicOutputConfig',
        },
      },
    },
    dependencies: [ThinkingConfig.$schema, AnthropicOutputConfig.$schema],
  );
}

/// Configuration for Anthropic's extended thinking mode.
base class ThinkingConfig {
  /// Creates a [ThinkingConfig] from a JSON map.
  factory ThinkingConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ThinkingConfig._(this._json);

  ThinkingConfig({String? type, int? budgetTokens}) {
    _json = {'type': ?type, 'budgetTokens': ?budgetTokens};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ThinkingConfig].
  static const SchemanticType<ThinkingConfig> $schema =
      _ThinkingConfigTypeFactory();

  String? get type {
    return _json['type'] as String?;
  }

  set type(String? value) {
    if (value == null) {
      _json.remove('type');
    } else {
      _json['type'] = value;
    }
  }

  int? get budgetTokens {
    return (_json['budgetTokens'] as num?)?.toInt();
  }

  set budgetTokens(int? value) {
    if (value == null) {
      _json.remove('budgetTokens');
    } else {
      _json['budgetTokens'] = value;
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
        'type': <String, Object?>{
          'type': 'string',
          'description':
              'Thinking mode. "enabled" uses budgetTokens, "adaptive" lets the model decide, "disabled" turns it off.',
          'enum': ['enabled', 'disabled', 'adaptive'],
        },
        'budgetTokens': <String, Object?>{
          'type': 'integer',
          'description':
              'Determines how many tokens Claude can use for its internal reasoning process. Larger budgets allow for more extensive thought but increase latency and cost. The budget must be at least 1024 tokens and cannot exceed the model\'s max_tokens limit.',
          'minimum': 1024,
        },
      },
    },
    dependencies: [],
  );
}

/// Configuration for Anthropic output behavior.
base class AnthropicOutputConfig {
  /// Creates a [AnthropicOutputConfig] from a JSON map.
  factory AnthropicOutputConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AnthropicOutputConfig._(this._json);

  AnthropicOutputConfig({String? effort}) {
    _json = {'effort': ?effort};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AnthropicOutputConfig].
  static const SchemanticType<AnthropicOutputConfig> $schema =
      _AnthropicOutputConfigTypeFactory();

  String? get effort {
    return _json['effort'] as String?;
  }

  set effort(String? value) {
    if (value == null) {
      _json.remove('effort');
    } else {
      _json['effort'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AnthropicOutputConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AnthropicOutputConfigTypeFactory
    extends SchemanticType<AnthropicOutputConfig> {
  const _AnthropicOutputConfigTypeFactory();

  @override
  AnthropicOutputConfig parse(Object? json) {
    return AnthropicOutputConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AnthropicOutputConfig',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'effort': <String, Object?>{
          'type': 'string',
          'description':
              'Controls the effort Claude spends on the response, trading off response depth against latency and token usage.',
          'enum': ['low', 'medium', 'high', 'xhigh', 'max'],
        },
      },
    },
    dependencies: [],
  );
}
