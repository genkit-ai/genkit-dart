// Copyright 2025 Google LLC
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
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Serves one canned reply whose `finish_reason` is [wireReason], as JSON or SSE.
MockClient finishClient(String wireReason, {bool toolCall = false}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({'object': 'list', 'data': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
    final toolCallJson = {
      'id': 'call_1',
      'type': 'function',
      'function': {'name': 'getWeather', 'arguments': '{}'},
    };
    if (body['stream'] == true) {
      final delta = toolCall
          ? {
              'role': 'assistant',
              'tool_calls': [
                {'index': 0, ...toolCallJson},
              ],
            }
          : {'role': 'assistant', 'content': 'x'};
      String chunk(Map<String, dynamic> choice) =>
          'data: ${jsonEncode({
            'id': 'c1',
            'object': 'chat.completion.chunk',
            'created': 0,
            'model': 'gpt-4o',
            'choices': [choice],
          })}\n\n';
      final first = chunk({'index': 0, 'delta': delta});
      final last = chunk({
        'index': 0,
        'delta': <String, dynamic>{},
        'finish_reason': wireReason,
      });
      return http.Response(
        '$first${last}data: [DONE]\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    return http.Response(
      jsonEncode({
        'id': 'chatcmpl-test',
        'object': 'chat.completion',
        'created': 0,
        'model': 'gpt-4o',
        'choices': [
          {
            'index': 0,
            'message': toolCall
                ? {
                    'role': 'assistant',
                    'content': null,
                    'tool_calls': [toolCallJson],
                  }
                : {'role': 'assistant', 'content': 'x'},
            'finish_reason': wireReason,
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  const cases = {
    'stop': (FinishReason.stop, false),
    'length': (FinishReason.length, false),
    'tool_calls': (FinishReason.stop, true),
    'content_filter': (FinishReason.blocked, false),
  };

  Future<Genkit> setUpAi(String wire, bool toolCall) async {
    final ai = Genkit(
      isDevEnv: false,
      plugins: [
        openAI(
          apiKey: 'test-key',
          httpClient: finishClient(wire, toolCall: toolCall),
        ),
      ],
    );
    addTearDown(ai.shutdown);
    ai.defineTool(
      name: 'getWeather',
      description: 'Get the weather',
      fn: (input, ctx) async => .response({'t': 72}),
    );
    return ai;
  }

  group('finish_reason on the wire', () {
    for (final MapEntry(key: wire, value: (expected, toolCall))
        in cases.entries) {
      test('non-streaming finish_reason "$wire" -> $expected', () async {
        final ai = await setUpAi(wire, toolCall);
        final response = await ai.generate(
          model: openAI.model('gpt-4o'),
          prompt: 'hi',
          toolNames: ['getWeather'],
          returnToolRequests: true,
        );
        expect(response.finishReason, expected);
      });

      test('streaming finish_reason "$wire" -> $expected', () async {
        final ai = await setUpAi(wire, toolCall);
        final stream = ai.generateStream(
          model: openAI.model('gpt-4o'),
          prompt: 'hi',
          toolNames: ['getWeather'],
          returnToolRequests: true,
        );
        await for (final _ in stream) {}
        final result = await stream.onResult;
        expect(result.finishReason, expected);
      });
    }
  });
}
