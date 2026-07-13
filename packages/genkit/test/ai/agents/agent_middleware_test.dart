// Copyright 2026 Google LLC
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
import 'package:genkit/plugin.dart';
import 'package:test/test.dart';

/// A middleware that acts as a "kit": it contributes a tool and appends a
/// marker to the system prompt on every turn. Used to prove that middleware
/// attached via `use:` on `defineAgent` is actually applied.
class _KitMiddleware extends GenerateMiddleware {
  _KitMiddleware();

  static const marker = '<<kit-injected>>';

  @override
  List<Tool> get tools => [
    Tool<void, String>(
      name: 'kit_tool',
      description: 'A tool contributed by the kit middleware.',
      fn: (input, ctx) async => 'ok',
    ),
  ];

  @override
  Future<GenerateResponseHelper> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) {
    final options = envelope.request;
    final messages = List<Message>.from(options.messages);
    final systemIdx = messages.indexWhere((m) => m.role == Role.system);
    if (systemIdx != -1) {
      final systemMsg = messages[systemIdx];
      messages[systemIdx] = Message(
        role: systemMsg.role,
        content: [
          ...systemMsg.content,
          TextPart(text: marker),
        ],
      );
    } else {
      messages.insert(
        0,
        Message(
          role: Role.system,
          content: [TextPart(text: marker)],
        ),
      );
    }

    final newOptions = GenerateActionOptions(
      model: options.model,
      docs: options.docs,
      messages: messages,
      tools: options.tools,
      toolChoice: options.toolChoice,
      config: options.config,
      output: options.output,
      resume: options.resume,
      returnToolRequests: options.returnToolRequests,
      maxTurns: options.maxTurns,
      stepName: options.stepName,
    );

    return next((
      request: newOptions,
      currentTurn: envelope.currentTurn,
      messageIndex: envelope.messageIndex,
    ), ctx);
  }
}

class _KitPlugin extends GenkitPlugin {
  @override
  String get name => 'kit';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<void>(
      name: 'kit',
      create: (config, ctx) => _KitMiddleware(),
    ),
  ];
}

GenerateMiddlewareRef<void> kit() => middlewareRef(name: 'kit');

void main() {
  group('middleware on defineAgent', () {
    late Genkit ai;
    late ModelRequest capturedRequest;

    setUp(() {
      ai = Genkit(promptDir: null, plugins: [_KitPlugin()]);
      // Capturing model: records the request it receives and replies with a
      // fixed message (no tool calls).
      ai.defineModel(
        name: 'capture',
        fn: (request, ctx) async {
          capturedRequest = request;
          return ModelResponse(
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'done')],
            ),
            finishReason: FinishReason.stop,
          );
        },
      );
    });

    tearDown(() => ai.shutdown());

    test('injects middleware tools and applies the generate hook', () async {
      final agent = ai.defineAgent(
        name: 'kitAgent',
        model: modelRef('capture'),
        system: 'You are a helpful assistant.',
        use: [kit()],
      );

      final chat = agent.chat();
      final res = await chat.sendText('hi');

      expect(res.finishReason, AgentFinishReason.stop);

      // The kit tool contributed by the middleware must appear in the request.
      final toolNames =
          capturedRequest.tools?.map((t) => t.name).toList() ?? [];
      expect(toolNames, contains('kit_tool'));

      // The middleware's generate hook must have appended its marker to the
      // system prompt.
      final systemText = capturedRequest.messages
          .where((m) => m.role == Role.system)
          .expand((m) => m.content)
          .map((p) => p.text ?? '')
          .join('\n');
      expect(systemText, contains(_KitMiddleware.marker));
    });
  });
}
