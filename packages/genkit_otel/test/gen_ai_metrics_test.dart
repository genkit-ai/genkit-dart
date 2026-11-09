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

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/telemetry.dart';
import 'package:genkit_otel/src/genai/gen_ai_attributes.dart';
import 'package:genkit_otel/src/genai_instrumentation.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'genai-metrics-test',
    );
  });

  setUp(() => harness.clear());

  // The meter provider is shared across the whole test process and histograms
  // are cumulative, so tests filter data points by a unique request model
  // rather than relying on a metric being wholly absent.
  List<otel.MetricPoint<dynamic>> pointsForModel(String metricName, String m) {
    final metric = harness.metrics.findMetricByName(metricName);
    if (metric == null) return const [];
    return metric.points
        .where((p) => p.attributes.getString(GenAiAttr.requestModel) == m)
        .toList();
  }

  ModelResponse response({GenerationUsage? usage}) {
    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [TextPart(text: 'ok')],
      ),
      usage: usage,
    );
  }

  Future<void> runModel(
    GenAiInstrumentation instr,
    String name,
    Future<ModelResponse> Function() fn,
  ) {
    return instr.runInNewSpan<ModelResponse>(
      SpanMetadata(name: name, actionType: 'model'),
      ([span]) => fn(),
    );
  }

  test('records token usage split by input/output', () async {
    final instr = GenAiInstrumentation();
    await runModel(
      instr,
      'googleai/metrics-usage',
      () async =>
          response(usage: GenerationUsage(inputTokens: 12, outputTokens: 34)),
    );
    await harness.collectMetrics();

    final points = pointsForModel(GenAiMetric.tokenUsage, 'metrics-usage');
    final input =
        points
                .firstWhere(
                  (p) => p.attributes.getString(GenAiAttr.tokenType) == 'input',
                )
                .value
            as otel.HistogramValue;
    final output =
        points
                .firstWhere(
                  (p) =>
                      p.attributes.getString(GenAiAttr.tokenType) == 'output',
                )
                .value
            as otel.HistogramValue;
    expect(input.sum, 12);
    expect(output.sum, 34);

    // Low-cardinality shared attributes are present on each point.
    final any = points.first;
    expect(any.attributes.getString(GenAiAttr.operationName), 'chat');
    expect(any.attributes.getString(GenAiAttr.providerName), 'gcp.gemini');
  });

  test('records operation duration on success', () async {
    final instr = GenAiInstrumentation();
    await runModel(
      instr,
      'openai/metrics-duration',
      () async => response(usage: GenerationUsage(inputTokens: 1)),
    );
    await harness.collectMetrics();

    final metric = harness.metrics.findMetricByName(
      GenAiMetric.operationDuration,
    );
    expect(metric!.unit, 's');
    final points = pointsForModel(
      GenAiMetric.operationDuration,
      'metrics-duration',
    );
    expect(points, hasLength(1));
    expect(points.first.attributes.getString(GenAiAttr.providerName), 'openai');
    expect(points.first.attributes.getString(GenAiAttr.errorType), isNull);
  });

  test('records duration with error.type on failure', () async {
    final instr = GenAiInstrumentation();
    await expectLater(
      runModel(
        instr,
        'googleai/metrics-error',
        () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );
    await harness.collectMetrics();

    final duration = pointsForModel(
      GenAiMetric.operationDuration,
      'metrics-error',
    );
    expect(duration, hasLength(1));
    expect(
      duration.first.attributes.getString(GenAiAttr.errorType),
      'StateError',
    );

    // A failed call with no usage records no token-usage points.
    expect(pointsForModel(GenAiMetric.tokenUsage, 'metrics-error'), isEmpty);
  });

  test('emitMetrics: false records no metrics', () async {
    final instr = GenAiInstrumentation(emitMetrics: false);
    await runModel(
      instr,
      'googleai/metrics-disabled',
      () async => response(usage: GenerationUsage(inputTokens: 5)),
    );
    await harness.collectMetrics();

    expect(pointsForModel(GenAiMetric.tokenUsage, 'metrics-disabled'), isEmpty);
    expect(
      pointsForModel(GenAiMetric.operationDuration, 'metrics-disabled'),
      isEmpty,
    );
  });
}
