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

import 'dart:convert';

import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/o11y/direct_http_instrumentation.dart';
import 'package:genkit/src/o11y/instrumentation.dart'
    show configureInstrumentation, resetInstrumentation;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import '../test_util.dart';

part 'action_test.g.dart';

@Schema()
abstract class $TestInput {
  String get name;
}

@Schema()
abstract class $TestOutput {
  String get greeting;
}

void main() {
  // The custom direct-HTTP tracer records finished spans into this sink.
  final sink = RecordingSpanSink();

  group('Action', () {
    setUp(() {
      sink.reset();
      // Actions rely on a configured instrumentation to emit spans.
      configureInstrumentation(DirectHttpInstrumentation(sink));
    });

    tearDown(resetInstrumentation);

    test('should start and end a span when run', () async {
      final action = Action(
        name: 'testAction',
        actionType: ActionType('test'),
        fn: (input, context) async => 'output',
      );

      await action('input');

      expect(sink.finished.length, 1);
      expect(sink.finished[0].name, 'testAction');
    });

    test('should set attributes on the span', () async {
      final action = Action(
        name: 'testAction',
        actionType: ActionType('test'),
        fn: (input, context) async => 'output',
      );

      await action('input');

      expect(sink.finished.length, 1);
      final span = sink.finished[0];
      expect(span.attributes['genkit:type'], 'test');
      expect(span.attributes['genkit:name'], 'testAction');
      expect(span.attributes['genkit:input'], '"input"');
      expect(span.attributes['genkit:output'], '"output"');
    });

    test('records execution context on the span, redacting secrets', () async {
      final action = Action(
        name: 'testAction',
        actionType: ActionType('test'),
        fn: (input, context) async => 'output',
      );

      await action.run(
        'input',
        context: {'auth': 'secret-token', 'secrets': 'shh', 'uid': 'u123'},
      );

      expect(sink.finished.length, 1);
      final raw = sink.finished[0].attributes['genkit:metadata:context'];
      expect(raw, isA<String>());
      final context = jsonDecode(raw as String) as Map<String, dynamic>;
      expect(context['auth'], '<redacted>');
      expect(context['secrets'], '<redacted>');
      expect(context['uid'], 'u123');
    });

    test('does not record context metadata when no context is given', () async {
      final action = Action(
        name: 'testAction',
        actionType: ActionType('test'),
        fn: (input, context) async => 'output',
      );

      await action('input');

      expect(sink.finished.length, 1);
      expect(
        sink.finished[0].attributes.containsKey('genkit:metadata:context'),
        isFalse,
      );
    });

    test('should run a basic action', () async {
      final action = Action(
        name: 'testAction',
        actionType: ActionType('test'),
        fn: (String? input, context) async => 'output',
      );

      final result = await action('input');
      expect(result, 'output');
    });

    test('should run an action with schema', () async {
      final action = Action(
        name: 'testAction',
        actionType: ActionType('test'),
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
        actionType: ActionType('test'),
        inputSchema: TestInput.$schema,
        outputSchema: TestOutput.$schema,
        fn: (TestInput? input, context) async {
          return TestOutput.$schema.parse({'greeting': 'Hello ${input!.name}'});
        },
      );

      await action(TestInput.$schema.parse({'name': 'world'}));

      expect(sink.finished.length, 1);
      final span = sink.finished[0];
      expect(span.attributes['genkit:type'], 'test');
      expect(span.attributes['genkit:name'], 'testAction');
      expect(span.attributes['genkit:input'], '{"name":"world"}');
      expect(span.attributes['genkit:output'], '{"greeting":"Hello world"}');
    });

    test('should stream an action', () async {
      final action = Action<String, String, String, void>(
        name: 'testAction',
        actionType: ActionType('test'),
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
        actionType: ActionType('test'),
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
        actionType: ActionType('test'),
        fn: (input, ctx) async {
          return ctx.context!['value'];
        },
      );

      final result = await action('input', context: {'value': 'foo'});
      expect(result, 'foo');
    });

    test('provided context should be available in a nested action', () async {
      final innerAction = Action(
        name: 'innerAction',
        actionType: ActionType('test'),
        fn: (input, ctx) async {
          return ctx.context!['value'];
        },
      );
      final outerAction = Action(
        name: 'outerAction',
        actionType: ActionType('test'),
        fn: (input, ctx) async {
          return await innerAction(input);
        },
      );

      final result = await outerAction('input', context: {'value': 'baz'});
      expect(result, 'baz');
    });
  });
}
