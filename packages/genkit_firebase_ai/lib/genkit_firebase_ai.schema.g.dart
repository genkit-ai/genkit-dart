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

part of 'genkit_firebase_ai.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type GeminiOptions(Map<String, dynamic> _json) {
  factory GeminiOptions.from({
    required int maxOutputTokens,
    required int temperature,
  }) {
    return GeminiOptions({
      'maxOutputTokens': maxOutputTokens,
      'temperature': temperature,
    });
  }

  int get maxOutputTokens {
    return _json['maxOutputTokens'] as int;
  }

  set maxOutputTokens(int value) {
    _json['maxOutputTokens'] = value;
  }

  int get temperature {
    return _json['temperature'] as int;
  }

  set temperature(int value) {
    _json['temperature'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GeminiOptionsTypeFactory implements JsonExtensionType<GeminiOptions> {
  const GeminiOptionsTypeFactory();

  @override
  GeminiOptions parse(Object json) {
    return GeminiOptions(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'maxOutputTokens': Schema.integer(),
        'temperature': Schema.integer(),
      },
      required: ['maxOutputTokens', 'temperature'],
    );
  }
}

// ignore: constant_identifier_names
const GeminiOptionsType = GeminiOptionsTypeFactory();
