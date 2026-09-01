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

part of 'speech.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Speech-specific options for OpenAI text-to-speech models.
base class OpenAISpeechOptions {
  /// Creates a [OpenAISpeechOptions] from a JSON map.
  factory OpenAISpeechOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OpenAISpeechOptions._(this._json);

  OpenAISpeechOptions({
    String? version,
    String? voice,
    String? instructions,
    double? speed,
    String? responseFormat,
  }) {
    _json = {
      'version': ?version,
      'voice': ?voice,
      'instructions': ?instructions,
      'speed': ?speed,
      'responseFormat': ?responseFormat,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [OpenAISpeechOptions].
  static const SchemanticType<OpenAISpeechOptions> $schema =
      _OpenAISpeechOptionsTypeFactory();

  /// Model version override (e.g., 'tts-1-1106')
  String? get version {
    return _json['version'] as String?;
  }

  /// Model version override (e.g., 'tts-1-1106')
  set version(String? value) {
    if (value == null) {
      _json.remove('version');
    } else {
      _json['version'] = value;
    }
  }

  /// Voice used to render the audio (e.g. 'alloy', 'sage', 'coral').
  ///
  /// Left free-form on purpose: OpenAI adds voices without warning, and an
  /// enum here would reject them until the plugin shipped a new release.
  /// Defaults to 'alloy' when unset.
  String? get voice {
    return _json['voice'] as String?;
  }

  /// Voice used to render the audio (e.g. 'alloy', 'sage', 'coral').
  ///
  /// Left free-form on purpose: OpenAI adds voices without warning, and an
  /// enum here would reject them until the plugin shipped a new release.
  /// Defaults to 'alloy' when unset.
  set voice(String? value) {
    if (value == null) {
      _json.remove('voice');
    } else {
      _json['voice'] = value;
    }
  }

  /// Tone and delivery guidance, e.g. 'Speak in a calm, warm tone.'
  ///
  /// Only honored by `gpt-4o-mini-tts`; the `tts-1` family ignores it.
  String? get instructions {
    return _json['instructions'] as String?;
  }

  /// Tone and delivery guidance, e.g. 'Speak in a calm, warm tone.'
  ///
  /// Only honored by `gpt-4o-mini-tts`; the `tts-1` family ignores it.
  set instructions(String? value) {
    if (value == null) {
      _json.remove('instructions');
    } else {
      _json['instructions'] = value;
    }
  }

  /// Playback speed multiplier (0.25 - 4.0).
  ///
  /// Not supported by `gpt-4o-mini-tts`, which rejects the field outright.
  double? get speed {
    return (_json['speed'] as num?)?.toDouble();
  }

  /// Playback speed multiplier (0.25 - 4.0).
  ///
  /// Not supported by `gpt-4o-mini-tts`, which rejects the field outright.
  set speed(double? value) {
    if (value == null) {
      _json.remove('speed');
    } else {
      _json['speed'] = value;
    }
  }

  /// Audio container for the generated speech. Defaults to 'mp3'.
  String? get responseFormat {
    return _json['responseFormat'] as String?;
  }

  /// Audio container for the generated speech. Defaults to 'mp3'.
  set responseFormat(String? value) {
    if (value == null) {
      _json.remove('responseFormat');
    } else {
      _json['responseFormat'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [OpenAISpeechOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OpenAISpeechOptionsTypeFactory
    extends SchemanticType<OpenAISpeechOptions> {
  const _OpenAISpeechOptionsTypeFactory();

  @override
  OpenAISpeechOptions parse(Object? json) {
    return OpenAISpeechOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OpenAISpeechOptions',
    definition: $Schema
        .object(
          properties: {
            'version': $Schema.string(),
            'voice': $Schema.string(),
            'instructions': $Schema.string(),
            'speed': $Schema.number(minimum: 0.25, maximum: 4.0),
            'responseFormat': $Schema.string(
              enumValues: ['mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'],
            ),
          },
        )
        .value,
    dependencies: [],
  );
}
