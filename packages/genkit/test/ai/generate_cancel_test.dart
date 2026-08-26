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
import 'package:test/test.dart';

/// A middleware that observes the ambient cancellation token at the `model`
/// hook and records whether it was cancelled by the time the model ran.
class _CancelObservingMiddleware extends GenerateMiddleware {
  bool sawCancelledAtModel = false;
  bool registeredHookFired = false;

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
    ctx.cancel.onCancel(() => registeredHookFired = true);
    sawCancelledAtModel = ctx.cancel.isCancelled;
    return next(request, ctx);
  }
}

void main() {
  group('generate cancellation', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('already-cancelled token returns an aborted response with the '
        'request history', () async {
      var modelCalled = false;
      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          modelCalled = true;
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'hi')],
            ),
          );
        },
      );

      final controller = CancellationController()..cancel();
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'hello',
        cancel: controller.token,
      );

      expect(res.finishReason, FinishReason.aborted);
      expect(res.message, isNull);
      expect(res.output, isNull);
      // The last-good history (the user prompt) is preserved for resumption.
      expect(res.messages, hasLength(1));
      expect(res.messages.first.role, Role.user);
      expect(modelCalled, isFalse);
    });

    test(
      'cancelling during the model call returns an aborted response',
      () async {
        final controller = CancellationController();
        genkit.defineModel(
          name: 'm',
          fn: (request, ctx) async {
            // Cancel mid-flight and cooperatively bail.
            controller.cancel();
            ctx.cancel.throwIfCancelled();
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'hi')],
              ),
            );
          },
        );

        final res = await genkit.generate(
          model: modelRef('m'),
          prompt: 'hello',
          cancel: controller.token,
        );

        expect(res.finishReason, FinishReason.aborted);
        expect(res.message, isNull);
        // History carries the turn's input (the user prompt), not the partial
        // model output.
        expect(res.messages, hasLength(1));
        expect(res.messages.first.role, Role.user);
      },
    );

    test('middleware can observe the cancellation token', () async {
      final mwInstance = _CancelObservingMiddleware();
      final mw = defineMiddleware(
        name: 'cancel-observer',
        create: (c, ctx) => mwInstance,
      );
      genkit.registry.registerValue('middleware', 'cancel-observer', mw);

      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'hi')],
            ),
          );
        },
      );

      final controller = CancellationController();
      await genkit.generate(
        model: modelRef('m'),
        prompt: 'hello',
        cancel: controller.token,
        use: [middlewareRef(name: 'cancel-observer')],
      );
      expect(mwInstance.sawCancelledAtModel, isFalse);

      // Cancelling now fires the hook the middleware registered on the token.
      controller.cancel();
      expect(mwInstance.registeredHookFired, isTrue);
    });

    test('generateStream resolves to an aborted response when the token is '
        'already cancelled', () async {
      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          ctx.sendChunk(
            ModelResponseChunk(content: [TextPart(text: 'partial')]),
          );
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'hi')],
            ),
          );
        },
      );

      final controller = CancellationController()..cancel();
      final stream = genkit.generateStream(
        model: modelRef('m'),
        prompt: 'hello',
        cancel: controller.token,
      );

      final res = await stream.onResult;
      expect(res.finishReason, FinishReason.aborted);
      expect(res.message, isNull);
    });

    test('cancel aborts between tool-loop turns, preserving history', () async {
      final controller = CancellationController();
      var modelCalls = 0;

      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          modelCalls++;
          if (request.messages.last.role == Role.tool) {
            controller.cancel();
            ctx.cancel.throwIfCancelled();
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'done')],
              ),
            );
          }
          // First turn: request a tool, then cancel so the loop should not
          // begin another turn.
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'noop', input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'noop',
        description: 'noop',
        fn: (input, ctx) async {
          return .response('ok');
        },
      );

      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'go',
        cancel: controller.token,
      );

      expect(res.finishReason, FinishReason.aborted);
      expect(modelCalls, 2);
      expect(res.messages, hasLength(3));
      expect(res.messages.first.role, Role.user);
      expect(res.messages[1].role, Role.model);
      expect(res.messages.last.role, Role.tool);
    });

    test(
      'exceeding maxTurns returns an aborted response with history',
      () async {
        var modelCalls = 0;
        genkit.defineModel(
          name: 'm',
          fn: (request, ctx) async {
            modelCalls++;
            // Always request the tool so the loop keeps going until maxTurns.
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(name: 'noop', input: {}),
                  ),
                ],
              ),
            );
          },
        );

        genkit.defineTool(
          name: 'noop',
          description: 'noop',
          fn: (input, ctx) async => .response('ok'),
        );

        final res = await genkit.generate(
          model: modelRef('m'),
          prompt: 'go',
          maxTurns: 2,
        );

        expect(res.finishReason, FinishReason.aborted);
        expect(res.finishMessage, contains('max turns'));
        expect(modelCalls, 2);
        expect(res.messages, isNotEmpty);
      },
    );
  });
}
