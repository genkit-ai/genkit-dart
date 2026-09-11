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

/// Answers chat completions with an optional reasoning payload, recording the
/// request bodies the plugin sent.
MockClient reasoningClient(
  List<Map<String, dynamic>> capturedBodies, {
  String? reasoningContent,
  String? reasoning,
  List<String>? sseFrames,
}) {
  return MockClient((request) async {
    if (!request.url.path.endsWith('/chat/completions')) {
      return http.Response('not found', 404);
    }
    capturedBodies.add(
      (jsonDecode(request.body) as Map).cast<String, dynamic>(),
    );

    if (sseFrames != null) {
      final body = sseFrames.map((f) => 'data: $f\n\n').join();
      return http.Response(
        '${body}data: [DONE]\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }

    return http.Response(
      jsonEncode({
        'id': 'chatcmpl-test',
        'object': 'chat.completion',
        'created': 0,
        'model': 'o4-mini',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': 'the answer',
              'reasoning_content': ?reasoningContent,
              'reasoning': ?reasoning,
            },
            'finish_reason': 'stop',
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Matches the failed response `generate()` returns for a request error.
///
/// The action layer still throws; `ai.generate()` reports the failure on the
/// response instead (see #413), so a rejected `reasoningEffort` lands here.
Matcher failsWith(StatusCodes status, {String? message}) =>
    isA<GenerateResponse>()
        .having((r) => r.finishReason, 'finishReason', FinishReason.failed)
        .having((r) => r.error?.status, 'error.status', status.name)
        .having(
          (r) => r.error?.message ?? '',
          'error.message',
          message == null ? anything : contains(message),
        );

/// The reasoning text a response carries, or null when it carries none.
String? reasoningOf(GenerateResponseHelper<dynamic> response) => response
    .message
    ?.content
    .firstWhere((p) => p.isReasoning, orElse: () => TextPart(text: ''))
    .reasoning;

Genkit genkitWith(http.Client client, {String? baseUrl}) {
  final ai = Genkit(
    plugins: [openAI(apiKey: 'test-key', baseUrl: baseUrl, httpClient: client)],
  );
  addTearDown(ai.shutdown);
  return ai;
}

void main() {
  group('reasoning effort on the wire', () {
    test('reaches the request for a reasoning model', () async {
      final captured = <Map<String, dynamic>>[];
      await genkitWith(reasoningClient(captured)).generate(
        model: openAI.model('o4-mini'),
        prompt: 'think',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      expect(captured.single['reasoning_effort'], 'high');
    });

    test('reaches the request for the GPT-5 family', () async {
      final captured = <Map<String, dynamic>>[];
      await genkitWith(reasoningClient(captured)).generate(
        model: OpenAIModels.gpt5Mini,
        prompt: 'think',
        config: OpenAIChatOptions(reasoningEffort: 'minimal'),
      );

      expect(captured.single['reasoning_effort'], 'minimal');
    });

    test('every level the API knows is sendable', () async {
      // The vocabulary moves per model generation, so the plugin forwards it
      // rather than judging it - `none` arrived with GPT-5.1, `xhigh` later.
      for (final effort in ['none', 'low', 'medium', 'high', 'xhigh', 'max']) {
        final captured = <Map<String, dynamic>>[];
        await genkitWith(reasoningClient(captured)).generate(
          model: OpenAIModels.gpt56Sol,
          prompt: 'think',
          config: OpenAIChatOptions(reasoningEffort: effort),
        );

        expect(captured.single['reasoning_effort'], effort);
      }
    });

    test('is omitted when unset', () async {
      final captured = <Map<String, dynamic>>[];
      await genkitWith(
        reasoningClient(captured),
      ).generate(model: openAI.model('o4-mini'), prompt: 'hi');

      expect(captured.single, isNot(contains('reasoning_effort')));
      expect(captured.single, isNot(contains('verbosity')));
    });

    test('verbosity reaches the request', () async {
      final captured = <Map<String, dynamic>>[];
      await genkitWith(reasoningClient(captured)).generate(
        model: OpenAIModels.gpt5,
        prompt: 'hi',
        config: OpenAIChatOptions(verbosity: 'low'),
      );

      expect(captured.single['verbosity'], 'low');
    });
  });

  group('reasoning effort validation', () {
    test('a model that does not reason is named, not the parameter', () async {
      final captured = <Map<String, dynamic>>[];

      await expectLater(
        genkitWith(reasoningClient(captured)).generate(
          model: OpenAIModels.gpt4o,
          prompt: 'hi',
          config: OpenAIChatOptions(reasoningEffort: 'high'),
        ),
        completion(failsWith(StatusCodes.INVALID_ARGUMENT, message: 'gpt-4o')),
      );
      expect(captured, isEmpty, reason: 'rejected before any request');
    });

    test('o1-mini predates the parameter and is rejected', () async {
      await expectLater(
        genkitWith(reasoningClient([])).generate(
          model: openAI.model('o1-mini'),
          prompt: 'hi',
          config: OpenAIChatOptions(reasoningEffort: 'low'),
        ),
        completion(failsWith(StatusCodes.INVALID_ARGUMENT, message: 'o1-mini')),
      );
    });

    test('an uncurated model is left to OpenAI to judge', () async {
      final captured = <Map<String, dynamic>>[];
      await genkitWith(reasoningClient(captured)).generate(
        model: openAI.model('o7-preview'),
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'max'),
      );

      expect(captured.single['reasoning_effort'], 'max');
    });

    test('version is the model judged, not the action id', () async {
      // `version` overrides the model that answers, so it is the one the
      // catalog has to be asked about - both ways round.
      final captured = <Map<String, dynamic>>[];

      await expectLater(
        genkitWith(reasoningClient(captured)).generate(
          model: OpenAIModels.o4Mini,
          prompt: 'hi',
          config: OpenAIChatOptions(version: 'gpt-4o', reasoningEffort: 'high'),
        ),
        completion(failsWith(StatusCodes.INVALID_ARGUMENT, message: 'gpt-4o')),
      );
      expect(captured, isEmpty);

      // And the reverse: a reasoning `version` behind a non-reasoning action
      // is allowed through, because that is the model that will answer.
      await genkitWith(reasoningClient(captured)).generate(
        model: OpenAIModels.gpt4o,
        prompt: 'hi',
        config: OpenAIChatOptions(version: 'o3', reasoningEffort: 'high'),
      );

      expect(captured.single['model'], 'o3');
      expect(captured.single['reasoning_effort'], 'high');
    });

    test('a compat host judges its own models', () async {
      // gpt-4o behind a gateway may be a fine-tune or a rename; the catalog
      // describes OpenAI's deployment, not that host's.
      final captured = <Map<String, dynamic>>[];
      await genkitWith(
        reasoningClient(captured),
        baseUrl: 'https://openrouter.ai/api/v1',
      ).generate(
        model: openAI.model('gpt-4o'),
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      expect(captured.single['reasoning_effort'], 'high');
    });

    test('an unknown level is the caller\'s mistake', () async {
      await expectLater(
        genkitWith(reasoningClient([])).generate(
          model: openAI.model('o4-mini'),
          prompt: 'hi',
          config: OpenAIChatOptions(reasoningEffort: 'extreme'),
        ),
        completion(
          failsWith(StatusCodes.INVALID_ARGUMENT, message: 'Known levels'),
        ),
      );
    });
  });

  group('reasoning in the response', () {
    test('reasoning_content becomes a ReasoningPart', () async {
      final response = await genkitWith(
        reasoningClient([], reasoningContent: 'step one, step two'),
      ).generate(model: openAI.model('deepseek-reasoner'), prompt: 'hi');

      expect(reasoningOf(response), 'step one, step two');
      expect(response.text, 'the answer');
    });

    test('reasoning is read too, for the gateways that use it', () async {
      final response = await genkitWith(
        reasoningClient([], reasoning: 'thinking out loud'),
      ).generate(model: openAI.model('some-router-model'), prompt: 'hi');

      expect(reasoningOf(response), 'thinking out loud');
    });

    test('reasoning leads the content, ahead of the answer', () async {
      final response = await genkitWith(
        reasoningClient([], reasoningContent: 'because'),
      ).generate(model: openAI.model('deepseek-reasoner'), prompt: 'hi');

      expect(response.message!.content.first.isReasoning, isTrue);
      expect(response.message!.content.last.isText, isTrue);
    });

    test('a response without reasoning carries no ReasoningPart', () async {
      final response = await genkitWith(
        reasoningClient([]),
      ).generate(model: openAI.model('gpt-4o'), prompt: 'hi');

      expect(response.message!.content.any((p) => p.isReasoning), isFalse);
    });
  });

  group('reasoning while streaming', () {
    test('deltas are forwarded as they arrive', () async {
      final frames = [
        jsonEncode({
          'id': 'c',
          'object': 'chat.completion.chunk',
          'created': 0,
          'model': 'deepseek-reasoner',
          'choices': [
            {
              'index': 0,
              'delta': {'reasoning_content': 'first thought'},
            },
          ],
        }),
        jsonEncode({
          'id': 'c',
          'object': 'chat.completion.chunk',
          'created': 0,
          'model': 'deepseek-reasoner',
          'choices': [
            {
              'index': 0,
              'delta': {'content': 'the answer'},
              'finish_reason': 'stop',
            },
          ],
        }),
      ];

      final chunks = <List<Part>>[];
      final stream = genkitWith(
        reasoningClient([], sseFrames: frames),
      ).generateStream(model: openAI.model('deepseek-reasoner'), prompt: 'hi');
      await for (final chunk in stream) {
        chunks.add(chunk.content);
      }
      final response = await stream.onResult;

      // The thought arrives before the answer, not bundled in after it.
      expect(chunks.first.first.isReasoning, isTrue);
      expect(chunks.first.first.reasoning, 'first thought');
      expect(chunks.last.first.isText, isTrue);
      expect(reasoningOf(response), 'first thought');
      expect(response.text, 'the answer');
    });
  });
}
