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

part of 'genkit_openai.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class OpenAIOptions {
  factory OpenAIOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OpenAIOptions._(this._json);

  OpenAIOptions({
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
    List<String>? responseModalities,
    String? audioVoice,
    String? audioFormat,
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
      'responseModalities': ?responseModalities,
      'audioVoice': ?audioVoice,
      'audioFormat': ?audioFormat,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<OpenAIOptions> $schema =
      _OpenAIOptionsTypeFactory();

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
    return _json['seed'] as int?;
  }

  set seed(int? value) {
    if (value == null) {
      _json.remove('seed');
    } else {
      _json['seed'] = value;
    }
  }

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

  String? get audioVoice {
    return _json['audioVoice'] as String?;
  }

  set audioVoice(String? value) {
    if (value == null) {
      _json.remove('audioVoice');
    } else {
      _json['audioVoice'] = value;
    }
  }

  String? get audioFormat {
    return _json['audioFormat'] as String?;
  }

  set audioFormat(String? value) {
    if (value == null) {
      _json.remove('audioFormat');
    } else {
      _json['audioFormat'] = value;
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

base class _OpenAIOptionsTypeFactory extends SchemanticType<OpenAIOptions> {
  const _OpenAIOptionsTypeFactory();

  @override
  OpenAIOptions parse(Object? json) {
    return OpenAIOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OpenAIOptions',
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
            'responseModalities': $Schema.list(items: $Schema.string()),
            'audioVoice': $Schema.string(
              enumValues: [
                'alloy',
                'ash',
                'ballad',
                'coral',
                'echo',
                'sage',
                'shimmer',
                'verse',
              ],
            ),
            'audioFormat': $Schema.string(
              enumValues: ['wav', 'mp3', 'flac', 'opus', 'pcm16'],
            ),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}
