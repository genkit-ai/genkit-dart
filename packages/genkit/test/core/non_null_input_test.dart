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

import 'package:genkit/experimental.dart';
import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

/// Typed action constructors take a non-null-input function and reject a null
/// input with INVALID_ARGUMENT before it reaches the implementation.
void main() {
  final rejectsNull = throwsA(
    isA<GenkitException>()
        .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
        .having((e) => e.message, 'message', contains('non-null input')),
  );

  final response = ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(
      role: Role.model,
      content: [TextPart(text: 'ok')],
    ),
  );

  test('Model rejects a null request', () {
    var called = false;
    final model = Model<void>(
      name: 'm',
      fn: (req, ctx) async {
        called = true;
        return response;
      },
    );
    expect(model.run(null), rejectsNull);
    expect(called, isFalse);
  });

  test('Model passes a non-null request through', () async {
    ModelRequest? seen;
    final model = Model<void>(
      name: 'm',
      fn: (req, ctx) async {
        seen = req;
        return response;
      },
    );
    final request = ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
      ],
    );
    expect(await model(request), same(response));
    expect(seen, same(request));
  });

  test('Embedder rejects a null request', () {
    final embedder = Embedder<void>(
      name: 'e',
      fn: (req, ctx) async => EmbedResponse(embeddings: []),
    );
    expect(embedder.run(null), rejectsNull);
  });

  test('Evaluator rejects a null request', () {
    final evaluator = Evaluator<void>(
      name: 'ev',
      description: 'test evaluator',
      fn: (req, ctx) async => [],
    );
    expect(evaluator.run(null), rejectsNull);
  });

  test('Tool rejects a null input even without an input schema', () {
    final tool = Tool<String, String>(
      name: 't',
      description: 'd',
      fn: (input, ctx) => .response(input),
    );
    expect(tool.run(null), rejectsNull);
  });

  group('Flow', () {
    test('rejects a null input when Input is non-nullable', () {
      final flow = Flow<String, String, void, void>(
        name: 'f',
        fn: (input, ctx) async => input.toUpperCase(),
      );
      expect(flow.run(null), rejectsNull);
    });

    test('passes null through when Input is nullable', () async {
      final flow = Flow<String?, String, void, void>(
        name: 'f',
        fn: (input, ctx) async => input ?? 'none',
      );
      expect(await flow(null), 'none');
    });

    test('defineFlow rejects a null input', () {
      final ai = Genkit();
      final flow = ai.defineFlow(
        name: 'df',
        inputSchema: .string(),
        fn: (String input, ctx) async => input,
      );
      expect(flow.run(null), rejectsNull);
    });

    // A bidi flow is run with a null unary input (see `Action.streamBidi`),
    // so it must not go through the non-null check even for a non-nullable
    // Input.
    test(
      'Flow.bidi with a non-nullable Input receives the input stream',
      () async {
        final flow = Flow<String, String, String, void>.bidi(
          name: 'bf',
          fn: (inputs, ctx) async {
            final all = await inputs.toList();
            return all.join(',');
          },
        );
        final controller = StreamController<String>();
        final session = flow.streamBidi(inputStream: controller.stream);
        controller
          ..add('a')
          ..add('b');
        await controller.close();
        expect(await session.onResult, 'a,b');
      },
    );
  });

  test('BidiModel receives the input stream', () async {
    final model = BidiModel<void>(
      name: 'bm',
      fn: (requests, ctx) async {
        await requests.drain<void>();
        return response;
      },
    );
    final session = model.streamBidi();
    await session.close();
    expect(await session.onResult, same(response));
  });
}
