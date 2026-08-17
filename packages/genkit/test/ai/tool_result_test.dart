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
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('ToolResult', () {
    test('.response constructs a ToolResponseResult', () {
      final result = ToolResult.response('hello');
      expect(result, isA<ToolResponseResult<String>>());
      final response = result as ToolResponseResult<String>;
      expect(response.output, 'hello');
      expect(response.parts, isNull);
      expect(response.metadata, isNull);
    });

    test('.response carries multipart parts and metadata', () {
      final result = ToolResult.response(
        {'result': 'captured'},
        parts: [
          MediaPart(
            media: Media(contentType: 'image/png', url: 'data:image/png;xyz'),
          ),
        ],
        metadata: {'source': 'test'},
      );
      final response = result as ToolResponseResult;
      expect(response.parts, hasLength(1));
      expect(response.metadata, {'source': 'test'});

      final json = response.toJson();
      expect(json['output'], {'result': 'captured'});
      expect(json['content'], hasLength(1));
      expect(json['metadata'], {'source': 'test'});
    });

    test('.interrupt constructs a ToolInterruptResult', () {
      final result = ToolResult.interrupt({'requiresConfirmation': true});
      expect(result, isA<ToolInterruptResult>());
      final interrupt = result as ToolInterruptResult;
      expect(interrupt.data, {'requiresConfirmation': true});
      expect(interrupt.toJson(), {
        'interrupt': {'requiresConfirmation': true},
      });
    });

    test('.interrupt with no data serializes to interrupt: true', () {
      expect(ToolResult.interrupt().toJson(), {'interrupt': true});
    });
  });

  group('defineTool with ToolResult', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('registers the tool under /tool.v2/ only', () async {
      genkit.defineTool<Map<String, dynamic>, String>(
        name: 'echo',
        description: 'echoes',
        inputSchema: SchemanticType.map(
          SchemanticType.string(),
          SchemanticType.dynamicSchema(),
        ),
        fn: (input, ctx) async => .response('ok'),
      );

      // Every Dart tool implements the multipart contract, so it lives under
      // the single `tool.v2` action type (no legacy `tool` registration).
      final v2 = await genkit.registry.lookupAction(.tool, 'echo');
      final legacy = await genkit.registry.lookupAction(
        ActionType('tool'),
        'echo',
      );
      expect(v2, isNotNull);
      expect(legacy, isNull);
      expect(v2!.actionType, 'tool.v2');
      expect(v2.metadata['type'], 'tool.v2');
    });

    test('a returned .response flows through the generate loop', () async {
      genkit.defineModel(
        name: 'toolModel',
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            final toolResponse =
                request.messages.last.content.first.toolResponse!;
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'got: ${toolResponse.output}')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'greet', input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool<Map<String, dynamic>, String>(
        name: 'greet',
        description: 'greets',
        inputSchema: SchemanticType.map(
          SchemanticType.string(),
          SchemanticType.dynamicSchema(),
        ),
        fn: (input, ctx) async => .response('hello world'),
      );

      final response = await genkit.generate(
        model: modelRef('toolModel'),
        prompt: 'hi',
        toolNames: ['greet'],
      );

      expect(response.text, 'got: hello world');
    });

    test('multipart .response populates ToolResponse.content', () async {
      Map<String, dynamic>? capturedToolMessage;
      genkit.defineModel(
        name: 'multipartModel',
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            capturedToolMessage = request.messages.last.toJson();
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
                  toolRequest: ToolRequest(name: 'screenshot', input: {}),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
        name: 'screenshot',
        description: 'takes a screenshot',
        inputSchema: SchemanticType.map(
          SchemanticType.string(),
          SchemanticType.dynamicSchema(),
        ),
        fn: (input, ctx) async => .response(
          {'result': 'captured'},
          parts: [
            MediaPart(
              media: Media(
                contentType: 'image/png',
                url: 'data:image/png;base64,abc',
              ),
            ),
          ],
        ),
      );

      await genkit.generate(
        model: modelRef('multipartModel'),
        prompt: 'capture',
        toolNames: ['screenshot'],
      );

      final content = capturedToolMessage!['content'] as List;
      final toolResponse =
          (content.first as Map<String, dynamic>)['toolResponse']
              as Map<String, dynamic>;
      expect(toolResponse['output'], {'result': 'captured'});
      expect(toolResponse['content'], hasLength(1));
      final part = (toolResponse['content'] as List).first as Map;
      expect(part['media'], isNotNull);
    });

    test(
      'returned .interrupt behaves like ctx.interrupt (finishReason)',
      () async {
        genkit.defineModel(
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

        genkit.defineTool<Map<String, dynamic>, String>(
          name: 'needsApproval',
          description: 'requires approval',
          inputSchema: SchemanticType.map(
            SchemanticType.string(),
            SchemanticType.dynamicSchema(),
          ),
          fn: (input, ctx) async => .interrupt({'requiresConfirmation': true}),
        );

        final response = await genkit.generate(
          model: modelRef('interruptModel'),
          prompt: 'go',
          toolNames: ['needsApproval'],
        );

        expect(response.finishReason, FinishReason.interrupted);
        expect(response.interrupts, hasLength(1));
        final interruptMeta = response.interrupts.first.metadata!['interrupt'];
        expect(interruptMeta, {'requiresConfirmation': true});
      },
    );
  });
}
