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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

void main() {
  group('Bidi Model', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('defineBidiModel registers a bidi model', () async {
      final model = genkit.defineBidiModel(
        name: 'myBidiModel',
        function: (input, context) async {
          context.sendChunk(ModelResponseChunk(content: []));
          return ModelResponse(finishReason: FinishReason.stop);
        },
      );
      expect(model.name, 'myBidiModel');
      expect(await genkit.registry.lookUpBidiModel('myBidiModel'), isNotNull);
    });

    test('can stream to/from bidi model', () async {
      final model = genkit.defineBidiModel(
        name: 'echoBidiModel',
        function: (input, context) async {
          await for (final chunk in input) {
            final text = chunk.messages.first.content.first.text;
            context.sendChunk(
              ModelResponseChunk(content: [TextPart(text: 'echo $text')]),
            );
          }
          return ModelResponse(finishReason: FinishReason.stop);
        },
      );
      // ...

      final session = model.streamBidi();
      session.send(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
        ),
      );
      session.send(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'world')],
            ),
          ],
        ),
      );
      session.close();

      final chunks = await session.toList();
      expect(chunks.length, 2);
      expect(chunks[0].content.first.text, 'echo hello');
      expect(chunks[1].content.first.text, 'echo world');
      expect((await session.onResult).finishReason, FinishReason.stop);
    });

    test('bidi model receives init data', () async {
      final model = genkit.defineBidiModel(
        name: 'initBidiModel',
        function: (input, context) async {
          final config = context.init?.config;
          final prefix = config?['prefix'] as String? ?? '';
          await for (final chunk in input) {
            final text = chunk.messages.first.content.first.text;
            context.sendChunk(
              ModelResponseChunk(content: [TextPart(text: '$prefix$text')]),
            );
          }
          return ModelResponse(finishReason: FinishReason.stop);
        },
      );

      final session = model.streamBidi(
        init: ModelRequest(messages: [], config: {'prefix': '>> '}),
      );
      session.send(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'm1')],
            ),
          ],
        ),
      );
      session.close();

      final chunks = await session.toList();
      expect(chunks.length, 1);
      expect(chunks[0].content.first.text, '>> m1');
    });
  });
}
