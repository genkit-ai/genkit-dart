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

Future<Map<String, dynamic>> _requestOnTheWire({
  required String model,
  ThinkingConfig? thinking,
  AnthropicOutputConfig? outputConfig,
  List<Message>? messages,
}) async {
  Map<String, dynamic>? captured;
  final client = MockClient((request) async {
    if (request.url.path != '/v1/messages') {
      return http.Response('not found', 404);
    }
    captured = (jsonDecode(request.body) as Map).cast<String, dynamic>();
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
  final plugin = AnthropicPluginImpl(apiKey: 'test-key', httpClient: client);
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
      config: AnthropicOptions(
        thinking: thinking,
        outputConfig: outputConfig,
      ).toJson(),
    ),
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

      final assistant = (body['messages'] as List)[1] as Map;
      expect(assistant['role'], 'assistant');
      expect(assistant['content'], [
        {'type': 'thinking', 'thinking': 'Hmm', 'signature': 'sig_123'},
        {'type': 'redacted_thinking', 'data': 'opaque_payload'},
        {'type': 'text', 'text': 'hi'},
      ]);
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
