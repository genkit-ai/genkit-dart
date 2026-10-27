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

import 'src/google_api_client.dart';
import 'src/model.dart';

export 'src/model.dart';

const GoogleGenAiPluginHandle googleAI = GoogleGenAiPluginHandle();

class GoogleGenAiPluginHandle {
  const GoogleGenAiPluginHandle();

  /// Creates the Gemini API plugin.
  ///
  /// [apiKey] defaults to the `GOOGLE_API_KEY` or `GEMINI_API_KEY`
  /// environment variable. [store] stores interactions on the server for
  /// requests that don't set `store` themselves (only for models called
  /// through the Interactions API); a stored interaction is continued by the
  /// next request, which then only sends the newer messages.
  GenkitPlugin call({String? apiKey, bool store = false}) {
    return GoogleGenAiPluginImpl(apiKey: apiKey, store: store);
  }

  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('googleai/$name', customOptions: GeminiOptions.$schema);
  }

  /// A [ModelRef] for the Gemini text-to-speech model [name].
  ///
  /// Carries [GeminiTtsOptions], which adds `speechConfig` on top of
  /// [GeminiOptions]. Use it for any `-tts` name, curated or not, so the
  /// request config is typed to what the model accepts.
  ModelRef<GeminiTtsOptions> geminiTts(String name) {
    return modelRef('googleai/$name', customOptions: GeminiTtsOptions.$schema);
  }

  /// A [ModelRef] for the Gemma model [name] served by the Gemini API.
  ///
  /// An alias of [gemini] that reads correctly at Gemma call sites. Should
  /// Gemma ever gain an options schema of its own, the options type here
  /// narrows to it, which is a breaking change for callers.
  ModelRef<GeminiOptions> gemma(String name) => gemini(name);

  EmbedderRef<GoogleGenAiEmbedderOptions> textEmbedding(String name) {
    return embedderRef(
      'googleai/$name',
      customOptions: GoogleGenAiEmbedderOptions.$schema,
    );
  }
}
