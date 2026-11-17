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

import 'package:genkit/genkit.dart' show Message, ModelRequest, Role, TextPart;
import 'package:genkit/src/o11y/instrumentation.dart' show resetInstrumentation;
import 'package:genkit/telemetry.dart';
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/generated/generativelanguage.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:genkit_google_genai/src/interaction_types.dart'
    show CreateInteractionRequest;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A span the recorder saw: its name, input and output (or error).
typedef _Span = ({String name, Object? input, Object? output, Object? error});

/// Records every span opened through the instrumentation API.
class _Recorder implements Instrumentation {
  final List<_Span> spans = [];

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) async {
    try {
      final output = await next();
      spans.add((
        name: metadata.name,
        input: metadata.input,
        output: output,
        error: null,
      ));
      return output;
    } catch (e) {
      spans.add((
        name: metadata.name,
        input: metadata.input,
        output: null,
        error: e,
      ));
      rethrow;
    }
  }
}

const _completed = {'status': 'completed'};

/// A client that answers every request: SSE for streamed calls, the JSON
/// [body] otherwise, with [status].
GenerativeLanguageBaseClient _client({
  required bool debugTraces,
  Map<String, Object?> body = const {'ok': true},
  int status = 200,
  String? apiKey = 'test-key',
  String Function()? accessToken,
}) => GenerativeLanguageBaseClient(
  baseUrl: 'https://example.test/',
  client: MockClient((request) async {
    if (request.url.path.endsWith(':streamGenerateContent')) {
      return http.Response('data: {}\n\n', status);
    }
    if (request.body.contains('"stream":true')) {
      return http.Response(
        'data: {"event_type":"interaction.completed",'
        '"interaction":{"status":"completed"}}\n\n',
        status,
      );
    }
    return http.Response(jsonEncode(body), status);
  }),
  apiKey: apiKey,
  accessToken: accessToken,
  debugTraces: debugTraces,
);

/// The input of [span] as a map.
Map<String, Object?> _input(_Span span) =>
    (span.input! as Map).cast<String, Object?>();

void main() {
  late _Recorder recorder;
  setUp(() {
    recorder = _Recorder();
    configureInstrumentation(recorder);
  });
  tearDown(resetInstrumentation);

  test('googleAI(experimentalDebugTraces: true) traces a model call', () async {
    final model = GoogleGenAiPluginImpl(
      apiKey: 'test-key',
      experimentalDebugTraces: true,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
        ),
      ),
    ).resolve(.model, 'gemini-3.1-flash-lite')!;
    await model.run(
      ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
        ],
      ),
    );
    expect(recorder.spans.where((s) => s.name == 'httpRequest').map(_input), [
      containsPair('model', 'gemini-3.1-flash-lite'),
    ]);
  });

  test('without debugTraces nothing is traced', () async {
    final client = _client(debugTraces: false, body: _completed);
    await client.generateContent(GenerateContentRequest(), model: 'models/m');
    await client.createInteraction(
      CreateInteractionRequest(model: 'm', input: 'Hi'),
    );
    expect(recorder.spans, isEmpty);
  });

  group('with debugTraces', () {
    test('generateContent: one httpRequest span with the request, the '
        'model, redacted headers and the response', () async {
      final request = GenerateContentRequest(
        contents: [
          Content(
            role: 'user',
            parts: [Part(text: 'hi')],
          ),
        ],
      );
      await _client(
        debugTraces: true,
      ).generateContent(request, model: 'models/gemini-x');

      final span = recorder.spans.single;
      expect(span.name, 'httpRequest');
      final input = _input(span);
      expect(
        input['apiEndpoint'],
        'https://example.test/v1beta/models/gemini-x:generateContent',
      );
      expect(input['request'], request.toJson());
      expect(input['model'], 'gemini-x');
      final headers = input['headers']! as Map;
      expect(headers['x-goog-api-key'], '<REDACTED> (8 characters)');
      expect(headers['Content-Type'], startsWith('application/json'));
      expect(span.output, {'ok': true});
    });

    test('an access token is redacted too', () async {
      await _client(
        debugTraces: true,
        apiKey: null,
        accessToken: () => 'secret-token',
      ).generateContent(GenerateContentRequest(), model: 'models/m');
      final input = _input(recorder.spans.single);
      // 'Bearer secret-token' is 19 characters.
      expect(
        (input['headers']! as Map)['Authorization'],
        '<REDACTED> (19 characters)',
      );
      expect(jsonEncode(input), isNot(contains('secret')));
    });

    test('streamed calls show [Streaming Response]; Interactions requests '
        'have no model field', () async {
      final client = _client(debugTraces: true);
      await client
          .streamGenerateContent(GenerateContentRequest(), model: 'models/m')
          .drain<void>();
      await client
          .createInteractionStream(
            CreateInteractionRequest(model: 'm', input: 'Hi'),
          )
          .drain<void>();
      expect(recorder.spans.map((s) => s.output), [
        '[Streaming Response]',
        '[Streaming Response]',
      ]);
      final interaction = _input(recorder.spans.last);
      expect(interaction, isNot(contains('model')));
      expect(interaction['request'], containsPair('stream', true));
    });

    test('createInteraction, embedContent and predict are traced; '
        'listModels is not', () async {
      final client = _client(debugTraces: true, body: _completed);
      await client.createInteraction(
        CreateInteractionRequest(model: 'm', input: 'Hi'),
      );
      await client.embedContent(EmbedContentRequest(), model: 'models/e');
      await client.predict({'instances': <Object?>[]}, model: 'models/p');
      await client.listModels();
      expect(recorder.spans.map((s) => _input(s)['apiEndpoint']), [
        'https://example.test/v1beta/interactions',
        'https://example.test/v1beta/models/e:embedContent',
        'https://example.test/v1beta/models/p:predict',
      ]);
    });

    test('an error response fails the span with the API error', () async {
      final client = _client(
        debugTraces: true,
        status: 400,
        body: {
          'error': {
            'code': 400,
            'message': 'boom',
            'status': 'INVALID_ARGUMENT',
          },
        },
      );
      await expectLater(
        client.generateContent(GenerateContentRequest(), model: 'models/m'),
        throwsA(anything),
      );
      expect(recorder.spans.single.error.toString(), contains('boom'));
    });
  });
}
