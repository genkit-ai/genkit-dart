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

part 'generate_test.g.dart';

@Schema()
abstract class $TestToolInput {
  String get name;
}

void main() {
  group('generate', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should use toolChoice to select a tool', () async {
      const modelName = 'toolChoiceModel';
      const tool1Name = 'tool1';
      const tool2Name = 'tool2';
      var tool1Called = false;
      var tool2Called = false;

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Done')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: tool1Name,
                    input: {'name': 'world'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: tool1Name,
        description: 'Tool 1',
        inputSchema: TestToolInput.$schema,
        fn: (input, context) async {
          tool1Called = true;
          return 'tool 1 output';
        },
      );

      genkit.defineTool(
        name: tool2Name,
        description: 'Tool 2',
        inputSchema: TestToolInput.$schema,
        fn: (input, context) async {
          tool2Called = true;
          return 'tool 2 output';
        },
      );

      await genkit.generate(
        model: modelRef(modelName),
        prompt: 'Use a tool',
        toolNames: [tool1Name, tool2Name],
        toolChoice: tool1Name,
      );

      expect(tool1Called, isTrue);
      expect(tool2Called, isFalse);
    });

    test('should allow passing Tool objects directly', () async {
      const modelName = 'toolObjectModel';
      var directToolCalled = false;

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Done')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'directTool',
                    input: {'name': 'world'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      final directTool = Tool(
        name: 'directTool',
        description: 'Direct Tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, context) async {
          directToolCalled = true;
          return 'direct output';
        },
      );

      await genkit.generate(
        model: modelRef(modelName),
        prompt: 'Use direct tool',
        tools: [directTool],
      );

      expect(directToolCalled, isTrue);
    });

    test('should allow mixed String and Tool objects', () async {
      const modelName = 'mixedToolsModel';
      const registeredToolName = 'registeredTool';
      var registeredToolCalled = false;
      var directToolCalled = false;

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            // Check if both called? No, just finish
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Done')],
              ),
            );
          }
          // Request both tools
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: registeredToolName,
                    input: {'name': 'reg'},
                  ),
                ),
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'directFunctTool',
                    input: {'name': 'direct'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: registeredToolName,
        description: 'Registered Tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, context) async {
          registeredToolCalled = true;
          return 'reg output';
        },
      );

      final directTool = Tool(
        name: 'directFunctTool',
        description: 'Direct Tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, context) async {
          directToolCalled = true;
          return 'direct output';
        },
      );

      await genkit.generate(
        model: modelRef(modelName),
        prompt: 'Use tools',
        toolNames: [registeredToolName],
        tools: [directTool],
      );

      expect(registeredToolCalled, isTrue);
      expect(directToolCalled, isTrue);
    });

    test(
      'should return tool requests when returnToolRequests is true',
      () async {
        const modelName = 'returnToolRequestsModel';
        const toolName = 'testTool';
        var toolCalled = false;

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
                      input: {'name': 'world'},
                    ),
                  ),
                ],
              ),
            );
          },
        );

        genkit.defineTool(
          name: toolName,
          description: 'A test tool',
          inputSchema: TestToolInput.$schema,
          fn: (input, context) async {
            toolCalled = true;
            return 'tool output';
          },
        );

        final result = await genkit.generate(
          model: modelRef(modelName),
          prompt: 'Use a tool',
          toolNames: [toolName],
          returnToolRequests: true,
        );

        expect(toolCalled, isFalse);
        expect(result.toolRequests, isNotEmpty);
        expect(result.toolRequests.first.name, toolName);
      },
    );

    test('should throw an error when maxTurns is reached', () async {
      const modelName = 'maxTurnsModel';
      const toolName = 'testTool';

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
                    input: {'name': 'world'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: toolName,
        description: 'A test tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, context) async {
          return 'tool output';
        },
      );

      await expectLater(
        () => genkit.generate(
          model: modelRef(modelName),
          prompt: 'Use a tool',
          // this tool causes an infinite tool call loop
          toolNames: [toolName],
          maxTurns: 5,
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.ABORTED)
              .having(
                (e) => e.message,
                'message',
                contains('Adjust maxTurns option'),
              ),
        ),
      );

      await expectLater(
        () => genkit.generate(
          model: modelRef(modelName),
          prompt: 'Use a tool',
          // this tool causes an infinite tool call loop
          toolNames: [toolName],
          // maxTurns is not specified, should still use default (5).
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.ABORTED)
              .having(
                (e) => e.message,
                'message',
                contains('Adjust maxTurns option'),
              ),
        ),
      );
    });

    test('should return full message history in response.messages', () async {
      const modelName = 'historyModel';
      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'Response')],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'Request',
      );

      expect(response.messages.length, 2);
      expect(response.messages[0].role, Role.user);
      expect(response.messages[0].content[0].toJson()['text'], 'Request');
      expect(response.messages[1].role, Role.model);
      expect(response.messages[1].content[0].toJson()['text'], 'Response');
      expect(response.messages[1].toJson(), response.message!.toJson());
    });

    test('generate resolves DAP tools using wildcard', () async {
      genkit.defineDynamicActionProvider(
        name: 'my-dap',
        listActionsFn: () => [
          ActionMetadata(
            actionType: 'tool',
            name: 'weatherTool',
            description: 'get weather',
            inputSchema: TestToolInput.$schema,
            outputSchema: .dynamicSchema(),
          ),
        ],
        getActionFn: (id) async {
          if (id == 'weatherTool') {
            return Tool(
              name: 'weatherTool',
              description: 'get weather',
              inputSchema: TestToolInput.$schema,
              outputSchema: .dynamicSchema(),
              fn: (input, context) async => 'sunny',
            );
          }
          return null;
        },
      );

      genkit.defineModel(
        name: 'testModel',
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'The weather is sunny')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'weatherTool',
                    input: {'name': 'test'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('testModel'),
        prompt: 'What is the weather?',
        toolNames: ['my-dap:*'],
      );

      expect(response.text, 'The weather is sunny');
    });

    test('generate resolves DAP tools using tool/ wildcard', () async {
      genkit.defineDynamicActionProvider(
        name: 'my-dap',
        listActionsFn: () => [
          ActionMetadata(
            actionType: 'tool',
            name: 'weatherTool',
            description: 'get weather',
            inputSchema: TestToolInput.$schema,
            outputSchema: .dynamicSchema(),
          ),
        ],
        getActionFn: (id) async {
          if (id == 'weatherTool') {
            return Tool(
              name: 'weatherTool',
              description: 'get weather',
              inputSchema: TestToolInput.$schema,
              outputSchema: .dynamicSchema(),
              fn: (input, context) async => 'sunny',
            );
          }
          return null;
        },
      );

      genkit.defineModel(
        name: 'testModel2',
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'The weather is sunny')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'weatherTool',
                    input: {'name': 'test'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('testModel2'),
        prompt: 'What is the weather?',
        toolNames: ['my-dap:tool/*'],
      );

      expect(response.text, 'The weather is sunny');
    });

    test('generate resolves DAP tools using specific name', () async {
      genkit.defineDynamicActionProvider(
        name: 'my-dap',
        listActionsFn: () => [
          ActionMetadata(
            actionType: 'tool',
            name: 'weatherTool',
            description: 'get weather',
            inputSchema: TestToolInput.$schema,
            outputSchema: .dynamicSchema(),
          ),
        ],
        getActionFn: (id) async {
          if (id == 'weatherTool') {
            return Tool(
              name: 'weatherTool',
              description: 'get weather',
              inputSchema: TestToolInput.$schema,
              outputSchema: .dynamicSchema(),
              fn: (input, context) async => 'sunny explicit',
            );
          }
          return null;
        },
      );

      genkit.defineModel(
        name: 'testModelExplicit',
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'The weather is sunny explicit')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'weatherTool',
                    input: {'name': 'test'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('testModelExplicit'),
        prompt: 'What is the weather?',
        toolNames: ['my-dap:weatherTool'],
      );

      expect(response.text, 'The weather is sunny explicit');
    });

    test(
      'generate resolves DAP tools using specific name with tool/ prefix',
      () async {
        genkit.defineDynamicActionProvider(
          name: 'my-dap',
          listActionsFn: () => [
            ActionMetadata(
              actionType: 'tool',
              name: 'weatherTool',
              description: 'get weather',
              inputSchema: TestToolInput.$schema,
              outputSchema: .dynamicSchema(),
            ),
          ],
          getActionFn: (id) async {
            if (id == 'weatherTool') {
              return Tool(
                name: 'weatherTool',
                description: 'get weather',
                inputSchema: TestToolInput.$schema,
                outputSchema: .dynamicSchema(),
                fn: (input, context) async => 'sunny explicit prefix',
              );
            }
            return null;
          },
        );

        genkit.defineModel(
          name: 'testModelExplicitPrefix',
          fn: (request, context) async {
            if (request.messages.last.role == Role.tool) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [
                    TextPart(text: 'The weather is sunny explicit prefix'),
                  ],
                ),
              );
            }
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'weatherTool',
                      input: {'name': 'test'},
                    ),
                  ),
                ],
              ),
            );
          },
        );

        final response = await genkit.generate(
          model: modelRef('testModelExplicitPrefix'),
          prompt: 'What is the weather?',
          toolNames: ['my-dap:tool/weatherTool'],
        );

        expect(response.text, 'The weather is sunny explicit prefix');
      },
    );

    test('generate resolves DAP tools using prefix wildcard', () async {
      genkit.defineDynamicActionProvider(
        name: 'my-dap',
        listActionsFn: () => [
          ActionMetadata(
            actionType: 'tool',
            name: 'wea/weatherTool',
            description: 'get weather',
            inputSchema: TestToolInput.$schema,
            outputSchema: .dynamicSchema(),
          ),
          ActionMetadata(
            actionType: 'tool',
            name: 'other/timeTool',
            description: 'get time',
            inputSchema: TestToolInput.$schema,
            outputSchema: .dynamicSchema(),
          ),
        ],
        getActionFn: (id) async {
          if (id == 'wea/weatherTool') {
            return Tool(
              name: 'wea/weatherTool',
              description: 'get weather',
              inputSchema: TestToolInput.$schema,
              outputSchema: .dynamicSchema(),
              fn: (input, context) async => 'sunny prefix wildcard',
            );
          }
          return null;
        },
      );

      genkit.defineModel(
        name: 'testModelPrefixWildcard',
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  TextPart(text: 'The weather is sunny prefix wildcard'),
                ],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'wea/weatherTool',
                    input: {'name': 'test'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('testModelPrefixWildcard'),
        prompt: 'What is the weather?',
        toolNames: ['my-dap:wea*'],
      );

      expect(response.text, 'The weather is sunny prefix wildcard');
    });

    test('generate() without model uses defaultModel', () async {
      var defaultModelCalled = false;
      genkit = Genkit(
        isDevEnv: false,
        model: modelRef('defaultTestModel', config: {'temperature': 0.7}),
      );

      genkit.defineModel(
        name: 'defaultTestModel',
        fn: (request, context) async {
          defaultModelCalled = true;
          expect(request.config?['temperature'], 0.7);
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'Default Model Output')],
            ),
          );
        },
      );

      final response = await genkit.generate(prompt: 'Hello');
      expect(defaultModelCalled, isTrue);
      expect(response.text, 'Default Model Output');
    });

    test(
      'generate(model: myModelRef) uses myModelRef and its config',
      () async {
        var customModelCalled = false;
        var defaultModelCalled = false;
        genkit = Genkit(
          isDevEnv: false,
          model: modelRef('defaultTestModel', config: {'temperature': 0.7}),
        );

        genkit.defineModel(
          name: 'defaultTestModel',
          fn: (request, context) async {
            defaultModelCalled = true;
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Default')],
              ),
            );
          },
        );

        genkit.defineModel(
          name: 'customTestModel',
          fn: (request, context) async {
            customModelCalled = true;
            expect(request.config?['temperature'], 0.9);
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Custom')],
              ),
            );
          },
        );

        await genkit.generate(
          prompt: 'Hello',
          model: modelRef('customTestModel', config: {'temperature': 0.9}),
        );

        expect(defaultModelCalled, isFalse);
        expect(customModelCalled, isTrue);
      },
    );

    test(
      'generate() with explicit config overrides defaultModel.config',
      () async {
        var defaultModelCalled = false;
        genkit = Genkit(
          isDevEnv: false,
          model: modelRef('defaultTestModel', config: {'temperature': 0.7}),
        );

        genkit.defineModel(
          name: 'defaultTestModel',
          fn: (request, context) async {
            defaultModelCalled = true;
            // explicit config should be used
            expect(request.config?['temperature'], 0.5);
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Default')],
              ),
            );
          },
        );

        await genkit.generate(prompt: 'Hello', config: {'temperature': 0.5});

        expect(defaultModelCalled, isTrue);
      },
    );

    test(
      'generate(model: myModelRef, config: explicitConfig) uses myModelRef and explicit config',
      () async {
        var customModelCalled = false;
        genkit = Genkit(isDevEnv: false);

        genkit.defineModel(
          name: 'customTestModel',
          fn: (request, context) async {
            customModelCalled = true;
            // explicit config should override modelRef's config
            expect(request.config?['temperature'], 0.5);
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Custom')],
              ),
            );
          },
        );

        await genkit.generate(
          prompt: 'Hello',
          model: modelRef('customTestModel', config: {'temperature': 0.9}),
          config: {'temperature': 0.5},
        );

        expect(customModelCalled, isTrue);
      },
    );

    test('propagates "use" (middleware) across multiple turns', () async {
      final mwInstance = _CheckUseMiddleware('test-mw');
      genkit.registry.registerValue(
        'middleware',
        'test-mw',
        defineMiddleware(name: 'test-mw', create: ([_]) => mwInstance),
      );

      genkit.defineModel(
        name: 'multi-turn-model',
        fn: (req, ctx) async {
          if (req.messages.any((m) => m.role == Role.tool)) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Done')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'test-tool',
                    input: {'name': 'world'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'test-tool',
        description: 'Test Tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, ctx) async => 'result',
      );

      await genkit.generate(
        model: modelRef('multi-turn-model'),
        prompt: 'start',
        toolNames: ['test-tool'],
        use: [middlewareRef(name: 'test-mw')],
      );

      // Should have 2 turns (initial + tool response)
      expect(mwInstance.turns, equals(2));
    });

    test('propagates "use" (middleware) when restarting tools', () async {
      final mwInstance = _CheckUseMiddleware('test-mw-restart');
      genkit.registry.registerValue(
        'middleware',
        'test-mw-restart',
        defineMiddleware(name: 'test-mw-restart', create: ([_]) => mwInstance),
      );

      genkit.defineModel(
        name: 'restart-model',
        fn: (req, ctx) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'Final Answer')],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'test-tool',
        description: 'Test Tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, ctx) async => 'result',
      );

      final toolReq = ToolRequestPart(
        toolRequest: ToolRequest(name: 'test-tool', input: {'name': 'world'}),
      );

      await genkit.generate(
        model: modelRef('restart-model'),
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(role: Role.model, content: [toolReq]),
        ],
        use: [middlewareRef(name: 'test-mw-restart')],
        interruptRestart: [toolReq],
      );

      // Should have at least one turn call where middleware is active
      expect(mwInstance.turns, greaterThanOrEqualTo(1));
    });
  });
}

class _CheckUseMiddleware extends GenerateMiddleware {
  int turns = 0;
  final String expectedName;
  _CheckUseMiddleware(this.expectedName);

  @override
  Future<GenerateResponseHelper> generate(
    GenerateActionOptions options,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateActionOptions options,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) {
    turns++;
    expect(options.use?.any((m) => m.name == expectedName), isTrue);
    return next(options, ctx);
  }
}
