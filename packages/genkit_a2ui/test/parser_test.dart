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

String fixedId() => 'surface-1';

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

({String prose, List<List<A2uiEnvelope>> batches}) collect(
  A2uiStreamParser parser,
  List<String> chunks,
) {
  var prose = '';
  final batches = <List<A2uiEnvelope>>[];
  for (final c in chunks) {
    final r = parser.push(c);
    prose += r.prose;
    batches.addAll(r.envelopeBatches);
  }
  final f = parser.flush();
  prose += f.prose;
  batches.addAll(f.envelopeBatches);
  return (prose: prose, batches: batches);
}

const sampleBlock = '''
<a2ui>
root = Text("hi")
</a2ui>
''';

void main() {
  group('A2uiStreamParser', () {
    test('separates prose from a complete a2ui block', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final result = collect(parser, ['Here is the weather:\n', sampleBlock]);
      expect(result.prose, contains('Here is the weather'));
      expect(result.prose, isNot(contains('createSurface')));
      expect(result.batches.length, 1);
      expect(result.batches[0].length, 2);
    });

    test('substitutes SURFACE_ID placeholder with the generated id', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final result = collect(parser, [sampleBlock]);
      final create = result.batches[0][0];
      expect((create['createSurface'] as Map)['surfaceId'], 'surface-1');
      final update = result.batches[0][1];
      expect((update['updateComponents'] as Map)['surfaceId'], 'surface-1');
    });

    test('stamps the protocol version', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        version: 'v0.9',
      );
      final result = collect(parser, [sampleBlock]);
      expect(result.batches[0][0]['version'], 'v0.9');
    });

    test('handles a block split across many tiny chunks', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final chunks = <String>[];
      for (var i = 0; i < sampleBlock.length; i += 3) {
        chunks.add(
          sampleBlock.substring(
            i,
            i + 3 < sampleBlock.length ? i + 3 : sampleBlock.length,
          ),
        );
      }
      final result = collect(parser, ['prefix ', ...chunks]);
      expect(result.prose, contains('prefix'));
      expect(result.batches.length, 1);
      expect(result.batches[0].length, 2);
    });

    test('does not leak a partial fence into prose', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      // The opening tag can be split across chunks, so a partial match must be
      // held back rather than streamed out as prose.
      final r1 = parser.push('hello <a2');
      expect(r1.prose, isNot(contains('<a2')));
      final result = collect(parser, ['ui>\nroot = Text("hi")\n</a2ui>\n']);
      expect(result.batches.length, 1);
    });

    test('emits prose with no blocks unchanged', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final result = collect(parser, ['just ', 'text ', 'here']);
      expect(result.prose, 'just text here');
      expect(result.batches.length, 0);
    });

    test('throws in strict mode on unknown component', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.strict,
      );
      final bad = '''
<a2ui>
root = NotAThing()
</a2ui>
''';
      expect(
        () => collect(parser, [bad]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not in catalog'),
          ),
        ),
      );
    });

    test('throws in strict mode when root is missing', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.strict,
      );
      final bad = '''
<a2ui>
x = Text("hi")
</a2ui>
''';
      expect(
        () => collect(parser, [bad]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('root'),
          ),
        ),
      );
    });

    test('validate:off does not throw on malformed Express', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.off,
      );
      final result = collect(parser, ['<a2ui>\nroot = Text(((\n</a2ui>\n']);
      expect(result.batches.length, 0);
    });

    test('validate:warn drops an unknown component without throwing', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.warn,
      );
      final bad = '''
<a2ui>
root = NotAThing()
</a2ui>
''';
      final warnings = captureWarnings(() {
        final result = collect(parser, [bad]);
        expect(result.batches.length, 0);
      });
      expect(warnings.any((w) => w.contains('not in catalog')), isTrue);
    });

    test('validate:warn drops malformed Express without throwing', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.warn,
      );
      final warnings = captureWarnings(() {
        final result = collect(parser, ['<a2ui>\nroot = Text(((\n</a2ui>\n']);
        expect(result.batches.length, 0);
      });
      expect(warnings.any((w) => w.contains('Express')), isTrue);
    });

    test('prepends a createSurface when a block only has updates', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final updateOnly = '''
<a2ui>
root = Text("refreshed")
</a2ui>
''';
      final result = collect(parser, [updateOnly]);
      expect(result.batches.length, 1);
      final first = result.batches[0][0];
      expect(first['createSurface'], isNotNull);
      expect((first['createSurface'] as Map)['surfaceId'], 'surface-1');
      expect((first['createSurface'] as Map)['catalogId'], basicCatalog.id);
      final update = result.batches[0][1];
      expect((update['updateComponents'] as Map)['surfaceId'], 'surface-1');
    });

    test('does not add a second createSurface when one is present', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final result = collect(parser, [sampleBlock]);
      final createCount = result.batches[0]
          .where((e) => e['createSurface'] != null)
          .length;
      expect(createCount, 1);
    });

    test('targets an explicit existing surface rather than a fresh id', () {
      // A block naming a real, pre-existing surface id (one the model learned
      // from a prior turn) must keep it, rather than being retargeted at the
      // freshly-minted id - otherwise the client drops the update as "surface
      // not found".
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final incremental = '''
<a2ui>
surface("existing-surface")
root = Text("patched")
</a2ui>
''';
      final result = collect(parser, [incremental]);
      final update = result.batches.single.firstWhere(
        (e) => e['updateComponents'] != null,
      );
      expect(
        (update['updateComponents'] as Map)['surfaceId'],
        'existing-surface',
      );
    });

    test('keeps markdown backticks inside a Text value intact', () {
      // Text "may use inline Markdown", so a value can legitimately contain a
      // ``` fence. The Express sentinel tags make this a non-issue (unlike the
      // Markdown fence they replaced, which had to be line-anchored to avoid
      // truncating the block here).
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final result = collect(parser, [
        '<a2ui>\n',
        'root = Text("Run ```npm test``` to check.")\n',
        '</a2ui>\n',
      ]);
      expect(result.batches.length, 1, reason: 'block should not truncate');
      final update = result.batches[0][1];
      final components =
          (update['updateComponents'] as Map)['components'] as List;
      expect((components[0] as Map)['text'], contains('npm test'));
    });

    test('handles two separate blocks in one turn', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final result = collect(parser, [
        sampleBlock,
        'some text between\n',
        sampleBlock,
      ]);
      expect(result.batches.length, 2);
    });

    test('preserves prose/block order in segments (prose after a block)', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final segments = <ParseSegment>[];
      for (final c in ['intro ', sampleBlock, 'outro']) {
        segments.addAll(parser.push(c).segments);
      }
      segments.addAll(parser.flush().segments);

      // Expect: prose("intro "), envelopes, prose("outro").
      expect(segments.length, 3);
      expect(segments[0], isA<ProseSegment>());
      expect((segments[0] as ProseSegment).prose, contains('intro'));
      expect(segments[1], isA<EnvelopeSegment>());
      expect(segments[2], isA<ProseSegment>());
      expect((segments[2] as ProseSegment).prose, contains('outro'));
    });

    test('rejects a block naming a component outside the catalog', () {
      // The catalog is a constructor requirement rather than something
      // `validate` can soften: Express is positional, so without it there is
      // no way to map arguments onto properties at all.
      final parser = A2uiStreamParser(
        catalog: const A2uiCatalog(id: 'empty', components: {}),
        surfaceId: fixedId,
        validate: A2uiValidateMode.warn,
      );
      final warnings = captureWarnings(() {
        final result = collect(parser, [
          '<a2ui>\nroot = Text("hi")\n</a2ui>\n',
        ]);
        expect(result.batches, isEmpty);
      });
      expect(warnings.any((w) => w.contains('not in catalog')), isTrue);
    });

    test('stamps the protocol version on every envelope', () {
      // Open-ended top-level keys still survive normalization (only `version`
      // is stamped), but Express gives the model no way to author them, so the
      // reachable behaviour is the version stamp itself.
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final result = collect(parser, [sampleBlock]);
      expect(result.batches.single.every((e) => e['version'] != null), isTrue);
    });
  });
}
