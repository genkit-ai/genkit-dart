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
import 'package:genkit/lite.dart' as lite;
import 'package:test/test.dart';

void main() {
  test('lite generate with outputSchema does not throw', () async {
    // Defines a dummy model
    final model = Model<void>(
      name: 'testModel',
      fn: (request, context) async {
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "success"}')],
          ),
        );
      },
    );

    // Tests that lite.dart's generate passes outputSchema correctly
    // without throwing "type 'Function' is not a subtype of type 'Map<String, dynamic>' in type cast"
    final response = await lite.generate(
      model: model,
      prompt: 'Hello',
      outputSchema: .string(),
    );

    expect(response.text, '{"result": "success"}');
  });

  test('lite generateStream with outputSchema does not throw', () async {
    final model = Model<void>(
      name: 'testModelStream',
      fn: (request, context) async {
        context.sendChunk(
          ModelResponseChunk(index: 0, content: [TextPart(text: '{"res')]),
        );
        context.sendChunk(
          ModelResponseChunk(
            index: 0,
            content: [TextPart(text: 'ult": "success"}')],
          ),
        );
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "success"}')],
          ),
        );
      },
    );

    final stream = lite.generateStream(
      model: model,
      prompt: 'Hello',
      outputSchema: .string(),
    );

    final chunks = await stream.toList();
    expect(chunks.length, 2);
    expect(chunks[0].text, '{"res');
    expect(chunks[1].text, 'ult": "success"}');

    final response = await stream.onResult;
    expect(response.text, '{"result": "success"}');
  });
}
