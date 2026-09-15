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

/// Reads a single-value attribute off a recorded span by key, or null.
Object? attr(otel.Span span, String key) {
  for (final a in span.attributes.toList()) {
    if (a.key == key) return a.value;
  }
  return null;
}

void main() {
  late TestHarness harness;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(serviceName: 'genai-test');
  });

  setUp(() => harness.clear());

  ModelRequest modelRequest({
    Map<String, dynamic>? config,
    List<Message>? messages,
    OutputConfig? output,
  }) {
    return ModelRequest(
      messages:
          messages ??
          [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hi')],
            ),
          ],
      config: config,
      output: output,
    );
  }

  ModelResponse modelResponse({
    FinishReason? finishReason,
    Message? message,
    GenerationUsage? usage,
  }) {
    return ModelResponse(
      finishReason: finishReason ?? FinishReason.stop,
      message:
          message ??
          Message(
            role: Role.model,
            content: [TextPart(text: 'ok')],
          ),
      usage: usage,
    );
  }

  Future<O> runModel<O>(
    GenAiInstrumentation instr,
    String name,
    Object? input,
    Future<O> Function([SpanContext? span]) fn,
  ) {
    return instr.runInNewSpan(
      SpanMetadata(name: name, actionType: 'model', input: input),
      fn,
    );
  }

  test('emits a chat span with request/provider/model attributes', () async {
    final instr = GenAiInstrumentation();
    await runModel(
      instr,
      'googleai/gemini-flash-latest',
      modelRequest(
        config: {'temperature': 0.5, 'topK': 40, 'maxOutputTokens': 100},
      ),
      ([span]) async => modelResponse(),
    );

    final span = harness.spans.findSpanByName('chat gemini-flash-latest');
    expect(span, isNotNull);
    expect(attr(span!, GenAiAttr.operationName), 'chat');
    expect(attr(span, GenAiAttr.providerName), 'gcp.gemini');
    expect(attr(span, GenAiAttr.requestModel), 'gemini-flash-latest');
    expect(attr(span, GenAiAttr.requestTemperature), 0.5);
    expect(attr(span, GenAiAttr.requestTopK), 40);
    expect(attr(span, GenAiAttr.requestMaxTokens), 100);
  });

  test('records usage and finish reason from the response', () async {
    final instr = GenAiInstrumentation();
    await runModel(
      instr,
      'openai/gpt-x',
      modelRequest(),
      ([span]) async => modelResponse(
        finishReason: FinishReason.length,
        usage: GenerationUsage(inputTokens: 10, outputTokens: 20),
      ),
    );

    final span = harness.spans.findSpanByName('chat gpt-x')!;
    expect(attr(span, GenAiAttr.providerName), 'openai');
    expect(attr(span, GenAiAttr.usageInputTokens), 10);
    expect(attr(span, GenAiAttr.usageOutputTokens), 20);
    expect(attr(span, GenAiAttr.responseFinishReasons), ['length']);
  });

  test(
    'reports tool_calls when the response contains a tool request',
    () async {
      final instr = GenAiInstrumentation();
      await runModel(
        instr,
        'googleai/gemini-flash-latest',
        modelRequest(),
        ([span]) async => modelResponse(
          message: Message(
            role: Role.model,
            content: [
              ToolRequestPart(
                toolRequest: ToolRequest(name: 'lookup', input: {}),
              ),
            ],
          ),
        ),
      );

      final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
      expect(attr(span, GenAiAttr.responseFinishReasons), ['tool_calls']);
    },
  );

  test('records error status and error.type on throw', () async {
    final instr = GenAiInstrumentation();
    await expectLater(
      runModel<ModelResponse>(
        instr,
        'googleai/gemini-flash-latest',
        modelRequest(),
        ([span]) async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );

    final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    expect(span.status, otel.SpanStatusCode.Error);

    expect(attr(span, GenAiAttr.errorType), 'StateError');
  });

  test('does not capture content by default', () async {
    final instr = GenAiInstrumentation();
    await runModel(
      instr,
      'googleai/gemini-flash-latest',
      modelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'secret')],
          ),
        ],
      ),
      ([span]) async => modelResponse(),
    );

    final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    expect(attr(span, GenAiAttr.inputMessages), isNull);
  });

  test('captures content on the span in span mode', () async {
    final instr = GenAiInstrumentation(
      captureContent: true,
      contentMode: GenAiContentMode.span,
    );
    await runModel(
      instr,
      'googleai/gemini-flash-latest',
      modelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'Be nice')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
      ),
      ([span]) async => modelResponse(),
    );

    final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    final input = attr(span, GenAiAttr.inputMessages);
    expect(input, isA<String>());
    expect(input as String, contains('hello'));
    expect(attr(span, GenAiAttr.systemInstructions), contains('Be nice'));
    expect(attr(span, GenAiAttr.outputMessages), contains('ok'));
  });

  test('emits an operation.details event in event mode', () async {
    final instr = GenAiInstrumentation(captureContent: true);
    await runModel(
      instr,
      'googleai/gemini-flash-latest',
      modelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
      ),
      ([span]) async => modelResponse(),
    );
    await harness.flushLogs();

    final events = harness.logs.records
        .where((r) => r.eventName == genAiOperationDetailsEvent)
        .toList();
    expect(events, isNotEmpty);

    // The content event must NOT put content on the span.
    final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    expect(attr(span, GenAiAttr.inputMessages), isNull);
  });

  test('nests spans (flow -> model) into one trace', () async {
    final instr = GenAiInstrumentation();
    await instr.runInNewSpan(
      const SpanMetadata(name: 'myFlow', actionType: 'flow'),
      ([flowSpan]) async {
        return runModel(
          instr,
          'googleai/gemini-flash-latest',
          modelRequest(),
          ([span]) async => modelResponse(),
        );
      },
    );

    final flow = harness.spans.findSpanByName('myFlow')!;
    final model = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    expect(attr(flow, GenkitAttr.actionType), 'flow');
    expect(
      model.spanContext.traceId.toString(),
      flow.spanContext.traceId.toString(),
    );
  });

  test('emits execute_tool spans only when enabled', () async {
    final off = GenAiInstrumentation();
    await off.runInNewSpan(
      const SpanMetadata(name: 'weather', actionType: 'tool'),
      ([span]) async => 'sunny',
    );
    expect(harness.spans.findSpanByName('execute_tool weather'), isNull);

    final on = GenAiInstrumentation(emitToolSpans: true);
    await on.runInNewSpan(
      const SpanMetadata(name: 'weather', actionType: 'tool'),
      ([span]) async => 'sunny',
    );
    final span = harness.spans.findSpanByName('execute_tool weather')!;
    expect(attr(span, GenAiAttr.operationName), 'execute_tool');
    expect(attr(span, GenAiAttr.toolName), 'weather');
  });

  test('does not capture action IO by default', () async {
    final instr = GenAiInstrumentation();
    await runModel(
      instr,
      'googleai/gemini-flash-latest',
      modelRequest(),
      ([span]) async => modelResponse(),
    );
    final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    expect(attr(span, GenkitAttr.input), isNull);
    expect(attr(span, GenkitAttr.output), isNull);
  });

  test('captureActionIO records raw genkit IO on all span types', () async {
    final instr = GenAiInstrumentation(
      captureActionIO: true,
      emitToolSpans: true,
    );

    // Model span.
    await runModel(
      instr,
      'googleai/gemini-flash-latest',
      modelRequest(),
      ([span]) async => modelResponse(),
    );
    final model = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    expect(attr(model, GenkitAttr.input), isA<String>());
    expect(attr(model, GenkitAttr.output), isA<String>());

    // Tool span.
    await instr.runInNewSpan(
      const SpanMetadata(name: 'weather', actionType: 'tool', input: 'Paris'),
      ([span]) async => 'sunny',
    );
    final tool = harness.spans.findSpanByName('execute_tool weather')!;
    expect(attr(tool, GenkitAttr.input) as String, contains('Paris'));
    expect(attr(tool, GenkitAttr.output) as String, contains('sunny'));
    // Raw IO must not land in the reserved gen_ai.* content keys.
    expect(attr(tool, GenAiAttr.inputMessages), isNull);
    expect(attr(tool, GenAiAttr.outputMessages), isNull);

    // Generic span.
    await instr.runInNewSpan(
      const SpanMetadata(name: 'myFlow', actionType: 'flow', input: 'in'),
      ([span]) async => 'out',
    );
    final flow = harness.spans.findSpanByName('myFlow')!;
    expect(attr(flow, GenkitAttr.input) as String, contains('in'));
    expect(attr(flow, GenkitAttr.output) as String, contains('out'));
    expect(attr(flow, GenAiAttr.inputMessages), isNull);
  });

  test(
    'captures legacy candidates[0].message when top-level is absent',
    () async {
      final instr = GenAiInstrumentation(
        captureContent: true,
        contentMode: GenAiContentMode.span,
      );
      final legacy = ModelResponse.fromJson({
        'finishReason': 'stop',
        'candidates': [
          {
            'index': 0,
            'finishReason': 'stop',
            'message': {
              'role': 'model',
              'content': [
                {'text': 'legacy answer'},
              ],
            },
          },
        ],
      });

      await runModel(
        instr,
        'googleai/gemini-flash-latest',
        modelRequest(),
        ([span]) async => legacy,
      );

      final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
      expect(attr(span, GenAiAttr.outputMessages), contains('legacy answer'));
    },
  );

  test('reports tool_calls from legacy candidates[0].message', () async {
    final instr = GenAiInstrumentation();
    final legacy = ModelResponse.fromJson({
      'finishReason': 'stop',
      'candidates': [
        {
          'index': 0,
          'finishReason': 'stop',
          'message': {
            'role': 'model',
            'content': [
              {
                'toolRequest': {'name': 'lookup', 'input': <String, Object?>{}},
              },
            ],
          },
        },
      ],
    });

    await runModel(
      instr,
      'googleai/gemini-flash-latest',
      modelRequest(),
      ([span]) async => legacy,
    );

    final span = harness.spans.findSpanByName('chat gemini-flash-latest')!;
    expect(attr(span, GenAiAttr.responseFinishReasons), ['tool_calls']);
  });
}
