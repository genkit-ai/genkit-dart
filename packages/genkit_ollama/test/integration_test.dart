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

// Live integration tests against a real Ollama server.
//
// These are skipped unless `OLLAMA_LIVE_TEST` is set. They require a running
// Ollama server and the models below pulled:
//
//   ollama serve
//   ollama pull llama3.2:1b
//   ollama pull nomic-embed-text
//
// Run with:
//   OLLAMA_LIVE_TEST=1 dart test test/integration_test.dart
//
// Override the models via OLLAMA_CHAT_MODEL / OLLAMA_EMBED_MODEL and the server
// via OLLAMA_BASE_URL.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_ollama/genkit_ollama.dart';
import 'package:test/test.dart';

void main() {
  final env = Platform.environment;
  if (env['OLLAMA_LIVE_TEST'] == null) {
    print('Skipping live Ollama tests (set OLLAMA_LIVE_TEST=1 to enable).');
    return;
  }

  final baseUrl = env['OLLAMA_BASE_URL'];
  final chatModel = env['OLLAMA_CHAT_MODEL'] ?? 'llama3.2:1b';
  final embedModel = env['OLLAMA_EMBED_MODEL'] ?? 'nomic-embed-text';

  late OllamaPlugin plugin;
  setUp(() => plugin = ollama(baseUrl: baseUrl) as OllamaPlugin);

  test('non-streaming generate', () async {
    final model = plugin.resolve('model', chatModel)!;
    final result =
        await model.call(
              ModelRequest(
                messages: [
                  Message(
                    role: Role.user,
                    content: [TextPart(text: 'Reply with the word: pong')],
                  ),
                ],
              ),
            )
            as ModelResponse;
    expect(result.message!.text, isNotEmpty);
  });

  test('streaming generate emits chunks', () async {
    final model = plugin.resolve('model', chatModel)!;
    final chunks = <String>[];
    final result =
        await model.call(
              ModelRequest(
                messages: [
                  Message(
                    role: Role.user,
                    content: [TextPart(text: 'Count from 1 to 5.')],
                  ),
                ],
              ),
              onChunk: (chunk) {
                final modelChunk = chunk as ModelResponseChunk;
                for (final part in modelChunk.content) {
                  if (part.isText) chunks.add(part.text!);
                }
              },
            )
            as ModelResponse;
    expect(chunks, isNotEmpty);
    expect(result.message!.text, isNotEmpty);
  });

  test('embedder returns a vector', () async {
    final embedder = plugin.resolve('embedder', embedModel)!;
    final result =
        await embedder.call(
              EmbedRequest(
                input: [
                  DocumentData(content: [TextPart(text: 'hello world')]),
                ],
              ),
            )
            as EmbedResponse;
    expect(result.embeddings.single.embedding, isNotEmpty);
  });

  test('list discovers local models', () async {
    final metadata = await plugin.list();
    expect(metadata, isNotEmpty);
  });
}
