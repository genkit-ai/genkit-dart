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

part 'schemas.g.dart';

/// Input schema for the joke prompt.
@JsonSerializable(createJsonSchema: true)
class JokeInput {
  /// The joke topic (e.g. programming, cats, cooking).
  final String topic;

  /// The joke style (e.g. punny, dry, dad, knock-knock).
  final String style;

  JokeInput({required this.topic, required this.style});

  factory JokeInput.fromJson(Map<String, dynamic> json) =>
      _$JokeInputFromJson(json);
  Map<String, dynamic> toJson() => _$JokeInputToJson(this);

  static const jsonSchema = _$JokeInputJsonSchema;

  static final schema = SchemanticType.from<JokeInput>(
    jsonSchema: JokeInput.jsonSchema,
    parse: (json) => JokeInput.fromJson(json as Map<String, dynamic>),
  );
}

/// Input schema for the email prompt.
@JsonSerializable(createJsonSchema: true)
class EmailInput {
  /// The email recipient name.
  final String recipient;

  /// The email subject.
  final String subject;

  EmailInput({required this.recipient, required this.subject});

  factory EmailInput.fromJson(Map<String, dynamic> json) =>
      _$EmailInputFromJson(json);
  Map<String, dynamic> toJson() => _$EmailInputToJson(this);

  static const jsonSchema = _$EmailInputJsonSchema;

  static final schema = SchemanticType.from<EmailInput>(
    jsonSchema: EmailInput.jsonSchema,
    parse: (json) => EmailInput.fromJson(json as Map<String, dynamic>),
  );
}

/// Input schema for the custom story prompt.
@JsonSerializable(createJsonSchema: true)
class StoryInput {
  /// The story genre (e.g. fantasy, sci-fi, mystery).
  final String genre;

  /// List of character names to include.
  final List<String> characters;

  StoryInput({required this.genre, required this.characters});

  factory StoryInput.fromJson(Map<String, dynamic> json) =>
      _$StoryInputFromJson(json);
  Map<String, dynamic> toJson() => _$StoryInputToJson(this);

  static const jsonSchema = _$StoryInputJsonSchema;

  static final schema = SchemanticType.from<StoryInput>(
    jsonSchema: StoryInput.jsonSchema,
    parse: (json) => StoryInput.fromJson(json as Map<String, dynamic>),
  );
}
