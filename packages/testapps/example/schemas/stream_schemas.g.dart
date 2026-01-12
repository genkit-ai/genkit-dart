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

part of 'stream_schemas.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StreamInput _$StreamInputFromJson(Map<String, dynamic> json) => StreamInput(
      prompt: json['prompt'] as String,
    );

Map<String, dynamic> _$StreamInputToJson(StreamInput instance) =>
    <String, dynamic>{
      'prompt': instance.prompt,
    };

StreamOutput _$StreamOutputFromJson(Map<String, dynamic> json) => StreamOutput(
      text: json['text'] as String,
      summary: json['summary'] as String,
    );

Map<String, dynamic> _$StreamOutputToJson(StreamOutput instance) =>
    <String, dynamic>{
      'text': instance.text,
      'summary': instance.summary,
    };
