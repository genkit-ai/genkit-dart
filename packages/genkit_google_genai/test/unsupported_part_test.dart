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

import 'test_harness.dart';

ModelRequest _requestWithCustomPart() => ModelRequest(
  messages: [
    Message(
      role: Role.user,
      content: [
        CustomPart(
          custom: {
            'futurePart': {'value': 42},
          },
        ),
      ],
    ),
  ],
);

void main() {
  group('a request part the plugin cannot send', () {
    late List<Map<String, dynamic>> captured;
    late Model model;

    setUp(() {
      captured = [];
      model =
          WirePlugin(captured).resolve(.model, 'gemini-flash-latest') as Model;
    });

    final invalidArgument = throwsA(
      isA<GenkitException>()
          .having((e) => e.status, 'status', StatusCode.invalidArgument)
          .having((e) => e.message, 'message', contains('custom')),
    );

    test('fails with INVALID_ARGUMENT, not INTERNAL', () async {
      await expectLater(model(_requestWithCustomPart()), invalidArgument);
      expect(captured, isEmpty);
    });

    test('fails with INVALID_ARGUMENT when streaming', () async {
      await expectLater(
        model(_requestWithCustomPart(), onChunk: (_) {}),
        invalidArgument,
      );
      expect(captured, isEmpty);
    });

    test('fails with INVALID_ARGUMENT in a system message', () async {
      final request = ModelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [
              CustomPart(
                custom: {
                  'futurePart': {'value': 42},
                },
              ),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
        ],
      );
      await expectLater(model(request), invalidArgument);
      expect(captured, isEmpty);
    });
  });
}
