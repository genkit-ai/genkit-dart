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

import 'package:json_annotation/json_annotation.dart';
import 'package:schemantic/schemantic.dart';

part 'person.g.dart';

@JsonSerializable(createJsonSchema: true)
class Person {
  @JsonKey(defaultValue: 'John')
  final String firstName;

  @JsonKey(defaultValue: 'Doe')
  final String lastName;

  Person({required this.firstName, required this.lastName});

  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);
  Map<String, dynamic> toJson() => _$PersonToJson(this);

  static const jsonSchema = _$PersonJsonSchema;

  static final schema = SchemanticType.from<Person>(
    jsonSchema: Person.jsonSchema,
    parse: (json) => Person.fromJson(json as Map<String, dynamic>),
  );
}

@JsonSerializable(createJsonSchema: true)
class RpgCharacter {
  final String name;
  final String alignment;
  final String backstory;

  RpgCharacter({
    required this.name,
    required this.alignment,
    required this.backstory,
  });

  factory RpgCharacter.fromJson(Map<String, dynamic> json) =>
      _$RpgCharacterFromJson(json);
  Map<String, dynamic> toJson() => _$RpgCharacterToJson(this);

  static const jsonSchema = _$RpgCharacterJsonSchema;

  static final schema = SchemanticType.from<RpgCharacter>(
    jsonSchema: RpgCharacter.jsonSchema,
    parse: (json) => RpgCharacter.fromJson(json as Map<String, dynamic>),
  );
}
