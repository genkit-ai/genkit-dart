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
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Captures every chat-completions request body the plugin puts on the wire
/// and serves canned OpenAI responses, so tests can assert on the actual
/// JSON sent rather than on plugin internals.
MockClient wireClient(List<Map<String, dynamic>> capturedBodies) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'gpt-4o',
              'object': 'model',
              'created': 0,
              'owned_by': 'openai',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith('/chat/completions')) {
      capturedBodies.add(
        (jsonDecode(request.body) as Map).cast<String, dynamic>(),
      );
      return http.Response(
        jsonEncode({
          'id': 'chatcmpl-test',
          'object': 'chat.completion',
          'created': 0,
          'model': 'o4-mini',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  group('wire-level request assembly', () {
    test('tools reach the wire for o-series models', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );
      ai.defineTool(
        name: 'getWeather',
        description: 'Get the weather for a location',
        fn: (input, ctx) async => {'temperature': 72},
      );

      await ai.generate(
        model: openAI.model('o4-mini'),
        prompt: 'What is the weather in Boston?',
        toolNames: ['getWeather'],
      );

      expect(captured, isNotEmpty);
      final body = captured.first;
      expect(
        body.containsKey('tools'),
        isTrue,
        reason:
            'request body must carry the tools array; the plugin silently '
            'dropping tools for o-series models is bug #357',
      );
      final tools = (body['tools'] as List).cast<Map<String, dynamic>>();
      final function = (tools.single['function'] as Map)
          .cast<String, dynamic>();
      expect(function['name'], 'getWeather');

      await ai.shutdown();
    });

    test(
      'tools reach the wire even when model metadata says tools unsupported',
      () async {
        // chatgpt-4o-latest advertises tools: false via the heuristics.
        // The request builder must not gate on that metadata: passing tools
        // through unconditionally is what keeps misdeclared models loud
        // instead of silently degraded (bug #357's second layer).
        final captured = <Map<String, dynamic>>[];
        final ai = Genkit(
          plugins: [
            openAI(apiKey: 'test-key', httpClient: wireClient(captured)),
          ],
        );
        ai.defineTool(
          name: 'getWeather',
          description: 'Get the weather for a location',
          fn: (input, ctx) async => {'temperature': 72},
        );

        expect(supportsTools('chatgpt-4o-latest'), isFalse);

        await ai.generate(
          model: openAI.model('chatgpt-4o-latest'),
          prompt: 'What is the weather in Boston?',
          toolNames: ['getWeather'],
        );

        expect(captured.first.containsKey('tools'), isTrue);

        await ai.shutdown();
      },
    );

    test('no tools requested leaves the tools key off the wire', () async {
      // Core hands the plugin a non-null (possibly empty) tools list; some
      // OpenAI-compatible providers reject "tools": [].
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );

      await ai.generate(model: openAI.model('o4-mini'), prompt: 'Say hello.');

      expect(captured.first.containsKey('tools'), isFalse);

      await ai.shutdown();
    });

    test('tools reach the wire for standard GPT models', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );
      ai.defineTool(
        name: 'getWeather',
        description: 'Get the weather for a location',
        fn: (input, ctx) async => {'temperature': 72},
      );

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'What is the weather in Boston?',
        toolNames: ['getWeather'],
      );

      expect(captured.first.containsKey('tools'), isTrue);

      await ai.shutdown();
    });
  });
}
