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
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('Interrupts', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should interrupt tool execution and return metadata', () async {
      const modelName = 'interruptModel';
      const toolName = 'interruptTool';

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: toolName,
                    input: {'name': 'interrupt me'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: toolName,
        description: 'Interrupts execution',
        inputSchema: mapSchema(stringSchema(), dynamicSchema()),
        fn: (input, context) async {
          context.interrupt('CONFIRM_ME');
        },
      );

      final response = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'trigger interrupt',
        tools: [toolName],
      );

      expect(response.finishReason, FinishReason.interrupted);

      final part = response.message!.content.first;
      expect(part.toolRequestPart, isNotNull);
      expect(part.metadata?['interrupt'], 'CONFIRM_ME');

      expect(response.interrupts.length, 1);
      expect(response.interrupts.first.toolRequest.name, toolName);

      // Verify messages getter
      expect(response.messages.length, 2);
      expect(response.messages[0].role, Role.user);
      expect(response.messages[1].role, Role.model);
      expect(response.messages[1].toJson(), response.message!.toJson());
    });

    test('should validly resume from interrupt', () async {
      const modelName = 'resumeModel';
      const toolName = 'interruptTool';

      var modelCallCount = 0;

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          modelCallCount++;
          // If it's the resume call (history has tool response)
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Resumed!')],
              ),
            );
          }
          // Initial call
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: toolName,
                    input: {'name': 'interrupt me'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: toolName,
        description: 'Interrupts execution',
        inputSchema: mapSchema(stringSchema(), dynamicSchema()),
        fn: (input, context) async {
          context.interrupt('CONFIRM_ME');
        },
      );

      final response1 = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'trigger interrupt',
        tools: [toolName],
      );

      expect(response1.finishReason, FinishReason.interrupted);

      // Construct history
      final history = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'trigger interrupt')],
        ),
        response1.message!,
      ];

      // 2. Resume Call
      final response2 = await genkit.generate(
        model: modelRef(modelName),
        messages: history,
        tools: [toolName],
        resume: [
          InterruptResponse(
            response1.message!.content.first.toolRequestPart!,
            'UserConfirmed',
          ),
        ],
      );

      expect(response2.text, 'Resumed!');
      expect(modelCallCount, 2);

      // Verify messages getter on resume
      expect(
        response2.messages.length,
        4,
      ); // User, Model(Interrupt), Tool(Resume), Model(Final)
      expect(response2.messages[0].role, Role.user);
      expect(response2.messages[1].role, Role.model);
      expect(response2.messages[2].toJson(), {
        'role': 'tool',
        'content': [
          {
            'toolResponse': {
              'name': 'interruptTool',
              'output': 'UserConfirmed',
            },
          },
        ],
      });
      expect(response2.messages[3].role, Role.model);
      expect(response2.messages[3].toJson(), response2.message!.toJson());
    });

    test('partial interruption (one success, one interrupt)', () async {
      const modelName = 'partialModel';
      const toolSafe = 'safeTool';
      const toolInterrupt = 'interruptTool';

      genkit.defineModel(
        name: modelName,
        fn: (req, ctx) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: toolSafe, input: {}),
                ),
                ToolRequestPart(
                  toolRequest: ToolRequest(name: toolInterrupt, input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: toolSafe,
        description: 'Safe',
        inputSchema: mapSchema(stringSchema(), dynamicSchema()),
        fn: (_, _) async => 'SafeOutput',
      );
      genkit.defineTool(
        name: toolInterrupt,
        description: 'Interrupted',
        inputSchema: mapSchema(stringSchema(), dynamicSchema()),
        fn: (_, c) async => c.interrupt('STOP'),
      );

      final response = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'go',
        tools: [toolSafe, toolInterrupt],
      );

      expect(response.finishReason, FinishReason.interrupted);

      final content = response.message!.content;
      expect(content.length, 2);

      final safePart = content.firstWhere(
        (p) => p.toolRequestPart?.toolRequest.name == toolSafe,
      );
      final interruptPart = content.firstWhere(
        (p) => p.toolRequestPart?.toolRequest.name == toolInterrupt,
      );

      expect(safePart.metadata?['pendingOutput'], 'SafeOutput');
      expect(interruptPart.metadata?['interrupt'], 'STOP');

      expect(response.interrupts.length, 1);
      expect(response.interrupts.first.toolRequest.name, toolInterrupt);
    });
  });
}
