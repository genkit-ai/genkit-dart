// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'genkit_openai_compat.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class OpenAIOptions implements OpenAIOptionsSchema {
  OpenAIOptions(this._json);

  factory OpenAIOptions.from({
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
    return OpenAIOptions({
      if (version != null) 'version': version,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (maxTokens != null) 'maxTokens': maxTokens,
      if (stop != null) 'stop': stop,
      if (presencePenalty != null) 'presencePenalty': presencePenalty,
      if (frequencyPenalty != null) 'frequencyPenalty': frequencyPenalty,
      if (seed != null) 'seed': seed,
      if (user != null) 'user': user,
      if (jsonMode != null) 'jsonMode': jsonMode,
      if (visualDetailLevel != null) 'visualDetailLevel': visualDetailLevel,
    });
  }

  Map<String, dynamic> _json;

  @override
  String? get version {
    return _json['version'] as String?;
  }

  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  @override
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

  @override
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

  @override
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

  @override
  List<String>? get stop {
    return (_json['stop'] as List?)?.cast<String>();
  }

  set stop(List<String>? value) {
    if (value == null) {
      _json.remove('stop');
    } else {
      _json['stop'] = value;
    }
  }

  @override
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

  @override
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
  String? get user {
    return _json['user'] as String?;
  }

  set user(String? value) {
    if (value == null) {
      _json.remove('user');
    } else {
      _json['user'] = value;
    }
  }

  @override
  bool? get jsonMode {
    return _json['jsonMode'] as bool?;
  }

  set jsonMode(bool? value) {
    if (value == null) {
      _json.remove('jsonMode');
    } else {
      _json['jsonMode'] = value;
    }
  }

  @override
  String? get visualDetailLevel {
    return _json['visualDetailLevel'] as String?;
  }

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _OpenAIOptionsTypeFactory extends SchemanticType<OpenAIOptions> {
  const _OpenAIOptionsTypeFactory();

  @override
  OpenAIOptions parse(Object? json) {
    return OpenAIOptions(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OpenAIOptions',
    definition: Schema.object(
      properties: {
        'version': Schema.string(),
        'temperature': Schema.number(minimum: 0.0, maximum: 2.0),
        'topP': Schema.number(minimum: 0.0, maximum: 1.0),
        'maxTokens': Schema.integer(),
        'stop': Schema.list(items: Schema.string()),
        'presencePenalty': Schema.number(minimum: -2.0, maximum: 2.0),
        'frequencyPenalty': Schema.number(minimum: -2.0, maximum: 2.0),
        'seed': Schema.integer(),
        'user': Schema.string(),
        'jsonMode': Schema.boolean(),
        'visualDetailLevel': Schema.string(enumValues: ['auto', 'low', 'high']),
      },
      required: [],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const OpenAIOptionsType = _OpenAIOptionsTypeFactory();
