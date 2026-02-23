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

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('Bidi Flow', () {
    test('defineBidiFlow should create a bidi action', () async {
      final genkit = Genkit(plugins: []);

      final flow = genkit.defineBidiFlow(
        name: 'chatFlow',
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
        initSchema: .voidSchema(),
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
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
        initSchema: .voidSchema(),
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
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
        initSchema: .map(.string(), .string()),
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
