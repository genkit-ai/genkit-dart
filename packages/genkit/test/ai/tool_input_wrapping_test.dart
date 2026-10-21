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

import 'package:genkit/experimental.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/tool_input_wrapping.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

/// Records the tool request input each middleware `tool` hook observes.
class _ToolInputSpy extends GenerateMiddleware {
  _ToolInputSpy(this.seen);
  final List<Object?> seen;

  @override
  Future<ToolResult> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResult> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) {
    seen.add(request.toolRequest.input);
    return next(request, ctx);
  }
}

class _SpyPlugin extends GenkitPlugin {
  _SpyPlugin(this._middleware);
  final List<GenerateMiddlewareDef> _middleware;

  @override
  String name = 'spy-plugin';

  @override
  List<GenerateMiddlewareDef> middleware() => _middleware;
}

ToolRequestPart _echoCall(Object? input) => ToolRequestPart(
  toolRequest: ToolRequest(name: 'echo', ref: 'r1', input: input),
);

void main() {
  group('needsWrapping', () {
    Map<String, dynamic> schema(SchemanticType<dynamic> t) => {
      ...t.jsonSchema(useRefs: true),
      r'$schema': 'draft-07',
    };

    test('wraps primitives, arrays and nullable primitives', () {
      expect(needsWrapping(schema(.string())), isTrue);
      expect(needsWrapping(schema(.integer())), isTrue);
      expect(needsWrapping(schema(.boolean())), isTrue);
      expect(needsWrapping(schema(.list(.string()))), isTrue);
      expect(needsWrapping(schema(.nullable(.string()))), isTrue);
    });

    test('leaves objects, maps and untyped schemas alone', () {
      expect(needsWrapping(schema(Message.$schema)), isFalse);
      expect(needsWrapping(schema(.map(.string(), .dynamicSchema()))), isFalse);
      expect(needsWrapping(schema(.dynamicSchema())), isFalse);
      expect(needsWrapping(schema(.dynamicSchema(description: 'x'))), isFalse);
    });

    test('annotations on a typed primitive still wrap', () {
      expect(needsWrapping(schema(.string(description: 'x'))), isTrue);
    });

    test('chunks without wrapped tool calls pass through untouched', () {
      final wrapping = ToolInputWrapping.forTools([
        ToolDefinition(
          name: 'echo',
          description: 'd',
          inputSchema: {'type': 'string'},
        ),
      ])!;
      final text = ModelResponseChunk(content: [TextPart(text: 'hi')]);
      expect(identical(wrapping.unwrapChunk(text), text), isTrue);
      final call = ModelResponseChunk(
        content: [
          _echoCall({'input': 'hi'}),
        ],
      );
      final unwrapped = wrapping.unwrapChunk(call);
      expect(unwrapped.content.single.toolRequestPart!.toolRequest.input, 'hi');
    });

    test('keeps definitions on the wrapper root', () {
      final wrapped = wrapSchema(schema(.list(Message.$schema)));
      expect(wrapped['type'], 'object');
      expect(wrapped, contains(r'$defs'));
      expect(wrapped, contains(r'$schema'));
      final inner = (wrapped['properties'] as Map)['input'] as Map;
      expect(inner, isNot(contains(r'$defs')));
      expect(inner, isNot(contains(r'$schema')));
    });
  });

  group('generate with a primitive tool input', () {
    late Genkit genkit;
    late List<Object?> middlewareSaw;
    late List<ModelRequest> wireRequests;
    late Object? toolGot;
    late Object? ctxToolRequestInput;
    late bool interruptOnce;

    setUp(() {
      middlewareSaw = [];
      wireRequests = [];
      toolGot = null;
      ctxToolRequestInput = null;
      interruptOnce = false;
      genkit = Genkit(
        isDevEnv: false,
        plugins: [
          _SpyPlugin([
            generateMiddleware(
              name: 'spy',
              create: (_, _) => _ToolInputSpy(middlewareSaw),
            ),
          ]),
        ],
      );

      // A provider stand-in: it only understands object parameters, so it
      // emits object-shaped calls.
      genkit.defineModel(
        name: 'wire',
        fn: (request, ctx) async {
          wireRequests.add(request);
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: .stop,
              message: Message(
                role: .model,
                content: [TextPart(text: 'ok')],
              ),
            );
          }
          ctx.sendChunk(
            ModelResponseChunk(
              content: [
                _echoCall({'input': 'hi'}),
              ],
            ),
          );
          return ModelResponse(
            finishReason: .stop,
            message: Message(
              role: .model,
              content: [
                _echoCall({'input': 'hi'}),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'echo',
        description: 'Echo a string back.',
        inputSchema: .string(),
        fn: (input, ctx) async {
          toolGot = input;
          ctxToolRequestInput = ctx.toolRequest?.toolRequest.input;
          if (interruptOnce && ctx.resumed == null) {
            return .interrupt('confirm');
          }
          return .response('echo: $input');
        },
      );
    });

    tearDown(() => genkit.shutdown());

    test('the model sees the wrapped schema and wrapped history', () async {
      await genkit.generate(
        model: modelRef('wire'),
        prompt: 'go',
        toolNames: ['echo'],
      );

      final schema = wireRequests.first.tools!.single.inputSchema!;
      expect(schema['type'], 'object');
      expect(schema['properties'], {
        'input': {'type': 'string'},
      });
      expect(schema['required'], ['input']);

      // Second turn: the history replays the call in wire shape.
      final replayed = wireRequests.last.messages
          .expand((m) => m.content)
          .firstWhere((p) => p.isToolRequest);
      expect(replayed.toolRequestPart!.toolRequest.input, {'input': 'hi'});
    });

    test('everything above the model sees the declared shape', () async {
      final chunkInputs = <Object?>[];
      final response = await genkit.generate(
        model: modelRef('wire'),
        prompt: 'go',
        toolNames: ['echo'],
        use: [middlewareRef(name: 'spy')],
        onChunk: (chunk) => chunkInputs.addAll(
          chunk.content
              .where((p) => p.isToolRequest)
              .map((p) => p.toolRequestPart!.toolRequest.input),
        ),
      );

      expect(toolGot, 'hi');
      expect(middlewareSaw, ['hi']);
      expect(ctxToolRequestInput, 'hi');
      expect(chunkInputs, ['hi']);
      // The request trace (and `ToolDefinition`) keep the declared schema.
      expect(
        response.modelRequest!.tools!.single.inputSchema!['type'],
        'string',
      );
      final historyCall = response.messages
          .expand((m) => m.content)
          .firstWhere((p) => p.isToolRequest);
      expect(historyCall.toolRequestPart!.toolRequest.input, 'hi');
    });

    test('interrupts and restarts carry the bare value', () async {
      interruptOnce = true;
      final first = await genkit.generate(
        model: modelRef('wire'),
        prompt: 'go',
        toolNames: ['echo'],
      );
      expect(first.finishReason, FinishReason.interrupted);
      final interrupt = first.interrupts.single;
      expect(interrupt.toolRequest.input, 'hi');
      expect(AgentInterrupt<String, String>(interrupt).input, 'hi');

      final second = await genkit.generate(
        model: modelRef('wire'),
        messages: first.messages,
        toolNames: ['echo'],
        interruptRestart: [
          ToolRequestPart(
            toolRequest: interrupt.toolRequest,
            metadata: {'resumed': true},
          ),
        ],
      );
      expect(second.text, 'ok');
      expect(toolGot, 'hi');
    });

    test('returnToolRequests hands back the bare value', () async {
      final response = await genkit.generate(
        model: modelRef('wire'),
        prompt: 'go',
        toolNames: ['echo'],
        returnToolRequests: true,
      );
      expect(response.toolRequests.single.input, 'hi');
    });
  });

  test('generateBidi wraps the init and unwraps tool calls', () async {
    final genkit = Genkit(isDevEnv: false);
    addTearDown(genkit.shutdown);
    Object? toolGot;
    Map<String, dynamic>? wireSchema;

    genkit.defineTool(
      name: 'echo',
      description: 'Echo a string back.',
      inputSchema: .string(),
      fn: (input, _) async {
        toolGot = input;
        return .response('echo: $input');
      },
    );

    genkit.defineBidiModel(
      name: 'bidiWire',
      fn: (input, ctx) async {
        wireSchema = ctx.init?.tools?.single.inputSchema;
        await for (final request in input) {
          if (request.messages.first.role == Role.tool) {
            ctx.sendChunk(
              ModelResponseChunk(content: [TextPart(text: 'done')]),
            );
          } else {
            ctx.sendChunk(
              ModelResponseChunk(
                content: [
                  _echoCall({'input': 'hi'}),
                ],
              ),
            );
          }
        }
        return ModelResponse(finishReason: .stop);
      },
    );

    final session = await genkit.generateBidi(
      model: 'bidiWire',
      toolNames: ['echo'],
    );
    final done = Completer<void>();
    session.stream.listen((chunk) {
      if (chunk.text == 'done' && !done.isCompleted) done.complete();
    });
    session.send('go');
    await done.future.timeout(const Duration(seconds: 2));
    await session.close();

    expect(wireSchema?['type'], 'object');
    expect(toolGot, 'hi');
  });
}
