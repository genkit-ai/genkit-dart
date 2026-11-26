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

import 'dart:convert';

import 'package:genkit/genkit.dart' hide Score;
import 'package:genkit_systemone/genkit_systemone.dart';
import 'package:genkit_systemone/src/protocol/questions.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import 'test_types.dart';

Map<String, Object?> wire(Map<String, WireQuestion> questions) =>
    (jsonDecode(
              jsonEncode({
                for (final e in questions.entries) e.key: e.value.toJson(),
              }),
            )
            as Map)
        .cast<String, Object?>();

Matcher throwsInvalid(Object message) => throwsA(
  isA<GenkitException>()
      .having((e) => e.status, 'status', StatusCode.invalidArgument)
      .having((e) => e.message, 'message', message),
);

/// The schema generate sends a model for [type].
Map<String, dynamic> toJsonSchema(SchemanticType<Object?> type) =>
    type.jsonSchema(useRefs: true);

void main() {
  group('decision schema', () {
    test('compiles every question type to the wire', () {
      final questions = wire(
        compileQuestions(toJsonSchema(Triage.$schema), ''),
      );
      expect(questions.keys, [
        'deadline',
        'department',
        'frustration',
        'is_urgent',
      ]);
      expect(questions['department'], {
        'type': 'choice',
        'instructions': 'Which team should handle this?',
        // Sorted by name, as Go and Java send them; guidance in place of the
        // string, with the string as its what.
        'criteria': {
          'billing': {
            'not_for': 'Where an order is, or when it arrives',
            'examples': ['I was charged twice for one order.'],
            'what': 'Payments, invoicing, refunds',
          },
          'other': 'None of the above',
          'technical': 'Bugs, outages, integrations',
        },
      });
      expect(
        ((jsonDecode(jsonEncode(questions['department'])) as Map)['criteria']
                as Map)
            .keys,
        ['billing', 'other', 'technical'],
      );
      expect(questions['frustration'], {
        'type': 'score',
        'instructions': 'How frustrated is the customer?',
        'criteria': [
          'Calm',
          'Concerned but civil',
          {
            'signals': ['all caps', 'threats to leave'],
            'what': 'Very angry',
          },
        ],
      });
      expect(questions['is_urgent'], {
        'type': 'noul',
        'instructions': 'Does the ticket explicitly communicate time pressure?',
      });
      expect(questions['deadline'], {
        'type': 'noul',
        'instructions': 'Is there a deadline?',
        'criteria': {
          'true': 'Names a deadline, or says now or today',
          'false': 'No time pressure is expressed',
        },
      });
    });

    test('the system preamble and the schema description lead', () {
      final schema = toJsonSchema(
        decisionSchema(
          {'urgent': Noul.schema(description: 'Is it urgent?')},
          (a) => a,
          description: 'The state is a support ticket.',
        ),
      );
      final q = compileQuestions(schema, 'Be strict.')['urgent']!;
      expect(
        q.instructions,
        'Be strict.\n\nThe state is a support ticket.\n\nIs it urgent?',
      );
    });

    test('parses the answers into typed fields', () {
      final triage = Triage.$schema.parse({
        'department': {
          'choice': 'billing',
          'probabilities': {'billing': 0.8, 'other': 0.1, 'technical': 0.1},
          'confidence': 0.7,
        },
        'is_urgent': {'noul': 0.93},
        'frustration': {
          'score': 1.6,
          'probabilities': {'0': 0.1, '1': 0.2, '2': 0.7},
          'confidence': 0.5,
          'legend': {
            '0': 'Calm',
            '1': 'Concerned but civil',
            '2': 'Very angry',
          },
        },
        'deadline': {'noul': 0.2},
      });
      expect(triage.department.choice, Dept.billing);
      expect(triage.department.ranked, [
        Dept.billing,
        Dept.other,
        Dept.technical,
      ]);
      expect(triage.department.margin, closeTo(0.7, 1e-9));
      expect(triage.isUrgent.probability, 0.93);
      expect(triage.frustration.level, 2);
      expect(triage.frustration.label, 'Very angry');
      expect(triage.deadline.probability, 0.2);
    });

    test('an option the type does not have fails the parse', () {
      expect(
        () => Choice.schema(Dept.values).parse({'choice': 'sales'}),
        throwsFormatException,
      );
    });

    test('a score level is clamped to the rubric', () {
      final schema = ScoreOf.schema(Anger.values);
      expect(schema.parse({'score': -0.4}).level, 0);
      expect(schema.parse({'score': 2.6}).label, 'Very angry');
    });

    test('a question without instructions is refused', () {
      expect(
        () => compileQuestions(
          toJsonSchema(decisionSchema({'x': Noul.schema()}, (a) => a)),
          '',
        ),
        throwsInvalid(contains('question "x" has no instructions')),
      );
    });

    test('an output type field that is not a question is refused', () {
      expect(
        () => compileQuestions({
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'A name'},
          },
        }, ''),
        throwsInvalid(contains('field "name" is not a question')),
      );
    });

    test('a schema with no properties is refused', () {
      expect(
        () => compileQuestions({'type': 'object'}, ''),
        throwsInvalid(contains('has no properties')),
      );
    });

    test('a registered schema reached by reference compiles', () {
      final schema = {
        r'$ref': r'#/$defs/Triage',
        r'$defs': {'Triage': toJsonSchema(Triage.$schema)},
      };
      expect(compileQuestions(schema, '').keys, hasLength(4));
    });
  });

  group('runtime questions', () {
    test('keep the options in the order given', () {
      final questions = wire(
        compileQuestions(
          toJsonSchema(
            questionsSchema({
              'tool': ChoiceQuestion(
                instructions: 'Which tool serves the request?',
                options: [
                  ChoiceOption('weather', criteria: 'Forecasts'),
                  ChoiceOption('calendar'),
                  ChoiceOption(
                    'mail',
                    criteria: 'Email',
                    guidance: ['inbox', 'drafts'],
                  ),
                ],
              ),
            }),
          ),
          '',
        ),
      );
      final criteria = (questions['tool'] as Map)['criteria'] as Map;
      // wire() round-trips through JSON text, so this is the order sent.
      expect(criteria.keys, ['weather', 'calendar', 'mail']);
      // An option with neither criteria nor guidance is described by its
      // name; guidance that is not an object goes out as it is.
      expect(criteria, {
        'weather': 'Forecasts',
        'calendar': 'calendar',
        'mail': ['inbox', 'drafts'],
      });
    });

    test(
      'structured instructions take the preamble as their first element',
      () {
        final schema = toJsonSchema(
          questionsSchema({
            'effort': ScoreQuestion(
              instructions: {'field': 'request'},
              levels: ['A lookup', 'A few steps', 'A project'],
              guidance: {1: 'Two or three tools'},
            ),
            'steps': ScoreQuestion(
              instructions: ['Rate it.', 'Be strict.'],
              levels: ['Few', 'Many'],
            ),
          }),
        );
        final questions = wire(compileQuestions(schema, 'Shared context.'));
        expect(questions['effort'], {
          'type': 'score',
          'instructions': [
            'Shared context.',
            {'field': 'request'},
          ],
          'criteria': ['A lookup', 'Two or three tools', 'A project'],
        });
        expect((questions['steps'] as Map)['instructions'], [
          'Shared context.',
          'Rate it.',
          'Be strict.',
        ]);
      },
    );

    test('a noul says both sides or neither', () {
      final schema = toJsonSchema(
        questionsSchema({
          'half': NoulQuestion(instructions: 'Is it?', yes: 'Yes it is'),
        }),
      );
      expect(
        () => compileQuestions(schema, ''),
        throwsInvalid(contains('says what only one side means')),
      );
      final guided = toJsonSchema(
        questionsSchema({
          'guided': NoulQuestion(
            instructions: 'Is it?',
            yesGuidance: {'what': 'Yes'},
            no: 'No',
          ),
        }),
      );
      expect(compileQuestions(guided, '')['guided']!.criteria, {
        'true': {'what': 'Yes'},
        'false': 'No',
      });
    });

    test('a score needs two levels, and guidance only for its levels', () {
      expect(
        () => compileQuestions(
          toJsonSchema(
            questionsSchema({
              's': ScoreQuestion(instructions: 'Rate', levels: ['Only']),
            }),
          ),
          '',
        ),
        throwsInvalid(contains('needs at least two levels')),
      );
      expect(
        () => compileQuestions(
          toJsonSchema(
            questionsSchema({
              's': ScoreQuestion(
                instructions: 'Rate',
                levels: ['Low', 'High'],
                guidance: {2: 'Off the scale'},
              ),
            }),
          ),
          '',
        ),
        throwsInvalid(contains('guidance for level 2')),
      );
    });

    test('a choice lists each option once, with guidance only for them', () {
      expect(
        () => compileQuestions(
          toJsonSchema(
            questionsSchema({
              'c': ChoiceQuestion(
                instructions: 'Pick',
                options: [ChoiceOption('a'), ChoiceOption('a')],
              ),
            }),
          ),
          '',
        ),
        throwsInvalid(contains('lists option "a" twice')),
      );
      final schema = toJsonSchema(
        questionsSchema({
          'c': ChoiceQuestion(
            instructions: 'Pick',
            options: [ChoiceOption('a')],
          ),
        }),
      );
      ((schema['properties'] as Map)['c'] as Map)[guidanceKeyword] = {
        'b': 'not an option',
      };
      expect(
        () => compileQuestions(schema, ''),
        throwsInvalid(contains('guidance for "b"')),
      );
    });

    test('answers decode with their kind inferred, and keep zeros', () {
      final answers = questionsSchema({}).parse({
        'tool': {
          'choice': 'mail',
          'probabilities': {'mail': 1.0},
          'confidence': 0.0,
        },
        'effort': {'score': 0, 'confidence': 0.2},
        'personal': {'noul': 0.1},
      });
      expect(answers['tool']!.type, 'choice');
      expect(answers['effort']!.type, 'score');
      expect(answers['personal']!.type, 'noul');
      expect(answers['tool']!.toJson(), {
        'type': 'choice',
        'choice': 'mail',
        'probabilities': {'mail': 1.0},
        'confidence': 0.0,
      });
      expect(answers['effort']!.toJson(), {
        'type': 'score',
        'score': 0.0,
        'confidence': 0.2,
      });
      expect(answers['personal']!.toJson(), {'type': 'noul', 'noul': 0.1});
    });
  });

  group('enum format', () {
    test('is one choice whose instructions are the preamble', () {
      final questions = wire(
        enumQuestion({
          'type': 'string',
          'enum': ['sales', 'billing'],
        }, 'Which team?'),
      );
      expect(questions, {
        'choice': {
          'type': 'choice',
          'instructions': 'Which team?',
          'criteria': {'sales': 'sales', 'billing': 'billing'},
        },
      });
    });

    test('keeps the values in order on the wire, and follows a reference', () {
      final questions = enumQuestion({
        r'$ref': r'#/$defs/Team',
        r'$defs': {
          'Team': {
            'type': 'string',
            'enum': ['sales', 'billing', 'technical'],
          },
        },
      }, '');
      expect(
        jsonEncode(questions['choice']!.criteria),
        '{"sales":"sales","billing":"billing","technical":"technical"}',
      );
    });

    test('has default instructions, and refuses empty or repeated values', () {
      expect(
        enumQuestion({
          'enum': ['a', 'b'],
        }, '')['choice']!.instructions,
        'Choose the option that best describes the state.',
      );
      expect(
        () => enumQuestion({
          'enum': ['a', 'a'],
        }, ''),
        throwsInvalid(contains('lists "a" twice')),
      );
      expect(
        () => enumQuestion({
          'enum': ['a', ''],
        }, ''),
        throwsInvalid(contains('non-empty strings')),
      );
      expect(
        () => enumQuestion({'enum': <String>[]}, ''),
        throwsInvalid(contains('lists no values')),
      );
    });
  });
}
