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

import 'dart:async';

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
    ctx.cancel?.onCancel(() => registeredHookFired = true);
    sawCancelledAtModel = ctx.cancel?.isCancelled ?? false;
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
            ctx.cancel?.throwIfCancelled();
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
            ctx.cancel?.throwIfCancelled();
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

    test('a generic tool error during cancellation aborts instead of being '
        'swallowed as a tool failure', () async {
      final controller = CancellationController();
      var modelCalls = 0;

      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          modelCalls++;
          // Always request the tool. If the generic tool error were swallowed
          // into an error tool response, the loop would call the model again.
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'boom', input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'boom',
        description: 'boom',
        fn: (input, ctx) async {
          // Simulate a plugin that reacts to cancellation by tearing down its
          // transport, surfacing a generic error (e.g. SocketException) rather
          // than a CancelledException.
          controller.cancel();
          throw StateError('client closed');
        },
      );

      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'go',
        cancel: controller.token,
      );

      expect(res.finishReason, FinishReason.aborted);
      // The model ran exactly once: the generic tool error propagated as a
      // cancellation and stopped the loop rather than triggering another turn.
      expect(modelCalls, 1);
      expect(res.messages, hasLength(1));
      expect(res.messages.first.role, Role.user);
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

    test('a completed model call is returned even if the token was cancelled '
        'while it ran (work is not discarded)', () async {
      final controller = CancellationController();
      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          // Plugin does not observe cancellation: it runs to completion even
          // though the token is cancelled mid-flight.
          controller.cancel();
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'complete answer')],
            ),
          );
        },
      );

      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'hello',
        cancel: controller.token,
      );

      // Cooperative cancellation is best-effort: a completed result is not
      // thrown away and relabeled as aborted.
      expect(res.finishReason, FinishReason.stop);
      expect(res.text, 'complete answer');
    });

    test('a tool can observe the cancellation token via ctx.cancel', () async {
      final controller = CancellationController();
      var toolSawCancel = false;

      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'done')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'waits', input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'waits',
        description: 'waits for cancellation',
        fn: (input, ctx) async {
          // The token is exposed on ToolFnArgs and can be raced/observed.
          final cancel = ctx.cancel!;
          controller.cancel('stop it');
          await cancel.whenCancelled;
          toolSawCancel = cancel.isCancelled;
          throw CancelledException(reason: cancel.reason, token: cancel);
        },
      );

      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'go',
        cancel: controller.token,
      );

      expect(toolSawCancel, isTrue);
      expect(res.finishReason, FinishReason.aborted);
    });

    test("a tool's own internal cancellation does not escape generate when the "
        'caller never asked to cancel', () async {
      var modelCalls = 0;
      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          modelCalls++;
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'recovered')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'timeout', input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'timeout',
        description: 'has its own internal timeout token',
        fn: (input, ctx) async {
          // A tool's *own* cancellation token, unrelated to the caller's.
          final internal = CancellationController()..cancel('tool timed out');
          internal.token.throwIfCancelled();
          return .response('unreachable');
        },
      );

      // No `cancel:` supplied by the caller.
      final res = await genkit.generate(model: modelRef('m'), prompt: 'go');

      // The tool's internal cancellation is recorded as an error tool response
      // (like any other tool failure) and the loop continues, rather than
      // escaping generate() as a throw.
      expect(res.finishReason, FinishReason.stop);
      expect(res.text, 'recovered');
      expect(modelCalls, 2);
    });

    test('an already-cancelled token on the resume/restart path returns an '
        'aborted response instead of throwing', () async {
      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async => ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'hi')],
          ),
        ),
      );

      genkit.defineTool(
        name: 'restarted',
        description: 'a tool being restarted',
        fn: (input, ctx) async {
          ctx.cancel?.throwIfCancelled();
          return .response('ok');
        },
      );

      final controller = CancellationController()..cancel();
      // `interruptRestart` drives the resume/restart path in coreGenerate,
      // which runs before the loop's own entry checkpoint.
      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'go',
        interruptRestart: [
          ToolRequestPart(
            toolRequest: ToolRequest(name: 'restarted', input: {}),
          ),
        ],
        cancel: controller.token,
      );

      expect(res.finishReason, FinishReason.aborted);
    });

    test(
      'jsonOutput returns null on an aborted response rather than throwing',
      () async {
        final controller = CancellationController()..cancel();
        final res = await genkit.generate(
          model: modelRef('m'),
          prompt: 'give me json',
          cancel: controller.token,
        );

        expect(res.finishReason, FinishReason.aborted);
        // Degrades safely like the other accessors instead of throwing a
        // FormatException on the empty text.
        expect(res.jsonOutput, isNull);
        expect(res.text, '');
      },
    );

    test('a genuine failure that races a cancel is not masked as a clean '
        'abort', () async {
      final controller = CancellationController();
      genkit.defineModel(
        name: 'm',
        fn: (request, ctx) async {
          // A real provider failure surfaces, and the caller cancels in the
          // same instant.
          controller.cancel();
          throw GenkitException(
            '503 upstream',
            status: StatusCodes.UNAVAILABLE,
          );
        },
      );

      final res = await genkit.generate(
        model: modelRef('m'),
        prompt: 'hello',
        cancel: controller.token,
      );

      // The abort still resolves (not throws), but the underlying cause is
      // preserved in the finish message rather than reported as a clean
      // "Generation was cancelled".
      expect(res.finishReason, FinishReason.aborted);
      expect(res.finishMessage, contains('503 upstream'));
    });
  });
}
