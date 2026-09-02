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
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Headers of the most recent captured request, alongside its decoded body.
Map<String, String> _lastHeaders = const {};

/// A minimal well-formed Anthropic SSE stream, enough for the SDK accumulator.
String _sseStream(String model) {
  String event(String type, Map<String, dynamic> data) =>
      'event: $type\ndata: ${jsonEncode(data)}\n\n';

  return event('message_start', {
        'type': 'message_start',
        'message': {
          'id': 'msg_test',
          'type': 'message',
          'role': 'assistant',
          'model': model,
          'content': <dynamic>[],
          'stop_reason': null,
          'stop_sequence': null,
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        },
      }) +
      event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'text', 'text': ''},
      }) +
      event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'ok'},
      }) +
      event('content_block_stop', {'type': 'content_block_stop', 'index': 0}) +
      event('message_delta', {
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn', 'stop_sequence': null},
        'usage': {'output_tokens': 1},
      }) +
      event('message_stop', {'type': 'message_stop'});
}

Future<Map<String, dynamic>> _requestOnTheWire({
  required String model,
  ThinkingConfig? thinking,
  AnthropicOutputConfig? outputConfig,
  String? apiVersion,
  List<String>? betas,
  String? pluginApiVersion,
  Map<String, dynamic>? outputSchema,
  String? toolChoice,
  bool streaming = false,
}) async {
  Map<String, dynamic>? captured;
  final client = MockClient((request) async {
    if (request.url.path != '/v1/messages') {
      return http.Response('not found', 404);
    }
    _lastHeaders = request.headers;
    captured = (jsonDecode(request.body) as Map).cast<String, dynamic>();

    if (streaming) {
      return http.Response(
        _sseStream(model),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    return http.Response(
      jsonEncode({
        'id': 'msg_test',
        'type': 'message',
        'role': 'assistant',
        'model': model,
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
        'stop_reason': 'end_turn',
        'stop_sequence': null,
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final plugin = AnthropicPluginImpl(
    apiKey: 'test-key',
    httpClient: client,
    apiVersion: pluginApiVersion,
  );
  addTearDown(plugin.close);
  final action = plugin.resolve(.model, model) as Model;

  await action(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ],
      toolChoice: toolChoice,
      output: outputSchema == null
          ? null
          : OutputConfig(
              format: 'json',
              constrained: true,
              schema: outputSchema,
            ),
      config: AnthropicOptions(
        thinking: thinking,
        outputConfig: outputConfig,
        apiVersion: apiVersion,
        betas: betas,
      ).toJson(),
    ),
    onChunk: streaming ? (_) {} : null,
  );

  return captured!;
}

void main() {
  group('thinking config on the wire', () {
    const adaptiveModels = [
      'claude-fable-5',
      'claude-opus-5',
      'claude-opus-4-8',
      'claude-opus-4-7',
      'claude-opus-4-6',
      'claude-sonnet-5',
      'claude-sonnet-4-6',
    ];

    for (final model in adaptiveModels) {
      test('$model defaults to adaptive', () async {
        final body = await _requestOnTheWire(
          model: model,
          thinking: ThinkingConfig(),
        );
        expect(body['thinking'], {'type': 'adaptive'});
      });
    }

    test('dated adaptive snapshot uses its curated alias', () async {
      final body = await _requestOnTheWire(
        model: 'claude-opus-4-7-20260205',
        thinking: ThinkingConfig(),
      );
      expect(body['thinking'], {'type': 'adaptive'});
    });

    test('Claude 4.5 models default to manual thinking', () async {
      final sonnet = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        thinking: ThinkingConfig(),
      );
      final haiku = await _requestOnTheWire(
        model: 'claude-haiku-4-5-20251001',
        thinking: ThinkingConfig(budgetTokens: 2048),
      );
      final opus = await _requestOnTheWire(
        model: 'claude-opus-4-5',
        thinking: ThinkingConfig(),
      );

      expect(sonnet['thinking'], {'type': 'enabled', 'budget_tokens': 1024});
      expect(haiku['thinking'], {'type': 'enabled', 'budget_tokens': 2048});
      expect(opus['thinking'], {'type': 'enabled', 'budget_tokens': 1024});
    });

    test('explicit types override curated defaults', () async {
      final manual = await _requestOnTheWire(
        model: 'claude-opus-4-7',
        thinking: ThinkingConfig(type: 'enabled', budgetTokens: 2048),
      );
      final adaptive = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        thinking: ThinkingConfig(type: 'adaptive', budgetTokens: 2048),
      );

      expect(manual['thinking'], {'type': 'enabled', 'budget_tokens': 2048});
      expect(adaptive['thinking'], {'type': 'adaptive'});
    });

    test('explicit type works for an unknown model', () async {
      final body = await _requestOnTheWire(
        model: 'claude-future-model',
        thinking: ThinkingConfig(type: 'disabled'),
      );
      expect(body['thinking'], {'type': 'disabled'});
    });

    test('unknown model requires an explicit type', () async {
      await expectLater(
        _requestOnTheWire(
          model: 'claude-future-model',
          thinking: ThinkingConfig(),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having((e) => e.message, 'message', contains('thinking.type')),
        ),
      );
    });

    test('omits thinking when no config is provided', () async {
      final body = await _requestOnTheWire(model: 'claude-opus-4-7');
      expect(body, isNot(contains('thinking')));
    });
  });

  group('output config on the wire', () {
    for (final effort in ['low', 'medium', 'high', 'xhigh', 'max']) {
      test('maps $effort effort', () async {
        final body = await _requestOnTheWire(
          model: 'claude-sonnet-5',
          outputConfig: AnthropicOutputConfig(effort: effort),
        );
        expect(body['output_config'], {'effort': effort});
      });
    }

    test('omits output_config when no effort is provided', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-5',
        outputConfig: AnthropicOutputConfig(),
      );
      expect(body, isNot(contains('output_config')));
    });
  });

  group('api version on the wire', () {
    test('stable is the default and sends no beta header', () async {
      await _requestOnTheWire(model: 'claude-sonnet-5');
      expect(_lastHeaders, isNot(contains('anthropic-beta')));
    });

    test('request apiVersion beta sends the curated list', () async {
      await _requestOnTheWire(model: 'claude-sonnet-5', apiVersion: 'beta');
      expect(_lastHeaders['anthropic-beta'], defaultAnthropicBetas.join(','));
    });

    test('plugin-level beta applies when the request is silent', () async {
      await _requestOnTheWire(
        model: 'claude-sonnet-5',
        pluginApiVersion: 'beta',
      );
      expect(_lastHeaders['anthropic-beta'], defaultAnthropicBetas.join(','));
    });

    test('request stable overrides a beta plugin default', () async {
      await _requestOnTheWire(
        model: 'claude-sonnet-5',
        pluginApiVersion: 'beta',
        apiVersion: 'stable',
      );
      expect(_lastHeaders, isNot(contains('anthropic-beta')));
    });

    test('a supplied betas list replaces the default', () async {
      await _requestOnTheWire(
        model: 'claude-sonnet-5',
        apiVersion: 'beta',
        betas: ['my-beta-2026-01-01'],
      );
      expect(_lastHeaders['anthropic-beta'], 'my-beta-2026-01-01');
    });

    test('betas are ignored on the stable surface', () async {
      await _requestOnTheWire(
        model: 'claude-sonnet-5',
        betas: ['my-beta-2026-01-01'],
      );
      expect(_lastHeaders, isNot(contains('anthropic-beta')));
    });

    test('the streaming path sends the beta header too', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-5',
        apiVersion: 'beta',
        streaming: true,
      );
      expect(body['stream'], true);
      expect(_lastHeaders['anthropic-beta'], defaultAnthropicBetas.join(','));
    });

    test('the streaming path stays stable by default', () async {
      await _requestOnTheWire(model: 'claude-sonnet-5', streaming: true);
      expect(_lastHeaders, isNot(contains('anthropic-beta')));
    });
  });

  group('structured output on the wire', () {
    final schema = <String, dynamic>{
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'pet': {
          'type': 'object',
          'properties': {
            'species': {'type': 'string'},
          },
        },
      },
    };

    test('a capable model sends a native json_schema format', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
      );

      final format =
          (body['output_config'] as Map)['format'] as Map<String, dynamic>;
      expect(format['type'], 'json_schema');
      expect(body, isNot(contains('tools')));
      expect(body, isNot(contains('tool_choice')));
    });

    test('normalization strips \$schema and closes nested objects', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent, isNot(contains(r'$schema')));
      expect(sent['additionalProperties'], false);

      final pet = (sent['properties'] as Map)['pet'] as Map;
      expect(pet['additionalProperties'], false);
    });

    test('an uncurated model falls back to the forced tool', () async {
      final body = await _requestOnTheWire(
        model: 'claude-future-model',
        outputSchema: schema,
      );

      expect(body, isNot(contains('output_config')));
      final tool = (body['tools'] as List).single as Map<String, dynamic>;
      expect(tool['name'], 'return_output');
      expect(body['tool_choice'], {'type': 'tool', 'name': 'return_output'});
    });

    test('native structured output composes with manual thinking', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
        thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
      );

      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 1024});
      expect((body['output_config'] as Map)['format'], isNotNull);
    });

    test('the fallback rejects manual thinking instead of erroring on the '
        'wire', () async {
      await expectLater(
        _requestOnTheWire(
          model: 'claude-future-model',
          outputSchema: schema,
          thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having((e) => e.message, 'message', contains('manual thinking')),
        ),
      );
    });

    test('the fallback allows adaptive thinking', () async {
      final body = await _requestOnTheWire(
        model: 'claude-future-model',
        outputSchema: schema,
        thinking: ThinkingConfig(type: 'adaptive'),
      );
      expect(body['tool_choice'], {'type': 'tool', 'name': 'return_output'});
    });

    test('a dated snapshot of a capable model still goes native', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5-20250929',
        outputSchema: schema,
      );
      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('tool_choice')));
    });

    test('normalization recurses through schema lists', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'tags': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'label': {'type': 'string'},
                },
              },
            },
            'either': {
              'anyOf': [
                {
                  'type': 'object',
                  'properties': {
                    'a': {'type': 'string'},
                  },
                },
              ],
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final props = sent['properties'] as Map;
      final items = (props['tags'] as Map)['items'] as Map;
      expect(items['additionalProperties'], false);

      final anyOf = (props['either'] as Map)['anyOf'] as List;
      expect((anyOf.single as Map)['additionalProperties'], false);
    });

    test('a \$ref root keeps no sibling constraints', () async {
      // Named Genkit schemas arrive as a bare $ref plus $defs. Anthropic
      // rejects `$ref` alongside `type`/`additionalProperties`, so neither may
      // be added to the root - only to the definitions it points at.
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          r'$defs': {
            'Person': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
              },
              'required': ['name'],
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent.containsKey('type'), isFalse);
      expect(sent.containsKey('additionalProperties'), isFalse);

      final person = (sent[r'$defs'] as Map)['Person'] as Map;
      expect(person['additionalProperties'], false);
    });

    test('an untyped object schema is inferred and closed', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'properties': {
            'name': {'type': 'string'},
            'inner': {
              'required': ['x'],
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent['type'], 'object');
      expect(sent['additionalProperties'], false);

      // Inferred from `required` alone, at depth.
      final inner = (sent['properties'] as Map)['inner'] as Map;
      expect(inner['type'], 'object');
      expect(inner['additionalProperties'], false);

      // A leaf with a declared non-object type is left alone.
      final name = (sent['properties'] as Map)['name'] as Map;
      expect(name.containsKey('additionalProperties'), isFalse);
    });

    test('type is not inferred onto a \$ref node', () async {
      // Inferring here would recreate the sibling-constraint 400 that the
      // $ref guard exists to prevent.
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          'properties': {
            'name': {'type': 'string'},
          },
          r'$defs': {
            'Person': {'type': 'object'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent.containsKey('type'), isFalse);
      expect(sent.containsKey('additionalProperties'), isFalse);
    });

    test('the fallback still types a \$ref root for the tool schema', () async {
      final body = await _requestOnTheWire(
        model: 'claude-future-model',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          r'$defs': {
            'Person': {'type': 'object'},
          },
        },
      );

      final tool = (body['tools'] as List).single as Map<String, dynamic>;
      expect((tool['input_schema'] as Map)['type'], 'object');
    });

    test('effort and a native format ride in the same output_config', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
        outputConfig: AnthropicOutputConfig(effort: 'low'),
      );

      final outputConfig = body['output_config'] as Map;
      expect(outputConfig['effort'], 'low');
      expect((outputConfig['format'] as Map)['type'], 'json_schema');
    });

    test('a caller toolChoice cannot unforce return_output', () async {
      // Honoring 'auto' here would let the model skip the tool that carries
      // the schema, silently losing structured output.
      final body = await _requestOnTheWire(
        model: 'claude-future-model',
        outputSchema: schema,
        toolChoice: 'auto',
      );
      expect(body['tool_choice'], {'type': 'tool', 'name': 'return_output'});
    });

    test('a caller toolChoice still applies on the native path', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
        toolChoice: 'auto',
      );
      expect(body['tool_choice'], {'type': 'auto'});
      expect((body['output_config'] as Map)['format'], isNotNull);
    });
  });
}
