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
const badTurn = '''Here you go:
<a2ui>
root = Button("Refresh", "primary", Event("refresh"))
</a2ui>
''';

/// What a model should answer with when asked to fix it.
const goodRepair = '''<a2ui>
refreshLabel = Text("Refresh")
root = Button(refreshLabel, "primary", Event("refresh"))
</a2ui>''';

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
    void defineModel(String name, String first, String then) {
      var calls = 0;
      genkit.defineModel(
        name: name,
        fn: (req, ctx) async {
          prompts.add(
            req.messages
                .expand((m) => m.content)
                .map((p) => p.text ?? '')
                .join('\n'),
          );
          final reply = calls++ == 0 ? first : then;
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

    /// The a2ui envelopes on a response, if any.
    List<A2uiEnvelope> envelopesOf(GenerateResponseHelper res) =>
        a2uiEnvelopesFromParts(res.message?.content);

    test('fixes a block the model got wrong', () async {
      defineModel('m', badTurn, goodRepair);

      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'weather',
        use: [a2ui()],
      );

      // The surface renders despite the first attempt failing.
      final envelopes = envelopesOf(res);
      expect(envelopes, isNotEmpty);
      final update = envelopes.firstWhere((e) => e['updateComponents'] != null);
      final components =
          ((update['updateComponents'] as Map)['components'] as List)
              .cast<Map<String, dynamic>>();
      final root = components.firstWhere((c) => c['id'] == 'root');
      expect(root['child'], 'refreshLabel');
    });

    test('the repair prompt carries the error and the failed block', () async {
      defineModel('m', badTurn, goodRepair);
      await genkit.generate(
        model: modelRef('m'),
        prompt: 'weather',
        use: [a2ui()],
      );

      expect(prompts, hasLength(2), reason: 'one turn plus one repair');
      final repairPrompt = prompts[1];
      expect(repairPrompt, contains('expects a component id'));
      expect(repairPrompt, contains('Button("Refresh"'));
      // Signatures of the components involved, to ground the fix.
      expect(repairPrompt, contains('Button(child (id)'));
    });

    test('makes at most one attempt', () async {
      // Always answers with the same broken block, so a looping implementation
      // would never terminate.
      defineModel('m', badTurn, badTurn);
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'weather',
        use: [a2ui()],
      );

      expect(prompts, hasLength(2));
      // Repair failed, so the block is dropped and prose survives.
      expect(envelopesOf(res), isEmpty);
      expect(res.text, contains('Here you go:'));
    });

    test('repair: false skips the extra call entirely', () async {
      defineModel('m', badTurn, goodRepair);
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'weather',
        use: [a2ui(repair: false)],
      );

      expect(prompts, hasLength(1), reason: 'no repair call');
      expect(envelopesOf(res), isEmpty);
    });

    test('never repairs an unknown component', () async {
      // Not fixable by rewriting: the component does not exist, so retrying
      // would only cost a call.
      const unknown = '''<a2ui>
root = Sparkline([1, 2])
</a2ui>
''';
      defineModel('m', unknown, goodRepair);
      await genkit.generate(
        model: modelRef('m'),
        prompt: 'chart',
        use: [a2ui()],
      );

      expect(prompts, hasLength(1), reason: 'configuration error, no repair');
    });

    test('repairs a duplicated block only once', () async {
      // Repaired sources are keyed by block text, so one attempt already covers
      // every copy; a second call would buy nothing.
      const twice = '''First:
<a2ui>
root = Button("Refresh", "primary", Event("refresh"))
</a2ui>
Second:
<a2ui>
root = Button("Refresh", "primary", Event("refresh"))
</a2ui>
''';
      defineModel('m', twice, goodRepair);
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'weather',
        use: [a2ui()],
      );

      expect(prompts, hasLength(2), reason: 'one turn plus ONE repair');
      // Both copies are fixed by the single repair.
      final roots = envelopesOf(res)
          .where((e) => e['updateComponents'] != null)
          .expand(
            (e) => ((e['updateComponents'] as Map)['components'] as List)
                .cast<Map<String, dynamic>>(),
          )
          .where((c) => c['id'] == 'root');
      expect(roots, hasLength(2));
      expect(roots.every((c) => c['child'] == 'refreshLabel'), isTrue);
    });

    test('accepts a repair whose tags differ in case', () async {
      // The streaming parser matches tags case-insensitively; discarding a
      // valid repair over `<A2UI>` would waste the call.
      const shouty = '''<A2UI>
refreshLabel = Text("Refresh")
root = Button(refreshLabel, "primary", Event("refresh"))
</A2UI>''';
      defineModel('m', badTurn, shouty);
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'weather',
        use: [a2ui()],
      );

      expect(envelopesOf(res), isNotEmpty);
    });

    test('a valid turn costs no extra call', () async {
      const good = '''All set:
<a2ui>
root = Text("hi")
</a2ui>
''';
      defineModel('m', good, goodRepair);
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'hi',
        use: [a2ui()],
      );

      expect(prompts, hasLength(1));
      expect(envelopesOf(res), isNotEmpty);
    });
  });
}
