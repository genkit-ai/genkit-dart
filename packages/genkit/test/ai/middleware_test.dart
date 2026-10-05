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

part 'middleware_test.g.dart';

@Schema()
abstract class $TestToolInput {
  String get name;
}

@Schema()
abstract class $TagOptions {
  String get tag;
}

class TestMiddleware extends GenerateMiddleware {
  final List<String> log;
  final String name;

  TestMiddleware(this.log, this.name);

  @override
  Future<GenerateResult> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) async {
    log.add('$name:generate:start');
    final result = await next(envelope, ctx);
    log.add('$name:generate:end');
    return result;
  }

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) async {
    log.add('$name:model:start');
    final result = await next(request, ctx);
    log.add('$name:model:end');
    return result;
  }

  @override
  Future<ToolResult> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResult> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    log.add('$name:tool:${request.toolRequest.name}:start');
    final result = await next(request, ctx);
    log.add('$name:tool:${request.toolRequest.name}:end');
    return result;
  }
}

class InterceptorMiddleware extends GenerateMiddleware {
  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) async {
    // Modify request
    final content = request.messages.last.content.first;
    if (!content.isText) {
      throw Exception('Content is not text');
    }
    final text = content.text;
    final newRequest = ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'intercepted: $text')],
        ),
      ],
      config: request.config,
      tools: request.tools,
      toolChoice: request.toolChoice,
      output: request.output,
    );
    return await next(newRequest, ctx);
  }
}

void main() {
  group('Generate Middleware', () {
    late Genkit genkit;

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should execute middleware in order', () async {
      final log = <String>[];
      final mw1 = generateMiddleware(
        name: 'mw1',
        create: (c, ctx) => TestMiddleware(log, 'mw1'),
      );
      final mw2 = generateMiddleware(
        name: 'mw2',
        create: (c, ctx) => TestMiddleware(log, 'mw2'),
      );

      genkit = Genkit(
        isDevEnv: false,
        plugins: [
          MiddlewarePlugin([mw1, mw2]),
        ],
      );

      genkit.defineModel(
        name: 'test-model',
        fn: (req, ctx) async {
          log.add('model:exec');
          if (req.messages.any((m) => m.role == Role.tool)) {
            // After tool execution
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Final Answer')],
              ),
            );
          }
          // Request tool
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'test-tool',
                    input: {'name': 'foo'},
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
        fn: (input, ctx) async {
          log.add('tool:exec');
          return .response('bar');
        },
      );

      await genkit.generate(
        model: modelRef('test-model'),
        prompt: 'hello',
        toolNames: ['test-tool'],
        use: [
          middlewareRef(name: 'mw1'),
          middlewareRef(name: 'mw2'),
        ],
      );

      // Verify log order
      // mw1 start -> mw2 start -> model start -> model end -> tool start -> tool end -> model start -> model end -> mw2 end -> mw1 end
      // Wait, models are called multiple times in a loop.
      // 1. generate start mw1
      // 2. generate start mw2
      // 3. model start mw1
      // 4. model start mw2
      // 5. model:exec (returns tool request)
      // 6. model end mw2
      // 7. model end mw1
      // 8. tool start mw1
      // 9. tool start mw2
      // 10. tool:exec
      // 11. tool end mw2
      // 12. tool end mw1
      // 13. model start mw1
      // 14. model start mw2
      // 15. model:exec (returns final answer)
      // 16. model end mw2
      // 17. model end mw1
      // 18. generate end mw2
      // 19. generate end mw1

      expect(
        log,
        containsAllInOrder([
          'mw1:generate:start',
          'mw2:generate:start',
          'mw1:model:start',
          'mw2:model:start',
          'model:exec',
          'mw2:model:end',
          'mw1:model:end',
          'mw1:tool:test-tool:start',
          'mw2:tool:test-tool:start',
          'tool:exec',
          'mw2:tool:test-tool:end',
          'mw1:tool:test-tool:end',
          'mw1:generate:start',
          'mw2:generate:start',
          'mw1:model:start',
          'mw2:model:start',
          'model:exec',
          'mw2:model:end',
          'mw1:model:end',
          'mw2:generate:end',
          'mw1:generate:end',
          'mw2:generate:end',
          'mw1:generate:end',
        ]),
      );
    });

    test('should intercept model request', () async {
      final interceptor = generateMiddleware(
        name: 'interceptor',
        create: (_, _) => InterceptorMiddleware(),
      );
      genkit = Genkit(
        isDevEnv: false,
        plugins: [
          MiddlewarePlugin([interceptor]),
        ],
      );

      genkit.defineModel(
        name: 'echo-model',
        fn: (req, ctx) async {
          final text = req.messages.last.content.first.text!;
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'echo: $text')],
            ),
          );
        },
      );

      final result = await genkit.generate(
        model: modelRef('echo-model'),
        prompt: 'original',
        use: [middlewareRef(name: 'interceptor')],
      );

      expect(result.text, 'echo: intercepted: original');
    });

    test('should pass a GenkitAI instance in the middleware context', () async {
      GenerateMiddlewareContext? capturedCtx;

      final mw = generateMiddleware(
        name: 'ctx-capture-mw',
        create: (config, ctx) {
          capturedCtx = ctx;
          return TestMiddleware(<String>[], 'ctx-capture-mw');
        },
      );

      genkit = Genkit(
        isDevEnv: false,
        plugins: [
          MiddlewarePlugin([mw]),
        ],
      );

      genkit.defineModel(
        name: 'ctx-model',
        fn: (req, ctx) async => ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'ok')],
          ),
        ),
      );

      await genkit.generate(
        model: modelRef('ctx-model'),
        prompt: 'hi',
        use: [middlewareRef(name: 'ctx-capture-mw')],
      );

      expect(capturedCtx, isNotNull);
      expect(capturedCtx!.ai, isA<GenkitAI>());
      // The ephemeral GenkitAI is backed by the active generation registry.
      expect(capturedCtx!.ai.registry, isNotNull);
    });

    test('middleware can run nested AI operations via context', () async {
      genkit = Genkit(isDevEnv: false);

      genkit.defineModel(
        name: 'nested-model',
        fn: (req, ctx) async {
          final text = req.messages.last.content.first.text!;
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'nested: $text')],
            ),
          );
        },
      );

      String? nestedResult;
      final mw = generateMiddleware(
        name: 'nested-mw',
        create: (config, ctx) => FunctionMiddleware(
          generateFn: (envelope, mctx, next) async {
            // Use the GenkitAI passed in the context to run a nested generate.
            final nested = await ctx.ai.generate(
              model: modelRef('nested-model'),
              prompt: 'from-middleware',
            );
            nestedResult = nested.text;
            return next(envelope, mctx);
          },
        ),
      );
      genkit.registry.registerValue('middleware', mw.name, mw);

      await genkit.generate(
        model: modelRef('nested-model'),
        prompt: 'outer',
        use: [middlewareRef(name: 'nested-mw')],
      );

      expect(nestedResult, 'nested: from-middleware');
    });

    test('should resolve and execute registered middleware refs', () async {
      final log = <String>[];

      // Register a middleware definition manually (as a plugin would).
      final def = generateMiddleware<dynamic>(
        name: 'reg-mw',
        create: (config, ctx) =>
            TestMiddleware(log, 'reg-mw-${config ?? 'none'}'),
      );
      genkit.registry.registerValue('middleware', def.name, def);

      genkit.defineModel(
        name: 'echo-model-ref',
        fn: (req, ctx) async {
          final text = req.messages.last.content.first.text!;
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'echo: $text')],
            ),
          );
        },
      );

      // Use the middleware ref
      final result = await genkit.generate(
        model: modelRef('echo-model-ref'),
        prompt: 'hello ref',
        use: [middlewareRef(name: 'reg-mw', config: 'conf1')],
      );

      expect(result.text, 'echo: hello ref');
      expect(
        log,
        containsAllInOrder([
          'reg-mw-conf1:generate:start',
          'reg-mw-conf1:model:start',
          'reg-mw-conf1:model:end',
          'reg-mw-conf1:generate:end',
        ]),
      );
    });

    group('ai.defineGenerateMiddleware', () {
      final log = <String>[];

      setUp(() {
        log.clear();
        genkit = Genkit(isDevEnv: false);
        genkit.defineModel(
          name: 'echo',
          fn: (req, ctx) async => ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'ok')],
            ),
          ),
        );
      });

      GenerateMiddlewareDef<TagOptions> defineTagging() =>
          genkit.defineGenerateMiddleware<TagOptions>(
            name: 'tagging',
            configSchema: TagOptions.$schema,
            create: (config, ctx) =>
                TestMiddleware(log, config?.tag ?? 'untagged'),
          );

      test('registers it and builds refs by calling it', () async {
        final tagging = defineTagging();

        await genkit.generate(
          model: modelRef('echo'),
          prompt: 'hi',
          use: [tagging(TagOptions(tag: 'a'))],
        );
        await genkit.generate(
          model: modelRef('echo'),
          prompt: 'hi',
          use: [tagging()],
        );

        expect(log, contains('a:generate:start'));
        expect(log, contains('untagged:generate:start'));
        expect(
          genkit.registry.lookupValue<GenerateMiddlewareDef>(
            'middleware',
            'tagging',
          ),
          same(tagging),
        );
      });

      test('the ref config round-trips through the config schema', () async {
        final tagging = defineTagging();
        // A ref with a JSON config (e.g. from a .prompt file or the Dev UI)
        // is parsed with the config schema.
        await genkit.generate(
          model: modelRef('echo'),
          prompt: 'hi',
          use: [
            middlewareRef(name: tagging.name, config: {'tag': 'json'}),
          ],
        );
        expect(log, contains('json:generate:start'));
      });

      test('creates a fresh instance per generate call', () async {
        var created = 0;
        final counting = genkit.defineGenerateMiddleware<void>(
          name: 'counting',
          create: (_, _) {
            created++;
            return TestMiddleware(log, 'c$created');
          },
        );

        for (var i = 0; i < 2; i++) {
          await genkit.generate(
            model: modelRef('echo'),
            prompt: 'hi',
            use: [counting()],
          );
        }
        expect(created, 2);
      });

      test('replaces a plugin middleware with the same name', () async {
        genkit = Genkit(
          isDevEnv: false,
          plugins: [
            MiddlewarePlugin([
              generateMiddleware<TagOptions>(
                name: 'tagging',
                create: (_, _) => TestMiddleware(log, 'plugin'),
              ),
            ]),
          ],
        );
        genkit.defineModel(
          name: 'echo',
          fn: (req, ctx) async => ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'ok')],
            ),
          ),
        );
        final tagging = defineTagging();

        await genkit.generate(
          model: modelRef('echo'),
          prompt: 'hi',
          use: [tagging(TagOptions(tag: 'app'))],
        );
        expect(log, contains('app:generate:start'));
        expect(log, isNot(contains('plugin:generate:start')));
      });

      test('a generateMiddleware def from a plugin is callable', () async {
        final tagging = generateMiddleware<TagOptions>(
          name: 'tagging',
          configSchema: TagOptions.$schema,
          create: (config, ctx) =>
              TestMiddleware(log, config?.tag ?? 'untagged'),
        );
        await genkit.shutdown();
        genkit = Genkit(
          isDevEnv: false,
          plugins: [
            MiddlewarePlugin([tagging]),
          ],
        );
        genkit.defineModel(
          name: 'echo',
          fn: (req, ctx) async => ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'ok')],
            ),
          ),
        );

        await genkit.generate(
          model: modelRef('echo'),
          prompt: 'hi',
          use: [tagging(TagOptions(tag: 'plugin'))],
        );
        expect(log, contains('plugin:generate:start'));
      });

      Matcher throwsInvalidArgument(String message) => throwsA(
        isA<GenkitException>()
            .having((e) => e.status, 'status', StatusCode.invalidArgument)
            .having((e) => e.message, 'message', contains(message)),
      );

      test('rejects a typed config meant for the middleware it replaced', () {
        // Replaces the built-in `retry`, whose refs carry RetryOptions.
        genkit.defineGenerateMiddleware<TagOptions>(
          name: 'retry',
          create: (config, ctx) => TestMiddleware(log, config!.tag),
        );

        expect(
          genkit.generate(
            model: modelRef('echo'),
            prompt: 'hi',
            use: [retry(maxRetries: 2)],
          ),
          throwsInvalidArgument(
            "Middleware 'retry' expects a config of type TagOptions, "
            'got RetryOptions.',
          ),
        );
      });

      test('rejects a JSON config when there is no config schema', () {
        genkit.defineGenerateMiddleware<TagOptions>(
          name: 'noSchema',
          create: (config, ctx) => TestMiddleware(log, config!.tag),
        );

        expect(
          genkit.generate(
            model: modelRef('echo'),
            prompt: 'hi',
            use: [
              middlewareRef(name: 'noSchema', config: {'tag': 'json'}),
            ],
          ),
          throwsInvalidArgument('It has no configSchema'),
        );
      });

      test(
        'passes a JSON config through when the options type is a Map',
        () async {
          genkit.defineGenerateMiddleware<Map<String, dynamic>>(
            name: 'mapConfig',
            create: (config, ctx) => TestMiddleware(log, '${config!['tag']}'),
          );

          await genkit.generate(
            model: modelRef('echo'),
            prompt: 'hi',
            use: [
              middlewareRef(name: 'mapConfig', config: {'tag': 'map'}),
            ],
          );
          expect(log, contains('map:generate:start'));
        },
      );
    });

    test('should inject tools from middleware', () async {
      final log = <String>[];

      final injectedTool = Tool(
        name: 'injected-tool',
        description: 'Injected Tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, ctx) async {
          log.add('tool:exec');
          return .response('injected-result');
        },
      );

      final mw = generateMiddleware(
        name: 'injected-tool-mw',
        create: (_, _) => ToolInjectingMiddleware([injectedTool]),
      );
      genkit = Genkit(
        isDevEnv: false,
        plugins: [
          MiddlewarePlugin([mw]),
        ],
      );

      genkit.defineModel(
        name: 'tool-calling-model',
        fn: (req, ctx) async {
          if (req.messages.any((m) => m.role == Role.tool)) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Tool Called')],
              ),
            );
          }
          // Request the injected tool
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'injected-tool',
                    input: {'name': 'foo'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      await genkit.generate(
        model: modelRef('tool-calling-model'),
        prompt: 'call tool',
        use: [middlewareRef(name: 'injected-tool-mw')],
      );

      expect(log, contains('tool:exec'));
    });

    test('should trigger middleware when restarting tools via resume', () async {
      final log = <String>[];
      final mw1 = TestMiddleware(log, 'mw1');
      var toolCallCount = 0;

      final mdef1 = generateMiddleware(name: 'mw1', create: (_, _) => mw1);

      genkit = Genkit(
        isDevEnv: false,
        plugins: [
          MiddlewarePlugin([mdef1]),
        ],
      );

      genkit.defineModel(
        name: 'test-model-resume',
        fn: (req, ctx) async {
          log.add('model:exec');
          if (req.messages.any((m) => m.role == Role.tool)) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Final Answer')],
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
                    ref: 'ref1',
                    input: {'name': 'foo'},
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
        fn: (input, ctx) async {
          log.add('tool:exec');
          if (toolCallCount == 0) {
            toolCallCount++;
            return .interrupt('PLZ_RESTART');
          }
          return .response('bar');
        },
      );

      final response1 = await genkit.generate(
        model: modelRef('test-model-resume'),
        prompt: 'hello',
        toolNames: ['test-tool'],
        use: [middlewareRef(name: 'mw1')],
      );

      expect(response1.finishReason, FinishReason.interrupted);
      final toolReq = response1.message!.content.first.toolRequestPart!;

      final history = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
        response1.message!,
      ];

      log.clear(); // Reset log to only test restart behavior

      final response2 = await genkit.generate(
        model: modelRef('test-model-resume'),
        messages: history,
        toolNames: ['test-tool'],
        use: [middlewareRef(name: 'mw1')],
        interruptRestart: [ToolRequestPart(toolRequest: toolReq.toolRequest)],
      );

      expect(response2.text, 'Final Answer');

      // The restart should trigger the tool middleware specifically.
      // Additionally, the generate middleware around the initial generate() call should wrap it.
      // Verify log order
      expect(
        log,
        containsAllInOrder([
          'mw1:generate:start',
          'mw1:tool:test-tool:start',
          'tool:exec',
          'mw1:tool:test-tool:end',
          'mw1:generate:start',
          'mw1:model:start',
          'model:exec',
          'mw1:model:end',
          'mw1:generate:end',
          'mw1:generate:end',
        ]),
      );
    });

    test('GenerateTurnState.toString summarizes the request', () {
      final state = GenerateTurnState(
        request: GenerateActionOptions(
          model: 'echo',
          messages: [
            Message(
              role: .user,
              content: [TextPart(text: 'a very long prompt')],
            ),
          ],
        ),
        currentTurn: 2,
        messageIndex: 1,
      );
      expect(
        state.toString(),
        'GenerateTurnState(currentTurn: 2, messageIndex: 1, '
        'messages: 1, model: echo)',
      );
    });

    test(
      'should pass and respect envelope updates in generate middleware',
      () async {
        var receivedIndex = -1;
        var receivedTurn = -1;

        final envChecker = generateMiddleware(
          name: 'env-checker',
          create: (_, _) => FunctionMiddleware(
            generateFn: (envelope, ctx, next) async {
              receivedIndex = envelope.messageIndex;
              receivedTurn = envelope.currentTurn;
              return next(
                envelope.copyWith(
                  currentTurn: envelope.currentTurn + 2,
                  messageIndex: envelope.messageIndex + 5,
                ),
                ctx,
              );
            },
          ),
        );

        var checkIndex = -1;
        var checkTurn = -1;
        final envValidator = generateMiddleware(
          name: 'env-validator',
          create: (_, _) => FunctionMiddleware(
            generateFn: (envelope, ctx, next) async {
              checkIndex = envelope.messageIndex;
              checkTurn = envelope.currentTurn;
              return next(envelope, ctx);
            },
          ),
        );

        genkit = Genkit(
          isDevEnv: false,
          plugins: [
            MiddlewarePlugin([envChecker, envValidator]),
          ],
        );

        genkit.defineModel(
          name: 'test-model',
          fn: (req, ctx) async {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'done')],
              ),
            );
          },
        );

        await genkit.generate(
          model: modelRef('test-model'),
          prompt: 'hi',
          use: [
            middlewareRef(name: 'env-checker'),
            middlewareRef(name: 'env-validator'),
          ],
        );

        expect(receivedIndex, 0);
        expect(receivedTurn, 0);
        expect(checkIndex, 5);
        expect(checkTurn, 2);
      },
    );

    group('options preservation', () {
      setUp(() {
        genkit = Genkit(isDevEnv: false);
      });

      test('multi-turn generation should preserve middleware', () async {
        genkit.defineModel(
          name: 'multiTurnModel',
          fn: (req, ctx) async {
            return ModelResponse(
              finishReason: req.messages.length < 3
                  ? FinishReason.other
                  : FinishReason.stop,
              message: Message(
                role: Role.model,
                content: req.messages.length < 3
                    ? [
                        ToolRequestPart(
                          toolRequest: ToolRequest(
                            name: 'myTool',
                            input: {'foo': 'bar'},
                            ref: '123',
                          ),
                        ),
                      ]
                    : [TextPart(text: 'done')],
              ),
            );
          },
        );

        genkit.defineTool(
          name: 'myTool',
          description: 'a tool',
          fn: (input, ctx) async => .response('tool output'),
        );

        final capturedOptions = <GenerateActionOptions>[];
        final middleware = generateMiddleware(
          name: 'captureOptions',
          create: (config, ctx) => _CaptureMiddleware(capturedOptions),
        );
        genkit.registry.registerValue(
          'middleware',
          middleware.name,
          middleware,
        );

        await genkit.generate(
          model: modelRef('multiTurnModel'),
          prompt: 'hi',
          use: [middlewareRef(name: 'captureOptions')],
          toolNames: ['myTool'],
        );

        expect(capturedOptions.length, greaterThan(1));
        for (var i = 0; i < capturedOptions.length; i++) {
          expect(
            capturedOptions[i].use,
            isNotEmpty,
            reason: 'Turn $i missing middleware',
          );
          expect(capturedOptions[i].use!.first.name, 'captureOptions');
        }
      });

      test('resume flow should preserve middleware', () async {
        final capturedOptions = <GenerateActionOptions>[];
        final middleware = generateMiddleware(
          name: 'captureOptionsResume',
          create: (config, ctx) => _CaptureMiddleware(capturedOptions),
        );
        genkit.registry.registerValue(
          'middleware',
          middleware.name,
          middleware,
        );

        genkit.defineModel(
          name: 'resumeModel',
          fn: (req, ctx) async {
            if (req.messages.any(
              (m) => m.content.any((p) => p.isToolResponse),
            )) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [TextPart(text: 'resumed')],
                ),
              );
            }

            return ModelResponse(
              finishReason: FinishReason.other,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'interruptTool',
                      input: {'foo': 'bar'},
                      ref: '123',
                    ),
                  ),
                ],
              ),
            );
          },
        );

        genkit.defineTool(
          name: 'interruptTool',
          description: 'interrupts',
          fn: (input, ctx) async => .interrupt('interrupt'),
        );

        final response1 = await genkit.generate(
          model: modelRef('resumeModel'),
          prompt: 'hi',
          use: [middlewareRef(name: 'captureOptionsResume')],
          toolNames: ['interruptTool'],
        );

        expect(response1.interrupts, isNotEmpty);

        capturedOptions.clear();

        await genkit.generate(
          model: modelRef('resumeModel'),
          prompt: 'hi',
          interruptRespond: [
            InterruptResponse(response1.interrupts.first, 'resumed output'),
          ],
          use: [middlewareRef(name: 'captureOptionsResume')],
          toolNames: ['interruptTool'],
        );

        expect(
          capturedOptions.any((o) => o.resume?.respond?.isNotEmpty ?? false),
          isTrue,
        );
        final resumedOption = capturedOptions.firstWhere(
          (o) => o.resume?.respond?.isNotEmpty ?? false,
        );

        expect(
          resumedOption.use,
          isNotEmpty,
          reason: 'Middleware lost on resume',
        );
        expect(resumedOption.use!.first.name, 'captureOptionsResume');
      });

      test('generate should preserve middleware (use) in options', () async {
        final capturedOptions = <GenerateActionOptions>[];
        final middleware = generateMiddleware(
          name: 'captureOptionsMiddleware',
          create: (config, ctx) => _CaptureMiddleware(capturedOptions),
        );
        genkit.registry.registerValue(
          'middleware',
          middleware.name,
          middleware,
        );

        genkit.defineModel(
          name: 'simpleModel',
          fn: (req, ctx) async => ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'ok')],
            ),
          ),
        );

        await genkit.generate(
          model: modelRef('simpleModel'),
          prompt: 'hi',
          use: [middlewareRef(name: 'captureOptionsMiddleware')],
        );

        expect(capturedOptions.last.use, isNotEmpty);
        expect(
          capturedOptions.last.use!.first.name,
          'captureOptionsMiddleware',
        );
      });

      test(
        'generate action should resolve middleware from options.use',
        () async {
          final capturedOptions = <GenerateActionOptions>[];
          final middleware = generateMiddleware(
            name: 'captureOptionsAction',
            create: (config, ctx) => _CaptureMiddleware(capturedOptions),
          );
          genkit.registry.registerValue(
            'middleware',
            middleware.name,
            middleware,
          );

          genkit.defineModel(
            name: 'simpleModelAction',
            fn: (req, ctx) async => ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'ok')],
              ),
            ),
          );

          final generateAction = (await genkit.registry.lookupAction(
            .util,
            'generate',
          ))!;

          await generateAction(
            GenerateActionOptions(
              model: 'simpleModelAction',
              messages: [
                Message(
                  role: Role.user,
                  content: [TextPart(text: 'hi')],
                ),
              ],
              use: [MiddlewareRef(name: 'captureOptionsAction')],
            ),
          );

          expect(capturedOptions, isNotEmpty);
          expect(capturedOptions.first.use, isNotEmpty);
          expect(capturedOptions.first.use!.first.name, 'captureOptionsAction');
        },
      );
    });
  });
}

class _CaptureMiddleware extends GenerateMiddleware {
  final List<GenerateActionOptions> capturedOptions;
  _CaptureMiddleware(this.capturedOptions);

  @override
  Future<GenerateResult> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) async {
    capturedOptions.add(envelope.request);
    return next(envelope, ctx);
  }
}

class FunctionMiddleware extends GenerateMiddleware {
  final Future<GenerateResult> Function(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  )?
  generateFn;

  FunctionMiddleware({this.generateFn});

  @override
  Future<GenerateResult> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) {
    if (generateFn != null) {
      return generateFn!(envelope, ctx, next);
    }
    return super.generate(envelope, ctx, next);
  }
}

class ToolInjectingMiddleware extends GenerateMiddleware {
  final List<Tool> _tools;

  ToolInjectingMiddleware(this._tools);

  @override
  List<Tool> get tools => _tools;
}

class MiddlewarePlugin extends GenkitPlugin {
  @override
  String name = 'mw-plugin';

  final List<GenerateMiddlewareDef> _middleware;

  MiddlewarePlugin(this._middleware);

  @override
  List<GenerateMiddlewareDef> middleware() => _middleware;
}
