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

part of 'schemas.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JokeInput _$JokeInputFromJson(Map<String, dynamic> json) =>
    JokeInput(topic: json['topic'] as String, style: json['style'] as String);

Map<String, dynamic> _$JokeInputToJson(JokeInput instance) => <String, dynamic>{
  'topic': instance.topic,
  'style': instance.style,
};

const _$JokeInputJsonSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'type': 'object',
  'properties': {
    'topic': {
      'type': 'string',
      'description': 'The joke topic (e.g. programming, cats, cooking).',
    },
    'style': {
      'type': 'string',
      'description': 'The joke style (e.g. punny, dry, dad, knock-knock).',
    },
  },
  'required': ['topic', 'style'],
};

EmailInput _$EmailInputFromJson(Map<String, dynamic> json) => EmailInput(
  recipient: json['recipient'] as String,
  subject: json['subject'] as String,
);

Map<String, dynamic> _$EmailInputToJson(EmailInput instance) =>
    <String, dynamic>{
      'recipient': instance.recipient,
      'subject': instance.subject,
    };

const _$EmailInputJsonSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'type': 'object',
  'properties': {
    'recipient': {'type': 'string', 'description': 'The email recipient name.'},
    'subject': {'type': 'string', 'description': 'The email subject.'},
  },
  'required': ['recipient', 'subject'],
};

StoryInput _$StoryInputFromJson(Map<String, dynamic> json) => StoryInput(
  genre: json['genre'] as String,
  characters: (json['characters'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$StoryInputToJson(StoryInput instance) =>
    <String, dynamic>{
      'genre': instance.genre,
      'characters': instance.characters,
    };

const _$StoryInputJsonSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'type': 'object',
  'properties': {
    'genre': {
      'type': 'string',
      'description': 'The story genre (e.g. fantasy, sci-fi, mystery).',
    },
    'characters': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'List of character names to include.',
    },
  },
  'required': ['genre', 'characters'],
};
