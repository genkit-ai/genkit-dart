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

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:genkit/genkit.dart';
import 'package:test/test.dart';
import '../test_util.dart';

void main() {
  group('Instrumentation with nested spans', () {
    late TracerProvider provider;
    late TextExporter exporter;
    late SimpleSpanProcessor processor;
    late Genkit genkit;

    setUp(() async {
      // Reset OTel for each test
      await OTel.reset();

      // Set up an in-memory exporter to capture spans
      exporter = TextExporter();
      processor = SimpleSpanProcessor(exporter);

      OTelFactory.otelFactory = otelSDKFactoryFactoryFunction(
        apiEndpoint: 'http://localhost:4317',
        apiServiceName: 'genkit-dart-test',
        apiServiceVersion: '0.12.0',
      );

      provider = OTel.tracerProvider();
      provider.addSpanProcessor(processor);

      genkit = Genkit();
    });

    tearDown(() async {
      await provider.shutdown();
      await OTel.reset();
    });

    test(
      'should create nested spans with correct parent-child relationship',
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
            return await childFlow(input);
          },
        );

        await parentFlow('World');

        // Force flush to ensure spans are exported
        await processor.forceFlush();

        final spans = exporter.spans;
        expect(spans.length, 2);

        final parentSpan = spans.firstWhere((s) => s.name == 'parentFlow');
        final childSpan = spans.firstWhere((s) => s.name == 'childFlow');

        // Verify the parent-child relationship
        expect(
          childSpan.spanContext.parentSpanId,
          parentSpan.spanContext.spanId,
        );
        expect(parentSpan.spanContext.parentSpanId!.isValid, isFalse);
      },
    );
  });
}
