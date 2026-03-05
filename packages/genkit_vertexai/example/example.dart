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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_vertexai/genkit_vertexai.dart';

void main(List<String> args) async {
  final ai = Genkit(
    plugins: [
      vertexAI(
        projectId: Platform.environment['GCLOUD_PROJECT'],
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'us-central1',
      ),
    ],
  );

  // --- Basic Generate Flow ---
  ai.defineFlow(
    name: 'basicGenerate',
    inputSchema: .string(defaultValue: 'Hello Genkit for Dart!'),
    outputSchema: .string(),
    fn: (input, context) async {
      final response = await ai.generate(
        model: vertexAI.gemini('gemini-2.5-flash'),
        prompt: input,
      );
      return response.text;
    },
  );

  // --- Embedding Flow ---
  ai.defineFlow(
    name: 'embedding',
    inputSchema: .string(defaultValue: 'Hello Genkit'),
    outputSchema: .list(.doubleSchema()),
    fn: (input, _) async {
      final embeddings = await ai.embedMany(
        embedder: vertexAI.textEmbedding('text-embedding-004'),
        documents: [
          DocumentData(content: [TextPart(text: input)]),
        ],
      );
      return embeddings.first.embedding;
    },
  );
}
