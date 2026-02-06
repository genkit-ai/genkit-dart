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

import 'genkit_google_genai.dart';
import 'src/plugin_impl.dart';

export 'src/model.dart';

class GoogleAI extends GoogleAiPluginImpl {
  GoogleAI({super.apiKey});

  static ModelReference<GeminiOptions> gemini(String name) =>
      modelRef('googleai/$name', customOptions: GeminiOptions.$schema);

  static EmbedderRef<TextEmbedderOptions> textEmbedding(String name) =>
      embedderRef('googleai/$name', customOptions: TextEmbedderOptions.$schema);
}
