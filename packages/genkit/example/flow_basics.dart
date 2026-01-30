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
import 'dart:convert';
import 'dart:math';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

part 'flow_basics.g.dart';

@Schematic()
abstract class $Subject {
  String get subject;
}

@Schematic()
abstract class $Count {
  int get count;
}

void main() async {
  configureCollectorExporter();

  final ai = Genkit();

  // To run this flow;
  // genkit flow:run basic "\"hello\""
  final basic = ai.defineFlow(
    name: 'basic',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (String subject, _) async {
      final foo = await ai.run('call-llm', () async {
        return 'subject: $subject';
      });

      return await ai.run('call-llm1', () async {
        return 'foo: $foo';
      });
    },
  );

  ai.defineFlow(
    name: 'parent',
    outputSchema: stringSchema(),
    fn: (_, _) async {
      // Dart flow objects are callable, but we need to handle the input.
      // basic expects a string.
      final result = await basic('foo');
      return jsonEncode(result);
    },
  );

  ai.defineFlow(
    name: 'withInputSchema',
    inputSchema: Subject.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      final foo = await ai.run('call-llm', () async {
        return 'subject: ${input.subject}';
      });

      return await ai.run('call-llm1', () async {
        return 'foo: $foo';
      });
    },
  );

  ai.defineFlow(
    name: 'withListInputSchema',
    inputSchema: listSchema(Subject.$schema),
    outputSchema: stringSchema(),
    fn: (input, _) async {
      final foo = await ai.run('call-llm', () async {
        return 'subjects: ${input.map((e) => e.subject).join(', ')}';
      });

      return await ai.run('call-llm1', () async {
        return 'foo: $foo';
      });
    },
  );

  ai.defineFlow(
    name: 'withContext',
    inputSchema: Subject.$schema,
    outputSchema: stringSchema(),
    fn: (input, context) async {
      return 'subject: ${input.subject}, context: ${jsonEncode(context.context)}';
    },
  );

  // genkit flow:run streamy 5 -s
  ai.defineFlow(
    name: 'streamy',
    inputSchema: intSchema(),
    outputSchema: stringSchema(),
    streamSchema: Count.$schema,
    fn: (count, context) async {
      var i = 0;
      for (; i < count; i++) {
        await Future.delayed(Duration(seconds: 1));
        context.sendChunk(Count(count: i));
      }
      return 'done: $count, streamed: $i times';
    },
  );

  // genkit flow:run streamyThrowy 5 -s
  ai.defineFlow(
    name: 'streamyThrowy',
    inputSchema: intSchema(),
    outputSchema: stringSchema(),
    streamSchema: Count.$schema,
    fn: (count, context) async {
      var i = 0;
      for (; i < count; i++) {
        if (i == 3) {
          throw Exception('whoops');
        }
        await Future.delayed(Duration(seconds: 1));
        context.sendChunk(Count(count: i));
      }
      return 'done: $count, streamed: $i times';
    },
  );

  // To run this flow;
  // genkit flow:run throwy "\"hello\""
  ai.defineFlow(
    name: 'throwy',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (subject, _) async {
      final foo = await ai.run('call-llm', () async {
        return 'subject: $subject';
      });
      if (subject.isNotEmpty) {
        throw Exception(subject);
      }
      return await ai.run('call-llm', () async {
        return 'foo: $foo';
      });
    },
  );

  // To run this flow;
  // genkit flow:run throwy2 "\"hello\""
  ai.defineFlow(
    name: 'throwy2',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (subject, _) async {
      final foo = await ai.run('call-llm', () async {
        if (subject.isNotEmpty) {
          throw Exception(subject);
        }
        return 'subject: $subject';
      });
      return await ai.run('call-llm', () async {
        return 'foo: $foo';
      });
    },
  );

  ai.defineFlow(
    name: 'flowMultiStepCaughtError',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (input, _) async {
      var i = 1;

      final result1 = await ai.run('step1', () async {
        return '$input ${i++},';
      });

      var result2 = '';
      try {
        result2 = await ai.run('step2', () async {
          if (result1.isNotEmpty) {
            throw Exception('Got an error!');
          }
          return '$result1 ${i++},';
        });
      } catch (e) {
        // Ignored
      }

      return await ai.run('step3', () async {
        return '$result2 ${i++}';
      });
    },
  );

  ai.defineFlow(
    name: 'multiSteps',
    inputSchema: stringSchema(),
    outputSchema: intSchema(),
    fn: (input, _) async {
      final out1 = await ai.run('step1', () async {
        return 'Hello, $input! step 1';
      });
      await ai.run('step1', () async {
        return 'Hello2222, $input! step 1';
      });
      final out2 = await ai.run('step2', () async {
        return '$out1 Faf ';
      });
      final out3 = await ai.run('step3-array', () async {
        return [out2, out2];
      });
      await ai.run('step4-num', () async {
        return out3.join('-()-');
      });
      return 42;
    },
  );

  ai.defineFlow(
    name: 'largeSteps',
    outputSchema: stringSchema(),
    fn: (_, _) async {
      await ai.run('large-step1', () async {
        return generateString(100000);
      });
      await ai.run('large-step2', () async {
        return generateString(800000);
      });
      await ai.run('large-step3', () async {
        return generateString(900000);
      });
      await ai.run('large-step4', () async {
        return generateString(999000);
      });
      return 'something...';
    },
  );
}

const loremIpsum = [
  'lorem',
  'ipsum',
  'dolor',
  'sit',
  'amet',
  'consectetur',
  'adipiscing',
  'elit',
];

String generateString(int length) {
  var str = '';
  while (str.length < length) {
    str += '${loremIpsum[Random().nextInt(loremIpsum.length)]} ';
  }
  return str.substring(0, length);
}
