import 'package:test/test.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:genkit/src/core/action.dart';
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:genkit/schema.dart';
import 'test_util.dart';

part 'action_test.schema.g.dart';

@GenkitSchema()
abstract class TestInputSchema {
  String get name;
}

@GenkitSchema()
abstract class TestOutputSchema {
  String get greeting;
}

void main() {
  final exporter = TextExporter();
  final processor = sdk.SimpleSpanProcessor(exporter);
  final provider = sdk.TracerProviderBase(processors: [processor]);
  api.registerGlobalTracerProvider(provider);

  group('Action', () {
    setUp(() {
      exporter.reset();
    });

    tearDown(() {
      processor.forceFlush();
    });

    test('should start and end a span when run', () async {
      final action = Action(
        name: 'testAction',
        actionType: 'test',
        fn: (input, context) async => 'output',
      );

      await action.run('input', null);
      processor.forceFlush();

      expect(exporter.spans.length, 1);
      expect(exporter.spans[0].name, 'testAction');
    });

    test('should set attributes on the span', () async {
      final action = Action(
        name: 'testAction',
        actionType: 'test',
        fn: (input, context) async => 'output',
      );

      await action.run('input', null);
      processor.forceFlush();

      expect(exporter.spans.length, 1);
      final span = exporter.spans[0];
      expect(span.attributes.get('genkit:type'), 'test');
      expect(span.attributes.get('genkit:name'), 'testAction');
      expect(span.attributes.get('genkit:input'), '"input"');
      expect(span.attributes.get('genkit:output'), '"output"');
    });

    test('should run a basic action', () async {
      final action = Action(
        name: 'testAction',
        actionType: 'test',
        fn: (String input, context) async => 'output',
      );

      final result = await action.run('input', null);
      expect(result, 'output');
    });

    test('should run an action with schema', () async {
      final action = Action(
        name: 'testAction',
        actionType: 'test',
        inputType: TestInputType,
        outputType: TestOutputType,
        fn: (TestInput input, context) async {
          return TestOutputType.parse({'greeting': 'Hello ${input.name}'});
        },
      );

      final result = await action.run(
        TestInputType.parse({'name': 'world'}),
        null,
      );
      expect(result.greeting, 'Hello world');
    });

    test('should set attributes on the span with schema', () async {
      final action = Action(
        name: 'testAction',
        actionType: 'test',
        inputType: TestInputType,
        outputType: TestOutputType,
        fn: (TestInput input, context) async {
          return TestOutputType.parse({'greeting': 'Hello ${input.name}'});
        },
      );

      await action.run(TestInputType.parse({'name': 'world'}), null);
      processor.forceFlush();

      expect(exporter.spans.length, 1);
      final span = exporter.spans[0];
      expect(span.attributes.get('genkit:type'), 'test');
      expect(span.attributes.get('genkit:name'), 'testAction');
      expect(span.attributes.get('genkit:input'), '{"name":"world"}');
      expect(span.attributes.get('genkit:output'), '{"greeting":"Hello world"}');
    });

    test('should stream an action', () async {
      final action = Action<String, String, String>(
        name: 'testAction',
        actionType: 'test',
        fn: (input, context) async {
          context.sendChunk('chunk1');
          context.sendChunk('chunk2');
          return 'output';
        },
      );

      final stream = action.stream('input', null);
      final chunks = await stream.toList();
      final result = await stream.onResult;

      expect(chunks, ['chunk1', 'chunk2']);
      expect(result, 'output');
    });
  });
}
