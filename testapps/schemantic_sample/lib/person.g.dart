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

part of 'person.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Person _$PersonFromJson(Map<String, dynamic> json) => Person(
  firstName: json['firstName'] as String? ?? 'John',
  lastName: json['lastName'] as String? ?? 'Doe',
);

Map<String, dynamic> _$PersonToJson(Person instance) => <String, dynamic>{
  'firstName': instance.firstName,
  'lastName': instance.lastName,
};

const _$PersonJsonSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'type': 'object',
  'properties': {
    'firstName': {'type': 'string', 'default': 'John'},
    'lastName': {'type': 'string', 'default': 'Doe'},
  },
};

RpgCharacter _$RpgCharacterFromJson(Map<String, dynamic> json) => RpgCharacter(
  name: json['name'] as String,
  alignment: json['alignment'] as String,
  backstory: json['backstory'] as String,
);

Map<String, dynamic> _$RpgCharacterToJson(RpgCharacter instance) =>
    <String, dynamic>{
      'name': instance.name,
      'alignment': instance.alignment,
      'backstory': instance.backstory,
    };

const _$RpgCharacterJsonSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'type': 'object',
  'properties': {
    'name': {'type': 'string'},
    'alignment': {'type': 'string'},
    'backstory': {'type': 'string'},
  },
  'required': ['name', 'alignment', 'backstory'],
};
