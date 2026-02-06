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

import 'package:genkit/src/core/action.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import '../test_util.dart';

part 'action_test.g.dart';

@Schematic()
abstract class $TestInput {
  String get name;
}

@Schematic()
abstract class $TestOutput {
  String get greeting;
}

void main() {
  final exporter = TextExporter();
  final processor = sdk.SimpleSpanProcessor(exporter);
  final provider = sdk.TracerProviderBase(processors: [processor]);
  api.registerGlobalTracerProvider(provider);
  const actionType = ActionType.fromString('test');
  group('Action', () {
    setUp(exporter.reset);

    tearDown(processor.forceFlush);

    test('should start and end a span when run', () async {
      final action = Action(
        name: 'testAction',
        actionType: actionType,
        fn: (input, context) async => 'output',
      );

      await action('input');
      processor.forceFlush();

      expect(exporter.spans.length, 1);
      expect(exporter.spans[0].name, 'testAction');
    });

    test('should set attributes on the span', () async {
      final action = Action(
        name: 'testAction',
        actionType: actionType,
        fn: (input, context) async => 'output',
      );

      await action('input');
      processor.forceFlush();

      expect(exporter.spans.length, 1);
      final span = exporter.spans[0];
      expect(span.attributes.get('genkit:type'), actionType);
      expect(span.attributes.get('genkit:name'), 'testAction');
      expect(span.attributes.get('genkit:input'), '"input"');
      expect(span.attributes.get('genkit:output'), '"output"');
    });

    test('should run a basic action', () async {
      final action = Action(
        name: 'testAction',
        actionType: actionType,
        fn: (String? input, context) async => 'output',
      );

      final result = await action('input');
      expect(result, 'output');
    });

    test('should run an action with schema', () async {
      final action = Action(
        name: 'testAction',
        actionType: actionType,
        inputSchema: TestInput.$schema,
        outputSchema: TestOutput.$schema,
        fn: (TestInput? input, context) async {
          return TestOutput.$schema.parse({'greeting': 'Hello ${input!.name}'});
        },
      );

      final result = await action(TestInput.$schema.parse({'name': 'world'}));
      expect(result.greeting, 'Hello world');
    });

    test('should set attributes on the span with schema', () async {
      final action = Action(
        name: 'testAction',
        actionType: actionType,
        inputSchema: TestInput.$schema,
        outputSchema: TestOutput.$schema,
        fn: (TestInput? input, context) async {
          return TestOutput.$schema.parse({'greeting': 'Hello ${input!.name}'});
        },
      );

      await action(TestInput.$schema.parse({'name': 'world'}));
      processor.forceFlush();

      expect(exporter.spans.length, 1);
      final span = exporter.spans[0];
      expect(span.attributes.get('genkit:type'), actionType);
      expect(span.attributes.get('genkit:name'), 'testAction');
      expect(span.attributes.get('genkit:input'), '{"name":"world"}');
      expect(
        span.attributes.get('genkit:output'),
        '{"greeting":"Hello world"}',
      );
    });

    test('should stream an action', () async {
      final action = Action<String, String, String, void>(
        name: 'testAction',
        actionType: actionType,
        fn: (input, context) async {
          context.sendChunk('chunk1');
          context.sendChunk('chunk2');
          return 'output';
        },
      );

      final stream = action.stream('input');
      final chunks = await stream.toList();
      final result = await stream.onResult;

      expect(chunks, ['chunk1', 'chunk2']);
      expect(result, 'output');
    });

    test('should run an action with telemetry', () async {
      final action = Action(
        name: 'testAction',
        actionType: actionType,
        fn: (String? input, context) async => 'output',
      );

      final result = await action.run('input');
      expect(result.result, 'output');
      expect(result.traceId, isA<String>());
      expect(result.spanId, isA<String>());
    });

    test('should run an action with provided context', () async {
      final action = Action(
        name: 'testAction',
        actionType: actionType,
        fn: (input, ctx) async {
          return ctx.context!['value'] as Object?;
        },
      );

      final result = await action('input', context: {'value': 'foo'});
      expect(result, 'foo');
    });

    test('provided context should be available in a nested action', () async {
      final innerAction = Action(
        name: 'innerAction',
        actionType: actionType,
        fn: (input, ctx) async {
          return ctx.context!['value'];
        },
      );
      final outerAction = Action(
        name: 'outerAction',
        actionType: actionType,
        fn: (input, ctx) async {
          return await innerAction(input);
        },
      );

      final result = await outerAction('input', context: {'value': 'baz'});
      expect(result, 'baz');
    });
  });
}
