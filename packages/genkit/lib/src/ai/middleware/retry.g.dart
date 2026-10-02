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

part of 'retry.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class RetryOptions {
  /// Creates a [RetryOptions] from a JSON map.
  factory RetryOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RetryOptions._(this._json);

  RetryOptions({
    int? maxRetries,
    List<String>? statuses,
    int? initialDelayMs,
    int? maxDelayMs,
    double? backoffFactor,
    bool? noJitter,
    bool? noRetryModel,
    bool? retryTools,
  }) {
    _json = {
      'maxRetries': ?maxRetries,
      'statuses': ?statuses,
      'initialDelayMs': ?initialDelayMs,
      'maxDelayMs': ?maxDelayMs,
      'backoffFactor': ?backoffFactor,
      'noJitter': ?noJitter,
      'noRetryModel': ?noRetryModel,
      'retryTools': ?retryTools,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [RetryOptions].
  static const SchemanticType<RetryOptions> $schema =
      _RetryOptionsTypeFactory();

  int? get maxRetries {
    return (_json['maxRetries'] as num?)?.toInt();
  }

  set maxRetries(int? value) {
    if (value == null) {
      _json.remove('maxRetries');
    } else {
      _json['maxRetries'] = value;
    }
  }

  List<String>? get statuses {
    return (_json['statuses'] as List?)?.cast<String>();
  }

  set statuses(List<String>? value) {
    if (value == null) {
      _json.remove('statuses');
    } else {
      _json['statuses'] = value;
    }
  }

  int? get initialDelayMs {
    return (_json['initialDelayMs'] as num?)?.toInt();
  }

  set initialDelayMs(int? value) {
    if (value == null) {
      _json.remove('initialDelayMs');
    } else {
      _json['initialDelayMs'] = value;
    }
  }

  int? get maxDelayMs {
    return (_json['maxDelayMs'] as num?)?.toInt();
  }

  set maxDelayMs(int? value) {
    if (value == null) {
      _json.remove('maxDelayMs');
    } else {
      _json['maxDelayMs'] = value;
    }
  }

  double? get backoffFactor {
    return (_json['backoffFactor'] as num?)?.toDouble();
  }

  set backoffFactor(double? value) {
    if (value == null) {
      _json.remove('backoffFactor');
    } else {
      _json['backoffFactor'] = value;
    }
  }

  bool? get noJitter {
    return _json['noJitter'] as bool?;
  }

  set noJitter(bool? value) {
    if (value == null) {
      _json.remove('noJitter');
    } else {
      _json['noJitter'] = value;
    }
  }

  bool? get noRetryModel {
    return _json['noRetryModel'] as bool?;
  }

  set noRetryModel(bool? value) {
    if (value == null) {
      _json.remove('noRetryModel');
    } else {
      _json['noRetryModel'] = value;
    }
  }

  bool? get retryTools {
    return _json['retryTools'] as bool?;
  }

  set retryTools(bool? value) {
    if (value == null) {
      _json.remove('retryTools');
    } else {
      _json['retryTools'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [RetryOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RetryOptionsTypeFactory extends SchemanticType<RetryOptions> {
  const _RetryOptionsTypeFactory();

  @override
  RetryOptions parse(Object? json) {
    return RetryOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RetryOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'maxRetries': <String, Object?>{'type': 'integer'},
        'statuses': <String, Object?>{
          'type': 'array',
          'description':
              'Canonical status names that trigger a retry (e.g. UNAVAILABLE).',
          'items': <String, Object?>{'type': 'string'},
        },
        'initialDelayMs': <String, Object?>{'type': 'integer'},
        'maxDelayMs': <String, Object?>{'type': 'integer'},
        'backoffFactor': <String, Object?>{'type': 'number'},
        'noJitter': <String, Object?>{'type': 'boolean'},
        'noRetryModel': <String, Object?>{'type': 'boolean'},
        'retryTools': <String, Object?>{'type': 'boolean'},
      },
    },
    dependencies: [],
  );
}
