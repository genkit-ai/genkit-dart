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

// A minimal, server-side A2UI example.
//
// The whole server integration is the `a2ui()` middleware: register
// `A2uiPlugin()` on the Genkit instance, then add `a2ui()` to a `generate`
// call's (or an agent's) `use` list. The middleware injects the catalog's
// capabilities into the system prompt and rewrites the model's `a2ui` fenced
// blocks into canonical a2ui `data` parts.
//
// This example prints the A2UI envelopes the model emits. In a real app you
// would forward these to a client (see `client.dart` and the full Flutter
// sample under `testapps/a2ui`) and render them with a renderer such as
// `genui`.
//
// Run with:
//   GEMINI_API_KEY=your-key dart run example/example.dart

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

Future<void> main() async {
  if (Platform.environment['GEMINI_API_KEY'] == null) {
    print('Set GEMINI_API_KEY to run this example.');
    return;
  }

  // Register the A2UI plugin so `a2ui()` resolves from the registry.
  final ai = Genkit(plugins: [googleAI(), A2uiPlugin()]);

  print('--- Streaming ---');
  final stream = ai.generateStream(
    model: googleAI.gemini('gemini-flash-latest'),
    prompt: 'Show me the weather in Tokyo as a small card.',
    system:
        'Render an A2UI surface whenever a result is clearer shown than told. '
        'Keep any prose brief.',
    use: [a2ui()], // <- the entire A2UI integration (default 'basic' catalog).
  );

  // As chunks arrive, pull any A2UI envelopes off each chunk's content.
  await for (final chunk in stream) {
    for (final envelope in a2uiEnvelopesFromParts(chunk.content)) {
      print('envelope: ${jsonEncode(envelope)}');
    }
    if (chunk.text.isNotEmpty) print('prose: ${chunk.text}');
  }

  // The final aggregated message carries the same envelopes (plus any prose).
  final response = await stream.onResult;
  final envelopes = a2uiEnvelopesFromParts(response.message?.content);
  print('\n--- Final message: ${envelopes.length} envelope(s) ---');
}
