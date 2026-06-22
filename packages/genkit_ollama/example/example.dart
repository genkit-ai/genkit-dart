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

// Runnable example for the Genkit Ollama plugin.
//
// Prerequisites:
//   ollama serve
//   ollama pull llama3.2          # chat + tools
//   ollama pull nomic-embed-text  # embeddings
//
// Run with:
//   dart run example/example.dart

import 'dart:io';
import 'dart:math';

import 'package:genkit/genkit.dart';
import 'package:genkit_ollama/genkit_ollama.dart';
import 'package:schemantic/schemantic.dart';

part 'example.g.dart';

@Schema()
abstract class $WeatherToolInput {
  /// City name to look up.
  String get location;
}

@Schema()
abstract class $WeatherToolOutput {
  double get temperature;
  String get condition;
}

Future<void> main() async {
  final ai = Genkit(plugins: [ollama()]);

  final getWeather = ai.defineTool(
    name: 'getWeather',
    description: 'Get the current weather for a location.',
    inputSchema: WeatherToolInput.$schema,
    outputSchema: WeatherToolOutput.$schema,
    fn: (input, _) async {
      final random = Random();
      return WeatherToolOutput(
        temperature: 15 + random.nextInt(20).toDouble(),
        condition: ['sunny', 'cloudy', 'rainy'][random.nextInt(3)],
      );
    },
  );

  // 1. Streamed chat.
  stdout.writeln('--- Streamed chat ---');
  final stream = ai.generateStream(
    model: ollama.model('llama3.2'),
    prompt: 'Tell me a one-sentence joke about Dart.',
  );
  await for (final chunk in stream) {
    stdout.write(chunk.text);
  }
  stdout.writeln('\n');

  // 2. Tool calling.
  stdout.writeln('--- Tool calling ---');
  final toolResponse = await ai.generate(
    model: ollama.model('llama3.2'),
    prompt: "What's the weather in Boston?",
    toolNames: [getWeather.name],
  );
  stdout.writeln('${toolResponse.text}\n');

  // 3. Embeddings.
  stdout.writeln('--- Embeddings ---');
  final embeddings = await ai.embed(
    embedder: ollama.embedder('nomic-embed-text'),
    document: DocumentData(content: [TextPart(text: 'Hello Genkit')]),
  );
  stdout.writeln('vector length: ${embeddings.first.embedding.length}');
}
