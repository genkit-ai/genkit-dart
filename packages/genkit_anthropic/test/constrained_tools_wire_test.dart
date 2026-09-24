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
    test('leaves the caller tools callable', () async {
      final body = await _wireBodyFor(
        model: 'claude-sonnet-4-5',
        tools: ['lookup'],
      );

      // Forcing `return_output` here would make the caller's tool
      // unreachable: Claude can only answer with the one tool it is pinned
      // to, so the tool loop never fires and `lookup` is dead weight on the
      // wire. The schema has to come through the prompt instead.
      final toolChoice = body['tool_choice'] as Map<String, dynamic>?;
      expect(
        toolChoice?['name'],
        isNot('return_output'),
        reason: 'the caller tool can never be chosen',
      );

      final toolNames = (body['tools'] as List)
          .map((t) => (t as Map)['name'])
          .toList();
      expect(toolNames, contains('lookup'));
      expect(toolNames, isNot(contains('return_output')));

      // The shape still has to reach the model somehow.
      expect(
        jsonEncode(body['messages']),
        contains('conform to the following'),
      );
    });

    test('still forces the output tool when no tool is offered', () async {
      final body = await _wireBodyFor(model: 'claude-sonnet-4-5', tools: []);

      // Nothing competes with it here, so the native path is the better one.
      expect(body['tool_choice'], containsPair('name', 'return_output'));
    });

    test('an unconstrained request keeps the caller toolChoice', () async {
      final body = await _wireBodyFor(
        model: 'claude-sonnet-4-5',
        tools: ['lookup'],
        toolChoice: 'lookup',
        constrained: false,
      );

      // Opting out of constrained output opts out of the mechanism behind it,
      // and core stripped nothing, so there is no reason to overrule the
      // caller. `return_output` is still offered, just not forced.
      expect(body['tool_choice'], containsPair('name', 'lookup'));

      final toolNames = (body['tools'] as List)
          .map((t) => (t as Map)['name'])
          .toList();
      expect(toolNames, containsAll(['lookup', 'return_output']));
    });

    test('a caller toolChoice does not unpin the output tool', () async {
      final body = await _wireBodyFor(
        model: 'claude-sonnet-4-5',
        tools: [],
        toolChoice: 'none',
      );

      // Core does not simulate for a tool-free request, so `none` here would
      // leave the model neither the forced tool nor any instructions.
      expect(body['tool_choice'], containsPair('name', 'return_output'));
    });
  });
}
