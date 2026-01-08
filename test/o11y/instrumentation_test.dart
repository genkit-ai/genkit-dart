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

import 'package:genkit/genkit.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:test/test.dart';
import '../test_util.dart';

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
          return await childFlow(input);
        },
      );

      await parentFlow('World');

      // Force flush to ensure spans are exported
      processor.forceFlush();

      final spans = exporter.spans;
      expect(spans.length, 2);

      final parentSpan = spans.firstWhere((s) => s.name == 'parentFlow');
      final childSpan = spans.firstWhere((s) => s.name == 'childFlow');

      // Verify the parent-child relationship
      expect(childSpan.parentSpanId, parentSpan.spanContext.spanId);
      expect(parentSpan.parentSpanId.isValid, isFalse);
    });
  });
}
