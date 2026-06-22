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

/// Chat-specific options for Ollama models.
///
/// Mirrors the subset of Ollama's runtime options that map cleanly onto
/// Genkit's generation config, plus two Ollama-specific knobs (`numCtx` and
/// `keepAlive`) that are commonly tuned but absent from the JS plugin.
///
/// See https://github.com/ollama/ollama/blob/main/docs/modelfile.md and the
/// `/api/chat` options block for the full meaning of each field.
base class OllamaChatOptions {
  /// Creates a [OllamaChatOptions] from a JSON map.
  factory OllamaChatOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OllamaChatOptions._(this._json);

  OllamaChatOptions({
    double? temperature,
    int? topK,
    double? topP,
    int? maxOutputTokens,
    List<String>? stop,
    int? seed,
    int? numCtx,
    String? keepAlive,
  }) {
    _json = {
      'temperature': ?temperature,
      'topK': ?topK,
      'topP': ?topP,
      'maxOutputTokens': ?maxOutputTokens,
      'stop': ?stop,
      'seed': ?seed,
      'numCtx': ?numCtx,
      'keepAlive': ?keepAlive,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OllamaChatOptions].
  static const SchemanticType<OllamaChatOptions> $schema =
      _OllamaChatOptionsTypeFactory();

  /// Sampling temperature. Higher is more creative. Ollama default: 0.8.
  ///
  /// Ollama accepts values above 1.0; the JS plugin caps at 1.0, which rejects
  /// otherwise-valid configs.
  double? get temperature {
    return (_json['temperature'] as num?)?.toDouble();
  }

  /// Sampling temperature. Higher is more creative. Ollama default: 0.8.
  ///
  /// Ollama accepts values above 1.0; the JS plugin caps at 1.0, which rejects
  /// otherwise-valid configs.
  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  /// Top-k sampling. Ollama default: 40.
  int? get topK {
    return _json['topK'] as int?;
  }

  /// Top-k sampling. Ollama default: 40.
  set topK(int? value) {
    if (value == null) {
      _json.remove('topK');
    } else {
      _json['topK'] = value;
    }
  }

  /// Nucleus (top-p) sampling. Ollama default: 0.9.
  double? get topP {
    return (_json['topP'] as num?)?.toDouble();
  }

  /// Nucleus (top-p) sampling. Ollama default: 0.9.
  set topP(double? value) {
    if (value == null) {
      _json.remove('topP');
    } else {
      _json['topP'] = value;
    }
  }

  /// Maximum number of tokens to generate (Ollama `num_predict`).
  int? get maxOutputTokens {
    return _json['maxOutputTokens'] as int?;
  }

  /// Maximum number of tokens to generate (Ollama `num_predict`).
  set maxOutputTokens(int? value) {
    if (value == null) {
      _json.remove('maxOutputTokens');
    } else {
      _json['maxOutputTokens'] = value;
    }
  }

  /// Stop sequences. Generation halts when any is produced.
  List<String>? get stop {
    return (_json['stop'] as List?)?.cast<String>();
  }

  /// Stop sequences. Generation halts when any is produced.
  set stop(List<String>? value) {
    if (value == null) {
      _json.remove('stop');
    } else {
      _json['stop'] = value;
    }
  }

  /// Random seed for deterministic sampling.
  int? get seed {
    return _json['seed'] as int?;
  }

  /// Random seed for deterministic sampling.
  set seed(int? value) {
    if (value == null) {
      _json.remove('seed');
    } else {
      _json['seed'] = value;
    }
  }

  /// Size of the context window in tokens (Ollama `num_ctx`).
  ///
  /// Not exposed by the JS plugin; one of the most commonly tuned Ollama knobs.
  int? get numCtx {
    return _json['numCtx'] as int?;
  }

  /// Size of the context window in tokens (Ollama `num_ctx`).
  ///
  /// Not exposed by the JS plugin; one of the most commonly tuned Ollama knobs.
  set numCtx(int? value) {
    if (value == null) {
      _json.remove('numCtx');
    } else {
      _json['numCtx'] = value;
    }
  }

  /// How long the model stays loaded in memory after the request, e.g. `'5m'`,
  /// `'0'` to unload immediately, or `'-1'` to keep loaded indefinitely.
  ///
  /// Accepts the same values as Ollama's `keep_alive` field.
  String? get keepAlive {
    return _json['keepAlive'] as String?;
  }

  /// How long the model stays loaded in memory after the request, e.g. `'5m'`,
  /// `'0'` to unload immediately, or `'-1'` to keep loaded indefinitely.
  ///
  /// Accepts the same values as Ollama's `keep_alive` field.
  set keepAlive(String? value) {
    if (value == null) {
      _json.remove('keepAlive');
    } else {
      _json['keepAlive'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OllamaChatOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OllamaChatOptionsTypeFactory
    extends SchemanticType<OllamaChatOptions> {
  const _OllamaChatOptionsTypeFactory();

  @override
  OllamaChatOptions parse(Object? json) {
    return OllamaChatOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OllamaChatOptions',
    definition: $Schema
        .object(
          properties: {
            'temperature': $Schema.number(minimum: 0.0, maximum: 2.0),
            'topK': $Schema.integer(),
            'topP': $Schema.number(minimum: 0.0, maximum: 1.0),
            'maxOutputTokens': $Schema.integer(),
            'stop': $Schema.list(items: $Schema.string()),
            'seed': $Schema.integer(),
            'numCtx': $Schema.integer(),
            'keepAlive': $Schema.string(),
          },
        )
        .value,
    dependencies: [],
  );
}
