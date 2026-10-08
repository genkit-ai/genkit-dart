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

    setUp(() {
      genkit = Genkit(isDevEnv: false, plugins: [A2uiPlugin()]);
      prompts = [];
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    /// A model that answers [first] once, then [then] for every later call
    /// (the repair). Records each prompt it receives.
    void defineModel(String first, String then) {
      var calls = 0;
      genkit.defineModel(
        name: 'm',
        fn: (req, ctx) async {
          prompts.add(
            req.messages
                .expand((m) => m.content)
                .map((p) => p.text ?? '')
                .join('\n'),
          );
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: calls++ == 0 ? first : then)],
            ),
          );
        },
      );
    }

    Future<GenerateResult> run({bool? repair}) => genkit.generate(
      model: modelRef('m'),
      prompt: 'weather',
      use: [a2ui(repair: repair)],
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
