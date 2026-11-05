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
import 'package:genkit_a2ui/src/parser.dart' show liveSurfaceIds;
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
  liveSurfaceIds: live,
);

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
        ).map((b) => (b.first['createSurface'] as Map)['surfaceId']),
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

    group('re-rendering a surface the client already holds', () {
      test('deletes it first so the new render replaces it', () {
        final batch = batchesOf(
          collect(newParser(live: ['tokyo']), [weatherBlock]),
        ).single;
        expect(kinds(batch), [
          'deleteSurface',
          'createSurface',
          'updateComponents',
          'updateDataModel',
        ]);
        expect((batch.first['deleteSurface'] as Map)['surfaceId'], 'tokyo');
      });

      test('also when the same response renders it twice', () {
        final batches = batchesOf(
          collect(newParser(), [weatherBlock, 'and again ', weatherBlock]),
        );
        expect(kinds(batches[0]).first, 'createSurface');
        expect(kinds(batches[1]).first, 'deleteSurface');
      });

      test('but not after the model deleted it', () {
        final batches = batchesOf(
          collect(newParser(live: ['tokyo']), [
            '<a2ui>\ndeleteSurface("tokyo")\n</a2ui>\n',
            weatherBlock,
          ]),
        );
        expect(kinds(batches[0]), ['deleteSurface']);
        expect(kinds(batches[1]).first, 'createSurface');
      });

      test('leaves other surfaces alone', () {
        final batch = batchesOf(
          collect(newParser(live: ['paris']), [weatherBlock]),
        ).single;
        expect(kinds(batch).first, 'createSurface');
      });
    });

    group('liveSurfaceIds', () {
      test('tracks creates and deletes in order', () {
        A2uiEnvelope create(String id) => {
          'createSurface': {'surfaceId': id, 'catalogId': 'c'},
        };
        A2uiEnvelope delete(String id) => {
          'deleteSurface': {'surfaceId': id},
        };
        expect(liveSurfaceIds([create('a'), create('b'), delete('a')]), {'b'});
        expect(liveSurfaceIds([delete('a'), create('a')]), {'a'});
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
        expect(kinds(batch), ['createSurface', 'updateComponents']);
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
