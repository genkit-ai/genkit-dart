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

import 'package:genkit_a2ui/a2ui.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// Runs [fn] while capturing warnings logged by the parser.
List<String> captureWarnings(void Function() fn) {
  final warnings = <String>[];
  final sub = Logger.root.onRecord.listen((record) {
    if (record.level >= Level.WARNING) warnings.add(record.message);
  });
  final prevLevel = Logger.root.level;
  Logger.root.level = Level.ALL;
  try {
    fn();
  } finally {
    Logger.root.level = prevLevel;
    sub.cancel();
  }
  return warnings;
}

/// Pushes [chunks] through [parser] and flushes, collecting every segment.
List<ParseSegment> collect(A2uiStreamParser parser, List<String> chunks) => [
  for (final c in chunks) ...parser.push(c).segments,
  ...parser.flush().segments,
];

String proseOf(List<ParseSegment> segments) => ParseResult(segments).prose;

List<List<A2uiEnvelope>> batchesOf(List<ParseSegment> segments) =>
    ParseResult(segments).envelopeBatches;

A2uiStreamParser newParser({
  A2uiValidateMode validate = A2uiValidateMode.strict,
  Iterable<String> live = const [],
}) => A2uiStreamParser(
  catalog: basicCatalog,
  validate: validate,
  history: [for (final id in live) ...renderedSurface(id)],
);

/// The messages that rendered a minimal surface [id], as history.
List<A2uiEnvelope> renderedSurface(String id) => [
  {
    'version': a2uiVersion,
    'createSurface': {'surfaceId': id, 'catalogId': basicCatalogId},
  },
  {
    'version': a2uiVersion,
    'updateComponents': {
      'surfaceId': id,
      'components': [
        {'id': 'root', 'component': 'Text', 'text': 'old'},
      ],
    },
  },
];

const weatherSource = '''
surface("tokyo")
root = Card(Column([title, temp]))
title = Text("Weather in Tokyo", "h3")
temp = Text(\$/temp)
\$/temp = "18C"''';

const weatherBlock = '<a2ui>\n$weatherSource\n</a2ui>\n';

/// The kinds of the envelopes in [batch], e.g. `[createSurface, ...]`.
List<String> kinds(List<A2uiEnvelope> batch) => [
  for (final e in batch) e.keys.firstWhere((k) => k != 'version'),
];

void main() {
  group('A2uiStreamParser', () {
    test('separates prose from a complete block', () {
      final segments = collect(newParser(), [
        'Here is the weather:\n',
        weatherBlock,
        'Anything else?',
      ]);
      // Prose before the block stays before it, prose after stays after.
      final blockAt = segments.indexWhere((s) => s is EnvelopeSegment);
      expect(proseOf(segments.sublist(0, blockAt)), 'Here is the weather:\n');
      expect(proseOf(segments.sublist(blockAt + 1)), 'Anything else?');
      expect(kinds(batchesOf(segments).single), [
        'deleteSurface',
        'createSurface',
        'updateComponents',
        'updateDataModel',
      ]);
    });

    test('keeps the model-chosen surface id on every envelope', () {
      final batch = batchesOf(collect(newParser(), [weatherBlock])).single;
      for (final e in batch) {
        final payload = e.values.whereType<Map>().single;
        expect(payload['surfaceId'], 'tokyo');
      }
    });

    test('stamps the protocol version', () {
      final batch = batchesOf(collect(newParser(), [weatherBlock])).single;
      expect(batch.map((e) => e['version']), everyElement('v0.9'));
    });

    test('keeps the Express source, without tags, on the segment', () {
      final segment = collect(newParser(), [
        weatherBlock,
      ]).whereType<EnvelopeSegment>().single;
      expect(segment.source, weatherSource);
    });

    test('strips a markdown fence the model wrapped around the block', () {
      final segment = collect(newParser(), [
        '<a2ui>\n```\nsurface("s")\nroot = Text("hi")\n```\n</a2ui>',
      ]).whereType<EnvelopeSegment>().single;
      expect(segment.source, 'surface("s")\nroot = Text("hi")');
    });

    test('handles a block split across many tiny chunks', () {
      const text = 'prefix $weatherBlock';
      final chunks = [
        for (var i = 0; i < text.length; i += 3)
          text.substring(i, i + 3 < text.length ? i + 3 : text.length),
      ];
      final segments = collect(newParser(), chunks);
      // The newline after the closing tag is consumed with it.
      expect(proseOf(segments), 'prefix ');
      expect(batchesOf(segments), hasLength(1));
    });

    test('does not leak a partial opening tag into prose', () {
      final parser = newParser();
      expect(parser.push('hello <a2').prose, isNot(contains('<a2')));
      final rest = collect(parser, ['ui>\nroot = Text("hi")\n</a2ui>\n']);
      expect(batchesOf(rest), hasLength(1));
    });

    test('emits prose with no blocks unchanged', () {
      final segments = collect(newParser(), ['just ', 'text ', 'here']);
      expect(proseOf(segments), 'just text here');
      expect(batchesOf(segments), isEmpty);
    });

    test('compiles an unterminated trailing block on flush', () {
      final segments = collect(newParser(), [
        '<a2ui>\nsurface("s")\nroot = Text("hi")\n',
      ]);
      expect(batchesOf(segments), hasLength(1));
    });

    test('handles two blocks in one response, in order', () {
      final segments = collect(newParser(), [
        'a <a2ui>\nsurface("one")\nroot = Text("1")\n</a2ui>\n',
        'b <a2ui>\nsurface("two")\nroot = Text("2")\n</a2ui>\nc',
      ]);
      expect(proseOf(segments), 'a b c');
      expect(
        batchesOf(
          segments,
        ).map((b) => (b.first['deleteSurface'] as Map)['surfaceId']),
        ['one', 'two'],
      );
    });

    test('keeps markdown backticks inside a Text value intact', () {
      final batch = batchesOf(
        collect(newParser(), [
          '<a2ui>\nsurface("s")\nroot = Text("Use `dart run` to start.")\n'
              '</a2ui>',
        ]),
      ).single;
      final components =
          (batch.last['updateComponents'] as Map)['components'] as List;
      expect((components.single as Map)['text'], 'Use `dart run` to start.');
    });

    group('tag variants', () {
      const body = 'surface("s")\nroot = Text("hi")';

      for (final (label, open, close) in [
        ('a space before >', '<a2ui >', '</a2ui >'),
        ('attributes', '<a2ui version="0.9">', '</a2ui>'),
        ('wrapping backticks', '`<a2ui>`', '`</a2ui>`'),
      ]) {
        test('accepts $label, whole or split across chunks', () {
          final text = 'Before. $open\n$body\n$close\nAfter.';
          for (final chunks in [
            [text],
            [
              for (var i = 0; i < text.length; i += 3)
                text.substring(i, i + 3 > text.length ? text.length : i + 3),
            ],
          ]) {
            final segments = collect(newParser(), chunks);
            expect(batchesOf(segments), hasLength(1));
            expect(proseOf(segments), 'Before. After.');
            final block = segments.whereType<EnvelopeSegment>().single;
            expect(block.source, body);
          }
        });
      }
    });

    group('tolerant reading', () {
      const body = 'surface("s")\nroot = Text("hi")';

      // Every way a model has been seen wrapping a block; each must parse the
      // same whole or split at any single point.
      final variants = {
        'plain': 'Before.\n<a2ui>\n$body\n</a2ui>\nAfter.',
        'backticks': 'Before.\n`<a2ui>`\n$body\n`</a2ui>`\nAfter.',
        'fenced': 'Before.\n```a2ui\n<a2ui>\n$body\n</a2ui>\n```\nAfter.',
        'spaced': 'Before.\n<a2ui >\n$body\n</a2ui >\nAfter.',
      };
      for (final MapEntry(key: name, value: text) in variants.entries) {
        test('$name, split at every point', () {
          for (var i = 0; i <= text.length; i++) {
            final segments = collect(newParser(), [
              text.substring(0, i),
              text.substring(i),
            ]);
            final reason = 'split at $i: ${text.substring(0, i)}|';
            expect(proseOf(segments), 'Before.\nAfter.', reason: reason);
            expect(
              segments.whereType<EnvelopeSegment>().single.source,
              body,
              reason: reason,
            );
          }
        });
      }

      // Prose around a block that the after-close handling must not touch;
      // each must read the same whole, split at any point, or in 3 pieces.
      final edges = {
        'blank line after': (
          'Before.\n<a2ui>\n$body\n</a2ui>\n\nAfter.',
          'Before.\n\nAfter.',
        ),
        'inline code after': (
          'Before.\n<a2ui>\n$body\n</a2ui>\n`code` after.',
          'Before.\n`code` after.',
        ),
        'code block after': (
          'Before.\n<a2ui>\n$body\n</a2ui>\n```\nx = 1\n```\n',
          'Before.\n```\nx = 1\n```\n',
        ),
        'code block before': (
          'Code:\n```\nx = 1\n```\n<a2ui>\n$body\n</a2ui>\nAfter.',
          'Code:\n```\nx = 1\n```\nAfter.',
        ),
        'fenced, closing fence alone': (
          'Before.\n```\n<a2ui>\n$body\n</a2ui>\n```\nAfter.',
          'Before.\nAfter.',
        ),
      };
      for (final MapEntry(key: name, value: (text, prose)) in edges.entries) {
        test('$name, split anywhere', () {
          final splits = [
            for (var i = 0; i <= text.length; i++) ...[
              [text.substring(0, i), text.substring(i)],
              // A short middle chunk is where a boundary inside what
              // follows a tag shows up.
              for (var j = i + 1; j <= i + 4 && j <= text.length; j++)
                [text.substring(0, i), text.substring(i, j), text.substring(j)],
            ],
          ];
          for (final chunks in splits) {
            final segments = collect(newParser(), chunks);
            final reason = 'chunks: $chunks';
            expect(proseOf(segments), prose, reason: reason);
            expect(
              segments.whereType<EnvelopeSegment>().single.source,
              body,
              reason: reason,
            );
          }
        });
      }

      test('tags mentioned in prose with a close tag stay prose', () {
        const mention = 'Wrap blocks between `<a2ui>` and `</a2ui>` tags.';
        final segments = collect(newParser(), [
          '$mention\n<a2ui>\n$body\n</a2ui>\nDone.',
        ]);
        expect(proseOf(segments), '$mention\nDone.');
        expect(batchesOf(segments), hasLength(1));
      });

      test('a block may start with any Express comment', () {
        for (final comment in ['# c', '// c', '-- c', '/* c */']) {
          final segments = collect(newParser(), ['<a2ui>\n$comment\n$body\n']);
          expect(batchesOf(segments), hasLength(1), reason: comment);
        }
      });

      test('a tag mentioned in prose stays prose', () {
        for (final text in [
          'The <a2ui> tag is how I render UI. Anything else?',
          'I can draw UI with `<a2ui>` tags if you like.',
        ]) {
          final segments = collect(newParser(validate: A2uiValidateMode.warn), [
            text,
          ]);
          expect(proseOf(segments), text);
          expect(batchesOf(segments), isEmpty);
        }
      });

      test('an unterminated block that starts like Express still compiles', () {
        final segments = collect(newParser(), ['<a2ui>\n$body\n']);
        expect(batchesOf(segments), hasLength(1));
      });
    });

    group('replacing surfaces', () {
      test('every render deletes its surface first', () {
        // The client may hold the surface whether or not the server's history
        // records it; for a new surface the delete is a no-op.
        final batch = batchesOf(collect(newParser(), [weatherBlock])).single;
        expect(kinds(batch), [
          'deleteSurface',
          'createSurface',
          'updateComponents',
          'updateDataModel',
        ]);
        expect((batch.first['deleteSurface'] as Map)['surfaceId'], 'tokyo');
      });

      test('a model delete is passed through as written', () {
        final batches = batchesOf(
          collect(newParser(), ['<a2ui>\ndeleteSurface("tokyo")\n</a2ui>\n']),
        );
        expect(kinds(batches.single), ['deleteSurface']);
      });
    });

    group('updating a surface the client already holds', () {
      test('a block without root updates it in place', () {
        final batch = batchesOf(
          collect(newParser(live: ['tokyo']), [
            '<a2ui>\nsurface("tokyo")\nroot = Column([note])\n'
                'note = Text("Windy")\n</a2ui>',
            '<a2ui>\nsurface("tokyo")\nnote = Text("Calm")\n</a2ui>',
          ]),
        );
        expect(kinds(batch.last), ['updateComponents']);
      });

      test('a data-only block updates its data model', () {
        final batch = batchesOf(
          collect(newParser(live: ['tokyo']), [
            '<a2ui>\nsurface("tokyo")\n\$/temp = "21°C"\n</a2ui>',
          ]),
        ).single;
        expect(kinds(batch), ['updateDataModel']);
      });

      test('an update must still leave a valid tree', () {
        // Compiles on its own, but `note` is unreachable from the held root.
        expect(
          () => collect(newParser(live: ['tokyo']), [
            '<a2ui>\nsurface("tokyo")\nnote = Text("x")\n</a2ui>',
          ]),
          throwsA(isA<StateError>()),
        );
      });

      test('a component an earlier update orphaned does not block updates', () {
        // Turn 2 dropped `b` from the tree; the renderer still holds it, so a
        // later update must not be judged on it.
        final parser = A2uiStreamParser(
          catalog: basicCatalog,
          history: [
            {
              'version': a2uiVersion,
              'createSurface': {'surfaceId': 's', 'catalogId': basicCatalogId},
            },
            {
              'version': a2uiVersion,
              'updateComponents': {
                'surfaceId': 's',
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': ['a', 'b'],
                  },
                  {'id': 'a', 'component': 'Text', 'text': 'A'},
                  {'id': 'b', 'component': 'Text', 'text': 'B'},
                ],
              },
            },
            {
              'version': a2uiVersion,
              'updateComponents': {
                'surfaceId': 's',
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': ['a'],
                  },
                ],
              },
            },
          ],
        );
        final batch = batchesOf(
          collect(parser, ['<a2ui>\nsurface("s")\n\$/k = "v"\n</a2ui>']),
        ).single;
        expect(kinds(batch), ['updateDataModel']);
      });

      test('a data-only update passes when history left a broken tree', () {
        final parser = A2uiStreamParser(
          catalog: basicCatalog,
          history: [
            {
              'createSurface': {'surfaceId': 's', 'catalogId': basicCatalogId},
            },
            {
              'updateComponents': {
                'surfaceId': 's',
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': ['missing'],
                  },
                ],
              },
            },
          ],
        );
        final batch = batchesOf(
          collect(parser, ['<a2ui>\nsurface("s")\n\$/k = "v"\n</a2ui>']),
        ).single;
        expect(kinds(batch), ['updateDataModel']);
      });

      group('history', () {
        A2uiEnvelope create(String id) => {
          'createSurface': {'surfaceId': id, 'catalogId': basicCatalogId},
        };
        A2uiEnvelope components(String id, List<Map<String, Object?>> c) => {
          'updateComponents': {'surfaceId': id, 'components': c},
        };
        final withA = components('s', [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['a'],
          },
          {'id': 'a', 'component': 'Text', 'text': 'A'},
        ]);
        const updateA = '<a2ui>\nsurface("s")\na = Text("new")\n</a2ui>';

        test('a surface deleted and created again starts over', () {
          final parser = A2uiStreamParser(
            catalog: basicCatalog,
            history: [
              create('s'),
              withA,
              {
                'deleteSurface': {'surfaceId': 's'},
              },
              create('s'),
              components('s', [
                {'id': 'root', 'component': 'Text', 'text': 'new'},
              ]),
            ],
          );
          // `a` went with the old surface, so it would now be unreachable.
          expect(() => collect(parser, [updateA]), throwsA(isA<StateError>()));
        });

        test('a second create without a delete keeps the old tree', () {
          // The renderer rejects creating a live surface, so `a` survives.
          final parser = A2uiStreamParser(
            catalog: basicCatalog,
            history: [create('s'), withA, create('s')],
          );
          expect(kinds(batchesOf(collect(parser, [updateA])).single), [
            'updateComponents',
          ]);
        });
      });

      test('a rejected block does not change what later blocks see', () {
        final parser = newParser(
          live: ['tokyo'],
          validate: A2uiValidateMode.warn,
        );
        final batches = batchesOf(
          collect(parser, [
            // Compiles, but the renderer rejects the orphaned `extra`, so the
            // delete in the same block never happens either.
            '<a2ui>\ndeleteSurface("tokyo")\nsurface("x")\n'
                'root = Text("r")\nextra = Text("orphan")\n</a2ui>',
            '<a2ui>\nsurface("tokyo")\n\$/temp = "21°C"\n</a2ui>',
          ]),
        );
        expect(batches.map(kinds), [
          ['updateDataModel'],
        ]);
      });
    });

    group('rejected blocks', () {
      const unknownComponent = '<a2ui>\nroot = Bogus("x")\n</a2ui>';
      const syntaxError = '<a2ui>\nroot = Text(\n</a2ui>';
      const noRoot = '<a2ui>\nsurface("s")\ntitle = Text("x")\n</a2ui>';
      const literalInIdSlot =
          '<a2ui>\nsurface("s")\n'
          'root = Button("Refresh", action=Event("r"))\n</a2ui>';

      test('strict throws on an unknown component', () {
        expect(
          () => collect(newParser(), [unknownComponent]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Bogus'),
            ),
          ),
        );
      });

      test('strict throws on a syntax error', () {
        expect(
          () => collect(newParser(), [syntaxError]),
          throwsA(isA<StateError>()),
        );
      });

      test('strict throws when root is missing', () {
        // Without `root`, a2ui_agent reads the block as an update to an
        // existing surface, which a fresh state does not hold.
        expect(
          () => collect(newParser(), [noRoot]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Surface not found'),
            ),
          ),
        );
      });

      test('strict throws on a value outside a property enum', () {
        expect(
          () => collect(newParser(), [
            '<a2ui>\nsurface("s")\nroot = Text("hi", "huge")\n</a2ui>',
          ]),
          throwsA(isA<StateError>()),
        );
      });

      test('strict throws on a string literal in a component-id slot', () {
        // The most common Express mistake: the label must be its own component.
        expect(
          () => collect(newParser(), [literalInIdSlot]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Refresh'),
            ),
          ),
        );
      });

      test('warn drops the block, logs, and keeps the prose', () {
        late List<ParseSegment> segments;
        final warnings = captureWarnings(() {
          segments = collect(newParser(validate: A2uiValidateMode.warn), [
            'before ',
            unknownComponent,
            ' after',
          ]);
        });
        expect(batchesOf(segments), isEmpty);
        expect(proseOf(segments), 'before  after');
        expect(warnings.single, contains('Bogus'));
      });

      test('off skips the renderer-side checks', () {
        // A literal in an id slot compiles, but leaves a dangling reference
        // only the renderer-side check notices.
        final batch = batchesOf(
          collect(newParser(validate: A2uiValidateMode.off), [literalInIdSlot]),
        ).single;
        expect(kinds(batch), [
          'deleteSurface',
          'createSurface',
          'updateComponents',
        ]);
      });

      test('off still drops a block that does not compile, silently', () {
        late List<ParseSegment> segments;
        final warnings = captureWarnings(() {
          segments = collect(newParser(validate: A2uiValidateMode.off), [
            syntaxError,
          ]);
        });
        expect(batchesOf(segments), isEmpty);
        expect(warnings, isEmpty);
      });
    });
  });
}
