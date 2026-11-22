// Copyright 2026 Google LLC
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

import 'package:genkit/plugin.dart';

/// What a decision model's response carries beside the answers in the
/// message: the model version that answered, which is what confidence
/// thresholds are tuned against, a gateway's provider and generation ID, and
/// the answers as the API sent them, guidance echoes and fields the answer
/// types do not declare included.
///
/// It is the response's `raw`; [SystemOneInfo.of] reads it.
///
/// Preview: this API may change in any minor release.
final class SystemOneInfo {
  SystemOneInfo({
    this.model = '',
    this.provider = '',
    this.id = '',
    Map<String, Map<String, Object?>> answers = const {},
  }) : answers = Map.unmodifiable({
         for (final e in answers.entries) e.key: _frozen(e.value),
       });

  /// Reads the info from its JSON, such as a response's `raw`, a flow's
  /// output, or a stored trace.
  factory SystemOneInfo.fromJson(Map<String, Object?> json) => SystemOneInfo(
    model: json['model'] is String ? json['model'] as String : '',
    provider: json['provider'] is String ? json['provider'] as String : '',
    id: json['id'] is String ? json['id'] as String : '',
    answers: {
      if (json['answers'] case final Map answers)
        for (final e in answers.entries)
          if (e.value is Map)
            '${e.key}': (e.value as Map).cast<String, Object?>(),
    },
  );

  /// The info of a decision model's [response], or of the response of a
  /// generate call's result. It is empty for a response from any other model.
  static SystemOneInfo of(ModelResponse? response) {
    final raw = response?.raw;
    if (raw == null) return SystemOneInfo();
    return SystemOneInfo.fromJson(raw);
  }

  /// The model version that answered.
  final String model;

  /// The provider a gateway routed the request to; empty from a model
  /// vendor's own API.
  final String provider;

  /// A gateway's generation ID; empty from a model vendor's own API.
  final String id;

  /// The answers as the API sent them, keyed by question ID: a deep,
  /// unmodifiable copy, so it does not alias the response's `raw`.
  final Map<String, Map<String, Object?>> answers;

  Map<String, Object?> toJson() => {
    'model': model,
    if (provider.isNotEmpty) 'provider': provider,
    if (id.isNotEmpty) 'id': id,
    if (answers.isNotEmpty) 'answers': answers,
  };

  @override
  String toString() => 'SystemOneInfo${toJson()}';
}

/// A deep, unmodifiable copy of a JSON value.
Map<String, Object?> _frozen(Map<String, Object?> map) =>
    Map.unmodifiable({for (final e in map.entries) e.key: _freeze(e.value)});

Object? _freeze(Object? value) => switch (value) {
  Map() => Map<String, Object?>.unmodifiable({
    for (final e in value.entries) '${e.key}': _freeze(e.value),
  }),
  List() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};
