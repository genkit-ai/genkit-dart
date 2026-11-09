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
import 'package:test/test.dart';

void main() {
  group('defineInterrupt', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    /// Defines a model that always calls [toolName] with [input].
    void defineToolCallingModel(
      String modelName,
      String toolName, {
      Map<String, dynamic> input = const {},
    }) {
      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: toolName, input: input),
                ),
              ],
            ),
          );
        },
      );
    }

    test('registers a tool that can be looked up by name', () async {
      genkit.defineInterrupt(
        name: 'confirmAction',
        description: 'Asks the user to confirm.',
      );

      final action = await genkit.registry.lookupAction(.tool, 'confirmAction');
      expect(action, isNotNull);
      expect(action, isA<Tool>());
    });

    test('stores restartable: false in tool metadata', () async {
      final tool = genkit.defineInterrupt(
        name: 'confirmAction',
        description: 'Asks the user to confirm.',
      );

      expect(tool.metadata['tool'], {'restartable': false});
    });

    test('interrupts generation with metadata true by default', () async {
      const modelName = 'interruptModel';
      const toolName = 'confirmAction';

      defineToolCallingModel(modelName, toolName);
      genkit.defineInterrupt(
        name: toolName,
        description: 'Asks the user to confirm.',
      );

      final response = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'do the thing',
        toolNames: [toolName],
      );

      expect(response.finishReason, FinishReason.interrupted);
      expect(response.interrupts, hasLength(1));
      expect(response.interrupts.first.toolRequest.name, toolName);

      final part = response.message!.content.first;
      expect(part.metadata?['interrupt'], true);
    });

    test('attaches static requestMetadata to the interrupt', () async {
      const modelName = 'interruptModel';
      const toolName = 'confirmAction';

      defineToolCallingModel(modelName, toolName);
      genkit.defineInterrupt(
        name: toolName,
        description: 'Asks the user to confirm.',
        requestMetadata: (_, _) => {'requiresConfirmation': true},
      );

      final response = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'do the thing',
        toolNames: [toolName],
      );

      expect(response.finishReason, FinishReason.interrupted);
      final part = response.message!.content.first;
      expect(part.metadata?['interrupt'], {'requiresConfirmation': true});
    });

    test('computes requestMetadata from the tool input', () async {
      const modelName = 'interruptModel';
      const toolName = 'confirmAction';

      defineToolCallingModel(modelName, toolName, input: {'amount': 42});
      genkit.defineInterrupt<Map<String, dynamic>, dynamic>(
        name: toolName,
        description: 'Asks the user to confirm a charge.',
        inputSchema: .map(.string(), .dynamicSchema()),
        requestMetadata: (input, _) => {'amount': input['amount']},
      );

      final response = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'charge me',
        toolNames: [toolName],
      );

      expect(response.finishReason, FinishReason.interrupted);
      final part = response.message!.content.first;
      expect(part.metadata?['interrupt'], {'amount': 42});
    });

    test('awaits async requestMetadata', () async {
      const modelName = 'interruptModel';
      const toolName = 'confirmAction';

      defineToolCallingModel(modelName, toolName);
      genkit.defineInterrupt(
        name: toolName,
        description: 'Asks the user to confirm.',
        requestMetadata: (_, _) async {
          await Future<void>.delayed(Duration.zero);
          return {'async': true};
        },
      );

      final response = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'do the thing',
        toolNames: [toolName],
      );

      expect(response.finishReason, FinishReason.interrupted);
      final part = response.message!.content.first;
      expect(part.metadata?['interrupt'], {'async': true});
    });

    test('can be resumed with interruptRespond', () async {
      const modelName = 'resumeModel';
      const toolName = 'confirmAction';

      var modelCallCount = 0;
      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          modelCallCount++;
          // Resume call: history has the tool response.
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Done!')],
              ),
            );
          }
          // Initial call: trigger the interrupt.
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: toolName, input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineInterrupt(
        name: toolName,
        description: 'Asks the user to confirm.',
      );

      final response1 = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'do the thing',
        toolNames: [toolName],
      );
      expect(response1.finishReason, FinishReason.interrupted);
      expect(response1.interrupts, hasLength(1));

      final response2 = await genkit.generate(
        model: modelRef(modelName),
        messages: response1.messages,
        toolNames: [toolName],
        interruptRespond: [
          InterruptResponse(response1.interrupts.first, 'UserConfirmed'),
        ],
      );

      expect(response2.finishReason, FinishReason.stop);
      expect(response2.text, 'Done!');
      expect(modelCallCount, 2);
    });
  });
}
