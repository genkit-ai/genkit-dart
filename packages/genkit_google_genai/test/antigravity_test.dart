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

// The Antigravity agent on the googleAI plugin. Ported from the JS
// tests/googleai/antigravity_test.ts, plus routing and listing.

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/antigravity.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:test/test.dart';

import 'test_harness.dart';

const _agent = 'antigravity-preview-09-2026';

final _hello = [
  Message(
    role: Role.user,
    content: [TextPart(text: 'Hello antigravity')],
  ),
];

const _interaction = {
  'id': 'interaction-123',
  'status': 'completed',
  'environment_id': 'env-123',
  'steps': [
    {
      'type': 'model_output',
      'content': [
        {'type': 'text', 'text': 'Hello human'},
      ],
    },
  ],
};

final _getWeatherTool = ToolDefinition(
  name: 'getWeather',
  description: 'Gets the weather',
  inputSchema: {
    'type': 'object',
    'properties': {
      'location': {'type': 'string'},
    },
  },
);

/// The history after the first turn of a tool loop, as Genkit sends it: the
/// prompt, the model's pending call (with the IDs from the response
/// metadata) and the tool's result.
final _toolLoopMessages = [
  Message(
    role: Role.user,
    content: [TextPart(text: 'Weather in Tokyo?')],
  ),
  Message(
    role: Role.model,
    content: [
      ToolRequestPart(
        toolRequest: ToolRequest(
          name: 'getWeather',
          ref: 'call_58754',
          input: {'location': 'Tokyo'},
        ),
      ),
    ],
    metadata: {'interactionId': 'v1_abc123', 'environmentId': 'env-123'},
  ),
  Message(
    role: Role.tool,
    content: [
      ToolResponsePart(
        toolResponse: ToolResponse(
          name: 'getWeather',
          ref: 'call_58754',
          output: {'conditions': 'cloudy'},
        ),
      ),
    ],
  ),
];

/// Runs the agent once on [plugin] and returns the response.
Future<ModelResponse> _run(
  InteractionsWirePlugin plugin, {
  String model = _agent,
  List<Message>? messages,
  Map<String, dynamic>? config,
  List<ToolDefinition>? tools,
}) async {
  final action = plugin.resolve(.model, model) as Model;
  final result = await action.run(
    ModelRequest(messages: messages ?? _hello, config: config, tools: tools),
  );
  return result.result;
}

void main() {
  _requestTests();
  _toolLoopTests();
  _responseTests();
  _routingAndListingTests();
}

void _requestTests() {
  group('request', () {
    test('sets agent and sends nothing else by default', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(plugin);

      final body = plugin.lastBody;
      expect(body['agent'], _agent);
      // Unset, so the server default (stored) applies; tools unset, so the
      // agent's default tools apply.
      expect(body.keys.toSet(), {'agent', 'input'});
    });

    test('maps system messages to user messages', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'You are an agent')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'Hello')],
          ),
        ],
      );

      expect(plugin.lastBody['input'], [
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': 'You are an agent'},
          ],
        },
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': 'Hello'},
          ],
        },
      ]);
      expect(plugin.lastBody, isNot(contains('system_instruction')));
    });

    test('maps explicitly provided config options', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        config: {
          'environment': 'remote',
          'previousInteractionId': 'interaction-abc',
          'tools': [
            {'type': 'google_search'},
            {'type': 'code_execution'},
          ],
          'store': true,
          'responseModalities': ['TEXT', 'IMAGE'],
        },
      );

      final body = plugin.lastBody;
      expect(body['environment'], 'remote');
      expect(body['store'], true);
      expect(body['previous_interaction_id'], 'interaction-abc');
      expect(body['tools'], [
        {'type': 'google_search'},
        {'type': 'code_execution'},
      ]);
      expect(body['response_format'], [
        {'type': 'text'},
        {'type': 'image'},
      ]);
    });

    test('sends an environment map as is', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        config: {
          'environment': {'type': 'remote', 'someSetting': 1},
        },
      );
      expect(plugin.lastBody['environment'], {
        'type': 'remote',
        'someSetting': 1,
      });
    });

    test('sends config.model as agent_config.model, any name', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      for (final model in ['gemini-3.5-flash-lite', 'gemini-9.9-flash']) {
        await _run(plugin, config: {'model': model});
        final body = plugin.lastBody;
        expect(body['agent_config'], {'type': 'antigravity', 'model': model});
        expect(body, isNot(contains('model')));
        expect(body['agent'], _agent);
      }
    });

    test('sends function tools after the built-in tools from '
        'config', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        config: {
          'tools': [
            {'codeExecution': true},
          ],
        },
        tools: [_getWeatherTool],
      );
      expect(plugin.lastBody['tools'], [
        {'type': 'code_execution'},
        {
          'type': 'function',
          'name': 'getWeather',
          'description': 'Gets the weather',
          'parameters': {
            'type': 'object',
            'properties': {
              'location': {'type': 'string'},
            },
          },
        },
      ]);
    });

    test('does not send config keys it does not know (no '
        'passthrough)', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(plugin, config: {'temperature': 0.8, 'topP': 0.9});
      final body = plugin.lastBody;
      expect(body, isNot(contains('temperature')));
      expect(body, isNot(contains('topP')));
    });
  });
}

void _toolLoopTests() {
  group('tool loop', () {
    test('continues the stored interaction by default', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        messages: _toolLoopMessages,
        tools: [_getWeatherTool],
        config: {'environment': 'remote'},
      );

      final body = plugin.lastBody;
      expect(body['previous_interaction_id'], 'v1_abc123');
      // A new 'remote' sandbox wouldn't have the previous turn's files.
      expect(body['environment'], 'env-123');
      // Unset, so the server default (stored) applies.
      expect(body, isNot(contains('store')));
      expect(body['input'], [
        {
          'type': 'function_result',
          'name': 'getWeather',
          'result': {'conditions': 'cloudy'},
          'call_id': 'call_58754',
        },
      ]);
    });

    test('continues a conversation without tool calls the same way', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'Write hello.py')],
          ),
          Message(
            role: Role.model,
            content: [TextPart(text: 'Done.')],
            metadata: {
              'interactionId': 'v1_abc123',
              'environmentId': 'env-123',
            },
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'Now run it.')],
          ),
        ],
      );

      final body = plugin.lastBody;
      expect(body['previous_interaction_id'], 'v1_abc123');
      expect(body['environment'], 'env-123');
      expect(body['input'], [
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': 'Now run it.'},
          ],
        },
      ]);
    });

    test('keeps an explicitly configured environment ID', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        messages: _toolLoopMessages,
        tools: [_getWeatherTool],
        config: {'environment': 'env-other'},
      );
      expect(plugin.lastBody['environment'], 'env-other');
    });

    test('sends only the newer messages when previousInteractionId is '
        'set', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        messages: _toolLoopMessages,
        tools: [_getWeatherTool],
        config: {'previousInteractionId': 'v1_explicit'},
      );

      final body = plugin.lastBody;
      expect(body['previous_interaction_id'], 'v1_explicit');
      expect((body['input'] as List).map((s) => (s as Map)['type']), [
        'function_result',
      ]);
      // The environment is only taken from the history when continuing it.
      expect(body, isNot(contains('environment')));
    });

    // The agent rejects store: false; the plugin passes it through so the
    // server's error explains it (and so it keeps working if the server
    // ever accepts it).
    test('passes store: false in config through to the server', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(plugin, config: {'store': false});
      expect(plugin.lastBody['store'], false);
    });

    test('passes store: false in the plugin options through to the '
        'server', () async {
      final plugin = InteractionsWirePlugin(
        response: _interaction,
        store: false,
      );
      await _run(plugin);
      expect(plugin.lastBody['store'], false);
    });

    test('does not send the plugin store: true (the server default '
        'applies)', () async {
      final plugin = InteractionsWirePlugin(
        response: _interaction,
        store: true,
      );
      await _run(plugin);
      expect(plugin.lastBody, isNot(contains('store')));
    });

    test('lets config.store override the plugin options', () async {
      final plugin = InteractionsWirePlugin(
        response: _interaction,
        store: false,
      );
      await _run(
        plugin,
        messages: _toolLoopMessages,
        tools: [_getWeatherTool],
        config: {'store': true},
      );

      final body = plugin.lastBody;
      expect(body['store'], true);
      expect(body['previous_interaction_id'], 'v1_abc123');
    });
  });
}

void _responseTests() {
  group('response', () {
    test('returns a pending function call as a toolRequest', () async {
      final response = await _run(
        InteractionsWirePlugin(
          response: {
            'id': 'v1_abc123',
            'status': 'requires_action',
            'environment_id': 'env-123',
            'steps': [
              {
                'type': 'function_call',
                'id': 'call-1',
                'name': 'getWeather',
                'arguments': {'location': 'Tokyo'},
              },
            ],
          },
        ),
      );

      expect(response.message!.content.map((p) => p.toJson()), [
        {
          'toolRequest': {
            'name': 'getWeather',
            'ref': 'call-1',
            'input': {'location': 'Tokyo'},
          },
        },
      ]);
    });

    test('adds the interaction and environment IDs to the message '
        'metadata', () async {
      final response = await _run(
        InteractionsWirePlugin(response: _interaction),
      );
      expect(response.text, 'Hello human');
      expect(response.message?.metadata, {
        'interactionId': 'interaction-123',
        'environmentId': 'env-123',
      });
    });
  });
}

void _routingAndListingTests() {
  group('routing, metadata and listing', () {
    test('the known agent resolves with its label and the Antigravity '
        'profile', () {
      final plugin = GoogleGenAiPluginImpl(apiKey: 'test-key');
      for (final model in KnownAntigravityModel.values) {
        final action = plugin.resolve(.model, model.id) as Model;
        expect(action.name, 'googleai/${model.id}');
        expect(action.customOptions, same(AntigravityOptions.$schema));
        final info = (action.metadata['model'] as Map).cast<String, dynamic>();
        expect(info['label'], model.label);
        expect(info['stage'], 'stable');
        expect(info['supports'], {
          'multiturn': true,
          'media': true,
          'tools': true,
          'toolChoice': false,
          'systemRole': false,
          'output': ['text'],
        });
      }
    });

    test('the known list matches JS', () {
      expect(KnownAntigravityModel.values.map((m) => m.id), [_agent]);
    });

    test('unlisted antigravity-* names resolve as Antigravity', () {
      final plugin = GoogleGenAiPluginImpl(apiKey: 'test-key');
      final action = plugin.resolve(.model, 'antigravity-future') as Model;
      expect(action.customOptions, same(AntigravityOptions.$schema));
    });

    test('lists discovered agents (no deprecated ones) and the known '
        'one', () async {
      final plugin = GoogleGenAiPluginImpl(
        apiKey: 'test-key',
        httpClient: ListingClient(
          modelsResponse:
              '{"models": ['
              '{"name": "models/antigravity-future"}, '
              '{"name": "models/antigravity-old", '
              '"description": "deprecated"}]}',
        ),
      );
      final names = (await plugin.list()).map((a) => a.name).toList();
      expect(names, contains('googleai/antigravity-future'));
      expect(names, isNot(contains('googleai/antigravity-old')));
      expect(names.where((n) => n == 'googleai/$_agent'), hasLength(1));
    });
  });
}
