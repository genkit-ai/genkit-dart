// Copyright 2026 Google LLC
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

/// Demonstrates cooperative cancellation of a `generate` call.
///
/// A [CancellationController] is created by the caller; its [CancellationToken]
/// is passed into `generate` / `generateStream` via the `cancel:` parameter.
/// Calling `controller.cancel()` aborts the in-flight model call (and the whole
/// tool loop). Rather than throwing, `generate` resolves with a response whose
/// `finishReason` is [FinishReason.aborted]; `response.messages` carries the
/// last-good history so you can attempt to resume from there.
///
/// Run with:
///   dart run lib/cancellation_sample.dart
library;

import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

Future<void> main() async {
  final ai = Genkit(plugins: [googleAI()]);

  // 1) Streaming generate that we cancel shortly after the first chunk.
  final controller = CancellationController();
  final stream = ai.generateStream(
    model: googleAI.gemini('gemini-flash-latest'),
    prompt: 'Write a long, detailed essay about the history of the internet.',
    cancel: controller.token,
  );

  // Cancel after a brief delay to simulate a user hitting "stop".
  Timer(const Duration(milliseconds: 300), () {
    print('\n[cancelling...]');
    controller.cancel('user pressed stop');
  });

  // Chunks emitted before the cancel still arrive; the stream then closes.
  await for (final chunk in stream) {
    print(chunk.text);
  }
  final res = await stream.onResult;
  if (res.finishReason == FinishReason.aborted) {
    print('\nGeneration was cancelled: ${res.finishMessage}');
    print('Resumable history has ${res.messages.length} message(s): ${jsonEncode(res.messages).toString()}');
  }

  // 2) A token that is already cancelled short-circuits before the model runs
  //    and resolves with an aborted response carrying the request history.
  final preCancelled = CancellationController()..cancel();
  final res2 = await ai.generate(
    model: googleAI.gemini('gemini-flash-latest'),
    prompt: 'This should never reach the model.',
    cancel: preCancelled.token,
  );
  print(
    'Pre-cancelled generate finished as ${res2.finishReason?.value} '
    'with ${res2.messages.length} message(s) of history: ${jsonEncode(res2.messages).toString()}'
    ,
  );

  await ai.shutdown();
}
