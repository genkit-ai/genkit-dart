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
import 'package:genkit/telemetry.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:test/test.dart';
import '../test_util.dart';

/// A record of a span opened by [_FakeInstrumentation].
class _RecordedSpan implements SpanContext {
  final String label;

  @override
  final String traceId;

  @override
  final String spanId;

  final List<Map<String, Object?>> metadata = [];

  _RecordedSpan(this.label, {this.traceId = '', this.spanId = ''});

  @override
  void setMetadata(Map<String, Object?> metadata) {
    this.metadata.add(metadata);
  }
}

/// An [Instrumentation] that records the order of enter/exit and the spans it
/// creates, so tests can assert middleware wrapping behavior.
class _FakeInstrumentation implements Instrumentation {
  final String label;
  final List<String> log;
  final List<_RecordedSpan> spans = [];
  final String traceId;
  final String spanId;

  _FakeInstrumentation(
    this.label,
    this.log, {
    this.traceId = '',
    this.spanId = '',
  });

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function(SpanContext span) next,
  ) async {
    log.add('enter:$label');
    final span = _RecordedSpan(label, traceId: traceId, spanId: spanId);
    spans.add(span);
    try {
      return await next(span);
    } finally {
      log.add('exit:$label');
    }
  }
}

void main() {
  group('runInNewSpan dispatcher', () {
    tearDown(resetInstrumentation);

    test(
      'runs fn with a no-op span when no instrumentation configured',
      () async {
        SpanContext? seen;
        final result = await runInNewSpan<void, String>('op', (span) async {
          seen = span;
          return 'ok';
        });

        expect(result, 'ok');
        expect(seen, isNotNull);
        expect(seen!.traceId, '');
        expect(seen!.spanId, '');
        // setMetadata / setCustomMetadataAttributes must be safe no-ops.
        expect(() => seen!.setMetadata({'k': 'v'}), returnsNormally);
      },
    );

    test('composes providers as middleware in registration order', () async {
      final log = <String>[];
      configureInstrumentation(_FakeInstrumentation('a', log));
      configureInstrumentation(_FakeInstrumentation('b', log));

      await runInNewSpan<void, String>('op', (_) async {
        log.add('body');
        return 'x';
      });

      expect(log, ['enter:a', 'enter:b', 'body', 'exit:b', 'exit:a']);
    });

    test(
      'setCustomMetadataAttributes fans out to all provider spans',
      () async {
        final log = <String>[];
        final a = _FakeInstrumentation('a', log);
        final b = _FakeInstrumentation('b', log);
        configureInstrumentation(a);
        configureInstrumentation(b);

        await runInNewSpan<void, void>('op', (_) async {
          setCustomMetadataAttributes({'hello': 'world'});
        });

        expect(a.spans.single.metadata, [
          {'hello': 'world'},
        ]);
        expect(b.spans.single.metadata, [
          {'hello': 'world'},
        ]);
      },
    );

    test(
      'trace/span ids resolve to first non-empty across the chain',
      () async {
        final log = <String>[];
        // First provider exposes no ids, second does.
        configureInstrumentation(_FakeInstrumentation('a', log));
        configureInstrumentation(
          _FakeInstrumentation('b', log, traceId: 'trace-b', spanId: 'span-b'),
        );

        late String traceId;
        late String spanId;
        await runInNewSpan<void, void>('op', (span) async {
          traceId = span.traceId;
          spanId = span.spanId;
        });

        expect(traceId, 'trace-b');
        expect(spanId, 'span-b');
      },
    );

    test('propagates errors while still exiting each provider', () async {
      final log = <String>[];
      configureInstrumentation(_FakeInstrumentation('a', log));
      configureInstrumentation(_FakeInstrumentation('b', log));

      await expectLater(
        runInNewSpan<void, void>('op', (_) async {
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      expect(log, ['enter:a', 'enter:b', 'exit:b', 'exit:a']);
    });
  });

  group('OtelInstrumentation with nested spans', () {
    late sdk.TracerProviderBase provider;
    late TextExporter exporter;
    late sdk.SimpleSpanProcessor processor;
    late Genkit genkit;

    setUp(() {
      // Set up an in-memory exporter to capture spans.
      exporter = TextExporter();
      processor = sdk.SimpleSpanProcessor(exporter);
      provider = sdk.TracerProviderBase(processors: [processor]);
      api.registerGlobalTracerProvider(provider);

      // Explicitly enable the built-in OTel instrumentation (in production this
      // is only auto-injected in the dev environment).
      configureInstrumentation(genkitDevInstrumentation());

      genkit = Genkit();
    });

    tearDown(() {
      resetInstrumentation();
      provider.shutdown();
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

        // Force flush to ensure spans are exported.
        processor.forceFlush();

        final spans = exporter.spans;
        expect(spans.length, 2);

        final parentSpan = spans.firstWhere((s) => s.name == 'parentFlow');
        final childSpan = spans.firstWhere((s) => s.name == 'childFlow');

        // Verify the parent-child relationship.
        expect(childSpan.parentSpanId, parentSpan.spanContext.spanId);
        expect(parentSpan.parentSpanId.isValid, isFalse);

        // The span ids surfaced to callers must be real (non-zero). This guards
        // against the tracer being resolved eagerly against the no-op global
        // provider before the real SDK provider is registered.
        expect(
          parentSpan.spanContext.traceId.toString(),
          isNot('00000000000000000000000000000000'),
        );
        expect(
          parentSpan.spanContext.spanId.toString(),
          isNot('0000000000000000'),
        );
      },
    );
  });

  group('OtelInstrumentation provider routing', () {
    test('routes spans through the injected tracer provider', () async {
      // Give the instrumentation an explicit provider and assert spans land
      // there, proving Genkit routes through the injected provider instance
      // rather than depending on the global tracer provider.
      final localExporter = TextExporter();
      final localProcessor = sdk.SimpleSpanProcessor(localExporter);
      final localProvider = sdk.TracerProviderBase(
        processors: [localProcessor],
      );

      final instrumentation = OtelInstrumentation(
        tracerProvider: localProvider,
      );

      await instrumentation.runInNewSpan<void>(
        const SpanMetadata(name: 'injected'),
        (_) async {},
      );

      localProcessor.forceFlush();

      expect(
        localExporter.spans.map((s) => s.name),
        contains('injected'),
        reason: 'span should be exported via the injected provider',
      );
      // The injected provider mints real (non-zero) ids.
      final span = localExporter.spans.firstWhere((s) => s.name == 'injected');
      expect(
        span.spanContext.traceId.toString(),
        isNot('00000000000000000000000000000000'),
      );

      localProvider.shutdown();
    });
  });
}
