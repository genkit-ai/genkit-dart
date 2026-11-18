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
import 'package:genkit/src/ai/generate.dart' show runGenerateAction;
import 'package:genkit/src/o11y/instrumentation.dart';
import 'package:test/test.dart';

/// Records the [SpanMetadata] of every span it is asked to open.
class _RecordingInstrumentation implements Instrumentation {
  final List<SpanMetadata> spans = [];

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) {
    spans.add(metadata);
    return next();
  }
}

void main() {
  group('generate span name', () {
    late Genkit genkit;
    late _RecordingInstrumentation recorder;

    setUp(() {
      recorder = _RecordingInstrumentation();
      configureInstrumentation(recorder);
      genkit = Genkit(isDevEnv: false);
      genkit.defineModel(
        name: 'spanModel',
        fn: (request, context) async => ModelResponse(
          finishReason: .stop,
          message: Message(
            role: .model,
            content: [TextPart(text: 'ok')],
          ),
        ),
      );
    });

    tearDown(() async {
      resetInstrumentation();
      await genkit.shutdown();
    });

    Iterable<SpanMetadata> generateSpans() =>
        recorder.spans.where((s) => s.actionType == 'util');

    Future<void> run({String? stepName}) async {
      await runGenerateAction(
        genkit.registry,
        GenerateActionOptions(
          model: 'spanModel',
          messages: [
            Message(
              role: .user,
              content: [TextPart(text: 'hi')],
            ),
          ],
          stepName: stepName,
        ),
        ActionFnArg<ModelResponseChunk, GenerateActionOptions, void>(),
      );
    }

    test('uses stepName as the span name and keeps genkit:name', () async {
      await run(stepName: 'summarize');

      final span = generateSpans().single;
      expect(span.name, 'summarize');
      expect(span.attributes['genkit:name'], 'generate');
    });

    test('falls back to generate when there is no stepName', () async {
      await run();

      final span = generateSpans().single;
      expect(span.name, 'generate');
      expect(span.attributes, isNot(contains('genkit:name')));
    });

    test('falls back to generate for an empty stepName', () async {
      await run(stepName: '');

      final span = generateSpans().single;
      expect(span.name, 'generate');
      expect(span.attributes, isNot(contains('genkit:name')));
    });
  });
}
