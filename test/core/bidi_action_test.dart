import 'dart:async';
import 'package:genkit/src/core/action.dart';
import 'package:test/test.dart';

void main() {
  group('Bidi Action', () {
    test('streamBidi with input stream', () async {
      final action = Action<String, String, String, void>(
        name: 'chat',
        actionType: 'custom',
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
        actionType: 'custom',
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
        actionType: 'custom',
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
        actionType: 'custom',
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
        actionType: 'custom',
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
