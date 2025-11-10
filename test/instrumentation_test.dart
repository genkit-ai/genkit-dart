import 'package:genkit/genkit.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:test/test.dart';
import 'test_util.dart';

void main() {
  group('Instrumentation with nested spans', () {
    late sdk.TracerProviderBase provider;
    late TextExporter exporter;
    late sdk.SimpleSpanProcessor processor;
    late Genkit genkit;

    setUp(() {
      // Set up an in-memory exporter to capture spans
      exporter = TextExporter();
      processor = sdk.SimpleSpanProcessor(exporter);
      provider = sdk.TracerProviderBase(
        processors: [processor],
      );
      api.registerGlobalTracerProvider(provider);

      genkit = Genkit();
    });

    tearDown(() {
      provider.shutdown();
    });

    test('should create nested spans with correct parent-child relationship',
        () async {
      final childFlow = genkit.defineFlow(
        name: 'childFlow',
        fn: (String input, context) async {
          return 'Hello, $input!';
        },
      );

      final parentFlow = genkit.defineFlow(
        name: 'parentFlow',
        fn: (String input, context) async {
          return await childFlow.run(input, null);
        },
      );

      await parentFlow.run('World', null);

      // Force flush to ensure spans are exported
      processor.forceFlush();

      final spans = exporter.spans;
      expect(spans.length, 2);

      final parentSpan = spans.firstWhere((s) => s.name == 'parentFlow');
      final childSpan = spans.firstWhere((s) => s.name == 'childFlow');

      // Verify the parent-child relationship
      expect(childSpan.parentSpanId, parentSpan.spanContext.spanId);
      expect(parentSpan.parentSpanId?.isValid, isFalse);
    });
  });
}
