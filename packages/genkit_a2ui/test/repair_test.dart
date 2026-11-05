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

/// Tests for the one-shot repair of a block that failed to compile.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:test/test.dart';

/// The mistake that motivated repair: a label where a component id belongs.
const badBlock = '''surface("w")
root = Button("Refresh", "primary", Event("refresh"))''';

const badTurn = 'Here you go:\n<a2ui>\n$badBlock\n</a2ui>\n';

/// What a model should answer with when asked to fix it.
const goodBlock = '''surface("w")
refreshLabel = Text("Refresh")
root = Button(refreshLabel, "primary", Event("refresh"))''';

const goodRepair = '<a2ui>\n$goodBlock\n</a2ui>';

void main() {
  group('repair', () {
    late Genkit genkit;
    late List<String> prompts;
    late List<Map<String, dynamic>?> configs;

    setUp(() {
      genkit = Genkit(isDevEnv: false, plugins: [A2uiPlugin()]);
      prompts = [];
      configs = [];
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    /// A model that answers [first] once, then [then] for every later call
    /// (the repair). Records each prompt and config it receives, and streams
    /// its answer when asked to.
    void defineModel(String first, String then) {
      var calls = 0;
      genkit.defineModel(
        name: 'm',
        fn: (req, ctx) async {
          configs.add(req.config);
          final answer = calls++ == 0 ? first : then;
          if (ctx.streamingRequested) {
            ctx.sendChunk(
              ModelResponseChunk(
                role: Role.model,
                content: [TextPart(text: answer)],
              ),
            );
          }
          prompts.add(
            req.messages
                .expand((m) => m.content)
                .map((p) => p.text ?? '')
                .join('\n'),
          );
          return ModelResponse(
            finishReason: FinishReason.stop,
            usage: GenerationUsage(inputTokens: 10, outputTokens: 5),
            message: Message(
              role: Role.model,
              content: [TextPart(text: answer)],
            ),
          );
        },
      );
    }

    Future<GenerateResult> run({
      bool? repair,
      Map<String, dynamic>? config,
      void Function(GenerateResponseChunk chunk)? onChunk,
    }) => genkit.generate(
      model: modelRef('m'),
      prompt: 'weather',
      config: config,
      use: [a2ui(repair: repair)],
      onChunk: onChunk,
    );

    List<Map<String, dynamic>> componentsOf(GenerateResult res) => [
      for (final e in a2uiEnvelopesFromParts(res.message?.content))
        if (e['updateComponents'] case {'components': final List components})
          ...components.cast<Map<String, dynamic>>(),
    ];

    test('fixes a block the model got wrong', () async {
      defineModel(badTurn, goodRepair);
      final res = await run();

      final root = componentsOf(res).firstWhere((c) => c['id'] == 'root');
      expect(root['child'], 'refreshLabel');
      expect(res.text, contains('Here you go:'));
    });

    test('stores the repaired source, so history replays the fix', () async {
      defineModel(badTurn, goodRepair);
      final res = await run();

      final part = res.message!.content.firstWhere(isA2uiPart);
      expect(part.metadata?[a2uiExpressMetadataKey], goodBlock);
    });

    test('sends the repaired surface on the stream too', () async {
      // Clients that render from the stream would otherwise never get it,
      // while the session history says they did.
      defineModel(badTurn, goodRepair);
      final streamed = <Part>[];
      final res = await run(onChunk: (c) => streamed.addAll(c.content));

      final parts = streamed.where(isA2uiPart).toList();
      expect(parts, hasLength(1));
      expect(parts.single.metadata?[a2uiExpressMetadataKey], goodBlock);
      expect(
        a2uiEnvelopesFromParts(parts),
        a2uiEnvelopesFromParts(res.message!.content),
      );
    });

    test('does not resend blocks the stream already carried', () async {
      defineModel('ok:\n<a2ui>\n$goodBlock\n</a2ui>\n', 'unused');
      final streamed = <Part>[];
      await run(onChunk: (c) => streamed.addAll(c.content));

      expect(streamed.where(isA2uiPart), hasLength(1));
    });

    test('reports the repair call in the turn\'s usage', () async {
      defineModel(badTurn, goodRepair);
      final repaired = await run();
      expect(repaired.usage?.inputTokens, 20);
      expect(repaired.usage?.outputTokens, 10);
    });

    test('a valid turn reports only its own usage', () async {
      defineModel('ok:\n<a2ui>\n$goodBlock\n</a2ui>\n', 'unused');
      final res = await run();
      expect(res.usage?.inputTokens, 10);
    });

    test('discards a repair that renames the surface', () async {
      defineModel(
        badTurn,
        '<a2ui>\n${goodBlock.replaceFirst('surface("w")', 'surface("x")')}\n</a2ui>',
      );
      final res = await run();
      expect(prompts, hasLength(2));
      expect(res.message!.content.where(isA2uiPart), isEmpty);
    });

    test('forwards the request config to the repair call', () async {
      // A per-request API key, say: without it the repair cannot succeed.
      defineModel(badTurn, goodRepair);
      await run(config: {'apiKey': 'per-request-key'});

      expect(configs, hasLength(2));
      expect(configs[1], {'apiKey': 'per-request-key'});
    });

    /// A model that answers [first] once and lets [repair] decide later calls.
    void defineScripted(
      String first,
      Future<ModelResponse> Function(
        ModelRequest req,
        ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
      )
      repair,
    ) {
      var calls = 0;
      genkit.defineModel(
        name: 'm',
        fn: (req, ctx) async {
          if (calls++ > 0) return repair(req, ctx);
          if (ctx.streamingRequested) {
            ctx.sendChunk(
              ModelResponseChunk(
                role: Role.model,
                content: [TextPart(text: first)],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: first)],
            ),
          );
        },
      );
    }

    ModelResponse reply(String text, {FinishReason? finishReason}) =>
        ModelResponse(
          finishReason: finishReason ?? FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: text)],
          ),
        );

    test('a repair call that throws leaves the turn intact', () async {
      defineScripted(badTurn, (_, _) => throw StateError('boom'));
      final res = await run();
      expect(res.finishReason, FinishReason.stop);
      expect(res.text, contains('Here you go:'));
      expect(res.message!.content.where(isA2uiPart), isEmpty);
    });

    test('cancelling the turn during a repair aborts it', () async {
      final controller = CancellationController();
      defineScripted(badTurn, (_, ctx) async {
        controller.cancel();
        ctx.cancel?.throwIfCancelled();
        return reply(goodRepair);
      });
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'weather',
        cancel: controller.token,
        use: [a2ui()],
      );
      expect(res.finishReason, FinishReason.aborted);
    });

    test(
      'the repair request carries no tools or output, and does not stream',
      () async {
        ModelRequest? seen;
        bool? streaming;
        defineScripted(badTurn, (req, ctx) async {
          seen = req;
          streaming = ctx.streamingRequested;
          return reply(goodRepair);
        });
        await run(onChunk: (_) {});
        expect(seen!.tools, anyOf(isNull, isEmpty));
        expect(seen!.toolChoice, isNull);
        expect(seen!.output, isNull);
        expect(seen!.messages.single.role, Role.user);
        expect(streaming, isFalse);
      },
    );

    test('a repair reply cut off by the token limit is not used', () async {
      defineScripted(
        badTurn,
        (_, _) async => reply(goodRepair, finishReason: FinishReason.length),
      );
      final res = await run();
      expect(res.message!.content.where(isA2uiPart), isEmpty);
    });

    test('makes at most 3 repair calls per model call', () async {
      final turn = [
        for (var i = 0; i < 5; i++)
          '<a2ui>\nsurface("s$i")\nroot = Button("x$i", "primary", '
              'Event("e"))\n</a2ui>\n',
      ].join();
      var repairs = 0;
      defineScripted(turn, (_, _) async {
        repairs++;
        return reply('nothing useful');
      });
      await run();
      expect(repairs, 3);
    });

    test('does not repair a "block" with no surface(...) line', () async {
      var repairs = 0;
      defineScripted('<a2ui>\nroot = Bogus("x")\n</a2ui>', (_, _) async {
        repairs++;
        return reply(goodRepair);
      });
      await run();
      expect(repairs, 0);
    });

    test(
      're-sends later streamed parts of a repaired surface in order',
      () async {
        // The broken block is repaired at the end of the turn; the later render
        // of the same surface already streamed. Sent after it, the repair would
        // win on the client while history ends on the later render.
        const later = 'surface("w")\nroot = Text("later")';
        defineModel('$badTurn<a2ui>\n$later\n</a2ui>\n', goodRepair);
        final streamed = <Part>[];
        final res = await run(onChunk: (c) => streamed.addAll(c.content));
        List<Object?> sources(Iterable<Part> parts) => [
          for (final p in parts.where(isA2uiPart))
            p.metadata?[a2uiExpressMetadataKey],
        ];
        expect(sources(res.message!.content), [goodBlock, later]);
        // Live: `later`; then the catch-up: the repair, and `later` again.
        expect(sources(streamed), [later, goodBlock, later]);
      },
    );
    group('in a response with several blocks', () {
      const create = '''surface("s")
root = Card(col)
col = Column([title])
title = Text("Hi")''';
      // An update to the surface the block above creates, with the label
      // mistake. An update block must define every variable it uses, so it
      // redefines `title` too.
      const badUpdate = '''surface("s")
col = Column([title, go])
title = Text("Hi")
go = Button("Go", "primary", Event("go"))''';
      const goodUpdate = '''surface("s")
col = Column([title, go])
title = Text("Hi")
goLabel = Text("Go")
go = Button(goLabel, "primary", Event("go"))''';

      test('accepts a repaired update to a surface created earlier', () async {
        defineModel(
          '<a2ui>\n$create\n</a2ui>\n<a2ui>\n$badUpdate\n</a2ui>\n',
          '<a2ui>\n$goodUpdate\n</a2ui>',
        );
        final res = await run();

        expect(prompts, hasLength(2), reason: 'one turn plus one repair');
        final sources = [
          for (final p in res.message!.content.where(isA2uiPart))
            p.metadata?[a2uiExpressMetadataKey],
        ];
        expect(sources, [create, goodUpdate]);
      });

      test('a block that failed only because of an earlier one costs no '
          'repair', () async {
        // The update fails only because the broken block never created `w`.
        const updateW = 'surface("w")\n\$/k = "v"';
        defineModel(
          '<a2ui>\n$badBlock\n</a2ui>\n<a2ui>\n$updateW\n</a2ui>\n',
          goodRepair,
        );
        final res = await run();

        expect(prompts, hasLength(2), reason: 'one turn plus one repair');
        final sources = [
          for (final p in res.message!.content.where(isA2uiPart))
            p.metadata?[a2uiExpressMetadataKey],
        ];
        expect(sources, [goodBlock, updateW]);
      });
    });

    test(
      're-sends what a re-sent part drags along on other surfaces',
      () async {
        // `both` is re-sent for `w`, and it re-renders `z` too, so the later
        // `z` part must follow it again or the client ends on the older `z`.
        const both =
            'surface("w")\nroot = Text("w2")\nsurface("z")\nroot = Text("z1")';
        const zLater = 'surface("z")\nroot = Text("z2")';
        defineModel(
          '$badTurn<a2ui>\n$both\n</a2ui>\n<a2ui>\n$zLater\n</a2ui>\n',
          goodRepair,
        );
        final streamed = <Part>[];
        await run(onChunk: (c) => streamed.addAll(c.content));
        expect(
          [
            for (final p in streamed.where(isA2uiPart))
              p.metadata?[a2uiExpressMetadataKey],
          ],
          [both, zLater, goodBlock, both, zLater],
        );
      },
    );

    test('the repair prompt carries the error and the failed block', () async {
      defineModel(badTurn, goodRepair);
      await run();

      expect(prompts, hasLength(2), reason: 'one turn plus one repair');
      final repairPrompt = prompts[1];
      expect(repairPrompt, contains("non-existent component 'Refresh'"));
      expect(repairPrompt, contains(badBlock));
      // The signatures ground the fix.
      expect(repairPrompt, contains('Button(child (component ID)'));
    });

    test('makes at most one attempt', () async {
      // Always answers with the same broken block, so a looping implementation
      // would never terminate.
      defineModel(badTurn, badTurn);
      final res = await run();

      expect(prompts, hasLength(2));
      // Repair failed, so the block is dropped and prose survives.
      expect(a2uiEnvelopesFromParts(res.message?.content), isEmpty);
      expect(res.text, contains('Here you go:'));
    });

    test('repair: false skips the extra call entirely', () async {
      defineModel(badTurn, goodRepair);
      final res = await run(repair: false);

      expect(prompts, hasLength(1), reason: 'no repair call');
      expect(a2uiEnvelopesFromParts(res.message?.content), isEmpty);
    });

    test('an unfixable block costs one attempt, then is dropped', () async {
      // a2ui_agent reports catalog mismatches with the same error type as
      // fixable mistakes, so they are attempted once. The model has nothing
      // better to offer, and the block is dropped.
      const unknown = '<a2ui>\nsurface("w")\nroot = Sparkline([1, 2])\n</a2ui>';
      defineModel(unknown, unknown);
      final res = await run();

      expect(prompts, hasLength(2));
      expect(a2uiEnvelopesFromParts(res.message?.content), isEmpty);
    });

    test('repairs a duplicated block only once', () async {
      defineModel(
        'First:\n<a2ui>\n$badBlock\n</a2ui>\n'
        'Second:\n<a2ui>\n$badBlock\n</a2ui>\n',
        goodRepair,
      );
      final res = await run();

      expect(prompts, hasLength(2), reason: 'one turn plus ONE repair');
      // Both copies are fixed by the single repair. The second render of the
      // same surface replaces the first.
      final roots = componentsOf(res).where((c) => c['id'] == 'root');
      expect(roots, hasLength(2));
      expect(roots.every((c) => c['child'] == 'refreshLabel'), isTrue);
    });

    test(
      'accepts a repair whose tags differ in case or sit in a fence',
      () async {
        defineModel(badTurn, '```\n<A2UI>\n$goodBlock\n</A2UI>\n```');
        final res = await run();

        expect(componentsOf(res), isNotEmpty);
      },
    );

    test('a valid turn costs no extra call', () async {
      defineModel(
        'All set:\n<a2ui>\nsurface("w")\nroot = Text("hi")\n</a2ui>\n',
        goodRepair,
      );
      final res = await run();

      expect(prompts, hasLength(1));
      expect(componentsOf(res), isNotEmpty);
    });
  });
}
