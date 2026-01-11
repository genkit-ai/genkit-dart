import 'dart:async';
import 'package:genkit/genkit.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:test/test.dart';

void main() {
  group('Bidi Flow', () {
    test('defineBidiFlow should create a bidi action', () async {
      final genkit = Genkit(plugins: []);

      final flow = genkit.defineBidiFlow(
        name: 'chatFlow',
        inputType: StringType,
        outputType: StringType,
        streamType: StringType,
        initType: VoidType,
        fn: (inputStream, context) async {
          await for (final chunk in inputStream) {
            context.sendChunk('echo $chunk');
          }
          return 'done';
        },
      );

      final controller = StreamController<String>();
      final session = flow.streamBidi(inputStream: controller.stream);
      controller.add('1');
      controller.add('2');
      controller.close();

      final chunks = await session.toList();
      expect(chunks, ['echo 1', 'echo 2']);
      expect(await session.onResult, 'done');
    });

    test('defineBidiFlow should create a bidi action', () async {
      final genkit = Genkit(plugins: []);

      final flow = genkit.defineBidiFlow(
        name: 'chatFlow',
        inputType: StringType,
        outputType: StringType,
        streamType: StringType,
        initType: VoidType,
        fn: (inputStream, context) async {
          await for (final chunk in inputStream) {
            context.sendChunk('echo $chunk');
          }
          return 'done';
        },
      );

      final session = flow.streamBidi();
      session.send('1');
      session.send('2');
      session.close();

      final chunks = await session.toList();
      expect(chunks, ['echo 1', 'echo 2']);
      expect(await session.onResult, 'done');
    });

    test('defineBidiFlow with init data', () async {
      final genkit = Genkit(plugins: []);

      final flow = genkit.defineBidiFlow(
        name: 'chatFlowInit',
        inputType: StringType,
        outputType: StringType,
        streamType: StringType,
        initType: MapType,
        fn: (inputStream, context) async {
          final prefix = context.init?['prefix'] ?? '';
          await for (final chunk in inputStream) {
            context.sendChunk('$prefix$chunk');
          }
          return 'done';
        },
      );

      final controller = StreamController<String>();
      final session = flow.streamBidi(
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
