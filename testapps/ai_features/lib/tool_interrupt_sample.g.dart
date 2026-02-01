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

part of 'tool_interrupt_sample.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class TriviaQuestions {
  factory TriviaQuestions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TriviaQuestions._(this._json);

  TriviaQuestions({required String question, required List<String> answers}) {
    _json = {'question': question, 'answers': answers};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<TriviaQuestions> $schema =
      _TriviaQuestionsTypeFactory();

  String get question {
    return _json['question'] as String;
  }

  set question(String value) {
    _json['question'] = value;
  }

  List<String> get answers {
    return (_json['answers'] as List).cast<String>();
  }

  set answers(List<String> value) {
    _json['answers'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _TriviaQuestionsTypeFactory extends SchemanticType<TriviaQuestions> {
  const _TriviaQuestionsTypeFactory();

  @override
  TriviaQuestions parse(Object? json) {
    return TriviaQuestions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TriviaQuestions',
    definition: Schema.object(
      properties: {
        'question': Schema.string(description: 'the main question'),
        'answers': Schema.list(
          description:
              'list of multiple choice answers (typically 4), 1 correct 3 wrong',
          items: Schema.string(),
        ),
      },
      required: ['question', 'answers'],
    ),
    dependencies: [],
  );
}
