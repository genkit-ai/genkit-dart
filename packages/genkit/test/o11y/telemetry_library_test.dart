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

/// Opens spans through the public `package:genkit/telemetry.dart`, the way a
/// plugin does (plugins can't import `src/`). Only the cleanup between tests
/// comes from `src/`.
library;

import 'package:genkit/src/o11y/instrumentation.dart' show resetInstrumentation;
import 'package:genkit/telemetry.dart';
import 'package:test/test.dart';

/// Records what each span was given and how it ended.
class _RecordingInstrumentation implements Instrumentation {
  final List<SpanMetadata> started = [];
  final List<Object?> outputs = [];
  final List<Object> errors = [];

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) async {
    started.add(metadata);
    try {
      final output = await next();
      outputs.add(output);
      return output;
    } catch (e) {
      errors.add(e);
      rethrow;
    }
  }
}

void main() {
  group('telemetry.dart runInNewSpan', () {
    late _RecordingInstrumentation recorder;

    setUp(() {
      recorder = _RecordingInstrumentation();
      configureInstrumentation(recorder);
    });

    tearDown(resetInstrumentation);

    test('passes name, input and attributes and returns the output', () async {
      final result = await runInNewSpan<Map<String, Object?>, String>(
        'httpRequest',
        (_) async => 'response',
        input: {'apiEndpoint': 'https://example.test/v1/models'},
        attributes: {'custom:attr': 'value'},
      );

      expect(result, 'response');
      final span = recorder.started.single;
      expect(span.name, 'httpRequest');
      expect(span.input, {'apiEndpoint': 'https://example.test/v1/models'});
      expect(span.attributes, {'custom:attr': 'value'});
      expect(recorder.outputs, ['response']);
    });

    test('rethrows an error from the function', () async {
      await expectLater(
        runInNewSpan<void, void>(
          'httpRequest',
          (_) async => throw StateError('boom'),
        ),
        throwsStateError,
      );
      expect(recorder.errors.single, isStateError);
    });
  });
}
