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

import 'dart:convert';

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
        genkit,
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

      final envelopes = a2uiEnvelopesFromParts(res.message!.content);
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
      expect(a2uiEnvelopesFromParts(res.message!.content).length, 0);
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

    test('replays a prior assistant surface as a fenced a2ui block, not a '
        'sentinel', () async {
      ModelRequest? seen;
      defineReplyModel('m_replay', 'ok', onRequest: (r) => seen = r);

      // A prior assistant turn that rendered a surface: create + update.
      final surfacePart = DataPart(
        data: {
          'envelopes': [
            {
              'createSurface': {
                'surfaceId': 's1',
                'catalogId': basicCatalog.id,
              },
              'version': 'v0.9',
            },
            {
              'updateComponents': {
                'surfaceId': 's1',
                'components': [
                  {'id': 'root', 'component': 'Text', 'text': 'hi'},
                ],
              },
              'version': 'v0.9',
            },
          ],
        },
        metadata: {'mimeType': a2uiMimeType},
      );

      await genkit.generate(
        model: modelRef('m_replay'),
        messages: [
          Message(
            role: Role.model,
            content: [
              TextPart(text: 'Here you go:'),
              surfacePart,
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'thanks')],
          ),
        ],
        use: [a2ui()],
      );

      final modelMsg = seen!.messages.firstWhere((m) => m.role == Role.model);
      // The a2ui part is gone (the model converter never sees the mime type)...
      expect(modelMsg.content.any(isA2uiPart), isFalse);
      final joined = modelMsg.content.map((p) => p.text ?? '').join('\n');
      // ...replaced by the canonical fenced block the model originally emitted,
      // NOT the old `[rendered UI surface]` sentinel that poisoned the model.
      expect(joined, isNot(contains('[rendered UI surface]')));
      expect(joined, isNot(contains('[UI surface')));
      expect(joined, contains('```a2ui'));
      expect(joined, contains('createSurface'));
      expect(joined, contains('updateComponents'));
      expect(joined, contains('Here you go:'));

      // The reconstructed block round-trips: parsing it yields the envelopes.
      final block = joined.substring(
        joined.indexOf('```a2ui') + '```a2ui'.length,
        joined.lastIndexOf('```'),
      );
      final decoded = jsonDecode(block.trim()) as List;
      expect(decoded.length, 2);
      expect((decoded[0] as Map)['createSurface'], isNotNull);

      // The concrete surface id is rewritten back to the placeholder, so the
      // model can't copy a real id into a fresh render and reuse (overwrite) the
      // prior surface. The parser mints a fresh id per turn instead.
      expect(joined, isNot(contains('s1')));
      final create = (decoded[0] as Map)['createSurface'] as Map;
      final update = (decoded[1] as Map)['updateComponents'] as Map;
      expect(create['surfaceId'], surfaceIdPlaceholder);
      expect(update['surfaceId'], surfaceIdPlaceholder);
    });

    test('groups consecutive surface envelopes into one block but splits '
        'around an action', () async {
      ModelRequest? seen;
      defineReplyModel('m_mixed', 'ok', onRequest: (r) => seen = r);

      final mixedPart = DataPart(
        data: {
          'envelopes': [
            {
              'createSurface': {
                'surfaceId': 's1',
                'catalogId': basicCatalog.id,
              },
            },
            {
              'updateComponents': {'surfaceId': 's1', 'components': []},
            },
            {
              'action': {'name': 'refresh', 'surfaceId': 's1'},
            },
          ],
        },
        metadata: {'mimeType': a2uiMimeType},
      );

      await genkit.generate(
        model: modelRef('m_mixed'),
        messages: [
          Message(role: Role.user, content: [mixedPart]),
        ],
        use: [a2ui()],
      );

      final userMsg = seen!.messages.firstWhere((m) => m.role == Role.user);
      final joined = userMsg.content.map((p) => p.text ?? '').join('\n');
      // Exactly one fenced block (the two surface envelopes grouped together)...
      expect('```a2ui'.allMatches(joined).length, 1);
      // ...plus the action rendered as a text summary after it.
      expect(joined, contains('UI action "refresh"'));
      // The block precedes the action line (source order preserved).
      expect(joined.indexOf('```a2ui'), lessThan(joined.indexOf('UI action')));
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
          streamedEnvelopes.addAll(a2uiEnvelopesFromParts(chunk.content));
        },
      );

      // Stream saw prose (without the raw JSON) and the envelopes.
      expect(streamedProse, contains('Here is the weather'));
      expect(streamedProse, isNot(contains('createSurface')));
      expect(streamedEnvelopes.length, 2);

      // The final message and the stream agree on the surface id.
      final finalEnvelopes = a2uiEnvelopesFromParts(res.message!.content);
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

    test('flushes the withheld prose tail to the stream at end of turn', () async {
      // The parser holds back up to a partial-opening-fence tail on every push,
      // so without a final flush the last few chars of trailing prose would
      // never reach the streaming consumer. Stream a short prose turn one char
      // at a time and assert the streamed deltas reconstruct the full text.
      const full = 'short';
      genkit.defineModel(
        name: 'm_flush_prose',
        fn: (req, ctx) async {
          if (ctx.streamingRequested) {
            for (final ch in full.split('')) {
              ctx.sendChunk(
                ModelResponseChunk(
                  role: Role.model,
                  content: [TextPart(text: ch)],
                ),
              );
            }
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: full)],
            ),
          );
        },
      );

      var streamedProse = '';
      await genkit.generate(
        model: modelRef('m_flush_prose'),
        prompt: 'hi',
        use: [a2ui()],
        onChunk: (chunk) {
          streamedProse += chunk.content
              .where((p) => p.isText)
              .map((p) => p.text ?? '')
              .join();
        },
      );

      expect(streamedProse, full);
    });

    test('flushes an unterminated trailing block to the stream at end of '
        'turn', () async {
      // A block whose closing fence never arrives on the stream should still be
      // recovered on flush and reach the streaming consumer.
      final unterminated =
          '''
```a2ui
[
  { "createSurface": { "surfaceId": "SURFACE_ID", "catalogId": "${basicCatalog.id}" } },
  { "updateComponents": { "surfaceId": "SURFACE_ID", "components": [
    { "id": "root", "component": "Text", "text": "hi" }
  ] } }
]''';
      genkit.defineModel(
        name: 'm_flush_block',
        fn: (req, ctx) async {
          if (ctx.streamingRequested) {
            ctx.sendChunk(
              ModelResponseChunk(
                role: Role.model,
                content: [TextPart(text: unterminated)],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: unterminated)],
            ),
          );
        },
      );

      final streamedEnvelopes = <A2uiEnvelope>[];
      await genkit.generate(
        model: modelRef('m_flush_block'),
        prompt: 'weather',
        use: [a2ui()],
        onChunk: (chunk) {
          streamedEnvelopes.addAll(a2uiEnvelopesFromParts(chunk.content));
        },
      );

      expect(
        streamedEnvelopes.any((e) => e['updateComponents'] != null),
        isTrue,
        reason: 'the unterminated block should reach the stream after flush',
      );
    });

    test(
      'keeps distinct action lines when sanitizing inbound a2ui parts',
      () async {
        ModelRequest? seen;
        defineReplyModel('m_actions', 'ok', onRequest: (r) => seen = r);

        A2uiEnvelope action(String name) => {
          'action': {
            'name': name,
            'surfaceId': 's1',
            'sourceComponentId': 'btn',
            'timestamp': 't',
          },
        };

        // Two identical actions plus a distinct one, all in a single part.
        final actionsPart = DataPart(
          data: {
            'envelopes': [
              action('refresh'),
              action('refresh'),
              action('close'),
            ],
          },
          metadata: {'mimeType': a2uiMimeType},
        );

        await genkit.generate(
          model: modelRef('m_actions'),
          messages: [
            Message(role: Role.user, content: [actionsPart]),
          ],
          use: [a2ui()],
        );

        final userMsg = seen!.messages.firstWhere((m) => m.role == Role.user);
        final joined = userMsg.content.map((p) => p.text ?? '').join(' ');
        // Two "refresh" occurrences preserved (not deduped) + one "close".
        expect('refresh'.allMatches(joined).length, 2);
        expect(joined, contains('close'));
      },
    );

    test('keeps message content non-empty when a summary is empty', () async {
      ModelRequest? seen;
      defineReplyModel('m_empty', 'ok', onRequest: (r) => seen = r);

      // An envelope shape the summarizer does not recognize yields no summary
      // text; the sole a2ui part must not leave the message content empty.
      final unknownPart = DataPart(
        data: {
          'envelopes': [
            {'somethingUnknown': true},
          ],
        },
        metadata: {'mimeType': a2uiMimeType},
      );

      await genkit.generate(
        model: modelRef('m_empty'),
        messages: [
          Message(role: Role.user, content: [unknownPart]),
        ],
        use: [a2ui()],
      );

      final userMsg = seen!.messages.firstWhere((m) => m.role == Role.user);
      expect(userMsg.content, isNotEmpty);
      expect(userMsg.content.any((p) => (p.text ?? '').isNotEmpty), isTrue);
    });

    test('accepts a supported version', () async {
      defineReplyModel('m_ver_ok', 'ok');
      // A supported version must construct the middleware without throwing.
      await genkit.generate(
        model: modelRef('m_ver_ok'),
        prompt: 'hi',
        use: [a2ui(version: a2uiVersion)],
      );
    });

    test('rejects an unsupported version', () async {
      defineReplyModel('m_ver_bad', 'ok');
      // An unsupported version must fail fast rather than silently stamping
      // envelopes the renderer can't interpret.
      await expectLater(
        genkit.generate(
          model: modelRef('m_ver_bad'),
          prompt: 'hi',
          use: [a2ui(version: 'v0.1')],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
