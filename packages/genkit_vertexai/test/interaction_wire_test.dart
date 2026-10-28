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

// The Interactions route of the vertexAI plugin: which models use it, the
// URL, and where the request differs from googleAI (safety settings, the
// stateless resend filter, store, no TTS audio default).

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/common.dart'
    show resetDroppedConfigFieldWarnings, resetDroppedResentStepsWarning;
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

const _interactionsUrl =
    'https://aiplatform.googleapis.com/v1beta1/projects/my-project/locations/global/interactions';

final _hello = [
  Message(
    role: Role.user,
    content: [TextPart(text: 'hello')],
  ),
];

/// Runs [model] once on a vertexAI plugin with [client]; returns the
/// response.
Future<ModelResponse> _run(
  MockHttpClient client, {
  String model = 'gemini-3.8-flash',
  List<Message>? messages,
  Map<String, dynamic>? config,
  bool? store,
}) async {
  final plugin = VertexAiPluginImpl(
    projectId: 'my-project',
    location: 'global',
    authClient: client,
    store: store,
  );
  final action = plugin.resolve(.model, model) as Model;
  final result = await action.run(
    ModelRequest(messages: messages ?? _hello, config: config),
  );
  return result.result;
}

/// The JSON body of [client]'s last request.
Map<String, dynamic> _lastBody(MockHttpClient client) =>
    (jsonDecode(client.lastBody!) as Map).cast<String, dynamic>();

/// Captures log warnings for the rest of the test.
List<String> _captureWarnings() {
  final warnings = <String>[];
  final subscription = Logger.root.onRecord
      .where((r) => r.level == Level.WARNING)
      .listen((r) => warnings.add(r.message));
  addTearDown(subscription.cancel);
  return warnings;
}

void main() {
  setUp(() {
    resetDroppedConfigFieldWarnings();
    resetDroppedResentStepsWarning();
  });

  _routingTests();
  _requestTests();
  _resendTests();
}

void _routingTests() {
  group('routing', () {
    test(
      'an Interactions model posts to the project interactions URL',
      () async {
        final client = MockHttpClient();
        final response = await _run(client);

        expect(client.lastUrl.toString(), _interactionsUrl);
        final body = _lastBody(client);
        expect(body['model'], 'gemini-3.8-flash');
        expect(body['store'], false);
        expect(response.text, '"ok"');
      },
    );

    test(
      'pinned, hidden, image and TTS models stay on generateContent',
      () async {
        for (final model in [
          'gemini-3.1-pro-preview',
          'gemini-3.1-pro-preview-customtools',
          'gemini-3.8-flash-cyber',
          // Hidden models keep their routing.
          'gemini-2.5-flash',
          'gemini-nano-banana-2.1',
          'gemini-3.8-flash-tts',
        ]) {
          final client = MockHttpClient();
          await _run(client, model: model);
          expect(
            client.lastUrl.toString(),
            endsWith('/publishers/google/models/$model:generateContent'),
            reason: model,
          );
        }
      },
    );
  });
}

void _requestTests() {
  group('request', () {
    test('sends safety settings, blocking thresholds included', () async {
      final client = MockHttpClient();
      await _run(
        client,
        config: {
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_LOW_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_UNSPECIFIED',
              'threshold': 'BLOCK_NONE',
            },
          ],
        },
      );
      // googleAI throws for blocking thresholds; the platform accepts them.
      expect(_lastBody(client)['safety_settings'], [
        {'type': 'hate_speech', 'threshold': 'block_low_and_above'},
      ]);
    });

    test('store: true in the request or the plugin option stores', () async {
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

      var client = MockHttpClient();
      await _run(client, messages: history, store: true);
      var body = _lastBody(client);
      expect(body['store'], true);
      expect(body['previous_interaction_id'], 'v1_prev');
      expect((body['input'] as List).length, 1);

      client = MockHttpClient();
      await _run(client, messages: history, config: {'store': true});
      expect(_lastBody(client)['previous_interaction_id'], 'v1_prev');

      // Neither: stateless, the whole history is sent.
      client = MockHttpClient();
      await _run(client, messages: history);
      body = _lastBody(client);
      expect(body['store'], false);
      expect(body, isNot(contains('previous_interaction_id')));
      expect((body['input'] as List).length, 3);
    });

    // Unlike JS today (which ORs the two), the request's value wins.
    test("a request's store: false overrides the plugin's true", () async {
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
      final client = MockHttpClient();
      await _run(
        client,
        messages: history,
        config: {'store': false},
        store: true,
      );
      final body = _lastBody(client);
      expect(body['store'], false);
      expect(body, isNot(contains('previous_interaction_id')));
      expect((body['input'] as List).length, 3);
    });

    test('no TTS audio default, and audioFormat is dropped', () async {
      final warnings = _captureWarnings();
      final client = MockHttpClient();
      // An unlisted TTS name would stay on generateContent, so use a text
      // model with a TTS option to reach the Interactions path.
      await _run(
        client,
        config: {
          'audioFormat': {'mimeType': 'audio/wav'},
        },
      );
      expect(_lastBody(client), isNot(contains('response_format')));
      expect(warnings, [
        "audioFormat is not supported by 'gemini-3.8-flash' and was ignored.",
      ]);
    });

    test('image entries and JSON output work as on googleAI', () async {
      final client = MockHttpClient();
      await _run(
        client,
        config: {
          'imageConfig': {'aspectRatio': '9:16'},
          'responseMimeType': 'application/json',
        },
      );
      expect(_lastBody(client)['response_format'], [
        {'type': 'image', 'aspect_ratio': '9:16'},
        {
          'type': 'text',
          'mime_type': 'application/json',
          'schema': <String, Object?>{},
        },
      ]);
    });

    test('an unlisted model gets the minimal body (JS "sends unlisted '
        'models to the Interactions API")', () async {
      final client = MockHttpClient();
      await _run(client, model: 'gemini-future-flash');
      expect(client.lastUrl.toString(), _interactionsUrl);
      expect(client.lastHeaders!['Api-Revision'], '2026-05-20');
      expect(_lastBody(client), {
        'model': 'gemini-future-flash',
        'generation_config': <String, Object?>{},
        'input': [
          {
            'type': 'user_input',
            'content': [
              {'type': 'text', 'text': 'hello'},
            ],
          },
        ],
        'store': false,
      });
    });

    test('sends Omni video format and config', () async {
      final client = MockHttpClient();
      await _run(
        client,
        model: 'gemini-omni-1.1-flash-preview',
        config: {
          'videoFormat': {'aspectRatio': '9:16', 'resolution': '1080p'},
          'videoConfig': {'task': 'text_to_video'},
        },
      );
      expect(client.lastUrl.toString(), _interactionsUrl);
      final body = _lastBody(client);
      expect(body['response_format'], {
        'type': 'video',
        'aspect_ratio': '9:16',
        'resolution': '1080p',
      });
      expect(body['generation_config'], {
        'video_config': {'task': 'text_to_video'},
      });
    });

    test('rejects previousInteractionId without store, before any '
        'request', () async {
      final client = MockHttpClient();
      await expectLater(
        _run(client, config: {'previousInteractionId': 'v1_abc123'}),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('store must be true when previousInteractionId is set'),
          ),
        ),
      );
      expect(
        client.requestUrls.where((u) => u.path.endsWith('/interactions')),
        isEmpty,
      );
    });
  });
}

void _resendTests() {
  group('stateless resend', () {
    // A model turn with a Google Search step pair (rejected by the platform
    // when resent) and a code execution pair (accepted).
    final history = [
      ..._hello,
      Message.fromJson({
        'role': 'model',
        'content': [
          {
            'custom': {
              'googleSearchCall': {
                'id': 'g1',
                'arguments': {
                  'queries': ['q'],
                },
              },
            },
            'metadata': {'thoughtSignature': 'sig1'},
          },
          {
            'custom': {
              'googleSearchResult': {'callId': 'g1', 'result': <Object?>[]},
            },
            'metadata': {'thoughtSignature': 'sig2'},
          },
          {
            'custom': {
              'executableCode': {'code': 'print(1)', 'language': 'PYTHON'},
            },
            'metadata': {'callId': 'c1'},
          },
          {
            'custom': {
              'codeExecutionResult': {'output': '1', 'outcome': 'OUTCOME_OK'},
            },
            'metadata': {'callId': 'c1'},
          },
          {'text': 'Done.'},
        ],
      }),
      Message(
        role: Role.user,
        content: [TextPart(text: 'And now?')],
      ),
    ];

    test('leaves out the server-side tool steps the platform rejects, '
        'warning once', () async {
      final warnings = _captureWarnings();
      final client = MockHttpClient();
      await _run(client, messages: history);
      await _run(client, messages: history);

      final types = [
        for (final step in _lastBody(client)['input'] as List)
          (step as Map)['type'],
      ];
      expect(types, isNot(contains('google_search_call')));
      expect(types, isNot(contains('google_search_result')));
      expect(
        types,
        containsAll(['code_execution_call', 'code_execution_result']),
      );
      expect(
        warnings.where((w) => w.startsWith('Earlier server-side tool')),
        hasLength(1),
      );
    });

    test('with store: true only the newer messages are sent', () async {
      final storedHistory = [
        ...history.take(1),
        Message.fromJson({
          ...history[1].toJson(),
          'metadata': {'interactionId': 'v1_prev'},
        }),
        history[2],
      ];
      final warnings = _captureWarnings();
      final client = MockHttpClient();
      await _run(client, messages: storedHistory, config: {'store': true});

      final body = _lastBody(client);
      expect(body['previous_interaction_id'], 'v1_prev');
      expect(
        (body['input'] as List).single,
        containsPair('type', 'user_input'),
      );
      expect(warnings, isEmpty);
    });
  });
}
