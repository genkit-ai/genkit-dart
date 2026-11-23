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

import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/api_client.dart'
    show interactionsApiRevision;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _apiKey = 'test-key';

/// Not pinned to generateContent in the catalogue, so Interactions by default.
const _newModel = 'gemini-3.5-flash-lite';

/// Pinned to generateContent in the catalogue.
const _pinnedModel = 'gemini-3.5-flash';

const _proxy = 'https://proxy.test/genai';
const _proxyModel = 'google/gemini-4-argon';

const _sseChunks = [
  {
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': 'Hel'},
          ],
        },
      },
    ],
  },
  {
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': 'lo'},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
    'usageMetadata': {'promptTokenCount': 3, 'candidatesTokenCount': 2},
  },
];

const _interaction = {
  'status': 'completed',
  'steps': [
    {
      'type': 'model_output',
      'content': [
        {'type': 'text', 'text': 'interaction ok'},
      ],
    },
  ],
};

class _Sent {
  _Sent(http.Request request)
    : method = request.method,
      url = request.url,
      headers = {
        for (final entry in request.headers.entries)
          entry.key.toLowerCase(): entry.value,
      },
      body = (jsonDecode(request.body) as Map).cast<String, dynamic>();

  final String method;
  final Uri url;

  /// Header names lower-cased.
  final Map<String, String> headers;
  final Map<String, dynamic> body;
}

/// The HTTP transport the plugin's own client sits on. It records what was
/// sent and whether the plugin closed it.
class _Transport extends http.BaseClient {
  _Transport({this.streamBody, this.onClose});

  /// The body of streamGenerateContent responses; the default is [_sseChunks]
  /// sent whole.
  final Stream<List<int>> Function()? streamBody;

  /// Runs when the plugin closes the transport, like an aborted connection.
  final void Function()? onClose;

  final sent = <_Sent>[];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final recorded = _Sent(request as http.Request);
    sent.add(recorded);
    final path = recorded.url.path;
    if (path.endsWith(':streamGenerateContent')) {
      return http.StreamedResponse(
        streamBody?.call() ?? Stream.value(utf8.encode(_sse(_sseChunks))),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    final Object json;
    if (path.endsWith(':generateContent')) {
      json = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'generateContent ok'},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
        'usageMetadata': {'promptTokenCount': 3, 'candidatesTokenCount': 2},
      };
    } else if (path.endsWith('/interactions')) {
      json = _interaction;
    } else {
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(json))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closed = true;
    onClose?.call();
  }
}

String _sse(List<Map<String, Object?>> chunks) =>
    chunks.map((c) => 'data: ${jsonEncode(c)}\r\n\r\n').join();

Future<T> _withTransport<T>(_Transport transport, Future<T> Function() body) =>
    http.runWithClient(body, () => transport);

GenkitPlugin _plugin({String? baseUrl, bool? interactions}) =>
    interactions == null
    ? googleAI(apiKey: _apiKey, baseUrl: baseUrl)
    : googleAI(apiKey: _apiKey, baseUrl: baseUrl, interactions: interactions);

Future<GenerateResult> _generate(
  _Transport transport,
  GenkitPlugin plugin, {
  String model = _newModel,
  void Function(GenerateResponseChunk)? onChunk,
  CancellationToken? cancel,
}) async {
  final ai = Genkit(plugins: [plugin], isDevEnv: false);
  addTearDown(ai.shutdown);
  return _withTransport(
    transport,
    () => ai.generate(
      model: modelRef('googleai/$model'),
      prompt: 'hi',
      onChunk: onChunk,
      cancel: cancel,
    ),
  );
}

void main() {
  group('interactions: false', () {
    test('sends a bare new model to generateContent', () async {
      final transport = _Transport();
      final result = await _generate(transport, _plugin(interactions: false));

      final request = transport.sent.single;
      expect(request.method, 'POST');
      expect(
        '${request.url}',
        'https://generativelanguage.googleapis.com/v1beta/models/'
            '$_newModel:generateContent',
      );
      expect(result.text, 'generateContent ok');
    });

    test('sends a provider-qualified name to a custom baseUrl with the '
        'API-key headers and no Api-Revision', () async {
      final transport = _Transport();
      final response = await _generate(
        transport,
        _plugin(baseUrl: _proxy, interactions: false),
        model: _proxyModel,
      );

      final request = transport.sent.single;
      expect(request.method, 'POST');
      expect(
        '${request.url}',
        '$_proxy/v1beta/models/$_proxyModel:generateContent',
      );
      expect(request.headers.keys.toSet(), {
        'content-type',
        'x-goog-api-key',
        'x-goog-api-client',
      });
      expect(request.headers['content-type'], startsWith('application/json'));
      expect(request.headers['x-goog-api-key'], _apiKey);
      expect(request.headers['x-goog-api-client'], startsWith('genkit-dart/'));
      expect(response.text, 'generateContent ok');
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.inputTokens, 3);
    });

    test('sends a generateContent request body', () async {
      final transport = _Transport();
      await _generate(transport, _plugin(interactions: false));

      final body = transport.sent.single.body;
      expect(body['contents'], [
        {
          'role': 'user',
          'parts': [
            {'text': 'hi'},
          ],
        },
      ]);
      expect(body, isNot(contains('model')));
      expect(body, isNot(contains('input')));
      expect(body, isNot(contains('store')));
    });

    test('streams through streamGenerateContent as SSE', () async {
      final transport = _Transport();
      final chunks = <String>[];
      final response = await _generate(
        transport,
        _plugin(baseUrl: _proxy, interactions: false),
        onChunk: (chunk) => chunks.add(chunk.text),
      );

      final request = transport.sent.single;
      expect(
        '${request.url}',
        '$_proxy/v1beta/models/$_newModel:streamGenerateContent?alt=sse',
      );
      expect(request.headers, isNot(contains('api-revision')));
      expect(chunks, ['Hel', 'lo']);
      expect(response.text, 'Hello');
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.outputTokens, 2);
    });

    test('keeps the Lyria and Antigravity models on Interactions', () async {
      for (final model in ['lyria-3.5', 'antigravity-preview-09-2026']) {
        final transport = _Transport();
        await _generate(transport, _plugin(interactions: false), model: model);

        final request = transport.sent.single;
        expect(request.url.path, '/v1beta/interactions', reason: model);
        expect(
          request.headers['api-revision'],
          interactionsApiRevision,
          reason: model,
        );
        expect(
          request.body[model.startsWith('lyria-') ? 'model' : 'agent'],
          model,
          reason: model,
        );
      }
    });

    group('cancellation', () {
      test('after the first chunk stops the stream and closes the '
          'transport', () async {
        final held = StreamController<List<int>>();
        addTearDown(() {
          if (!held.isClosed) held.close();
        });
        final transport = _Transport(
          streamBody: () {
            held.add(utf8.encode(_sse([_sseChunks.first])));
            return held.stream;
          },
          onClose: held.close,
        );
        final cancel = CancellationController();
        final chunks = <String>[];

        final response = await _generate(
          transport,
          _plugin(interactions: false),
          onChunk: (chunk) {
            chunks.add(chunk.text);
            cancel.cancel();
          },
          cancel: cancel.token,
        ).timeout(const Duration(seconds: 5));

        expect(response.finishReason, FinishReason.aborted);
        expect(chunks, ['Hel']);
        expect(transport.closed, isTrue);
      });

      test('does not deliver a chunk that arrives after it', () async {
        final transport = _Transport();
        final cancel = CancellationController();
        final chunks = <String>[];

        final response = await _generate(
          transport,
          _plugin(interactions: false),
          onChunk: (chunk) {
            chunks.add(chunk.text);
            cancel.cancel();
          },
          cancel: cancel.token,
        );

        expect(response.finishReason, FinishReason.aborted);
        expect(chunks, ['Hel']);
        expect(transport.closed, isTrue);
      });
    });
  });

  group('interactions: true (default)', () {
    for (final (label, interactions) in [
      ('by default', null),
      ('when set', true),
    ]) {
      test('sends a new model to the Interactions API $label', () async {
        final transport = _Transport();
        final response = await _generate(
          transport,
          _plugin(baseUrl: _proxy, interactions: interactions),
        );

        final request = transport.sent.single;
        expect(request.method, 'POST');
        expect('${request.url}', '$_proxy/v1beta/interactions');
        expect(request.headers['api-revision'], interactionsApiRevision);
        expect(request.headers['x-goog-api-key'], _apiKey);
        expect(request.body['model'], _newModel);
        expect(response.text, 'interaction ok');
      });
    }

    test('keeps a model pinned to generateContent there', () async {
      final transport = _Transport();
      await _generate(
        transport,
        _plugin(interactions: true),
        model: _pinnedModel,
      );

      final request = transport.sent.single;
      expect(request.url.path, endsWith('/$_pinnedModel:generateContent'));
      expect(request.headers, isNot(contains('api-revision')));
    });
  });
}
