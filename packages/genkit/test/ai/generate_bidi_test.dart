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

import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'generate_bidi_test.g.dart';

@Schema()
abstract class $MyToolInput {
  String get location;
}

void main() {
  group('generateBidi', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should execute tools automatically', () async {
      final toolName = 'weatherTool';
      final modelName = 'weatherBidiModel';

      genkit.defineTool(
        name: toolName,
        description: 'Get weather',
        inputSchema: MyToolInput.$schema,
        fn: (input, context) async {
          return .response('Sunny in ${input.location}');
        },
      );

      genkit.defineBidiModel(
        name: modelName,
        fn: (input, context) async {
          await for (final request in input) {
            final msg = request.messages.first;
            if (msg.role == Role.tool) {
              final toolResponse = ToolResponsePart.fromJson(
                msg.content.first.toJson(),
              );
              context.sendChunk(
                ModelResponseChunk(
                  content: [
                    TextPart(
                      text: 'Weather is: ${toolResponse.toolResponse.output}',
                    ),
                  ],
                ),
              );
            } else {
              final text = msg.content.first.text;
              if (text == 'check weather') {
                context.sendChunk(
                  ModelResponseChunk(
                    content: [
                      ToolRequestPart(
                        toolRequest: ToolRequest(
                          name: toolName,
                          input: {'location': 'London'},
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                context.sendChunk(
                  ModelResponseChunk(content: [TextPart(text: 'echo $text')]),
                );
              }
            }
          }
          return ModelResponse(finishReason: FinishReason.stop);
        },
      );

      final session = await genkit.generateBidi(
        model: modelName,
        toolNames: [toolName],
      );

      final outputs = <String>[];
      final completer = Completer<void>();

      session.stream.listen((chunk) {
        if (chunk.text.isNotEmpty) {
          outputs.add(chunk.text);
          if (chunk.text.startsWith('Weather is:')) {
            completer.complete();
          }
        }
      });

      session.send('check weather');
      await completer.future.timeout(Duration(seconds: 2));
      await session.close();

      expect(outputs.contains('Weather is: Sunny in London'), isTrue);
    });

    test('should inject system prompt and config via init', () async {
      final modelName = 'configBidiModel';

      genkit.defineBidiModel(
        name: modelName,
        fn: (input, context) async {
          final systemMsg = context.init!.messages
              .where((m) => m.role == Role.system)
              .firstOrNull;
          final systemText = systemMsg?.content.first.text ?? '';
          final configVal = context.init!.config?['k'] ?? '';

          await for (final _ in input) {
            context.sendChunk(
              ModelResponseChunk(
                content: [TextPart(text: '$systemText $configVal')],
              ),
            );
          }
          return ModelResponse(finishReason: FinishReason.stop);
        },
      );

      final session = await genkit.generateBidi(
        model: modelName,
        system: 'SYS',
        config: {'k': 'V'},
      );

      final chunksFuture = session.stream.take(1).toList();
      session.send('hi');
      final chunks = await chunksFuture;
      await session.close();

      expect(chunks.first.text, 'SYS V');
    });

    // Interrupts are unary-only: a live bidi session has no resume path, so both
    // the returned `.interrupt(...)` and the deprecated throwing
    // `ctx.interrupt(...)` forms must fail the session (surface an error on the
    // stream) and must NOT answer the model with a tool message.
    for (final variant in ['returned', 'throwing']) {
      test('interrupt ($variant form) fails the session and does not '
          'answer the model', () async {
        final toolName = 'confirm_$variant';
        final modelName = 'interruptBidiModel_$variant';
        var modelSawToolMessage = false;

        genkit.defineTool<MyToolInput, String>(
          name: toolName,
          description: 'Requires confirmation',
          inputSchema: MyToolInput.$schema,
          fn: (input, context) async {
            if (variant == 'returned') {
              return .interrupt({'requiresConfirmation': true});
            }
            // Deprecated throwing form (intentionally exercised here).
            // ignore: deprecated_member_use_from_same_package
            context.interrupt({'requiresConfirmation': true});
          },
        );

        genkit.defineBidiModel(
          name: modelName,
          fn: (input, context) async {
            await for (final request in input) {
              final msg = request.messages.first;
              if (msg.role == Role.tool) {
                // The bug being guarded against: an interrupt should never come
                // back to the model as a tool response.
                modelSawToolMessage = true;
                context.sendChunk(
                  ModelResponseChunk(content: [TextPart(text: 'kept going')]),
                );
              } else {
                context.sendChunk(
                  ModelResponseChunk(
                    content: [
                      ToolRequestPart(
                        toolRequest: ToolRequest(
                          name: toolName,
                          input: {'location': 'London'},
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
            return ModelResponse(finishReason: FinishReason.stop);
          },
        );

        final session = await genkit.generateBidi(
          model: modelName,
          toolNames: [toolName],
        );

        Object? streamError;
        final done = Completer<void>();
        session.stream.listen(
          (_) {},
          onError: (Object e) {
            streamError = e;
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

        session.send('please confirm');
        await done.future.timeout(Duration(seconds: 2));
        await session.close();

        expect(
          streamError,
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.UNIMPLEMENTED,
          ),
          reason: 'interrupts must fail a bidi session',
        );
        expect(
          modelSawToolMessage,
          isFalse,
          reason: 'the model must not receive a tool answer for an interrupt',
        );
      });
    }
  });
}
