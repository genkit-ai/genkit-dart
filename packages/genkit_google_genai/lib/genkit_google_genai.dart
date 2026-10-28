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
  /// environment variable. [store] is used by requests that don't set
  /// `store` themselves. On models called through the Interactions API it
  /// stores interactions on the server (not set = not stored); a stored
  /// interaction is continued by the next request, which then only sends the
  /// newer messages. On generateContent models it sets whether the server
  /// logs requests for the API key's project; not set, it isn't sent and the
  /// project's logging setting applies.
  GenkitPlugin call({String? apiKey, bool? store}) {
    return GoogleGenAiPluginImpl(apiKey: apiKey, store: store);
  }

  /// A [ModelRef] for the Gemini model [name].
  ///
  /// Carries [GeminiOptions]. It works for every Gemini model, including
  /// image, text-to-speech and video models; their own handles
  /// ([geminiImage], [geminiTts], [geminiVideo]) add the options only those
  /// models take.
  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('googleai/$name', customOptions: GeminiOptions.$schema);
  }

  /// A [ModelRef] for the Gemini text-to-speech model [name].
  ///
  /// Carries [GeminiTtsOptions]: the [GeminiOptions] fields plus
  /// `audioFormat`. Use it for any `-tts` name, curated or not, so the
  /// request config is typed to what the model accepts.
  ModelRef<GeminiTtsOptions> geminiTts(String name) {
    return modelRef('googleai/$name', customOptions: GeminiTtsOptions.$schema);
  }

  /// A [ModelRef] for the Gemini image model [name] (e.g.
  /// `gemini-nano-banana-2.1`).
  ///
  /// Carries [GeminiImageOptions]: the [GeminiOptions] fields plus
  /// `imageConfig` (aspect ratio and size). Use it for any image model,
  /// curated or not.
  ModelRef<GeminiImageOptions> geminiImage(String name) {
    return modelRef(
      'googleai/$name',
      customOptions: GeminiImageOptions.$schema,
    );
  }

  /// A [ModelRef] for the Gemini video model [name] (e.g.
  /// `gemini-omni-1.1-flash`).
  ///
  /// Carries [GeminiVideoOptions]: the [GeminiOptions] fields plus
  /// `videoFormat` (aspect ratio, resolution, delivery) and `videoConfig`
  /// (the kind of generation). Use it for any video model, curated or not.
  ModelRef<GeminiVideoOptions> geminiVideo(String name) {
    return modelRef(
      'googleai/$name',
      customOptions: GeminiVideoOptions.$schema,
    );
  }

  /// A [ModelRef] for the Lyria music generation model [name] (e.g.
  /// `lyria-3.5`).
  ///
  /// Carries [LyriaOptions]. Lyria returns the music as audio, plus its
  /// lyrics or caption as text.
  ModelRef<LyriaOptions> lyria(String name) {
    return modelRef('googleai/$name', customOptions: LyriaOptions.$schema);
  }

  /// A [ModelRef] for the Antigravity agent [name] (e.g.
  /// `antigravity-preview-09-2026`).
  ///
  /// Carries [AntigravityOptions]. The agent keeps its conversation on the
  /// server: passing a previous response's messages continues it.
  ModelRef<AntigravityOptions> antigravity(String name) {
    return modelRef(
      'googleai/$name',
      customOptions: AntigravityOptions.$schema,
    );
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
