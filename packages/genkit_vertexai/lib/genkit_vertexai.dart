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
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:http/http.dart' as http;

import 'src/vertex_api_client.dart';

export 'package:genkit_google_genai/genkit_google_genai.dart'
    show
        GeminiAudioFormat,
        GeminiFileSearch,
        GeminiFunctionCallingConfig,
        GeminiGoogleSearch,
        GeminiImageConfig,
        GeminiImageOptions,
        GeminiLatLng,
        GeminiMultiSpeakerVoiceConfig,
        GeminiOptions,
        GeminiPrebuiltVoiceConfig,
        GeminiRetrievalConfig,
        GeminiSafetySettings,
        GeminiSpeakerVoiceConfig,
        GeminiSpeechConfig,
        GeminiThinkingConfig,
        GeminiTtsOptions,
        GeminiUrlContext,
        GeminiVertexDatastore,
        GeminiVertexRetrieval,
        GeminiVideoConfig,
        GeminiVideoFormat,
        GeminiVideoOptions,
        GeminiVoiceConfig,
        GoogleGenAiEmbedderOptions,
        LyriaOptions;

const VertexAiPluginHandle vertexAI = VertexAiPluginHandle();

class VertexAiPluginHandle {
  const VertexAiPluginHandle();

  /// Creates the Vertex AI plugin. [projectId] falls back to
  /// `GOOGLE_CLOUD_PROJECT`/`GCLOUD_PROJECT`, and [location] defaults to
  /// `global`.
  ///
  /// [apiVersion] is the API version in request paths: `v1` or `v1beta1`
  /// (the default). A request's own `apiVersion` option wins over it.
  ///
  /// [experimentalDebugTraces] runs each model API call in an `httpRequest`
  /// trace span with the endpoint, the request, the headers (the access
  /// token hidden) and the response (`[Streaming Response]` for streamed
  /// calls). Experimental: the option and the span's shape may change.
  ///
  /// [authClient] replaces the default transport for credential and API calls.
  /// It is never closed by the plugin; the caller owns its lifecycle.
  /// Cancellation aborts its in-flight requests when it passes each request on
  /// as is (as `http`'s own clients do); a client that copies requests (e.g.
  /// googleapis_auth's) drops the abort, and cancellation then lands once the
  /// request returns.
  ///
  /// [store] is used by requests that don't set `store` themselves. On
  /// models called through the Interactions API it stores interactions on
  /// the server (not set = not stored); a stored interaction is continued by
  /// the next request, which then only sends the newer messages. On
  /// generateContent models it's ignored (the platform has nothing to
  /// store); a request's own `store: true` there logs a warning.
  GenkitPlugin call({
    String? projectId,
    String? location,
    String? apiVersion,
    bool experimentalDebugTraces = false,
    http.Client? authClient,
    bool? store,
  }) {
    return VertexAiPluginImpl(
      projectId: projectId,
      location: location,
      apiVersion: apiVersion,
      experimentalDebugTraces: experimentalDebugTraces,
      authClient: authClient,
      store: store,
    );
  }

  /// A [ModelRef] for the Gemini model [name].
  ///
  /// Carries [GeminiOptions]. It works for every Gemini model, including
  /// image, text-to-speech and video models; their own handles
  /// ([geminiImage], [geminiTts], [geminiVideo]) add the options only those
  /// models take.
  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('vertexai/$name', customOptions: GeminiOptions.$schema);
  }

  /// A [ModelRef] for the Gemini image model [name] (e.g.
  /// `gemini-nano-banana-2.1`).
  ///
  /// Carries [GeminiImageOptions]: the [GeminiOptions] fields plus
  /// `imageConfig` (aspect ratio and size).
  ModelRef<GeminiImageOptions> geminiImage(String name) {
    return modelRef(
      'vertexai/$name',
      customOptions: GeminiImageOptions.$schema,
    );
  }

  /// A [ModelRef] for the Gemini text-to-speech model [name] (e.g.
  /// `gemini-3.8-flash-tts`).
  ///
  /// Carries [GeminiTtsOptions]: the [GeminiOptions] fields plus
  /// `audioFormat`.
  ModelRef<GeminiTtsOptions> geminiTts(String name) {
    return modelRef('vertexai/$name', customOptions: GeminiTtsOptions.$schema);
  }

  /// A [ModelRef] for the Gemini video model [name] (e.g.
  /// `gemini-omni-1.1-flash-preview`).
  ///
  /// Carries [GeminiVideoOptions]: the [GeminiOptions] fields plus
  /// `videoFormat` (aspect ratio, resolution, delivery, gcsUri) and
  /// `videoConfig` (the kind of generation).
  ModelRef<GeminiVideoOptions> geminiVideo(String name) {
    return modelRef(
      'vertexai/$name',
      customOptions: GeminiVideoOptions.$schema,
    );
  }

  /// A [ModelRef] for the Lyria music generation model [name] (e.g.
  /// `lyria-3-clip-preview`).
  ///
  /// Carries [LyriaOptions]. Lyria returns the music as audio, plus its
  /// lyrics or caption as text. It is only served on the `global` location
  /// (set `location: 'global'` if the plugin uses another one).
  ModelRef<LyriaOptions> lyria(String name) {
    return modelRef('vertexai/$name', customOptions: LyriaOptions.$schema);
  }

  EmbedderRef<GoogleGenAiEmbedderOptions> textEmbedding(String name) {
    return embedderRef(
      'vertexai/$name',
      customOptions: GoogleGenAiEmbedderOptions.$schema,
    );
  }
}
