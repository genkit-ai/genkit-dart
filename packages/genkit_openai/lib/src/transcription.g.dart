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

part of 'transcription.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Transcription-specific options for OpenAI speech-to-text models.
base class OpenAITranscriptionOptions {
  /// Creates a [OpenAITranscriptionOptions] from a JSON map.
  factory OpenAITranscriptionOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OpenAITranscriptionOptions._(this._json);

  OpenAITranscriptionOptions({
    String? version,
    String? language,
    String? prompt,
    double? temperature,
    String? responseFormat,
    List<String>? timestampGranularities,
    Object? chunkingStrategy,
    List<String>? include,
    bool? translate,
  }) {
    _json = {
      'version': ?version,
      'language': ?language,
      'prompt': ?prompt,
      'temperature': ?temperature,
      'responseFormat': ?responseFormat,
      'timestampGranularities': ?timestampGranularities,
      'chunkingStrategy': ?chunkingStrategy,
      'include': ?include,
      'translate': ?translate,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OpenAITranscriptionOptions].
  static const SchemanticType<OpenAITranscriptionOptions> $schema =
      _OpenAITranscriptionOptionsTypeFactory();

  /// Model version override (e.g., 'whisper-1').
  String? get version {
    return _json['version'] as String?;
  }

  /// Model version override (e.g., 'whisper-1').
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  /// ISO-639-1 code of the spoken language, e.g. 'en', 'es'.
  ///
  /// Supplying it improves accuracy and latency. Not accepted by the
  /// translation endpoint, which always outputs English.
  String? get language {
    return _json['language'] as String?;
  }

  /// ISO-639-1 code of the spoken language, e.g. 'en', 'es'.
  ///
  /// Supplying it improves accuracy and latency. Not accepted by the
  /// translation endpoint, which always outputs English.
  set language(String? value) {
    if (value == null) {
      _json.remove('language');
    } else {
      _json['language'] = value;
    }
  }

  /// Decoding hint: vocabulary, names, or the expected style.
  ///
  /// Distinct from the Genkit prompt. When unset, the text content of the
  /// request message is used instead.
  String? get prompt {
    return _json['prompt'] as String?;
  }

  /// Decoding hint: vocabulary, names, or the expected style.
  ///
  /// Distinct from the Genkit prompt. When unset, the text content of the
  /// request message is used instead.
  set prompt(String? value) {
    if (value == null) {
      _json.remove('prompt');
    } else {
      _json['prompt'] = value;
    }
  }

  /// Sampling temperature (0.0 - 1.0).
  double? get temperature {
    return (_json['temperature'] as num?)?.toDouble();
  }

  /// Sampling temperature (0.0 - 1.0).
  set temperature(double? value) {
    if (value == null) {
      _json.remove('temperature');
    } else {
      _json['temperature'] = value;
    }
  }

  /// Transcript format. Defaults to 'json'.
  ///
  /// 'srt' and 'vtt' return subtitle markup, 'verbose_json' adds timing
  /// metadata. Whatever the format, the transcript is returned as a single
  /// text part; the untouched payload is available on `ModelResponse.raw`.
  String? get responseFormat {
    return _json['responseFormat'] as String?;
  }

  /// Transcript format. Defaults to 'json'.
  ///
  /// 'srt' and 'vtt' return subtitle markup, 'verbose_json' adds timing
  /// metadata. Whatever the format, the transcript is returned as a single
  /// text part; the untouched payload is available on `ModelResponse.raw`.
  set responseFormat(String? value) {
    if (value == null) {
      _json.remove('responseFormat');
    } else {
      _json['responseFormat'] = value;
    }
  }

  /// Timestamp detail to include: 'word' and/or 'segment'.
  ///
  /// Requires `responseFormat: 'verbose_json'`, and is only supported by
  /// `whisper-1`.
  List<String>? get timestampGranularities {
    return (_json['timestampGranularities'] as List?)?.cast<String>();
  }

  /// Timestamp detail to include: 'word' and/or 'segment'.
  ///
  /// Requires `responseFormat: 'verbose_json'`, and is only supported by
  /// `whisper-1`.
  set timestampGranularities(List<String>? value) {
    if (value == null) {
      _json.remove('timestampGranularities');
    } else {
      _json['timestampGranularities'] = value;
    }
  }

  /// How to split long audio: the string 'auto', or a map such as
  /// `{'type': 'server_vad', 'prefix_padding_ms': 300}`.
  ///
  /// Only supported by the `gpt-4o-transcribe` family.
  Object? get chunkingStrategy {
    return _json['chunkingStrategy'] as Object?;
  }

  /// How to split long audio: the string 'auto', or a map such as
  /// `{'type': 'server_vad', 'prefix_padding_ms': 300}`.
  ///
  /// Only supported by the `gpt-4o-transcribe` family.
  set chunkingStrategy(Object? value) {
    if (value == null) {
      _json.remove('chunkingStrategy');
    } else {
      _json['chunkingStrategy'] = value;
    }
  }

  /// Extra fields to include in the response, e.g. `['logprobs']`.
  List<String>? get include {
    return (_json['include'] as List?)?.cast<String>();
  }

  /// Extra fields to include in the response, e.g. `['logprobs']`.
  set include(List<String>? value) {
    if (value == null) {
      _json.remove('include');
    } else {
      _json['include'] = value;
    }
  }

  /// Translate the audio into English instead of transcribing it verbatim.
  ///
  /// Routes to `/audio/translations`, which only `whisper-1` supports.
  bool? get translate {
    return _json['translate'] as bool?;
  }

  /// Translate the audio into English instead of transcribing it verbatim.
  ///
  /// Routes to `/audio/translations`, which only `whisper-1` supports.
  set translate(bool? value) {
    if (value == null) {
      _json.remove('translate');
    } else {
      _json['translate'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OpenAITranscriptionOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OpenAITranscriptionOptionsTypeFactory
    extends SchemanticType<OpenAITranscriptionOptions> {
  const _OpenAITranscriptionOptionsTypeFactory();

  @override
  OpenAITranscriptionOptions parse(Object? json) {
    return OpenAITranscriptionOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OpenAITranscriptionOptions',
    definition: $Schema
        .object(
          properties: {
            'version': $Schema.string(),
            'language': $Schema.string(),
            'prompt': $Schema.string(),
            'temperature': $Schema.number(minimum: 0.0, maximum: 1.0),
            'responseFormat': $Schema.string(
              enumValues: ['json', 'text', 'srt', 'verbose_json', 'vtt'],
            ),
            'timestampGranularities': $Schema.list(items: $Schema.string()),
            'chunkingStrategy': $Schema.any(),
            'include': $Schema.list(items: $Schema.string()),
            'translate': $Schema.boolean(),
          },
        )
        .value,
    dependencies: [],
  );
}
