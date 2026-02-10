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

class RetryOptions {
  factory RetryOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RetryOptions._(this._json);

  RetryOptions({
    int? maxRetries,
    List<StatusCodes>? statuses,
    int? initialDelayMs,
    int? maxDelayMs,
    double? backoffFactor,
    bool? noJitter,
    bool? retryModel,
    bool? retryTools,
  }) {
    _json = {
      'maxRetries': ?maxRetries,
      'statuses': ?statuses,
      'initialDelayMs': ?initialDelayMs,
      'maxDelayMs': ?maxDelayMs,
      'backoffFactor': ?backoffFactor,
      'noJitter': ?noJitter,
      'retryModel': ?retryModel,
      'retryTools': ?retryTools,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<RetryOptions> $schema =
      _RetryOptionsTypeFactory();

  int? get maxRetries {
    return _json['maxRetries'] as int?;
  }

  set maxRetries(int? value) {
    if (value == null) {
      _json.remove('maxRetries');
    } else {
      _json['maxRetries'] = value;
    }
  }

  List<StatusCodes>? get statuses {
    return (_json['statuses'] as List?)?.cast<StatusCodes>();
  }

  set statuses(List<StatusCodes>? value) {
    if (value == null) {
      _json.remove('statuses');
    } else {
      _json['statuses'] = value;
    }
  }

  int? get initialDelayMs {
    return _json['initialDelayMs'] as int?;
  }

  set initialDelayMs(int? value) {
    if (value == null) {
      _json.remove('initialDelayMs');
    } else {
      _json['initialDelayMs'] = value;
    }
  }

  int? get maxDelayMs {
    return _json['maxDelayMs'] as int?;
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

  bool? get retryModel {
    return _json['retryModel'] as bool?;
  }

  set retryModel(bool? value) {
    if (value == null) {
      _json.remove('retryModel');
    } else {
      _json['retryModel'] = value;
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _RetryOptionsTypeFactory extends SchemanticType<RetryOptions> {
  const _RetryOptionsTypeFactory();

  @override
  RetryOptions parse(Object? json) {
    return RetryOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RetryOptions',
    definition: Schema.object(
      properties: {
        'maxRetries': Schema.integer(),
        'statuses': Schema.list(
          items: Schema.string(
            enumValues: [
              'OK',
              'CANCELLED',
              'UNKNOWN',
              'INVALID_ARGUMENT',
              'DEADLINE_EXCEEDED',
              'NOT_FOUND',
              'ALREADY_EXISTS',
              'PERMISSION_DENIED',
              'UNAUTHENTICATED',
              'RESOURCE_EXHAUSTED',
              'FAILED_PRECONDITION',
              'ABORTED',
              'OUT_OF_RANGE',
              'UNIMPLEMENTED',
              'INTERNAL',
              'UNAVAILABLE',
              'DATA_LOSS',
            ],
          ),
        ),
        'initialDelayMs': Schema.integer(),
        'maxDelayMs': Schema.integer(),
        'backoffFactor': Schema.number(),
        'noJitter': Schema.boolean(),
        'retryModel': Schema.boolean(),
        'retryTools': Schema.boolean(),
      },
      required: [],
    ),
    dependencies: [],
  );
}
