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

part of 'chat.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Chat-specific options for OpenAI chat models.
base class OpenAIChatOptions {
  /// Creates a [OpenAIChatOptions] from a JSON map.
  factory OpenAIChatOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OpenAIChatOptions._(this._json);

  OpenAIChatOptions({
    String? version,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<String>? stop,
    double? presencePenalty,
    double? frequencyPenalty,
    int? seed,
    String? user,
    bool? jsonMode,
    String? visualDetailLevel,
  }) {
    _json = {
      'version': ?version,
      'temperature': ?temperature,
      'topP': ?topP,
      'maxTokens': ?maxTokens,
      'stop': ?stop,
      'presencePenalty': ?presencePenalty,
      'frequencyPenalty': ?frequencyPenalty,
      'seed': ?seed,
      'user': ?user,
      'jsonMode': ?jsonMode,
      'visualDetailLevel': ?visualDetailLevel,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OpenAIChatOptions].
  static const SchemanticType<OpenAIChatOptions> $schema =
      _OpenAIChatOptionsTypeFactory();

  /// Model version override (e.g., 'gpt-4o-2024-08-06')
  String? get version {
    return _json['version'] as String?;
  }

  /// Model version override (e.g., 'gpt-4o-2024-08-06')
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  /// Sampling temperature (0.0 - 2.0)
  double? get temperature {
    return (_json['temperature'] as num?)?.toDouble();
  }

  /// Sampling temperature (0.0 - 2.0)
  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  /// Nucleus sampling (0.0 - 1.0)
  double? get topP {
    return (_json['topP'] as num?)?.toDouble();
  }

  /// Nucleus sampling (0.0 - 1.0)
  set topP(double? value) {
    if (value == null) {
      _json.remove('topP');
    } else {
      _json['topP'] = value;
    }
  }

  /// Maximum tokens to generate
  int? get maxTokens {
    return _json['maxTokens'] as int?;
  }

  /// Maximum tokens to generate
  set maxTokens(int? value) {
    if (value == null) {
      _json.remove('maxTokens');
    } else {
      _json['maxTokens'] = value;
    }
  }

  /// Stop sequences
  List<String>? get stop {
    return (_json['stop'] as List?)?.cast<String>();
  }

  /// Stop sequences
  set stop(List<String>? value) {
    if (value == null) {
      _json.remove('stop');
    } else {
      _json['stop'] = value;
    }
  }

  /// Presence penalty (-2.0 - 2.0)
  double? get presencePenalty {
    return (_json['presencePenalty'] as num?)?.toDouble();
  }

  /// Presence penalty (-2.0 - 2.0)
  set presencePenalty(double? value) {
    if (value == null) {
      _json.remove('presencePenalty');
    } else {
      _json['presencePenalty'] = value;
    }
  }

  /// Frequency penalty (-2.0 - 2.0)
  double? get frequencyPenalty {
    return (_json['frequencyPenalty'] as num?)?.toDouble();
  }

  /// Frequency penalty (-2.0 - 2.0)
  set frequencyPenalty(double? value) {
    if (value == null) {
      _json.remove('frequencyPenalty');
    } else {
      _json['frequencyPenalty'] = value;
    }
  }

  /// Seed for deterministic sampling
  int? get seed {
    return _json['seed'] as int?;
  }

  /// Seed for deterministic sampling
  set seed(int? value) {
    if (value == null) {
      _json.remove('seed');
    } else {
      _json['seed'] = value;
    }
  }

  /// User identifier for abuse detection
  String? get user {
    return _json['user'] as String?;
  }

  /// User identifier for abuse detection
  set user(String? value) {
    if (value == null) {
      _json.remove('user');
    } else {
      _json['user'] = value;
    }
  }

  /// JSON mode
  bool? get jsonMode {
    return _json['jsonMode'] as bool?;
  }

  /// JSON mode
  set jsonMode(bool? value) {
    if (value == null) {
      _json.remove('jsonMode');
    } else {
      _json['jsonMode'] = value;
    }
  }

  /// Visual detail level for images ('auto', 'low', 'high')
  String? get visualDetailLevel {
    return _json['visualDetailLevel'] as String?;
  }

  /// Visual detail level for images ('auto', 'low', 'high')
  set visualDetailLevel(String? value) {
    if (value == null) {
      _json.remove('visualDetailLevel');
    } else {
      _json['visualDetailLevel'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OpenAIChatOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OpenAIChatOptionsTypeFactory
    extends SchemanticType<OpenAIChatOptions> {
  const _OpenAIChatOptionsTypeFactory();

  @override
  OpenAIChatOptions parse(Object? json) {
    return OpenAIChatOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OpenAIChatOptions',
    definition: $Schema
        .object(
          properties: {
            'version': $Schema.string(),
            'temperature': $Schema.number(minimum: 0.0, maximum: 2.0),
            'topP': $Schema.number(minimum: 0.0, maximum: 1.0),
            'maxTokens': $Schema.integer(),
            'stop': $Schema.list(items: $Schema.string()),
            'presencePenalty': $Schema.number(minimum: -2.0, maximum: 2.0),
            'frequencyPenalty': $Schema.number(minimum: -2.0, maximum: 2.0),
            'seed': $Schema.integer(),
            'user': $Schema.string(),
            'jsonMode': $Schema.boolean(),
            'visualDetailLevel': $Schema.string(
              enumValues: ['auto', 'low', 'high'],
            ),
          },
        )
        .value,
    dependencies: [],
  );
}
