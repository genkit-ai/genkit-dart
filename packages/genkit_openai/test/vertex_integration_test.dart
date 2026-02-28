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
import 'package:genkit_openai/genkit_openai.dart';
import 'package:test/test.dart';

void main() {
  final runVertexIntegration =
      Platform.environment['RUN_VERTEX_OPENAI_INTEGRATION'] == 'true';
  final projectId =
      Platform.environment['VERTEX_PROJECT_ID'] ??
      Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      Platform.environment['GCLOUD_PROJECT'];
  final location = Platform.environment['VERTEX_LOCATION'] ?? 'global';
  final model =
      Platform.environment['VERTEX_OPENAI_MODEL'] ?? 'google/gemini-2.5-flash';

  test(
    'vertex openai-compatible generate with ADC',
    () async {
      if (projectId == null || projectId.isEmpty) {
        fail(
          'Set VERTEX_PROJECT_ID or GOOGLE_CLOUD_PROJECT when running Vertex integration tests.',
        );
      }

      final ai = Genkit(
        plugins: [
          openAI(
            vertex: OpenAIVertexConfig.adc(
              projectId: projectId,
              location: location,
            ),
          ),
        ],
        isDevEnv: false,
      );

      final response = await ai.generate(
        model: openAI.model(model),
        prompt: 'Reply with exactly: Vertex OpenAI works.',
      );

      expect(response.text, isNotEmpty);
    },
    skip: !runVertexIntegration
        ? 'Set RUN_VERTEX_OPENAI_INTEGRATION=true to run Vertex integration tests.'
        : null,
  );
}
