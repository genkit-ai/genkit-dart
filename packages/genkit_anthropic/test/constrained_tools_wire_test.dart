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
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Runs a `generate` carrying both [tools] and an output schema, and returns
/// the first request body Anthropic was sent.
Future<Map<String, dynamic>> _wireBodyFor({
  required String model,
  required List<String> tools,
  String? toolChoice,
  bool constrained = true,
}) async {
  Map<String, dynamic>? captured;
  final client = MockClient((request) async {
    captured ??= (jsonDecode(request.body) as Map).cast<String, dynamic>();
    return http.Response(
      jsonEncode({
        'id': 'msg_test',
        'type': 'message',
        'role': 'assistant',
        'model': model,
        'content': [
          {'type': 'text', 'text': '{"answer": "ok"}'},
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
  final ai = Genkit(isDevEnv: false, plugins: [plugin]);
  addTearDown(() async {
    plugin.close();
    await ai.shutdown();
  });

  ai.defineTool(
    name: 'lookup',
    description: 'Looks something up',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (String input, _) async => .response('looked up $input'),
  );

  final generateAction = await ai.registry.lookupAction(.util, 'generate');
  await generateAction!(
    GenerateActionOptions(
      model: 'anthropic/$model',
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'answer the question')],
        ),
      ],
      tools: tools,
      toolChoice: toolChoice,
      output: GenerateActionOutputConfig(
        format: 'json',
        constrained: constrained,
        jsonSchema: {
          'type': 'object',
          'properties': {
            'answer': {'type': 'string'},
          },
        },
      ),
    ),
  );

  return captured!;
}

void main() {
  group('a constrained request carrying tools', () {
    test('sends the schema natively and leaves the tools callable', () async {
      final body = await _wireBodyFor(
        model: 'claude-sonnet-4-5',
        tools: ['lookup'],
      );

      // `output_config.format` adds no tool and pins no choice, so the
      // caller's tool is reachable and the tool loop can fire - which the
      // forced `return_output` tool this replaced made impossible.
      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('tool_choice')));

      final toolNames = (body['tools'] as List)
          .map((t) => (t as Map)['name'])
          .toList();
      expect(toolNames, ['lookup']);
    });

    test('sends the schema with no tools at all', () async {
      final body = await _wireBodyFor(model: 'claude-sonnet-4-5', tools: []);

      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('tools')));
      expect(body, isNot(contains('tool_choice')));
    });

    test('an unconstrained request sends no schema and keeps the '
        'toolChoice', () async {
      final body = await _wireBodyFor(
        model: 'claude-sonnet-4-5',
        tools: ['lookup'],
        toolChoice: 'lookup',
        constrained: false,
      );

      // Opting out of constrained output opts out of the mechanism, and
      // nothing was stripped, so the caller's choice stands.
      expect(body, isNot(contains('output_config')));
      expect(body['tool_choice'], containsPair('name', 'lookup'));
    });

    test('a toolChoice with no tools is dropped', () async {
      // Anthropic rejects a choice with nothing to choose from - "tool_choice.
      // any may only be specified while providing tools" - and an output
      // schema no longer contributes a tool for one to refer to.
      final body = await _wireBodyFor(
        model: 'claude-sonnet-4-5',
        tools: [],
        toolChoice: 'any',
      );

      expect(body, isNot(contains('tools')));
      expect(body, isNot(contains('tool_choice')));
    });
  });
}
