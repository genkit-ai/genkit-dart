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
import 'package:test/test.dart';
import 'package:genkit_schema_builder/genkit_schema_builder.dart';

part 'generate_bidi_test.schema.g.dart';

@GenkitSchema()
abstract class MyToolInputSchema {
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
        inputType: MyToolInputType,
        fn: (input, context) async {
          return 'Sunny in ${input.location}';
        },
      );

      genkit.defineBidiModel(
        name: modelName,
        fn: (input, context) async {
          await for (final request in input) {
            final msg = request.messages.first;
            if (msg.role == Role.tool) {
              final toolResponse = msg.content.first as ToolResponsePart;
              context.sendChunk(
                ModelResponseChunk.from(
                  content: [
                    TextPart.from(
                      text: 'Weather is: ${toolResponse.toolResponse.output}',
                    ),
                  ],
                ),
              );
            } else {
              final text = msg.content.first.text;
              if (text == 'check weather') {
                context.sendChunk(
                  ModelResponseChunk.from(
                    content: [
                      ToolRequestPart.from(
                        toolRequest: ToolRequest.from(
                          name: toolName,
                          input: {'location': 'London'},
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                context.sendChunk(
                  ModelResponseChunk.from(
                    content: [TextPart.from(text: 'echo $text')],
                  ),
                );
              }
            }
          }
          return ModelResponse.from(finishReason: FinishReason.stop);
        },
      );

      final session = await genkit.generateBidi(
        model: modelName,
        tools: [toolName],
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
              ModelResponseChunk.from(
                content: [TextPart.from(text: '$systemText $configVal')],
              ),
            );
          }
          return ModelResponse.from(finishReason: FinishReason.stop);
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
  });
}
