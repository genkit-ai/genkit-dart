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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

void main() {
  group('GenerateResult', () {
    final request = ModelRequest(
      messages: [
        Message(
          role: .user,
          content: [TextPart(text: 'hi')],
        ),
      ],
    );
    final response = ModelResponse(
      finishReason: .stop,
      finishMessage: 'ok',
      latencyMs: 12,
      usage: GenerationUsage(inputTokens: 3),
      custom: {'k': 'v'},
      message: Message(
        role: .model,
        content: [TextPart(text: 'hello')],
      ),
    );

    test('reads through to the model response', () {
      final res = GenerateResult<String>(
        response,
        request: request,
        output: 'parsed',
      );
      expect(res.modelResponse, same(response));
      expect(res.modelRequest, same(request));
      expect(res.text, 'hello');
      expect(res.message?.text, 'hello');
      expect(res.finishReason, FinishReason.stop);
      expect(res.finishMessage, 'ok');
      expect(res.latencyMs, 12);
      expect(res.usage?.inputTokens, 3);
      expect(res.custom, {'k': 'v'});
      expect(res.error, isNull);
      expect(res.output, 'parsed');
      expect(res.messages.map((m) => m.text), ['hi', 'hello']);
    });

    test('carries a failed response error', () {
      final res = GenerateResult<void>(
        ModelResponse(
          finishReason: .failed,
          error: RuntimeError(message: 'boom', status: 'UNAVAILABLE'),
        ),
      );
      expect(res.message, isNull);
      expect(res.text, '');
      expect(res.error?.message, 'boom');
      expect(res.messages, isEmpty);
    });

    test('is not a wire type, so it has no setters to desync', () {
      final Object res = GenerateResult<void>(response);
      // A view over the response, not a subtype of a mutable wire type.
      expect(res, isNot(isA<GenerateResponse>()));
      expect(res, isNot(isA<ModelResponse>()));
    });
  });

  group('GenerateResponseChunk', () {
    final previous = ModelResponseChunk(
      index: 0,
      role: .model,
      content: [TextPart(text: 'Hel')],
    );
    final chunk = ModelResponseChunk(
      index: 0,
      role: .model,
      content: [TextPart(text: 'lo')],
      custom: {'k': 'v'},
    );

    test('reads through to the model chunk', () {
      final c = GenerateResponseChunk<Map<String, dynamic>>(
        chunk,
        previousChunks: [previous],
        output: {'partial': true},
      );
      expect(c.modelChunk, same(chunk));
      expect(c.text, 'lo');
      expect(c.accumulatedText, 'Hello');
      expect(c.content.map((p) => p.text), ['lo']);
      expect(c.role, Role.model);
      expect(c.index, 0);
      expect(c.custom, {'k': 'v'});
      expect(c.output, {'partial': true});
      expect(c, isNot(isA<ModelResponseChunk>()));
    });

    test('forwards to a flow stream via modelChunk', () async {
      final ai = Genkit();
      addTearDown(ai.shutdown);
      final model = ai.defineModel(
        name: 'echo',
        fn: (req, ctx) async {
          ctx.sendChunk(chunk);
          return ModelResponse(
            finishReason: .stop,
            message: Message(
              role: .model,
              content: [TextPart(text: 'hello')],
            ),
          );
        },
      );
      final flow = ai.defineFlow(
        name: 'forward',
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: ModelResponseChunk.$schema,
        fn: (prompt, ctx) async {
          final res = await ai.generate(
            model: model,
            prompt: prompt,
            onChunk: (c) => ctx.sendChunk(c.modelChunk),
          );
          return res.text;
        },
      );
      final stream = flow.stream('hi');
      final chunks = await stream.toList();
      expect(chunks.map((c) => c.text), ['lo']);
      expect(await stream.onResult, 'hello');
    });
  });
}
