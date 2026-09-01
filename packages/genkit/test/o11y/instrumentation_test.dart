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

  group('DirectHttpInstrumentation with nested spans', () {
    late RecordingSpanSink sink;
    late Genkit genkit;

    setUp(() {
      sink = RecordingSpanSink();
      configureInstrumentation(DirectHttpInstrumentation(sink));
      genkit = Genkit();
    });

    tearDown(resetInstrumentation);

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

        // Two finished spans (each also had a start export).
        expect(sink.finished.length, 2);

        final parentSpan = sink.byName('parentFlow');
        final childSpan = sink.byName('childFlow');

        // Verify the parent-child relationship.
        expect(childSpan.parentSpanId, parentSpan.spanId);
        expect(parentSpan.parentSpanId, isNull);

        // Both spans share the same trace.
        expect(childSpan.traceId, parentSpan.traceId);

        // The span ids surfaced to callers must be real (non-zero).
        expect(parentSpan.traceId, isNot('0' * 32));
        expect(parentSpan.spanId, isNot('0' * 16));
      },
    );
  });

  group('DirectHttpInstrumentation span export', () {
    test('exports the span on start and again on end', () async {
      final sink = RecordingSpanSink();
      final instrumentation = DirectHttpInstrumentation(sink);

      await instrumentation.runInNewSpan<void>(
        const SpanMetadata(name: 'injected'),
        (_) async {},
      );

      // Two exports: a start snapshot (unfinished) then the finished span.
      final injected = sink.spans.where((s) => s.name == 'injected').toList();
      expect(injected.length, 2);

      final start = injected.first;
      expect(start.endTimeUnixNano, 0);
      expect(start.status.code, GenkitStatusCode.unset);
      expect(start.attributes.containsKey('genkit:output'), isFalse);

      final end = injected.last;
      expect(end.endTimeUnixNano, greaterThan(0));
      expect(end.traceId, isNot('0' * 32));
      expect(end.spanId, isNot('0' * 16));
      expect(end.status.code, GenkitStatusCode.ok);
    });

    test('records error status when the operation throws', () async {
      final sink = RecordingSpanSink();
      final instrumentation = DirectHttpInstrumentation(sink);

      await expectLater(
        instrumentation.runInNewSpan<void>(
          const SpanMetadata(name: 'boom'),
          (_) async => throw StateError('nope'),
        ),
        throwsA(isA<StateError>()),
      );

      final span = sink.byName('boom');
      expect(span.status.code, GenkitStatusCode.error);
      expect(span.status.message, contains('nope'));
    });
  });
}
