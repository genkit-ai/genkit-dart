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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit/lite.dart' as lite;
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'remote_model_test.mocks.dart';

void main() {
  test('lite generate with outputSchema does not throw', () async {
    // Defines a dummy model
    final model = Model<void>(
      name: 'testModel',
      fn: (request, context) async {
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "success"}')],
          ),
        );
      },
    );

    // Tests that lite.dart's generate passes outputSchema correctly
    // without throwing "type 'Function' is not a subtype of type 'Map<String, dynamic>' in type cast"
    final response = await lite.generate(
      model: model,
      prompt: 'Hello',
      outputSchema: .string(),
    );

    expect(response.text, '{"result": "success"}');
  });

  test('lite generate with outputSchema delivers constrained json request '
      'to the model', () async {
    ModelRequest? captured;
    final model = Model<void>(
      name: 'constrainedTestModel',
      fn: (request, context) async {
        captured = request;
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "ok"}')],
          ),
        );
      },
    );

    await lite.generate(model: model, prompt: 'Hello', outputSchema: .string());

    expect(captured, isNotNull);
    expect(captured!.output?.format, 'json');
    expect(captured!.output?.constrained, isTrue);
    expect(captured!.output?.schema, isNotNull);
  });

  test('lite generate with custom outputInstructions injects them into '
      'the prompt', () async {
    ModelRequest? captured;
    final model = Model<void>(
      name: 'instructionsTestModel',
      fn: (request, context) async {
        captured = request;
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "ok"}')],
          ),
        );
      },
    );

    await lite.generate(
      model: model,
      prompt: 'Hello',
      outputSchema: .string(),
      outputInstructions: 'Respond in JSON matching the schema.',
    );

    final allText = captured!.messages
        .expand((m) => m.content)
        .where((p) => p.isText)
        .map((p) => p.text!)
        .join('\n');
    expect(allText, contains('Respond in JSON matching the schema.'));
  });

  test('lite generate prepends system message before prompt', () async {
    ModelRequest? captured;
    final model = Model<void>(
      name: 'systemTestModel',
      fn: (request, context) async {
        captured = request;
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'ok')],
          ),
        );
      },
    );

    await lite.generate(
      model: model,
      system: 'You are a helpful pirate.',
      prompt: 'Hello',
    );

    expect(captured, isNotNull);
    expect(captured!.messages.length, 2);
    expect(captured!.messages[0].role, Role.system);
    expect(
      captured!.messages[0].content[0].toJson()['text'],
      'You are a helpful pirate.',
    );
    expect(captured!.messages[1].role, Role.user);
    expect(captured!.messages[1].content[0].toJson()['text'], 'Hello');
  });

  test('lite generate builds a user message from promptParts', () async {
    ModelRequest? captured;
    final model = Model<void>(
      name: 'promptPartsTestModel',
      fn: (request, context) async {
        captured = request;
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'ok')],
          ),
        );
      },
    );

    await lite.generate(
      model: model,
      promptParts: [
        TextPart(text: 'Describe this image:'),
        MediaPart(media: Media(url: 'data:image/png;base64,abc123')),
      ],
    );

    expect(captured, isNotNull);
    expect(captured!.messages.length, 1);
    expect(captured!.messages[0].role, Role.user);
    expect(captured!.messages[0].content.length, 2);
    expect(
      captured!.messages[0].content[0].toJson()['text'],
      'Describe this image:',
    );
    expect(captured!.messages[0].content[1].toJson()['media'], {
      'url': 'data:image/png;base64,abc123',
    });
  });

  test('lite generateStream with outputSchema does not throw', () async {
    final model = Model<void>(
      name: 'testModelStream',
      fn: (request, context) async {
        context.sendChunk(
          ModelResponseChunk(index: 0, content: [TextPart(text: '{"res')]),
        );
        context.sendChunk(
          ModelResponseChunk(
            index: 0,
            content: [TextPart(text: 'ult": "success"}')],
          ),
        );
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "success"}')],
          ),
        );
      },
    );

    final stream = lite.generateStream(
      model: model,
      prompt: 'Hello',
      outputSchema: .string(),
    );

    final chunks = await stream.toList();
    expect(chunks.length, 2);
    expect(chunks[0].text, '{"res');
    expect(chunks[1].text, 'ult": "success"}');

    final response = await stream.onResult;
    expect(response.text, '{"result": "success"}');
  });

  group('lite tools and interrupts', () {
    test('runs a tool and feeds its output back to the model', () async {
      final weather = Tool(
        name: 'weather',
        description: 'Gets the weather.',
        inputSchema: .map(.string(), .dynamicSchema()),
        fn: (input, ctx) async => .response('sunny'),
      );

      final model = Model<void>(
        name: 'toolModel',
        fn: (request, context) async {
          if (request!.messages.last.role == Role.tool) {
            final toolResponse =
                request.messages.last.content.first.toolResponse!;

            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'weather is ${toolResponse.output}')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'weather', input: {}),
                ),
              ],
            ),
          );
        },
      );

      final response = await lite.generate(
        model: model,
        prompt: 'what is the weather?',
        tools: [weather],
      );

      expect(response.text, 'weather is sunny');
    });

    test('a tool returning .interrupt halts the generation loop', () async {
      final needsApproval = Tool(
        name: 'needsApproval',
        description: 'requires approval',
        inputSchema: .map(.string(), .dynamicSchema()),
        fn: (input, ctx) async => .interrupt({'requiresConfirmation': true}),
      );

      final model = Model<void>(
        name: 'interruptModel',
        fn: (request, context) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'needsApproval', input: {}),
                ),
              ],
            ),
          );
        },
      );

      final response = await lite.generate(
        model: model,
        prompt: 'go',
        tools: [needsApproval],
      );

      expect(response.finishReason, FinishReason.interrupted);
      expect(response.interrupts, hasLength(1));
      expect(response.interrupts.first.toolRequest.name, 'needsApproval');
      expect(response.interrupts.first.metadata?['interrupt'], {
        'requiresConfirmation': true,
      });
    });

    test('an Interrupt always interrupts with default metadata', () async {
      final confirm = Interrupt(
        name: 'confirmAction',
        description: 'Asks the user to confirm.',
        inputSchema: .map(.string(), .dynamicSchema()),
      );

      expect(confirm.metadata['tool'], {'restartable': false});

      final model = Model<void>(
        name: 'confirmModel',
        fn: (request, context) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'confirmAction', input: {}),
                ),
              ],
            ),
          );
        },
      );

      final response = await lite.generate(
        model: model,
        prompt: 'do the thing',
        tools: [confirm],
      );

      expect(response.finishReason, FinishReason.interrupted);
      expect(response.interrupts, hasLength(1));
      expect(response.message!.content.first.metadata?['interrupt'], true);
    });

    test('an Interrupt attaches computed requestMetadata', () async {
      final confirm = Interrupt(
        name: 'confirmCharge',
        description: 'Asks the user to confirm a charge.',
        inputSchema: .map(.string(), .dynamicSchema()),
        requestMetadata: (input, _) => {'amount': input['amount']},
      );

      final model = Model<void>(
        name: 'chargeModel',
        fn: (request, context) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'confirmCharge',
                    input: {'amount': 42},
                  ),
                ),
              ],
            ),
          );
        },
      );

      final response = await lite.generate(
        model: model,
        prompt: 'charge me',
        tools: [confirm],
      );

      expect(response.finishReason, FinishReason.interrupted);
      expect(response.message!.content.first.metadata?['interrupt'], {
        'amount': 42,
      });
    });

    test('an interrupted Interrupt can be resumed with '
        'interruptRespond', () async {
      final confirm = Interrupt(
        name: 'confirmAction',
        description: 'Asks the user to confirm.',
        inputSchema: .map(.string(), .dynamicSchema()),
      );

      var modelCallCount = 0;
      final model = Model<void>(
        name: 'resumeModel',
        fn: (request, context) async {
          modelCallCount++;

          if (request!.messages.last.role == Role.tool) {
            final toolResponse =
                request.messages.last.content.first.toolResponse!;
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'confirmed: ${toolResponse.output}')],
              ),
            );
          }

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'confirmAction', input: {}),
                ),
              ],
            ),
          );
        },
      );

      final response1 = await lite.generate(
        model: model,
        prompt: 'do the thing',
        tools: [confirm],
      );
      expect(response1.finishReason, FinishReason.interrupted);
      expect(response1.interrupts, hasLength(1));

      final response2 = await lite.generate(
        model: model,
        messages: response1.messages,
        tools: [confirm],
        interruptRespond: [
          InterruptResponse(response1.interrupts.first, 'UserConfirmed'),
        ],
      );

      expect(response2.finishReason, FinishReason.stop);
      expect(response2.text, 'confirmed: UserConfirmed');
      expect(modelCallCount, 2);
    });
  });

  group('remoteModel', () {
    late MockClient mockClient;
    const remoteUrl = 'http://localhost:3400/remote-model';

    setUp(() {
      mockClient = MockClient();
    });

    test('should handle unary response', () async {
      final model = lite.remoteModel(
        name: 'my-remote-model',
        url: remoteUrl,
        httpClient: mockClient,
      );

      final expectedResponse = ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'Hello from remote!')],
        ),
      );

      when(
        mockClient.post(
          Uri.parse(remoteUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'result': expectedResponse.toJson()}),
          200,
        ),
      );

      final response = await lite.generate(model: model, prompt: 'say hello');

      expect(response.text, 'Hello from remote!');

      verify(
        mockClient.post(
          Uri.parse(remoteUrl),
          headers: anyNamed('headers'),
          body: argThat(contains('say hello'), named: 'body'),
        ),
      ).called(1);
    });

    test('should handle streaming response', () async {
      final model = lite.remoteModel(
        name: 'my-remote-model',
        url: remoteUrl,
        httpClient: mockClient,
      );

      final chunks = [
        ModelResponseChunk(content: [TextPart(text: 'Part 1 ')]),
        ModelResponseChunk(content: [TextPart(text: 'Part 2')]),
      ];

      final finalResponse = ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'Part 1 Part 2')],
        ),
      );

      final sseData =
          '${chunks.map((c) => 'data: ${jsonEncode({'message': c.toJson()})}').join('\n\n')}\n\ndata: ${jsonEncode({'result': finalResponse.toJson()})}\n\n';

      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.fromIterable([sseData.codeUnits]),
          200,
        );
      });

      final stream = lite.generateStream(model: model, prompt: 'stream it');

      final receivedChunks = <String>[];
      await for (final chunk in stream) {
        receivedChunks.add(chunk.text);
      }
      final response = await stream.onResult;

      expect(receivedChunks, ['Part 1 ', 'Part 2']);
      expect(response.text, 'Part 1 Part 2');
    });
  });
}
