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

// The Interactions route of the googleAI plugin: which models use it, the
// request it sends, and the response it returns.

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/common.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_harness.dart';

final _hello = [
  Message(
    role: Role.user,
    content: [TextPart(text: 'hello')],
  ),
];

/// Runs [model] once on [plugin] and returns the response.
Future<ModelResponse> _run(
  InteractionsWirePlugin plugin, {
  String model = 'gemini-3.8-flash',
  List<Message>? messages,
  Map<String, dynamic>? config,
  List<ToolDefinition>? tools,
  ToolChoice? toolChoice,
  OutputConfig? output,
  void Function(ModelResponseChunk)? onChunk,
}) async {
  final action = plugin.resolve(.model, model) as Model;
  final result = await action.run(
    ModelRequest(
      messages: messages ?? _hello,
      config: config,
      tools: tools,
      toolChoice: toolChoice,
      output: output,
    ),
    onChunk: onChunk,
  );
  return result.result;
}

/// Captures log warnings for the rest of the test.
List<String> _captureWarnings() {
  final warnings = <String>[];
  final subscription = Logger.root.onRecord
      .where((r) => r.level == Level.WARNING)
      .listen((r) => warnings.add(r.message));
  addTearDown(subscription.cancel);
  return warnings;
}

Matcher _throwsStatus(StatusCode status, [Object? message]) => throwsA(
  isA<GenkitException>()
      .having((e) => e.status, 'status', status)
      .having((e) => e.message, 'message', message ?? anything),
);

void main() {
  setUp(resetDroppedConfigFieldWarnings);

  group('routing', () {
    final plugin = GoogleGenAiPluginImpl(apiKey: 'test-key');

    test('known models pinned to generateContent stay there', () {
      for (final name in [
        'gemini-3.1-flash-lite',
        'gemini-3.1-pro-preview',
        'gemini-3-flash-preview',
        'gemini-3.1-flash-tts-preview',
        'gemini-2.5-flash',
        'gemma-4-31b-it',
      ]) {
        expect(plugin.usesInteractions(name), isFalse, reason: name);
      }
    });

    test('newer, unlisted and -latest names use Interactions', () {
      for (final name in [
        'gemini-3.8-flash',
        'gemini-3.8-flash-tts',
        'gemini-flash-latest',
        'gemini-4-argon',
        'gemini-future-model',
        'gemma-5-mystery',
      ]) {
        expect(plugin.usesInteractions(name), isTrue, reason: name);
      }
    });

    test('posts to interactions with the Api-Revision header', () async {
      final plugin = InteractionsWirePlugin();
      final response = await _run(plugin);

      final request = plugin.requests.single;
      expect(request.url.path, '/v1beta/interactions');
      expect(request.headers['Api-Revision'], interactionsApiRevision);
      expect(response.text, '"ok"');
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.inputTokens, 3);
      expect(response.raw?['status'], 'completed');
    });
  });

  _requestTests();
  _configTests();
  _toolAndFormatOptionTests();
  _storeTests();
  _responseTests();
  _streamingTests();
}

void _requestTests() {
  group('request', () {
    test('sends the model, the input steps and store: false', () async {
      final plugin = InteractionsWirePlugin();
      await _run(plugin);

      final body = plugin.lastBody;
      expect(body['model'], 'gemini-3.8-flash');
      expect(body['store'], false);
      expect(body['input'], [
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': 'hello'},
          ],
        },
      ]);
      expect(body, isNot(contains('stream')));
    });

    test('sends the system message as system_instruction', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        messages: [
          Message(
            role: Role.system,
            content: [
              TextPart(text: 'Be brief.'),
              TextPart(text: 'Be kind.'),
            ],
          ),
          ..._hello,
        ],
      );

      final body = plugin.lastBody;
      expect(body['system_instruction'], 'Be brief.\nBe kind.');
      expect((body['input'] as List).length, 1);
    });

    test('throws for non-text system content', () async {
      final plugin = InteractionsWirePlugin();
      await expectLater(
        _run(
          plugin,
          messages: [
            Message(
              role: Role.system,
              content: [MediaPart(media: Media(url: 'gs://b/i.png'))],
            ),
            ..._hello,
          ],
        ),
        _throwsStatus(StatusCode.invalidArgument),
      );
      expect(plugin.requests, isEmpty);
    });

    test('sends tools, built-in tools and the tool choice', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        tools: [
          ToolDefinition(
            name: 'getWeather',
            description: 'Get the weather',
            inputSchema: {
              r'$schema': 'http://json-schema.org/draft-07/schema#',
              'type': 'object',
              'properties': {
                'city': {'type': 'string'},
              },
            },
          ),
        ],
        toolChoice: .required,
        config: {
          'codeExecution': true,
          'googleSearch': <String, dynamic>{},
          'fileSearch': {
            'fileSearchStoreNames': ['fileSearchStores/abc'],
          },
        },
      );

      final body = plugin.lastBody;
      expect(body['tools'], [
        {
          'type': 'function',
          'name': 'getWeather',
          'description': 'Get the weather',
          'parameters': {
            'type': 'object',
            'properties': {
              'city': {'type': 'string'},
            },
          },
        },
        {'type': 'code_execution'},
        {'type': 'google_search'},
        {
          'type': 'file_search',
          'file_search_store_names': ['fileSearchStores/abc'],
        },
      ]);
      expect((body['generation_config'] as Map)['tool_choice'], {
        'allowed_tools': {'mode': 'any'},
      });
    });

    test('Gemma drops previous thoughts', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        model: 'gemma-5-mystery',
        messages: [
          ..._hello,
          Message(
            role: Role.model,
            content: [
              ReasoningPart(reasoning: 'thinking'),
              TextPart(text: 'Hi!'),
            ],
          ),
          ..._hello,
        ],
      );
      final steps = plugin.lastBody['input'] as List;
      expect(steps.map((s) => (s as Map)['type']), [
        'user_input',
        'model_output',
        'user_input',
      ]);
    });

    test('JSON mode sends response_format, with the schema when '
        'constrained', () async {
      final schema = {
        'type': 'object',
        'properties': {
          'a': {'type': 'string'},
        },
      };
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        output: OutputConfig(format: 'json', schema: schema, constrained: true),
      );
      expect(plugin.lastBody['response_format'], {
        'type': 'text',
        'mime_type': 'application/json',
        'schema': schema,
      });

      // Unconstrained: an empty schema, or the server answers in prose
      // (checked live, Oct 27).
      await _run(
        plugin,
        output: OutputConfig(format: 'json', schema: schema),
      );
      expect(plugin.lastBody['response_format'], {
        'type': 'text',
        'mime_type': 'application/json',
        'schema': <String, Object?>{},
      });
    });

    test('config responseMimeType application/json selects JSON output, '
        'without a warning', () async {
      final warnings = _captureWarnings();
      final plugin = InteractionsWirePlugin();
      await _run(plugin, config: {'responseMimeType': 'application/json'});
      expect(plugin.lastBody['response_format'], {
        'type': 'text',
        'mime_type': 'application/json',
        'schema': <String, Object?>{},
      });
      expect(warnings, isEmpty);
    });

    test('sends output types as response_format entries, never '
        'response_modalities', () async {
      final plugin = InteractionsWirePlugin();
      // Text models: nothing (server defaults).
      await _run(plugin);
      expect(plugin.lastBody, isNot(contains('response_format')));

      // TTS and image models keep their default outputs.
      await _run(plugin, model: 'gemini-3.8-flash-tts');
      expect(plugin.lastBody['response_format'], {'type': 'audio'});

      await _run(plugin, model: 'gemini-3.1-flash-lite-image');
      expect(plugin.lastBody['response_format'], [
        {'type': 'text'},
        {'type': 'image'},
      ]);

      // Nano Banana names are image models too.
      await _run(plugin, model: 'gemini-nano-banana-2.1');
      expect(plugin.lastBody['response_format'], [
        {'type': 'text'},
        {'type': 'image'},
      ]);

      // The user's responseModalities win.
      await _run(
        plugin,
        model: 'gemini-3.8-flash-tts',
        config: {
          'responseModalities': ['AUDIO', 'TEXT'],
        },
      );
      expect(plugin.lastBody['response_format'], [
        {'type': 'audio'},
        {'type': 'text'},
      ]);

      // JSON output joins the other entries.
      await _run(
        plugin,
        model: 'gemini-3.1-flash-lite-image',
        output: OutputConfig(format: 'json'),
      );
      expect(plugin.lastBody['response_format'], [
        {
          'type': 'text',
          'mime_type': 'application/json',
          'schema': <String, Object?>{},
        },
        {'type': 'image'},
      ]);

      for (final body in plugin.requests.map(
        (r) => jsonDecode(r.body) as Map,
      )) {
        expect(body, isNot(contains('response_modalities')));
      }
    });
  });
}

void _configTests() {
  group('config', () {
    test('maps generation config; thinkingBudget is dropped with a '
        'hint', () async {
      final warnings = _captureWarnings();
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        config: {
          'temperature': 0.5,
          'topP': 0.9,
          'seed': 7,
          'stopSequences': ['END'],
          'maxOutputTokens': 100,
          'thinkingConfig': {
            'thinkingLevel': 'LOW',
            'includeThoughts': true,
            'thinkingBudget': 1000,
          },
        },
      );

      expect(plugin.lastBody['generation_config'], {
        'temperature': 0.5,
        'top_p': 0.9,
        'seed': 7,
        'stop_sequences': ['END'],
        'max_output_tokens': 100,
        'thinking_level': 'low',
        'thinking_summaries': 'auto',
      });
      expect(
        warnings,
        contains(
          'thinkingConfig.thinkingBudget is not supported by '
          "'gemini-3.8-flash' and was ignored. Use "
          "thinkingConfig.thinkingLevel ('LOW' | 'MEDIUM' | 'HIGH') instead.",
        ),
      );
    });

    test('sends logprobs (they work on gemini-4-argon)', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        model: 'gemini-4-argon',
        config: {'responseLogprobs': true, 'logprobs': 3},
      );

      expect(plugin.lastBody['generation_config'], {
        'response_logprobs': true,
        'logprobs': 3,
      });
    });

    test('drops fields with no effect, warning once per model and '
        'field', () async {
      final warnings = _captureWarnings();
      final plugin = InteractionsWirePlugin();
      final config = {
        'topK': 40,
        'presencePenalty': 0.5,
        'frequencyPenalty': 0.5,
        'responseMimeType': 'text/plain',
        'candidateCount': 1,
      };
      await _run(plugin, config: config);
      await _run(plugin, config: config);

      final body = plugin.lastBody;
      expect(body['generation_config'], isEmpty);
      expect(body, isNot(contains('response_format')));
      String dropped(String field) =>
          "$field is not supported by 'gemini-3.8-flash' and was ignored.";
      expect(warnings, [
        dropped('topK'),
        dropped('presencePenalty'),
        dropped('frequencyPenalty'),
        dropped('responseMimeType'),
      ]);
    });

    test('warns about more than one candidate', () async {
      final warnings = _captureWarnings();
      await _run(InteractionsWirePlugin(), config: {'candidateCount': 2});
      expect(warnings.single, startsWith('Multiple candidates are not'));
    });

    test('sends serviceTier', () async {
      final plugin = InteractionsWirePlugin();
      await _run(plugin, config: {'serviceTier': 'flex'});
      expect(plugin.lastBody['service_tier'], 'flex');
    });
  });

  _safetyAndSpeechTests();
}

void _safetyAndSpeechTests() {
  group('safety and speech', () {
    test('drops permissive safety settings', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        config: {
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE',
            },
            {
              'category': 'HARM_CATEGORY_UNSPECIFIED',
              'threshold': 'BLOCK_ONLY_HIGH',
            },
          ],
        },
      );
      expect(plugin.lastBody, isNot(contains('safety_settings')));
    });

    test('throws for blocking safety settings', () async {
      final plugin = InteractionsWirePlugin();
      await expectLater(
        _run(
          plugin,
          config: {
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_ONLY_HIGH',
              },
            ],
          },
        ),
        _throwsStatus(StatusCode.invalidArgument, contains('BLOCK_NONE')),
      );
      expect(plugin.requests, isEmpty);
    });

    test('maps the speech config', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        model: 'gemini-3.8-flash-tts',
        config: {
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Kore'},
            },
          },
        },
      );
      expect((plugin.lastBody['generation_config'] as Map)['speech_config'], [
        {'voice': 'Kore'},
      ]);
    });

    test('throws for speech metadata without a voice', () async {
      await expectLater(
        _run(
          InteractionsWirePlugin(),
          model: 'gemini-3.8-flash-tts',
          messages: [
            Message(
              role: Role.user,
              content: [
                TextPart(
                  text: 'Hi',
                  metadata: {
                    'speechMetadata': {'speaker': 'A'},
                  },
                ),
              ],
            ),
          ],
        ),
        _throwsStatus(StatusCode.invalidArgument, contains('requires a voice')),
      );
    });

    test('throws for a multi-speaker turn without a configured '
        'speaker', () async {
      await expectLater(
        _run(
          InteractionsWirePlugin(),
          model: 'gemini-3.8-flash-tts',
          config: {
            'speechConfig': {
              'multiSpeakerVoiceConfig': {
                'speakerVoiceConfigs': [
                  {
                    'speaker': 'A',
                    'voiceConfig': {
                      'prebuiltVoiceConfig': {'voiceName': 'Kore'},
                    },
                  },
                ],
              },
            },
          },
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'No speaker here')],
            ),
          ],
        ),
        _throwsStatus(
          StatusCode.invalidArgument,
          contains('configured speakers (A)'),
        ),
      );
    });
  });
}

void _toolAndFormatOptionTests() {
  group('tool and format options', () {
    test('sends config tools, then the built-in tool options', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        config: {
          'tools': [
            {'googleMaps': <String, dynamic>{}},
            {'type': 'some_new_tool', 'someSetting': 1},
          ],
          'codeExecution': true,
          'googleSearch': <String, dynamic>{},
          'urlContext': <String, dynamic>{},
        },
      );
      expect(plugin.lastBody['tools'], [
        {'type': 'google_maps'},
        {'type': 'some_new_tool', 'some_setting': 1},
        {'type': 'code_execution'},
        {'type': 'google_search'},
        {'type': 'url_context'},
      ]);
    });

    test('applies retrievalConfig.latLng to the google_maps tool', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        config: {
          'tools': [
            {
              'googleMaps': {'enableWidget': true},
            },
          ],
          'retrievalConfig': {
            'latLng': {'latitude': 43.0896, 'longitude': -79.0849},
          },
        },
      );
      final body = plugin.lastBody;
      expect(body['tools'], [
        {
          'type': 'google_maps',
          'enable_widget': true,
          'latitude': 43.0896,
          'longitude': -79.0849,
        },
      ]);
      expect(body['generation_config'], isNot(contains('retrieval_config')));
    });

    test('keeps a location set on the googleMaps tool over '
        'retrievalConfig.latLng', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        config: {
          'tools': [
            {
              'googleMaps': {'latitude': 1, 'longitude': 2},
            },
          ],
          'retrievalConfig': {
            'latLng': {'latitude': 43.0896, 'longitude': -79.0849},
          },
        },
      );
      expect(plugin.lastBody['tools'], [
        {'type': 'google_maps', 'latitude': 1, 'longitude': 2},
      ]);
    });

    test('warns about retrievalConfig it cannot use', () async {
      final warnings = _captureWarnings();
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        config: {
          'retrievalConfig': {
            'latLng': {'latitude': 43.0896, 'longitude': -79.0849},
            'languageCode': 'en',
          },
        },
      );
      expect(plugin.lastBody, isNot(contains('tools')));
      expect(warnings, [
        'retrievalConfig.latLng is only used with the googleMaps tool for '
            'this model and will be ignored.',
        'retrievalConfig.languageCode is not supported for this model with '
            'the Interactions API and will be ignored.',
      ]);
    });

    test('sends imageConfig on the image entry with text, for image '
        'models', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        model: 'gemini-nano-banana-2.1',
        config: {
          'imageConfig': {'aspectRatio': '9:16', 'imageSize': '2K'},
        },
      );
      final body = plugin.lastBody;
      expect(body['response_format'], [
        {'type': 'text'},
        {'type': 'image', 'aspect_ratio': '9:16', 'image_size': '2K'},
      ]);
      expect(body['generation_config'], isNot(contains('image_config')));
    });

    test('sends audioFormat on the audio entry', () async {
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        model: 'gemini-3.8-flash-tts',
        config: {
          'audioFormat': {'mimeType': 'audio/l16', 'sampleRate': 16000},
        },
      );
      expect(plugin.lastBody['response_format'], {
        'type': 'audio',
        'mime_type': 'audio/l16',
        'sample_rate': 16000,
      });
    });

    test('keeps JSON output when audioFormat is set too', () async {
      final schema = {
        'type': 'object',
        'properties': {
          'answer': {'type': 'string'},
        },
      };
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        config: {
          'responseModalities': ['TEXT', 'AUDIO'],
          'audioFormat': {'mimeType': 'audio/wav'},
        },
        output: OutputConfig(format: 'json', schema: schema, constrained: true),
      );
      expect(plugin.lastBody['response_format'], [
        {'type': 'text', 'mime_type': 'application/json', 'schema': schema},
        {'type': 'audio', 'mime_type': 'audio/wav'},
      ]);
    });

    test('sends videoFormat on the video entry and videoConfig in the '
        'generation config', () async {
      final warnings = _captureWarnings();
      final plugin = InteractionsWirePlugin();
      await _run(
        plugin,
        model: 'gemini-omni-1.1-flash',
        config: {
          'videoFormat': {'aspectRatio': '9:16', 'resolution': '1080p'},
          'videoConfig': {'task': 'text_to_video'},
        },
      );
      final body = plugin.lastBody;
      expect(body['response_format'], {
        'type': 'video',
        'aspect_ratio': '9:16',
        'resolution': '1080p',
      });
      expect(body['generation_config'], {
        'video_config': {'task': 'text_to_video'},
      });
      expect(warnings, isEmpty);
    });
  });
}

void _storeTests() {
  group('store', () {
    final history = [
      ..._hello,
      Message(
        role: Role.model,
        content: [TextPart(text: 'Hi!')],
        metadata: {'interactionId': 'v1_prev'},
      ),
      Message(
        role: Role.user,
        content: [TextPart(text: 'And now?')],
      ),
    ];

    test('continues the last stored interaction with only the newer '
        'messages', () async {
      final plugin = InteractionsWirePlugin();
      await _run(plugin, messages: history, config: {'store': true});

      final body = plugin.lastBody;
      expect(body['store'], true);
      expect(body['previous_interaction_id'], 'v1_prev');
      expect((body['input'] as List).length, 1);
    });

    test('plugin-wide store', () async {
      final plugin = InteractionsWirePlugin(store: true);
      await _run(plugin, messages: history);
      expect(plugin.lastBody['previous_interaction_id'], 'v1_prev');
    });

    test('plugin-wide store: false is the default (stateless)', () async {
      final plugin = InteractionsWirePlugin(store: false);
      await _run(plugin, messages: history);
      final body = plugin.lastBody;
      expect(body['store'], false);
      expect(body, isNot(contains('previous_interaction_id')));
    });

    test('without store, sends the whole history', () async {
      final plugin = InteractionsWirePlugin();
      await _run(plugin, messages: history);

      final body = plugin.lastBody;
      expect(body['store'], false);
      expect(body, isNot(contains('previous_interaction_id')));
      expect((body['input'] as List).length, 3);
    });

    test('previousInteractionId without store throws', () async {
      await expectLater(
        _run(
          InteractionsWirePlugin(),
          config: {'previousInteractionId': 'v1_x'},
        ),
        _throwsStatus(StatusCode.invalidArgument),
      );
    });

    test('returns the interaction id in the message metadata', () async {
      final response = await _run(
        InteractionsWirePlugin(
          response: {
            ...InteractionsWirePlugin.defaultInteraction,
            'id': 'v1_new',
          },
        ),
        config: {'store': true},
      );
      expect(response.message?.metadata?['interactionId'], 'v1_new');
    });
  });
}

void _responseTests() {
  group('response', () {
    test('a pending function call becomes a tool request', () async {
      final response = await _run(
        InteractionsWirePlugin(
          response: {
            'status': 'requires_action',
            'steps': [
              {
                'type': 'function_call',
                'id': 'call_1',
                'name': 'getWeather',
                'arguments': {'city': 'Paris'},
              },
            ],
          },
        ),
      );
      expect(response.toolRequests.single.toJson(), {
        'ref': 'call_1',
        'name': 'getWeather',
        'input': {'city': 'Paris'},
      });
    });

    test('maps an Interactions error code to a Genkit status', () async {
      await expectLater(
        _run(
          InteractionsWirePlugin(
            status: 429,
            response: {
              'error': {
                'code': 'rate_limit_exceeded',
                'message': 'Too many requests',
              },
            },
          ),
        ),
        _throwsStatus(StatusCode.resourceExhausted),
      );
    });
  });
}

void _streamingTests() {
  group('streaming', () {
    test('streams text chunks and assembles the final response', () async {
      final chunks = <ModelResponseChunk>[];
      final plugin = InteractionsWirePlugin(
        sseEvents: [
          {
            'event_type': 'interaction.created',
            'interaction': {'id': 'v1_s', 'status': 'in_progress'},
          },
          {
            'event_type': 'step.start',
            'index': 0,
            'step': {'type': 'model_output'},
          },
          {
            'event_type': 'step.delta',
            'index': 0,
            'delta': {'type': 'text', 'text': 'Hel'},
          },
          {
            'event_type': 'step.delta',
            'index': 0,
            'delta': {'type': 'text', 'text': 'lo'},
          },
          {'event_type': 'step.stop', 'index': 0},
          {
            'event_type': 'interaction.completed',
            'interaction': {
              'id': 'v1_s',
              'status': 'completed',
              'usage': {'total_input_tokens': 2, 'total_output_tokens': 2},
            },
          },
        ],
      );
      final response = await _run(plugin, onChunk: chunks.add);

      expect(plugin.lastBody['stream'], true);
      expect(chunks.map((c) => c.text), ['Hel', 'lo']);
      expect(response.text, 'Hello');
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.outputTokens, 2);
      expect(response.raw?['id'], 'v1_s');
    });

    test('a signature-only delta is not streamed on its own, so structured '
        'output chunks always have output', () async {
      // Event order seen live (googleAI gemini-3.8-flash, structured output,
      // Oct 27): the thought signature arrives before any text. Sent as its
      // own chunk, `chunk.output` was null there and `chunk.output!` (the
      // pattern in the package example) threw.
      final plugin = InteractionsWirePlugin(
        sseEvents: [
          {
            'event_type': 'step.start',
            'index': 0,
            'step': {'type': 'thought'},
          },
          {
            'event_type': 'step.delta',
            'index': 0,
            'delta': {'type': 'thought_signature', 'signature': 'sig'},
          },
          {'event_type': 'step.stop', 'index': 0},
          {
            'event_type': 'step.start',
            'index': 1,
            'step': {'type': 'model_output'},
          },
          {
            'event_type': 'step.delta',
            'index': 1,
            'delta': {'type': 'text', 'text': '{"name": "Gor'},
          },
          {
            'event_type': 'step.delta',
            'index': 1,
            'delta': {'type': 'text', 'text': 'ble"}'},
          },
          {'event_type': 'step.stop', 'index': 1},
          {
            'event_type': 'interaction.completed',
            'interaction': {'status': 'completed'},
          },
        ],
      );
      final ai = Genkit(plugins: [plugin], promptDir: null, isDevEnv: false);
      addTearDown(ai.shutdown);

      final stream = ai.generateStream(
        model: modelRef('googleai/gemini-3.8-flash'),
        prompt: 'Generate a character',
        outputSchema: .map(.string(), .string()),
      );
      final outputs = <Map<String, String>>[];
      await for (final chunk in stream) {
        outputs.add(chunk.output!);
      }
      final response = await stream.onResult;

      expect(outputs, [
        {'name': 'Gor'},
        {'name': 'Gorble'},
      ]);
      expect(response.output, {'name': 'Gorble'});
      // The signature still reaches the final response (history, tool loops).
      expect(
        response.message!.content.first.metadata?['thoughtSignature'],
        'sig',
      );
    });

    test('an error event throws with the mapped status', () async {
      await expectLater(
        _run(
          InteractionsWirePlugin(
            sseEvents: [
              {
                'event_type': 'error',
                'error': {'code': 'service_unavailable', 'message': 'busy'},
              },
            ],
          ),
          onChunk: (_) {},
        ),
        _throwsStatus(StatusCode.unavailable),
      );
    });

    test('joins streamed audio chunks into one part', () async {
      final chunks = <ModelResponseChunk>[];
      final response = await _run(
        InteractionsWirePlugin(
          sseEvents: [
            {
              'event_type': 'step.start',
              'index': 0,
              'step': {'type': 'model_output'},
            },
            for (final data in ['AQI=', 'AwQ='])
              {
                'event_type': 'step.delta',
                'index': 0,
                'delta': {
                  'type': 'audio',
                  'mime_type': 'audio/l16',
                  'data': data,
                },
              },
            {'event_type': 'step.stop', 'index': 0},
            {
              'event_type': 'interaction.completed',
              'interaction': {'status': 'completed'},
            },
          ],
        ),
        model: 'gemini-3.8-flash-tts',
        onChunk: chunks.add,
      );

      expect(chunks, hasLength(2));
      final media = response.message!.content.single.media!;
      expect(media.contentType, 'audio/l16');
      expect(media.url, 'data:audio/l16;base64,AQIDBA==');
    });
  });
}
