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

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;

import 'src/model.dart';
import 'src/plugin_impl.dart';

export 'src/model.dart';

const GoogleGenAiPluginHandle googleAI = GoogleGenAiPluginHandle();
const VertexAiPluginHandle vertexAI = VertexAiPluginHandle();

class GoogleGenAiPluginHandle {
  const GoogleGenAiPluginHandle();

  GenkitPlugin call({String? apiKey}) {
    return GoogleGenAiPluginImpl(apiKey: apiKey);
  }

  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('googleai/$name', customOptions: GeminiOptions.$schema);
  }

  EmbedderRef<TextEmbedderOptions> textEmbedding(String name) {
    return embedderRef(
      'googleai/$name',
      customOptions: TextEmbedderOptions.$schema,
    );
  }
}

class VertexAiPluginHandle {
  const VertexAiPluginHandle();

  GenkitPlugin call({
    String? projectId,
    String? location,
    http.Client? authClient,
  }) {
    return GoogleGenAiPluginImpl(
      projectId: projectId,
      location: location,
      authClient: authClient,
    );
  }

  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('vertexai/$name', customOptions: GeminiOptions.$schema);
  }

  EmbedderRef<TextEmbedderOptions> textEmbedding(String name) {
    return embedderRef(
      'vertexai/$name',
      customOptions: TextEmbedderOptions.$schema,
    );
  }
}
