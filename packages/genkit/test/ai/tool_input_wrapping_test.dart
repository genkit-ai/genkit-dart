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
import 'package:genkit/src/ai/generate.dart' show toToolDefinition;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

Tool<I, String> _tool<I>(SchemanticType<I>? inputSchema) => Tool<I, String>(
  name: 'probe',
  description: 'probe',
  inputSchema: inputSchema,
  fn: (input, _) async => .response('ok'),
);

/// Records the input each `tool` hook sees.
class _RecordingMiddleware extends GenerateMiddleware {
  final List<Object?> seen;
  _RecordingMiddleware(this.seen);

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

class _RecordingPlugin extends GenkitPlugin {
  final List<Object?> seen;
  _RecordingPlugin(this.seen);

  @override
  String get name => 'recording';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<void>(
      name: 'recording',
      create: (_, _) => _RecordingMiddleware(seen),
    ),
  ];
}

void main() {
  group('tool input schema sent to the model', () {
    test('wraps a primitive', () {
      final def = toToolDefinition(_tool(.string()));
      expect(def.inputSchema, {
        'type': 'object',
        'properties': {
          'input': {'type': 'string'},
        },
        'required': ['input'],
        r'$schema': 'http://json-schema.org/draft-07/schema#',
      });
    });

    test('wraps a list and a nullable primitive', () {
      expect(_tool(.list(.integer())).wrapsInput, isTrue);
      expect(_tool(.nullable(.string())).wrapsInput, isTrue);
    });

    test(r'keeps $defs at the root when wrapping', () {
      final def = toToolDefinition(_tool(.list(Message.$schema)));
      final schema = def.inputSchema!;
      expect(schema[r'$defs'], containsPair('Message', isA<Map>()));
      final input = (schema['properties'] as Map)['input'] as Map;
      expect(input.containsKey(r'$defs'), isFalse);
      expect(input['items'], {r'$ref': r'#/$defs/Message'});
    });

    test('leaves object schemas alone', () {
      // A generated class (root `$ref` into `$defs`), a map, a nullable
      // object, and no / an empty schema.
      for (final schema in <SchemanticType?>[
        Message.$schema,
        .map(.string(), .dynamicSchema()),
        .nullable(Message.$schema),
        .dynamicSchema(),
        null,
      ]) {
        final tool = _tool(schema);
        expect(tool.wrapsInput, isFalse, reason: '$schema');
        final properties = toToolDefinition(tool).inputSchema?['properties'];
        expect((properties as Map?)?['input'], isNull);
      }
    });
  });

  group('generate with a primitive tool input', () {
    late Genkit ai;
    final seenByMiddleware = <Object?>[];
    setUp(() {
      seenByMiddleware.clear();
      ai = Genkit(
        isDevEnv: false,
        plugins: [_RecordingPlugin(seenByMiddleware)],
      );
    });
    tearDown(() => ai.shutdown());

    /// A model that calls `echo` with [toolInput], then replies with the
    /// tool's output.
    void defineCallingModel(Object? toolInput) {
      ai.defineModel(
        name: 'caller',
        fn: (request, _) async {
          final last = request.messages.last;
          final content = last.role == .tool
              ? <Part>[
                  TextPart(text: '${last.content.first.toolResponse!.output}'),
                ]
              : <Part>[
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'echo',
                      ref: 'r1',
                      input: toolInput,
                    ),
                  ),
                ];
          return ModelResponse(
            finishReason: .stop,
            message: Message(role: .model, content: content),
          );
        },
      );
    }

    test('unwraps the input before the tool runs', () async {
      defineCallingModel({'input': 'hello'});
      final received = <String>[];
      ai.defineTool(
        name: 'echo',
        description: 'Echo a string back.',
        inputSchema: .string(),
        fn: (input, _) async {
          received.add(input);
          return .response('echo: $input');
        },
      );

      final res = await ai.generate(
        model: modelRef('caller'),
        prompt: 'go',
        toolNames: ['echo'],
        use: [middlewareRef(name: 'recording')],
      );

      expect(res.text, 'echo: hello');
      expect(received, ['hello']);
      // Middleware and history both keep the request exactly as the model
      // sent it.
      expect(seenByMiddleware, [
        {'input': 'hello'},
      ]);
      final request = res.messages
          .expand((m) => m.content)
          .firstWhere((p) => p.isToolRequest);
      expect(request.toolRequest!.input, {'input': 'hello'});
    });

    test('a list input round-trips', () async {
      defineCallingModel({
        'input': [1, 2, 3],
      });
      ai.defineTool(
        name: 'echo',
        description: 'Sums numbers.',
        inputSchema: .list(.integer()),
        fn: (input, _) async =>
            .response('${input.fold<int>(0, (a, b) => a + b)}'),
      );

      final res = await ai.generate(
        model: modelRef('caller'),
        prompt: 'go',
        toolNames: ['echo'],
      );
      expect(res.text, '6');
    });

    test('an interrupt restart unwraps the input too', () async {
      defineCallingModel({'input': 'hello'});
      var calls = 0;
      final received = <String>[];
      ai.defineTool(
        name: 'echo',
        description: 'Echo a string back, after confirmation.',
        inputSchema: .string(),
        fn: (input, ctx) async {
          received.add(input);
          if (calls++ == 0) return .interrupt('confirm?');
          return .response('echo: $input');
        },
      );

      final first = await ai.generate(
        model: modelRef('caller'),
        prompt: 'go',
        toolNames: ['echo'],
      );
      expect(first.finishReason, FinishReason.interrupted);

      final second = await ai.generate(
        model: modelRef('caller'),
        messages: first.messages,
        toolNames: ['echo'],
        interruptRestart: [first.interrupts.single],
      );

      expect(second.text, 'echo: hello');
      expect(received, ['hello', 'hello']);
    });
  });
}
