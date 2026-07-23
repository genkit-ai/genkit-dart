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

import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

final sampleText =
    '''Here is the weather:
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
  group('a2ui() middleware', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false, plugins: [A2uiPlugin()]);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    /// Defines a model that replies with [reply] (echoing any system prompt via
    /// [onRequest] for assertions).
    void defineReplyModel(
      String name,
      String reply, {
      void Function(ModelRequest req)? onRequest,
    }) {
      genkit.defineModel(
        name: name,
        fn: (req, ctx) async {
          onRequest?.call(req);
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: reply)],
            ),
          );
        },
      );
    }

    test(
      'defaults to the bundled basic catalog and injects instructions',
      () async {
        ModelRequest? seen;
        defineReplyModel('m1', 'ok', onRequest: (r) => seen = r);

        await genkit.generate(
          model: modelRef('m1'),
          system: 'You are helpful.',
          prompt: 'hi',
          use: [a2ui()],
        );

        final sys = seen!.messages.firstWhere((m) => m.role == Role.system);
        final joined = sys.content.map((p) => p.text ?? '').join();
        expect(joined, contains('You are helpful.'));
        expect(joined, contains('Rendering UI with A2UI'));
        expect(joined, contains('Available components'));
      },
    );

    test('creates a system prompt when none exists', () async {
      ModelRequest? seen;
      defineReplyModel('m2', 'ok', onRequest: (r) => seen = r);

      await genkit.generate(model: modelRef('m2'), prompt: 'hi', use: [a2ui()]);

      final sys = seen!.messages.firstWhere((m) => m.role == Role.system);
      expect(sys.content.first.text, contains('Rendering UI with A2UI'));
    });

    test('resolves a custom catalog registered by id', () async {
      await loadCatalog(
        genkit.registry,
        id: 'my-catalog',
        catalog: const A2uiCatalog(
          id: 'my-catalog',
          components: [
            A2uiCatalogComponent(
              name: 'Widget',
              description: 'A widget.',
              props: 'label: string.',
            ),
          ],
        ),
      );
      ModelRequest? seen;
      defineReplyModel('m3', 'ok', onRequest: (r) => seen = r);

      await genkit.generate(
        model: modelRef('m3'),
        system: 'sys',
        prompt: 'hi',
        use: [a2ui(catalog: 'my-catalog')],
      );

      final sys = seen!.messages.firstWhere((m) => m.role == Role.system);
      final joined = sys.content.map((p) => p.text ?? '').join();
      expect(joined, contains('Widget: A widget.'));
      expect(joined, contains('my-catalog'));
    });

    test('throws when an unknown catalog id is configured', () async {
      defineReplyModel('m4', 'ok');
      await expectLater(
        genkit.generate(
          model: modelRef('m4'),
          system: 'sys',
          prompt: 'hi',
          use: [a2ui(catalog: 'nope')],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no catalog registered under id "nope"'),
          ),
        ),
      );
    });

    test('instructions:none injects nothing', () async {
      ModelRequest? seen;
      defineReplyModel('m5', 'ok', onRequest: (r) => seen = r);

      await genkit.generate(
        model: modelRef('m5'),
        system: 'sys',
        prompt: 'hi',
        use: [a2ui(instructions: 'none')],
      );

      final sys = seen!.messages.firstWhere((m) => m.role == Role.system);
      final joined = sys.content.map((p) => p.text ?? '').join();
      expect(joined, isNot(contains('Rendering UI with A2UI')));
    });

    test('rewrites the final message: prose text + a2ui part', () async {
      defineReplyModel('m6', sampleText);

      final res = await genkit.generate(
        model: modelRef('m6'),
        system: 'sys',
        prompt: 'weather',
        use: [a2ui(surfaceId: 'sfc')],
      );

      final content = res.message!.content;
      final textPart = content.where((p) => p.isText).firstOrNull;
      final uiPart = content.where(isA2uiPart).firstOrNull;
      expect(textPart, isNotNull);
      expect(textPart!.text, contains('Here is the weather'));
      expect(uiPart, isNotNull);

      final envelopes = a2uiEnvelopes(res.message);
      expect(envelopes.length, 2);
      expect((envelopes[0]['createSurface'] as Map)['surfaceId'], 'sfc');
    });

    test('leaves plain prose responses untouched (no a2ui parts)', () async {
      defineReplyModel('m7', 'just chatting');

      final res = await genkit.generate(
        model: modelRef('m7'),
        system: 'sys',
        prompt: 'hi',
        use: [a2ui()],
      );

      final content = res.message!.content;
      expect(content.any(isA2uiPart), isFalse);
      expect(a2uiEnvelopes(res.message).length, 0);
    });

    test('defaults to validate:warn - drops a bad block, keeps the turn '
        'alive', () async {
      // A hallucinated component would throw under strict, killing the turn.
      // With the warn default the block is dropped and prose survives.
      final bad = '''oops:
```a2ui
[{ "updateComponents": { "surfaceId": "SURFACE_ID", "components": [
  { "id": "root", "component": "NotAThing" }
] } }]
```
''';
      defineReplyModel('m_warn', bad);

      final warnings = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        if (record.level >= Level.WARNING) warnings.add(record.message);
      });
      final prevLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final GenerateResponse res;
      try {
        res = await genkit.generate(
          model: modelRef('m_warn'),
          system: 'sys',
          prompt: 'hi',
          use: [a2ui()],
        );
      } finally {
        Logger.root.level = prevLevel;
        await sub.cancel();
      }

      final content = res.message!.content;
      // No a2ui parts (the bad block was dropped), but prose is preserved.
      expect(content.any(isA2uiPart), isFalse);
      final text = content.where((p) => p.isText).map((p) => p.text).join();
      expect(text, contains('oops'));
      expect(warnings.any((w) => w.contains('not in catalog')), isTrue);
    });

    test(
      'preserves prose ordering around a block in the final message',
      () async {
        final mixed =
            'intro\n${sampleText.replaceFirst('Here is the weather:\n', '')}outro';
        defineReplyModel('m_order', mixed);

        final res = await genkit.generate(
          model: modelRef('m_order'),
          system: 'sys',
          prompt: 'weather',
          use: [a2ui(surfaceId: 'sfc')],
        );

        final content = res.message!.content;
        // Expect three ordered parts: prose("intro"), a2ui, prose("outro").
        expect(content.length, 3);
        expect(content[0].text, contains('intro'));
        expect(isA2uiPart(content[1]), isTrue);
        expect(content[2].text, contains('outro'));
      },
    );

    test('sanitizes inbound a2ui parts into text for the model', () async {
      ModelRequest? seen;
      defineReplyModel('m8', 'ok', onRequest: (r) => seen = r);

      final actionPart = DataPart(
        data: {
          'envelopes': [
            {
              'action': {
                'name': 'refresh',
                'surfaceId': 's1',
                'sourceComponentId': 'btn',
                'timestamp': 't',
                'context': {'city': 'Tokyo'},
              },
            },
          ],
        },
        metadata: {'mimeType': a2uiMimeType},
      );

      await genkit.generate(
        model: modelRef('m8'),
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(text: 'clicked:'),
              actionPart,
            ],
          ),
        ],
        use: [a2ui()],
      );

      final userMsg = seen!.messages.firstWhere((m) => m.role == Role.user);
      expect(userMsg.content.any(isA2uiPart), isFalse);
      final joined = userMsg.content.map((p) => p.text ?? '').join(' ');
      expect(joined, contains('UI action "refresh"'));
      expect(joined, contains('Tokyo'));
    });

    test('transforms streamed chunks and mints a matching final id', () async {
      // A model that streams the text in small pieces, then returns it whole.
      genkit.defineModel(
        name: 'm9',
        fn: (req, ctx) async {
          if (ctx.streamingRequested) {
            for (var i = 0; i < sampleText.length; i += 5) {
              final piece = sampleText.substring(
                i,
                i + 5 < sampleText.length ? i + 5 : sampleText.length,
              );
              ctx.sendChunk(
                ModelResponseChunk(
                  role: Role.model,
                  content: [TextPart(text: piece)],
                ),
              );
            }
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: sampleText)],
            ),
          );
        },
      );

      final streamedEnvelopes = <A2uiEnvelope>[];
      var streamedProse = '';
      final res = await genkit.generate(
        model: modelRef('m9'),
        system: 'sys',
        prompt: 'weather',
        use: [a2ui()],
        onChunk: (chunk) {
          streamedProse += chunk.content
              .where((p) => p.isText)
              .map((p) => p.text ?? '')
              .join();
          streamedEnvelopes.addAll(a2uiEnvelopes(chunk));
        },
      );

      // Stream saw prose (without the raw JSON) and the envelopes.
      expect(streamedProse, contains('Here is the weather'));
      expect(streamedProse, isNot(contains('createSurface')));
      expect(streamedEnvelopes.length, 2);

      // The final message and the stream agree on the surface id.
      final finalEnvelopes = a2uiEnvelopes(res.message);
      final streamedCreate = streamedEnvelopes.firstWhere(
        (e) => e['createSurface'] != null,
      );
      final finalCreate = finalEnvelopes.firstWhere(
        (e) => e['createSurface'] != null,
      );
      expect(
        (finalCreate['createSurface'] as Map)['surfaceId'],
        (streamedCreate['createSurface'] as Map)['surfaceId'],
      );
    });
  });
}
