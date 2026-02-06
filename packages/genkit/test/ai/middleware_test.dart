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

@Schematic()
abstract class $TestToolInput {
  String get name;
}

class TestMiddleware extends GenerateMiddleware {
  final List<String> log;
  final String name;

  TestMiddleware(this.log, this.name);

  @override
  Future<GenerateResponseHelper> generate(
    GenerateActionOptions options,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateActionOptions options,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) async {
    log.add('$name:generate:start');
    final result = await next(options, ctx);
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
  Future<ToolResponse> tool(
    ToolRequest request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponse> Function(
      ToolRequest request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    log.add('$name:tool:${request.name}:start');
    final result = await next(request, ctx);
    log.add('$name:tool:${request.name}:end');
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

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should execute middleware in order', () async {
      final log = <String>[];
      final mw1 = TestMiddleware(log, 'mw1');
      final mw2 = TestMiddleware(log, 'mw2');

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
          return 'bar';
        },
      );

      await genkit.generate(
        model: modelRef('test-model'),
        prompt: 'hello',
        tools: ['test-tool'],
        use: [mw1, mw2],
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
          'mw1:model:start',
          'mw2:model:start',
          'model:exec',
          'mw2:model:end',
          'mw1:model:end',
          'mw2:generate:end',
          'mw1:generate:end',
        ]),
      );
    });

    test('should intercept model request', () async {
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
        use: [InterceptorMiddleware()],
      );

      expect(result.text, 'echo: intercepted: original');
    });

    test('should resolve and execute registered middleware refs', () async {
      final log = <String>[];

      // Register a middleware definition manually (as a plugin would).
      final def = defineMiddleware<dynamic>(
        name: 'reg-mw',
        create: ([config]) => TestMiddleware(log, 'reg-mw-${config ?? 'none'}'),
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

    test('should inject tools from middleware', () async {
      final log = <String>[];

      final injectedTool = Tool(
        name: 'injected-tool',
        description: 'Injected Tool',
        inputSchema: TestToolInput.$schema,
        fn: (input, ctx) async {
          log.add('tool:exec');
          return 'injected-result';
        },
      );

      final mw = ToolInjectingMiddleware([injectedTool]);

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
        use: [mw],
      );

      expect(log, contains('tool:exec'));
    });
  });
}

class ToolInjectingMiddleware extends GenerateMiddleware {
  final List<Tool> _tools;

  ToolInjectingMiddleware(this._tools);

  @override
  List<Tool> get tools => _tools;
}
