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
import 'package:logging/logging.dart';
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
  List<Message>? messages,
  String? apiVersion,
  List<String>? betas,
  String? pluginApiVersion,
  Map<String, dynamic>? outputSchema,
  bool constrained = true,
  List<String>? tools,
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
      messages:
          messages ??
          [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
      toolChoice: toolChoice,
      tools: tools == null
          ? null
          : [
              for (final name in tools)
                ToolDefinition(
                  name: name,
                  description: 'a tool',
                  inputSchema: {'type': 'object'},
                ),
            ],
      output: outputSchema == null
          ? null
          : OutputConfig(
              format: 'json',
              constrained: constrained,
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
    // `output_config.format` is beta-gated, so every native-path case asks
    // for the beta surface. Stable serves the same schema through the forced
    // `return_output` tool, and an uncurated name reaches neither: it claims
    // nothing, so core simulates and the schema never arrives here at all.
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
        outputSchema: schema,
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent, isNot(contains(r'$schema')));
      expect(sent['additionalProperties'], false);

      final pet = (sent['properties'] as Map)['pet'] as Map;
      expect(pet['additionalProperties'], false);
    });

    test('the stable surface falls back to the forced tool', () async {
      // Outside beta there is no `output_config.format` to put the schema in,
      // so it travels as a tool the model is forced to call.
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
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
        apiVersion: 'beta',
        outputSchema: schema,
        thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
      );

      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 1024});
      expect((body['output_config'] as Map)['format'], isNotNull);
    });

    test('the fallback rejects manual thinking rather than the wire '
        'doing it', () async {
      // The forced tool choice is what Anthropic refuses alongside extended
      // thinking, so the stable path says so before spending the request.
      await expectLater(
        _requestOnTheWire(
          model: 'claude-sonnet-4-5',
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

    test('the fallback refuses a request that also carries tools', () async {
      // Only reachable by overriding apiVersion to stable after core read the
      // beta claim; forcing `return_output` would strand the caller's tools.
      await expectLater(
        _requestOnTheWire(
          model: 'claude-sonnet-4-5',
          pluginApiVersion: 'beta',
          apiVersion: 'stable',
          outputSchema: schema,
          tools: ['lookup'],
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having((e) => e.message, 'message', contains('beta API')),
        ),
      );
    });

    test('a dated snapshot of a capable model still goes native', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5-20250929',
        apiVersion: 'beta',
        outputSchema: schema,
      );
      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('tool_choice')));
    });

    test('normalization recurses through schema lists', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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

    test('a \$ref root passes through without sibling constraints', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          r'$defs': {
            'Person': {'type': 'object'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent[r'$ref'], '#/\$defs/Person');
      // A \$ref node may carry no siblings, so no inferred type is added.
      expect(sent.containsKey('type'), isFalse);
      expect(((sent[r'$defs'] as Map)['Person'] as Map)['type'], 'object');
    });

    test('a nullable object is still closed', () async {
      // `["object","null"]` is how schemantic spells an optional object. An
      // equality check against 'object' missed it, and Anthropic replied
      //   400 For 'object' type, 'additionalProperties' must be explicitly
      //   set to false
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: {
          'type': 'object',
          'properties': {
            'nested': {
              'type': ['object', 'null'],
              'properties': {
                'a': {'type': 'string'},
              },
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final nested = (sent['properties'] as Map)['nested'] as Map;
      expect(nested['additionalProperties'], false);
      expect(sent['additionalProperties'], false);
    });

    test('a field named like a keyword does not corrupt the schema', () async {
      // The recursion descended into every Map, so `properties` was itself
      // treated as a schema node: it gained `type: object` and a closed
      // marker as though the field names were keywords.
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: {
          'type': 'object',
          'properties': {
            'required': {'type': 'boolean'},
            'type': {'type': 'string'},
            'properties': {'type': 'string'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final properties = sent['properties'] as Map;
      expect(
        properties.keys,
        unorderedEquals(['required', 'type', 'properties']),
      );
      expect(properties['required'], {'type': 'boolean'});
      expect(properties.containsKey('additionalProperties'), isFalse);
    });

    test('a \$defs map is not treated as a schema node', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          r'$defs': {
            'Person': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
              },
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final defs = sent[r'$defs'] as Map;
      expect(defs.keys, ['Person']);
      expect((defs['Person'] as Map)['additionalProperties'], false);
      expect(defs.containsKey('type'), isFalse);
    });

    test('validation keywords are stripped from the native schema', () async {
      // output_config validates strictly: "For 'integer' type, properties
      // maximum, minimum are not supported". Genkit's generator emits these
      // from @IntegerField(minimum:), so ordinary annotated types hit it.
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: {
          'type': 'object',
          'properties': {
            'n': {'type': 'integer', 'minimum': 1, 'maximum': 10},
            's': {'type': 'string', 'minLength': 2, 'pattern': '^a'},
            'l': {
              'type': 'array',
              'minItems': 1,
              'items': {'type': 'string'},
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final properties = sent['properties'] as Map;
      expect(properties['n'], {'type': 'integer'});
      expect(properties['s'], {'type': 'string'});
      expect(properties['l'], {
        'type': 'array',
        'items': {'type': 'string'},
      });
    });

    test('an unrecognised apiVersion is rejected, not read as stable', () {
      // Silently downgrading 'Beta' to stable would drop the header and the
      // features that depend on it, with nothing to point at.
      for (final value in ['Beta', 'BETA', 'preview', '']) {
        expect(
          () => resolveBetaEnabled(value, null),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCodes.INVALID_ARGUMENT,
            ),
          ),
          reason: value,
        );
      }
      expect(resolveBetaEnabled('beta', null), isTrue);
      expect(resolveBetaEnabled('stable', null), isFalse);
      expect(resolveBetaEnabled(null, null), isFalse);
    });

    test('effort and a native format ride in the same output_config', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: schema,
        outputConfig: AnthropicOutputConfig(effort: 'low'),
      );

      final outputConfig = body['output_config'] as Map;
      expect(outputConfig['effort'], 'low');
      expect((outputConfig['format'] as Map)['type'], 'json_schema');
    });

    test('a caller toolChoice is dropped when there are no tools', () async {
      // Anthropic rejects a choice with nothing to choose from - "tool_choice.
      // any may only be specified while providing tools". Newly reachable:
      // an output schema used to always append `return_output`, so a caller's
      // toolChoice always had a tool to refer to. Both routes get there now:
      // the curated model goes native on beta, and the uncurated one is
      // simulated by core, which strips the schema before it arrives.
      for (final model in ['claude-sonnet-4-5', 'claude-future-model']) {
        final body = await _requestOnTheWire(
          model: model,
          apiVersion: 'beta',
          outputSchema: schema,
          toolChoice: 'any',
        );
        expect(body['tools'], isNull, reason: model);
        expect(body['tool_choice'], isNull, reason: model);
      }
    });
  });

  group('thinking blocks on the wire', () {
    test('replays a prior assistant turn with its thinking block', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(
                reasoning: 'Hmm',
                metadata: {'thoughtSignature': 'sig_123'},
              ),
              CustomPart(custom: {'redactedThinking': 'opaque_payload'}),
              TextPart(text: 'hi'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'and again?')],
          ),
        ],
      );

      final assistant = (body['messages'] as List)[1] as Map;
      expect(assistant['role'], 'assistant');
      expect(assistant['content'], [
        {'type': 'thinking', 'thinking': 'Hmm', 'signature': 'sig_123'},
        {'type': 'redacted_thinking', 'data': 'opaque_payload'},
        {'type': 'text', 'text': 'hi'},
      ]);
    });

    test('replays a redacted block persisted as a ReasoningPart', () async {
      // Through v0.3.1 a redacted block came back as
      // `ReasoningPart(reasoning: '', metadata: {redactedThinking})`. It is a
      // CustomPart now, matching JS, but the old shape must still replay.
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(
                reasoning: '',
                metadata: {'redactedThinking': 'opaque_payload'},
              ),
              TextPart(text: 'hi'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'and again?')],
          ),
        ],
      );

      expect(((body['messages'] as List)[1] as Map)['content'], [
        {'type': 'redacted_thinking', 'data': 'opaque_payload'},
        {'type': 'text', 'text': 'hi'},
      ]);
    });

    test('replays a thinking block persisted under the pre-0.4 key', () async {
      // Through v0.3.1 the plugin wrote the signature as `signature`. A
      // conversation persisted then and replayed after upgrading must still
      // round-trip, or the upgrade silently drops the blocks this conversion
      // exists to preserve.
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(
                reasoning: 'Hmm',
                metadata: {'signature': 'legacy_sig'},
              ),
              TextPart(text: 'hi'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'and again?')],
          ),
        ],
      );

      final assistant = (body['messages'] as List)[1] as Map;
      expect(assistant['content'], [
        {'type': 'thinking', 'thinking': 'Hmm', 'signature': 'legacy_sig'},
        {'type': 'text', 'text': 'hi'},
      ]);
    });

    test('prefers the current key when a part carries both', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(
                reasoning: 'Hmm',
                metadata: {
                  'thoughtSignature': 'current',
                  'signature': 'legacy',
                },
              ),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'and again?')],
          ),
        ],
      );

      final assistant = (body['messages'] as List)[1] as Map;
      expect((assistant['content'] as List).single, {
        'type': 'thinking',
        'thinking': 'Hmm',
        'signature': 'current',
      });
    });

    test('a malformed redacted payload names its own key', () async {
      final logged = <String>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen((r) => logged.add(r.message));
      addTearDown(sub.cancel);

      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.model,
            content: [
              CustomPart(custom: {'redactedThinking': ''}),
              TextPart(text: 'hi'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'and again?')],
          ),
        ],
      );

      expect(((body['messages'] as List)[1] as Map)['content'], [
        {'type': 'text', 'text': 'hi'},
      ]);
      // Blaming a missing thoughtSignature would name a key nothing read.
      final drops = logged.where((m) => m.startsWith('Dropping')).toList();
      expect(drops, hasLength(1));
      expect(drops.single, contains('redactedThinking'));
      expect(drops.single, isNot(contains('thoughtSignature')));
    });

    test('omits an unsigned thinking block from the wire', () async {
      final body = await _requestOnTheWire(
        model: 'claude-sonnet-4-5',
        thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(reasoning: 'Hmm'),
              TextPart(text: 'hi'),
            ],
          ),
        ],
      );

      final assistant = (body['messages'] as List)[1] as Map;
      expect(assistant['content'], [
        {'type': 'text', 'text': 'hi'},
      ]);
    });
  });
}
