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

import 'dart:async';
import 'package:genkit/src/core/action.dart';
import 'package:test/test.dart';

void main() {
  group('Bidi Action', () {
    test('streamBidi with input stream', () async {
      final action = Action<String, String, String, void>(
        name: 'chat',
        actionType: ActionType.custom,
        fn: (input, context) async {
          await for (final chunk in context.inputStream!) {
            context.sendChunk('echo $chunk');
          }
          return 'done';
        },
      );

      final controller = StreamController<String>();
      final session = action.streamBidi(inputStream: controller.stream);
      controller.add('1');
      controller.add('2');
      controller.close();
      session.close();

      final chunks = await session.toList();
      expect(chunks, ['echo 1', 'echo 2']);
      expect(await session.onResult, 'done');
    });

    test('streamBidi ergonomic (send)', () async {
      final action = Action<String, String, String, void>(
        name: 'chat',
        actionType: ActionType.custom,
        fn: (input, context) async {
          await for (final chunk in context.inputStream!) {
            context.sendChunk('echo $chunk');
          }
          return 'done';
        },
      );

      final session = action.streamBidi();
      session.send('1');
      session.send('2');
      session.close();

      final chunks = await session.toList();
      expect(chunks, ['echo 1', 'echo 2']);
      expect(await session.onResult, 'done');
    });

    test('can run bidi action with unary input', () async {
      final action = Action<String, String, String, void>(
        name: 'chat',
        actionType: ActionType.custom,
        fn: (input, context) async {
          await for (final chunk in context.inputStream!) {
            context.sendChunk('echo $chunk');
          }
          return 'done';
        },
      );

      final session = action.stream('1');
      final chunks = await session.toList();
      expect(chunks, ['echo 1']);
      expect(await session.onResult, 'done');
    });

    test('streamBidi pull (generator)', () async {
      final action = Action<String, String, String, void>(
        name: 'chat',
        actionType: ActionType.custom,
        fn: (input, context) async {
          await for (final chunk in context.inputStream!) {
            context.sendChunk('echo $chunk');
          }
          return 'done';
        },
      );

      final inputController = StreamController<String>();
      inputController.add('1');
      inputController.add('2');
      inputController.close();

      final session = action.streamBidi(inputStream: inputController.stream);

      final chunks = await session.toList();
      expect(chunks, ['echo 1', 'echo 2']);
      expect(await session.onResult, 'done');
    });

    test('bidi action receives init data', () async {
      final action = Action<String, String, String, Map<String, dynamic>>(
        name: 'chatWithInit',
        actionType: ActionType.custom,
        fn: (input, context) async {
          final prefix = context.init?['prefix'] ?? '';
          await for (final chunk in context.inputStream!) {
            context.sendChunk('$prefix$chunk');
          }
          return 'done';
        },
      );

      final controller = StreamController<String>();
      final session = action.streamBidi(
        inputStream: controller.stream,
        init: {'prefix': '>> '},
      );
      controller.add('1');
      controller.add('2');
      controller.close();
      session.close();

      final chunks = await session.toList();
      expect(chunks, ['>> 1', '>> 2']);
      expect(await session.onResult, 'done');
    });
  });
}
