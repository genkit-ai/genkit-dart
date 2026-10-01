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

// The generated open enums (`FinishReason`, `Role`, ...) are extension types
// over `String` with `static const` values, so they can be used as `case`
// patterns. These tests fail to compile if a value stops being a constant.

String describe(FinishReason reason) => switch (reason) {
  FinishReason.stop => 'done',
  FinishReason.length => 'truncated',
  FinishReason.blocked || FinishReason.failed => 'error',
  _ => 'other: ${reason.value}',
};

void main() {
  group('open enums', () {
    test('values work as switch cases', () {
      expect(describe(.stop), 'done');
      expect(describe(.length), 'truncated');
      expect(describe(.blocked), 'error');
      // Values a newer server sends that this SDK does not know yet.
      expect(describe(FinishReason('paused')), 'other: paused');
    });

    test('values are canonicalized constants', () {
      expect(identical(FinishReason.stop, const FinishReason('stop')), isTrue);
      expect(Role.model, Role('model'));
    });

    test('parsed values match the constants', () {
      final res = ModelResponse.fromJson({
        'finishReason': 'stop',
        'message': {
          'role': 'model',
          'content': [
            {'text': 'hi'},
          ],
        },
      });
      final kind = switch (res.message!.role) {
        Role.model => 'model',
        Role.user => 'user',
        _ => 'other',
      };
      expect(kind, 'model');
      expect(res.finishReason, FinishReason.stop);
    });

    test('ToolChoice and EvalStatusEnum are constant too', () {
      const choices = {ToolChoice.auto, ToolChoice.none, ToolChoice.required};
      expect(choices, hasLength(3));
      const status = EvalStatusEnum.PASS;
      expect(status.value, 'PASS');
    });
  });
}
