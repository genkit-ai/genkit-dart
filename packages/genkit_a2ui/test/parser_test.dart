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

final sampleBlock =
    '''
```a2ui
[
  { "createSurface": { "surfaceId": "SURFACE_ID", "catalogId": "${basicCatalog.id}" } },
  { "updateComponents": { "surfaceId": "SURFACE_ID", "components": [
    { "id": "root", "component": "Text", "text": "hi" }
  ] } }
]
```
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
      final r1 = parser.push('hello ```a2');
      expect(r1.prose, isNot(contains('```a2')));
      final result = collect(parser, [
        'ui\n[{"createSurface":{"surfaceId":"SURFACE_ID","catalogId":"'
            '${basicCatalog.id}"}}]\n```\n',
      ]);
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
```a2ui
[{ "updateComponents": { "surfaceId": "SURFACE_ID", "components": [
  { "id": "root", "component": "NotAThing" }
] } }]
```
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
```a2ui
[{ "updateComponents": { "surfaceId": "SURFACE_ID", "components": [
  { "id": "x", "component": "Text", "text": "hi" }
] } }]
```
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

    test('validate:off does not throw on bad JSON', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.off,
      );
      final result = collect(parser, ['```a2ui\n{not json}\n```\n']);
      expect(result.batches.length, 0);
    });

    test('validate:warn drops an unknown component without throwing', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.warn,
      );
      final bad = '''
```a2ui
[{ "updateComponents": { "surfaceId": "SURFACE_ID", "components": [
  { "id": "root", "component": "NotAThing" }
] } }]
```
''';
      final warnings = captureWarnings(() {
        final result = collect(parser, [bad]);
        expect(result.batches.length, 0);
      });
      expect(warnings.any((w) => w.contains('not in catalog')), isTrue);
    });

    test('validate:warn drops bad JSON without throwing', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
        validate: A2uiValidateMode.warn,
      );
      final warnings = captureWarnings(() {
        final result = collect(parser, ['```a2ui\n{not json}\n```\n']);
        expect(result.batches.length, 0);
      });
      expect(warnings.any((w) => w.contains('JSON')), isTrue);
    });

    test('prepends a createSurface when a block only has updates', () {
      final parser = A2uiStreamParser(
        catalog: basicCatalog,
        surfaceId: fixedId,
      );
      final updateOnly = '''
```a2ui
[{ "updateComponents": { "surfaceId": "SURFACE_ID", "components": [
  { "id": "root", "component": "Text", "text": "refreshed" }
] } }]
```
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
  });
}
