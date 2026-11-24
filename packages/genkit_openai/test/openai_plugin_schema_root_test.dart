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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/chat.dart' show needsRootWrapper;
import 'package:genkit_openai/src/schema_root.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

const _arraySchema = {
  'type': 'array',
  'items': {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
  },
};

SchemanticType<Object?> _raw(Map<String, Object?> schema) =>
    SchemanticType.from(jsonSchema: schema, parse: (json) => json);

String _deltaFrame({String? content, List<Map<String, Object?>>? toolCalls}) =>
    jsonEncode({
      'id': 'chatcmpl-test',
      'object': 'chat.completion.chunk',
      'created': 0,
      'model': 'gpt-4o',
      'choices': [
        {
          'index': 0,
          'delta': {'content': ?content, 'tool_calls': ?toolCalls},
          'finish_reason': null,
        },
      ],
    });

/// Answers chat completions with [content], as JSON or as an event stream of
/// [frames], and records the request bodies the plugin sent.
MockClient _client(
  List<Map<String, dynamic>> captured, {
  String content = '',
  List<String>? frames,
  List<Map<String, Object?>>? toolCalls,
}) {
  return MockClient((request) async {
    if (!request.url.path.endsWith('/chat/completions')) {
      return http.Response('not found', 404);
    }
    final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
    captured.add(body);
    if (body['stream'] == true) {
      final events = (frames ?? [_deltaFrame(content: content)])
          .map((f) => 'data: $f\n\n')
          .join();
      return http.Response(
        '${events}data: [DONE]\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    return http.Response(
      jsonEncode({
        'id': 'chatcmpl-test',
        'object': 'chat.completion',
        'created': 0,
        'model': 'gpt-4o',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': content,
              'tool_calls': ?toolCalls,
            },
            'finish_reason': toolCalls == null ? 'stop' : 'tool_calls',
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// The schema [body] sent, without the `$schema` Genkit adds at the root.
Map<String, dynamic> _sentSchema(Map<String, dynamic> body) => {
  ...((body['response_format'] as Map)['json_schema'] as Map)['schema']
      as Map<String, dynamic>,
}..remove(r'$schema');

String _run(List<String> deltas) {
  final unwrapper = WrapperStreamUnwrapper();
  return deltas.map(unwrapper.push).join() + unwrapper.flush();
}

void main() {
  group('hasObjectRoot', () {
    test('is true only for an explicit object type', () {
      expect(hasObjectRoot({'type': 'object'}), isTrue);
      expect(hasObjectRoot(_arraySchema), isFalse);
      expect(
        hasObjectRoot({
          'type': 'string',
          'enum': ['a'],
        }),
        isFalse,
      );
      expect(
        hasObjectRoot({
          'anyOf': [
            {'type': 'object'},
          ],
        }),
        isFalse,
      );
      expect(
        hasObjectRoot({
          'properties': {'a': {}},
        }),
        isFalse,
        reason: 'properties without a type also allow non-objects',
      );
    });
  });

  group('wrapSchemaRoot', () {
    test('wraps the schema as a single required property', () {
      expect(wrapSchemaRoot(_arraySchema), {
        'type': 'object',
        'properties': {'value': _arraySchema},
        'required': ['value'],
        'additionalProperties': false,
      });
    });

    test(r'keeps $schema at the root', () {
      const schema = {
        r'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'type': 'number',
      };
      expect(wrapSchemaRoot(schema), {
        r'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'type': 'object',
        'properties': {
          'value': {'type': 'number'},
        },
        'required': ['value'],
        'additionalProperties': false,
      });
      expect(schema.containsKey(r'$schema'), isTrue);
    });
  });

  group('unwrapText', () {
    test('returns the wrapped value', () {
      expect(unwrapText('{"value":[{"name":"a"}]}'), '[{"name":"a"}]');
      expect(unwrapText('{"value":42}'), '42');
      expect(unwrapText('{"value":"red"}'), '"red"');
    });

    test('keeps falsy values', () {
      expect(unwrapText('{"value":0}'), '0');
      expect(unwrapText('{"value":false}'), 'false');
      expect(unwrapText('{"value":""}'), '""');
      expect(unwrapText('{"value":null}'), 'null');
    });

    test('passes through anything that is not a wrapper', () {
      expect(unwrapText('[1,2]'), '[1,2]');
      expect(unwrapText('{"other":1}'), '{"other":1}');
      expect(unwrapText('not json'), 'not json');
    });
  });

  group('unwrapMessage', () {
    test('unwraps text and keeps other parts', () {
      final message = unwrapMessage(
        Message(
          role: Role.model,
          content: [
            ReasoningPart(reasoning: 'thinking'),
            TextPart(text: '{"value":[1]}'),
          ],
        ),
      );
      expect(message.content.first.reasoning, 'thinking');
      expect(message.content.last.text, '[1]');
    });

    test('leaves a tool-call preamble alone', () {
      final message = unwrapMessage(
        Message(
          role: Role.model,
          content: [
            TextPart(text: '{"value":1}'),
            ToolRequestPart(
              toolRequest: ToolRequest(name: 'lookup', input: {}),
            ),
          ],
        ),
      );
      expect(message.content.first.text, '{"value":1}');
    });
  });

  group('WrapperStreamUnwrapper', () {
    const full = '{"value":[{"name":"a"},{"name":"b"}]}';

    test('strips the wrapper however the stream is split', () {
      expect(_run([full]), '[{"name":"a"},{"name":"b"}]');
      expect(_run(full.split('')), '[{"name":"a"},{"name":"b"}]');
      for (var i = 1; i < full.length; i++) {
        expect(
          _run([full.substring(0, i), full.substring(i)]),
          '[{"name":"a"},{"name":"b"}]',
          reason: 'split at $i',
        );
      }
    });

    test('handles whitespace and pretty-printed output', () {
      expect(_run(['{ "value" : ', '[1, 2]', ' }\n']), '[1, 2]');
      expect(_run('{\n  "value": {"a": 1}\n}'.split('')), '{"a": 1}');
    });

    test('gives the same result however a spaced opening is split', () {
      const spaced = '{ "value" :  [1, 2] }';
      for (var i = 1; i < spaced.length; i++) {
        expect(
          _run([spaced.substring(0, i), spaced.substring(i)]),
          '[1, 2]',
          reason: 'split at $i',
        );
      }
      expect(_run(spaced.split('')), '[1, 2]');
    });

    test('unwraps scalars', () {
      expect(_run('{"value":42}'.split('')), '42');
      expect(_run('{"value":"red"}'.split('')), '"red"');
    });

    test('never emits the closing brace early', () {
      final unwrapper = WrapperStreamUnwrapper();
      expect(unwrapper.push('{"value":{"a":1}'), '{"a":1');
      expect(unwrapper.push('}'), '');
      expect(unwrapper.flush(), '}');
    });

    test('passes through output that is not a wrapper', () {
      expect(_run('[1,2]'.split('')), '[1,2]');
      expect(_run('{"valuable":1}'.split('')), '{"valuable":1}');
      expect(_run('{"other":1}'.split('')), '{"other":1}');
    });

    test('passThrough returns held text and stops unwrapping', () {
      final unwrapper = WrapperStreamUnwrapper();
      expect(unwrapper.push('{"val'), '');
      expect(unwrapper.passThrough(), '{"val');
      expect(unwrapper.push('ue":1}'), 'ue":1}');
      expect(unwrapper.flush(), '');
    });
  });

  group('openAI() with a non-object schema root', () {
    test('sends the schema wrapped and returns the unwrapped value', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            httpClient: _client(
              captured,
              content: '{"value":[{"name":"a"},{"name":"b"}]}',
            ),
          ),
        ],
      );

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'List two people.',
        outputSchema: _raw(_arraySchema),
        outputFormat: 'json',
      );

      expect(_sentSchema(captured.single), wrapSchemaRoot(_arraySchema));
      expect(response.text, '[{"name":"a"},{"name":"b"}]');
      expect(response.output, [
        {'name': 'a'},
        {'name': 'b'},
      ]);
      await ai.shutdown();
    });

    test('keeps a falsy scalar', () async {
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            httpClient: _client([], content: '{"value":0}'),
          ),
        ],
      );
      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Zero.',
        outputSchema: _raw({'type': 'number'}),
        outputFormat: 'json',
      );
      expect(response.output, 0);
      await ai.shutdown();
    });

    test('streams unwrapped chunks and an unwrapped final message', () async {
      final captured = <Map<String, dynamic>>[];
      const full = '{"value":[{"name":"a"},{"name":"b"}]}';
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            httpClient: _client(
              captured,
              frames: [
                for (var i = 0; i < full.length; i += 5)
                  _deltaFrame(
                    content: full.substring(
                      i,
                      i + 5 < full.length ? i + 5 : full.length,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );

      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
        prompt: 'List two people.',
        outputSchema: _raw(_arraySchema),
        outputFormat: 'json',
      );
      final streamed = StringBuffer();
      await for (final chunk in stream) {
        streamed.write(chunk.text);
      }
      final response = await stream.onResult;

      expect(_sentSchema(captured.single), wrapSchemaRoot(_arraySchema));
      expect(streamed.toString(), '[{"name":"a"},{"name":"b"}]');
      expect(response.output, [
        {'name': 'a'},
        {'name': 'b'},
      ]);
      await ai.shutdown();
    });

    test('streams a tool-call preamble unchanged', () async {
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            httpClient: _client(
              [],
              frames: [
                _deltaFrame(content: '{"val'),
                _deltaFrame(
                  toolCalls: [
                    {
                      'index': 0,
                      'id': 'call_1',
                      'type': 'function',
                      'function': {'name': 'lookup', 'arguments': '{}'},
                    },
                  ],
                ),
              ],
            ),
          ),
        ],
      );
      ai.defineTool(
        name: 'lookup',
        description: 'Looks things up.',
        fn: (input, ctx) async => .response('found'),
      );

      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
        prompt: 'List two people.',
        outputSchema: _raw(_arraySchema),
        outputFormat: 'json',
        toolNames: ['lookup'],
        returnToolRequests: true,
      );
      final streamed = StringBuffer();
      await for (final chunk in stream) {
        streamed.write(chunk.text);
      }
      final response = await stream.onResult;

      expect(streamed.toString(), '{"val');
      expect(response.message!.content.first.text, '{"val');
      expect(response.toolRequests, hasLength(1));
      await ai.shutdown();
    });

    test('sends an object root unchanged', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            httpClient: _client(captured, content: '{"a":"x"}'),
          ),
        ],
      );
      const object = {
        'type': 'object',
        'properties': {
          'a': {'type': 'string'},
        },
      };

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'An object.',
        outputSchema: _raw(object),
        outputFormat: 'json',
      );

      expect(_sentSchema(captured.single), object);
      expect(response.output, {'a': 'x'});
      await ai.shutdown();
    });
  });

  group('needsRootWrapper', () {
    test(
      'is true only for an object-only host, JSON output, non-object root',
      () {
        expect(
          needsRootWrapper(
            format: 'json',
            schema: _arraySchema,
            objectSchemaRoot: true,
          ),
          isTrue,
        );
        expect(
          needsRootWrapper(
            contentType: 'application/json',
            schema: _arraySchema,
            objectSchemaRoot: true,
          ),
          isTrue,
        );
        expect(needsRootWrapper(format: 'json', schema: _arraySchema), isFalse);
        expect(
          needsRootWrapper(
            format: 'json',
            schema: _arraySchema,
            objectSchemaRoot: true,
            supportsJsonSchema: false,
          ),
          isFalse,
        );
        expect(
          needsRootWrapper(format: 'json', objectSchemaRoot: true),
          isFalse,
        );
        expect(
          needsRootWrapper(
            format: 'text',
            schema: _arraySchema,
            objectSchemaRoot: true,
          ),
          isFalse,
        );
      },
    );

    test(r'looks at the root after $refs are resolved', () {
      const refToObject = {
        r'$ref': r'#/$defs/Person',
        r'$defs': {
          'Person': {'type': 'object'},
        },
      };
      expect(
        needsRootWrapper(
          format: 'json',
          schema: refToObject,
          objectSchemaRoot: true,
        ),
        isFalse,
      );
    });
  });

  test('a typed list schema with the default format is wrapped', () async {
    final captured = <Map<String, dynamic>>[];
    final ai = Genkit(
      plugins: [
        openAI(
          apiKey: 'test-key',
          httpClient: _client(captured, content: '{"value":["a","b"]}'),
        ),
      ],
    );

    final response = await ai.generate(
      model: openAI.model('gpt-4o'),
      prompt: 'Two letters.',
      outputSchema: SchemanticType.list(SchemanticType.string()),
    );

    expect(_sentSchema(captured.single)['required'], ['value']);
    expect(response.output, ['a', 'b']);
    await ai.shutdown();
  });

  test('openAI() pointed at another host still wraps', () async {
    // Gateways in front of OpenAI (OpenRouter, Azure) reject the same roots.
    final captured = <Map<String, dynamic>>[];
    final ai = Genkit(
      plugins: [
        openAI(
          name: 'gateway',
          apiKey: 'test-key',
          baseUrl: 'https://gateway.example.com/v1',
          httpClient: _client(captured, content: '{"value":[{"name":"a"}]}'),
        ),
      ],
    );

    final response = await ai.generate(
      model: modelRef('gateway/gpt-4o'),
      prompt: 'List one person.',
      outputSchema: _raw(_arraySchema),
      outputFormat: 'json',
    );

    expect(_sentSchema(captured.single), wrapSchemaRoot(_arraySchema));
    expect(response.output, [
      {'name': 'a'},
    ]);
    await ai.shutdown();
  });

  test('xAI sends a non-object root unchanged', () async {
    final captured = <Map<String, dynamic>>[];
    final ai = Genkit(
      plugins: [
        xAI(
          apiKey: 'test-key',
          httpClient: _client(captured, content: '[{"name":"a"}]'),
        ),
      ],
    );

    final response = await ai.generate(
      model: xAI.model('grok-4'),
      prompt: 'List one person.',
      outputSchema: _raw(_arraySchema),
      outputFormat: 'json',
    );

    expect(_sentSchema(captured.single), _arraySchema);
    expect(response.output, [
      {'name': 'a'},
    ]);
    await ai.shutdown();
  });
}
