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
import 'package:genkit/src/exception.dart';
import 'package:test/test.dart';

void main() {
  group('Bidi Action', () {
    test('streamBidi with input stream', () async {
      final action = Action<String, String, String, void>(
        name: 'chat',
        actionType: .custom,
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
        actionType: .custom,
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
        actionType: .custom,
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
        actionType: .custom,
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
        actionType: .custom,
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

    group('close() returns when the action never listens to its input', () {
      test('after the action fails', () async {
        final action = Action<String, String, String, void>(
          name: 'failsBeforeListening',
          actionType: .custom,
          fn: (input, context) async {
            throw GenkitException('connect failed');
          },
        );

        final session = action.streamBidi();
        await expectLater(session.onResult, throwsA(isA<GenkitException>()));

        await session.close().timeout(const Duration(seconds: 5));
        expect(session.isClosed, isTrue);
      });

      test('when called while the action is still starting', () async {
        final started = Completer<void>();
        final fail = Completer<void>();
        final action = Action<String, String, String, void>(
          name: 'failsLater',
          actionType: .custom,
          fn: (input, context) async {
            started.complete();
            await fail.future;
            throw GenkitException('connect failed');
          },
        );

        final session = action.streamBidi();
        final result = expectLater(
          session.onResult,
          throwsA(isA<GenkitException>()),
        );
        await started.future;

        final closed = session.close();
        fail.complete();

        await closed.timeout(const Duration(seconds: 5));
        await result;
      });

      test('after the action returns without reading its input', () async {
        final action = Action<String, String, String, void>(
          name: 'ignoresInput',
          actionType: .custom,
          fn: (input, context) async => 'done',
        );

        final session = action.streamBidi();
        expect(await session.onResult, 'done');

        await session.close().timeout(const Duration(seconds: 5));
      });
    });
  });
}
