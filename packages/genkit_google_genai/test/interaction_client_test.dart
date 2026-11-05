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
import 'package:genkit_google_genai/common.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

Stream<String> _lines(String text) => Stream.fromIterable(text.split('\n'));

void main() {
  group('parseInteractionSse', () {
    test(
      'parses events separated by blank lines, ignoring other fields',
      () async {
        final events = await parseInteractionSse(
          _lines(
            'event: step.start\n'
            'data: {"event_type":"step.start","index":0,'
            '"step":{"type":"model_output"}}\n'
            '\n'
            ': keep-alive\n'
            'id: 7\n'
            'data: {"event_type":"step.delta","index":0,\n'
            'data: "delta":{"type":"text","text":"Hi"}}\n'
            '\n'
            'data: {"event_type":"interaction.completed","interaction":{}}',
          ),
        ).toList();
        expect(events.map((e) => e.eventType), [
          'step.start',
          'step.delta',
          'interaction.completed',
        ]);
        expect(
          TextDelta.fromJson(
            StepDelta.fromJson(events[1].json).delta!.json,
          ).text,
          'Hi',
        );
      },
    );

    test('ignores the final data: [DONE]', () async {
      // Seen live (googleAI, Oct 27): the stream ends with `data: [DONE]`
      // after interaction.completed.
      final events = await parseInteractionSse(
        _lines(
          'event: interaction.completed\n'
          'data: {"event_type":"interaction.completed","interaction":{}}\n'
          '\n'
          'data: [DONE]\n'
          '\n',
        ),
      ).toList();
      expect(events.map((e) => e.eventType), ['interaction.completed']);
    });

    test('throws on an error event, with the mapped status', () {
      expect(
        parseInteractionSse(
          _lines(
            'data: {"event_type":"error","error":'
            '{"code":"rate_limit_exceeded","message":"slow down"}}\n\n',
          ),
        ).toList(),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.resourceExhausted,
          ),
        ),
      );
    });

    test('throws on a plain JSON error body instead of SSE', () {
      expect(
        parseInteractionSse(
          _lines(
            '{"error":{"code":"service_unavailable","message":"overloaded"}}',
          ),
        ).toList(),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.unavailable,
          ),
        ),
      );
    });

    test('throws on a plain JSON error body wrapped in a list', () {
      expect(
        parseInteractionSse(
          _lines(
            '[{\n'
            '  "error": {"code": "service_unavailable", "message": "overloaded"}\n'
            '}]',
          ),
        ).toList(),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.unavailable)
              .having(
                (e) => e.message,
                'message',
                'Interaction API returned an error: [service_unavailable] '
                    'overloaded',
              ),
        ),
      );
    });
  });

  group('GenerativeLanguageBaseClient interactions', () {
    late List<http.Request> requests;
    GenerativeLanguageBaseClient clientFor(http.Response response) {
      requests = [];
      return GenerativeLanguageBaseClient(
        baseUrl: 'https://example.test/',
        client: MockClient((request) async {
          requests.add(request);
          return response;
        }),
      );
    }

    test('createInteraction posts to interactions with Api-Revision', () async {
      final client = clientFor(
        http.Response(jsonEncode({'id': 'v1_x', 'status': 'completed'}), 200),
      );
      final interaction = await client.createInteraction(
        CreateInteractionRequest(model: 'gemini-3.8-flash', input: 'Hi'),
      );
      expect(interaction.id, 'v1_x');
      final request = requests.single;
      expect(
        request.url.toString(),
        'https://example.test/v1beta/interactions',
      );
      expect(request.headers['Api-Revision'], interactionsApiRevision);
      expect(jsonDecode(request.body), {
        'model': 'gemini-3.8-flash',
        'input': 'Hi',
      });
    });

    test('createInteraction maps an Interactions error code', () {
      final client = clientFor(
        http.Response(
          jsonEncode({
            'error': {'code': 'model_not_found', 'message': 'no such model'},
          }),
          404,
        ),
      );
      expect(
        client.createInteraction(
          CreateInteractionRequest(model: 'gemini-x', input: 'Hi'),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.notFound,
          ),
        ),
      );
    });

    // The Interactions API wraps some error bodies in a list (seen in review
    // with an invalid API key: `[{"error": {...}}]`); the message must be the
    // error's, not the raw JSON.
    final listErrorBody = jsonEncode([
      {
        'error': {
          'code': 400,
          'message': 'API key not valid. Please pass a valid API key.',
          'status': 'INVALID_ARGUMENT',
        },
      },
    ]);
    final isInvalidKeyError = isA<GenkitException>()
        .having((e) => e.status, 'status', StatusCode.invalidArgument)
        .having(
          (e) => e.message,
          'message',
          'Google AI Error: API key not valid. Please pass a valid API key.',
        );

    test('createInteraction reads an error body wrapped in a list', () {
      final client = clientFor(http.Response(listErrorBody, 400));
      expect(
        client.createInteraction(
          CreateInteractionRequest(model: 'gemini-3.8-flash', input: 'Hi'),
        ),
        throwsA(isInvalidKeyError),
      );
    });

    test('createInteractionStream reads an error body wrapped in a list', () {
      final client = clientFor(http.Response(listErrorBody, 400));
      expect(
        client
            .createInteractionStream(
              CreateInteractionRequest(model: 'gemini-3.8-flash', input: 'Hi'),
            )
            .toList(),
        throwsA(isInvalidKeyError),
      );
    });

    test(
      'createInteractionStream sets stream: true and parses events',
      () async {
        final client = clientFor(
          http.Response(
            'data: {"event_type":"interaction.created","interaction":{}}\n\n'
            'data: {"event_type":"interaction.completed",'
            '"interaction":{"status":"completed"}}\n\n',
            200,
          ),
        );
        final events = await client
            .createInteractionStream(
              CreateInteractionRequest(model: 'gemini-3.8-flash', input: 'Hi'),
            )
            .toList();
        expect(events.map((e) => e.eventType), [
          'interaction.created',
          'interaction.completed',
        ]);
        expect((jsonDecode(requests.single.body) as Map)['stream'], true);
        expect(
          requests.single.headers['Api-Revision'],
          interactionsApiRevision,
        );
      },
    );
  });
}
