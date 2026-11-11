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

import 'package:schemantic/schemantic.dart';

part 'model.g.dart';

// The Gemini option types (GeminiOptions, GeminiTtsOptions,
// GeminiImageOptions, GeminiVideoOptions) repeat the same fields: the schema
// generator has no inheritance. Keep the shared fields identical in all four
// (same order, same annotations); each type then adds its own fields at the
// end. The JS plugin has one schema per family the same way
// (GeminiConfigSchema and its `.extend(...)`s).

@Schema()
abstract class $GeminiOptions {
  String? get apiKey;
  // TODO: Add apiVersion, baseUrl
  // String? get apiVersion;
  // String? get baseUrl;

  List<$GeminiSafetySettings>? get safetySettings;

  bool? get codeExecution;
  $GeminiFunctionCallingConfig? get functionCallingConfig;
  $GeminiThinkingConfig? get thinkingConfig;
  List<String>? get responseModalities;

  // Retrieval
  $GeminiGoogleSearch? get googleSearch;
  $GeminiFileSearch? get fileSearch;
  $GeminiUrlContext? get urlContext;
  $GeminiRetrievalConfig? get retrievalConfig;

  @Field(
    description:
        'Built-in tools as maps, for tools without an option of their own '
        "(e.g. `{'googleMaps': {}}`, `{'urlContext': {}}`). A map with a "
        "`type` (e.g. `{'type': 'google_search'}`) is passed through to "
        'models called through the Interactions API.',
  )
  List<Map<String, dynamic>>? get tools;

  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  int? get topK;
  int? get candidateCount;
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  String? get responseMimeType;
  bool? get responseLogprobs;
  int? get logprobs;
  double? get presencePenalty;
  double? get frequencyPenalty;
  int? get seed;

  $GeminiSpeechConfig? get speechConfig;

  @StringField(
    description:
        'Service tier for the Gemini API: standard, flex or priority. '
        'Other values are sent as given.',
  )
  String? get serviceTier;

  @StringField(
    description:
        'The ID of the previous interaction, if any. Requires store: true. '
        'Only used by models called through the Interactions API.',
  )
  String? get previousInteractionId;

  @Field(
    description:
        'Interactions API models: whether to store the interaction for later '
        'retrieval (defaults to false). generateContent models: whether the '
        "server logs the request for the API key's project; sent only when "
        "set (otherwise the project's logging setting applies).",
  )
  bool? get store;

  // vertexAI only (the googleAI plugin ignores them with a warning).
  @StringField(
    description:
        'vertexAI only. The Google Cloud location for this request (e.g. '
        'global, us, us-central1); overrides the plugin location.',
  )
  String? get location;

  @Field(
    description:
        'vertexAI only. Key-value labels to attach to the request for cost '
        'tracking.',
  )
  Map<String, String>? get labels;

  @Field(
    description:
        'vertexAI only. Retrieve from a Vertex AI Search data store for '
        'grounding generative responses.',
  )
  $GeminiVertexRetrieval? get vertexRetrieval;

  @StringField(
    enumValues: ['priority', 'priority-only', 'flex', 'flex-only'],
    description:
        'vertexAI only. PayGo consumption options. Priority provides more '
        'consistent performance than Standard PayGo. Flex is a '
        'cost-effective option for non-critical workloads. The "-only" '
        'options use only PayGo and no Provisioned Throughput.',
  )
  String? get payGo;
}

@Schema()
abstract class $GeminiSafetySettings {
  @StringField(
    enumValues: [
      'HARM_CATEGORY_UNSPECIFIED',
      'HARM_CATEGORY_HATE_SPEECH',
      'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'HARM_CATEGORY_HARASSMENT',
      'HARM_CATEGORY_DANGEROUS_CONTENT',
      'HARM_CATEGORY_CIVIC_INTEGRITY',
    ],
  )
  String? get category;

  @StringField(
    enumValues: [
      'BLOCK_LOW_AND_ABOVE',
      'BLOCK_MEDIUM_AND_ABOVE',
      'BLOCK_ONLY_HIGH',
      'BLOCK_NONE',
    ],
  )
  String? get threshold;
}

@Schema()
abstract class $GeminiThinkingConfig {
  @Field(
    description:
        'Indicates whether to include thoughts in the response.'
        'If true, thoughts are returned only when available.',
  )
  bool? get includeThoughts;

  @IntegerField(
    minimum: 0,
    maximum: 24576,
    description:
        'The thinking budget parameter gives the model guidance on the '
        'number of thinking tokens it can use when generating a response. '
        'A greater number of tokens is typically associated with more detailed '
        'thinking, which is needed for solving more complex tasks. '
        'Setting the thinking budget to 0 disables thinking.',
  )
  int? get thinkingBudget;

  @StringField(
    enumValues: ['MINIMAL', 'LOW', 'MEDIUM', 'HIGH'],
    description:
        'For Gemini 3.0 - Indicates the thinking level. A higher level '
        'is associated with more detailed thinking, which is needed for solving '
        'more complex tasks.',
  )
  String? get thinkingLevel;
}

@Schema()
abstract class $GeminiFunctionCallingConfig {
  @StringField(enumValues: ['MODE_UNSPECIFIED', 'AUTO', 'ANY', 'NONE'])
  String? get mode;
  List<String>? get allowedFunctionNames;
}

@Schema()
abstract class $GeminiFileSearch {
  List<String>? get fileSearchStoreNames;
}

@Schema()
abstract class $GeminiTtsOptions {
  String? get apiKey;
  // TODO: Add apiVersion, baseUrl
  // String? get apiVersion;
  // String? get baseUrl;

  List<$GeminiSafetySettings>? get safetySettings;

  bool? get codeExecution;
  $GeminiFunctionCallingConfig? get functionCallingConfig;
  $GeminiThinkingConfig? get thinkingConfig;
  List<String>? get responseModalities;

  // Retrieval
  $GeminiGoogleSearch? get googleSearch;
  $GeminiFileSearch? get fileSearch;
  $GeminiUrlContext? get urlContext;
  $GeminiRetrievalConfig? get retrievalConfig;

  @Field(
    description:
        'Built-in tools as maps, for tools without an option of their own '
        "(e.g. `{'googleMaps': {}}`, `{'urlContext': {}}`). A map with a "
        "`type` (e.g. `{'type': 'google_search'}`) is passed through to "
        'models called through the Interactions API.',
  )
  List<Map<String, dynamic>>? get tools;

  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  int? get topK;
  int? get candidateCount;
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  String? get responseMimeType;
  bool? get responseLogprobs;
  int? get logprobs;
  double? get presencePenalty;
  double? get frequencyPenalty;
  int? get seed;

  $GeminiSpeechConfig? get speechConfig;

  @StringField(
    description:
        'Service tier for the Gemini API: standard, flex or priority. '
        'Other values are sent as given.',
  )
  String? get serviceTier;

  @StringField(
    description:
        'The ID of the previous interaction, if any. Requires store: true. '
        'Only used by models called through the Interactions API.',
  )
  String? get previousInteractionId;

  @Field(
    description:
        'Interactions API models: whether to store the interaction for later '
        'retrieval (defaults to false). generateContent models: whether the '
        "server logs the request for the API key's project; sent only when "
        "set (otherwise the project's logging setting applies).",
  )
  bool? get store;

  // vertexAI only (the googleAI plugin ignores them with a warning).
  @StringField(
    description:
        'vertexAI only. The Google Cloud location for this request (e.g. '
        'global, us, us-central1); overrides the plugin location.',
  )
  String? get location;

  @Field(
    description:
        'vertexAI only. Key-value labels to attach to the request for cost '
        'tracking.',
  )
  Map<String, String>? get labels;

  @Field(
    description:
        'vertexAI only. Retrieve from a Vertex AI Search data store for '
        'grounding generative responses.',
  )
  $GeminiVertexRetrieval? get vertexRetrieval;

  @StringField(
    enumValues: ['priority', 'priority-only', 'flex', 'flex-only'],
    description:
        'vertexAI only. PayGo consumption options. Priority provides more '
        'consistent performance than Standard PayGo. Flex is a '
        'cost-effective option for non-critical workloads. The "-only" '
        'options use only PayGo and no Provisioned Throughput.',
  )
  String? get payGo;

  // TTS only.
  $GeminiAudioFormat? get audioFormat;
}

@Schema()
abstract class $GeminiImageOptions {
  String? get apiKey;
  // TODO: Add apiVersion, baseUrl
  // String? get apiVersion;
  // String? get baseUrl;

  List<$GeminiSafetySettings>? get safetySettings;

  bool? get codeExecution;
  $GeminiFunctionCallingConfig? get functionCallingConfig;
  $GeminiThinkingConfig? get thinkingConfig;
  List<String>? get responseModalities;

  // Retrieval
  $GeminiGoogleSearch? get googleSearch;
  $GeminiFileSearch? get fileSearch;
  $GeminiUrlContext? get urlContext;
  $GeminiRetrievalConfig? get retrievalConfig;

  @Field(
    description:
        'Built-in tools as maps, for tools without an option of their own '
        "(e.g. `{'googleMaps': {}}`, `{'urlContext': {}}`). A map with a "
        "`type` (e.g. `{'type': 'google_search'}`) is passed through to "
        'models called through the Interactions API.',
  )
  List<Map<String, dynamic>>? get tools;

  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  int? get topK;
  int? get candidateCount;
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  String? get responseMimeType;
  bool? get responseLogprobs;
  int? get logprobs;
  double? get presencePenalty;
  double? get frequencyPenalty;
  int? get seed;

  $GeminiSpeechConfig? get speechConfig;

  @StringField(
    description:
        'Service tier for the Gemini API: standard, flex or priority. '
        'Other values are sent as given.',
  )
  String? get serviceTier;

  @StringField(
    description:
        'The ID of the previous interaction, if any. Requires store: true. '
        'Only used by models called through the Interactions API.',
  )
  String? get previousInteractionId;

  @Field(
    description:
        'Interactions API models: whether to store the interaction for later '
        'retrieval (defaults to false). generateContent models: whether the '
        "server logs the request for the API key's project; sent only when "
        "set (otherwise the project's logging setting applies).",
  )
  bool? get store;

  // vertexAI only (the googleAI plugin ignores them with a warning).
  @StringField(
    description:
        'vertexAI only. The Google Cloud location for this request (e.g. '
        'global, us, us-central1); overrides the plugin location.',
  )
  String? get location;

  @Field(
    description:
        'vertexAI only. Key-value labels to attach to the request for cost '
        'tracking.',
  )
  Map<String, String>? get labels;

  @Field(
    description:
        'vertexAI only. Retrieve from a Vertex AI Search data store for '
        'grounding generative responses.',
  )
  $GeminiVertexRetrieval? get vertexRetrieval;

  @StringField(
    enumValues: ['priority', 'priority-only', 'flex', 'flex-only'],
    description:
        'vertexAI only. PayGo consumption options. Priority provides more '
        'consistent performance than Standard PayGo. Flex is a '
        'cost-effective option for non-critical workloads. The "-only" '
        'options use only PayGo and no Provisioned Throughput.',
  )
  String? get payGo;

  // Image only.
  $GeminiImageConfig? get imageConfig;
}

/// Options for video generation models such as gemini-omni-1.1-flash.
/// See https://ai.google.dev/gemini-api/docs/omni
@Schema()
abstract class $GeminiVideoOptions {
  String? get apiKey;
  // TODO: Add apiVersion, baseUrl
  // String? get apiVersion;
  // String? get baseUrl;

  List<$GeminiSafetySettings>? get safetySettings;

  bool? get codeExecution;
  $GeminiFunctionCallingConfig? get functionCallingConfig;
  $GeminiThinkingConfig? get thinkingConfig;
  List<String>? get responseModalities;

  // Retrieval
  $GeminiGoogleSearch? get googleSearch;
  $GeminiFileSearch? get fileSearch;
  $GeminiUrlContext? get urlContext;
  $GeminiRetrievalConfig? get retrievalConfig;

  @Field(
    description:
        'Built-in tools as maps, for tools without an option of their own '
        "(e.g. `{'googleMaps': {}}`, `{'urlContext': {}}`). A map with a "
        "`type` (e.g. `{'type': 'google_search'}`) is passed through to "
        'models called through the Interactions API.',
  )
  List<Map<String, dynamic>>? get tools;

  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  int? get topK;
  int? get candidateCount;
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  String? get responseMimeType;
  bool? get responseLogprobs;
  int? get logprobs;
  double? get presencePenalty;
  double? get frequencyPenalty;
  int? get seed;

  $GeminiSpeechConfig? get speechConfig;

  @StringField(
    description:
        'Service tier for the Gemini API: standard, flex or priority. '
        'Other values are sent as given.',
  )
  String? get serviceTier;

  @StringField(
    description:
        'The ID of the previous interaction, if any. Requires store: true. '
        'Only used by models called through the Interactions API.',
  )
  String? get previousInteractionId;

  @Field(
    description:
        'Interactions API models: whether to store the interaction for later '
        'retrieval (defaults to false). generateContent models: whether the '
        "server logs the request for the API key's project; sent only when "
        "set (otherwise the project's logging setting applies).",
  )
  bool? get store;

  // vertexAI only (the googleAI plugin ignores them with a warning).
  @StringField(
    description:
        'vertexAI only. The Google Cloud location for this request (e.g. '
        'global, us, us-central1); overrides the plugin location.',
  )
  String? get location;

  @Field(
    description:
        'vertexAI only. Key-value labels to attach to the request for cost '
        'tracking.',
  )
  Map<String, String>? get labels;

  @Field(
    description:
        'vertexAI only. Retrieve from a Vertex AI Search data store for '
        'grounding generative responses.',
  )
  $GeminiVertexRetrieval? get vertexRetrieval;

  @StringField(
    enumValues: ['priority', 'priority-only', 'flex', 'flex-only'],
    description:
        'vertexAI only. PayGo consumption options. Priority provides more '
        'consistent performance than Standard PayGo. Flex is a '
        'cost-effective option for non-critical workloads. The "-only" '
        'options use only PayGo and no Provisioned Throughput.',
  )
  String? get payGo;

  // Video only.
  $GeminiVideoFormat? get videoFormat;
  $GeminiVideoConfig? get videoConfig;
}

@Schema(description: 'Speech generation config')
abstract class $GeminiSpeechConfig {
  $GeminiVoiceConfig? get voiceConfig;
  $GeminiMultiSpeakerVoiceConfig? get multiSpeakerVoiceConfig;
}

@Schema(description: 'Configuration for multi-speaker setup')
abstract class $GeminiMultiSpeakerVoiceConfig {
  @Field(description: 'Configuration for all the enabled speaker voices')
  List<$GeminiSpeakerVoiceConfig> get speakerVoiceConfigs;
}

@Schema(
  description: 'Configuration for a single speaker in a multi speaker setup',
)
abstract class $GeminiSpeakerVoiceConfig {
  @StringField(description: 'Name of the speaker to use')
  String get speaker;

  $GeminiVoiceConfig get voiceConfig;
}

@Schema(description: 'Configuration for the voice to use')
abstract class $GeminiVoiceConfig {
  $GeminiPrebuiltVoiceConfig? get prebuiltVoiceConfig;
}

@Schema(description: 'Configuration for the prebuilt speaker to use')
abstract class $GeminiPrebuiltVoiceConfig {
  @StringField(
    description:
        'Name of the preset voice to use. '
        'Known values: Zephyr, Puck, Charon, Kore, Fenrir, Leda, Orus, Aoede, '
        'Callirrhoe, Autonoe, Enceladus, Iapetus, Umbriel, Algieba, Despina, '
        'Erinome, Algenib, Rasalgethi, Laomedeia, Achernar, Alnilam, Schedar, '
        'Gacrux, Pulcherrima, Achird, Zubenelgenubi, Vindemiatrix, Sadachbia, '
        'Sadaltager, Sulafat',
  )
  String? get voiceName;
}

@Schema()
abstract class $GeminiGoogleSearch {
  // TODO: Add timeRangeFilter or other configurations if needed
}

@Schema(
  description:
      'Lets the model read the web pages linked in the prompt (URL context). '
      'Set it (an empty object) to turn the tool on.',
)
abstract class $GeminiUrlContext {}

@Schema(description: 'Configuration for retrieval tools.')
abstract class $GeminiRetrievalConfig {
  @Field(
    description:
        'The user location, used by the Google Maps tool (enable it with '
        "`tools: [{'googleMaps': {}}]`).",
  )
  $GeminiLatLng? get latLng;

  String? get languageCode;
}

@Schema(description: 'A location as latitude and longitude, in degrees.')
abstract class $GeminiLatLng {
  double? get latitude;
  double? get longitude;
}

@Schema(
  description:
      'Retrieve from a Vertex AI Search data store for grounding generative '
      'responses (vertexAI only).',
)
abstract class $GeminiVertexRetrieval {
  @Field(description: 'Vertex AI Search data store details.')
  $GeminiVertexDatastore get datastore;

  @Field(
    description:
        'Disable using the search data in detecting grounding attribution. '
        'This does not affect how the result is given to the model for '
        'generation.',
  )
  bool? get disableAttribution;
}

@Schema(description: 'Vertex AI Search data store details.')
abstract class $GeminiVertexDatastore {
  @StringField(
    description:
        'Google Cloud project ID. Defaults to the plugin project when not set.',
  )
  String? get projectId;

  @StringField(
    description:
        'Data store location: global, us or eu. Defaults to the plugin '
        'location when not set.',
  )
  String? get location;

  @StringField(
    description:
        'The data store ID, when projectId and location are given '
        'separately. Alternatively, the full path to the data store: '
        '"projects/{project}/locations/{location}/collections/'
        'default_collection/dataStores/{data_store}".',
  )
  String get dataStoreId;
}

@Schema(description: 'Settings for generated images.')
abstract class $GeminiImageConfig {
  @StringField(
    description:
        'Aspect ratio of the generated image: 1:1, 1:4, 1:8, 2:3, 3:2, 3:4, '
        '4:1, 4:3, 4:5, 5:4, 8:1, 9:16, 16:9 or 21:9 (depends on the model).',
  )
  String? get aspectRatio;

  @StringField(
    description:
        'Size of the generated image, e.g. 512, 1K, 2K or 4K (depends on the '
        'model).',
  )
  String? get imageSize;
}

@Schema(
  description:
      'Format of the generated audio. Supported by models called through the '
      'Interactions API (e.g. gemini-3.8-flash-tts on googleAI) and by TTS '
      'models on vertexAI.',
)
abstract class $GeminiAudioFormat {
  @StringField(
    description:
        'Audio encoding: audio/wav, audio/l16, audio/mulaw or audio/alaw. '
        'Defaults to audio/wav (with a header) for non-streamed requests and '
        'audio/l16 (raw PCM, no header) for streamed requests.',
  )
  String? get mimeType;

  @IntegerField(
    description: 'Sample rate in Hz, for example 24000, 16000 or 8000.',
  )
  int? get sampleRate;
}

@Schema(description: 'Format of the generated video.')
abstract class $GeminiVideoFormat {
  @StringField(
    description: 'Aspect ratio of the generated video: 16:9 (default) or 9:16.',
  )
  String? get aspectRatio;

  @StringField(
    description:
        'Resolution of the generated video: 360p, 720p (default), 1080p or '
        '4k. 1080p and 4k are upscaled.',
  )
  String? get resolution;

  @StringField(
    description:
        'How the video is returned. Inline by default; "uri" returns a Files '
        'API URI instead, recommended for large videos (requires store: '
        'true). On vertexAI, "uri" stores it in Cloud Storage (set gcsUri).',
  )
  String? get delivery;

  @StringField(
    description:
        'vertexAI only. The Cloud Storage URI to store the video in. '
        'Required when delivery is "uri".',
  )
  String? get gcsUri;
}

@Schema(description: 'Video generation settings.')
abstract class $GeminiVideoConfig {
  @StringField(
    description:
        'The kind of generation: text_to_video, image_to_video, '
        'reference_to_video, edit or extend. If not set, the model infers it '
        'from the prompt and inputs. Setting it adds constraints, so only use '
        'it when prompting alone does not give the intended mode.',
  )
  String? get task;
}

/// Options for the Lyria music generation models (e.g. lyria-3.5).
@Schema()
abstract class $LyriaOptions {
  @StringField(
    description: 'Overrides the plugin-configured API key, if specified.',
  )
  String? get apiKey;

  @Field(
    description:
        'The modalities to be used in response: TEXT, IMAGE, AUDIO. When not '
        'set, Lyria returns AUDIO and TEXT (the music, plus the lyrics or '
        'caption).',
  )
  List<String>? get responseModalities;

  @StringField(
    description:
        'vertexAI only. Lyria is only available in global. If the plugin '
        'uses a different location, set this to global.',
  )
  String? get location;
}

/// Options for the Antigravity agent (e.g. antigravity-preview-09-2026).
@Schema()
abstract class $AntigravityOptions {
  @StringField(
    description: 'Overrides the plugin-configured API key, if specified.',
  )
  String? get apiKey;

  @StringField(
    description:
        'The ID of the previous interaction, if any. By default the agent '
        'continues the interaction of the last model message.',
  )
  String? get previousInteractionId;

  @Field(
    description:
        'Whether to store the response and request for later retrieval. '
        'Sent only when set: the agent needs stored interactions (the '
        'server rejects store: false).',
  )
  bool? get store;

  @Field(
    description:
        'The sandbox environment: a string such as "remote" (a new sandbox), '
        'an environment ID, or a map with the environment configuration. A '
        'continued conversation reuses the previous environment.',
  )
  Object? get environment;

  @Field(description: 'The modalities to be used in response: TEXT, IMAGE.')
  List<String>? get responseModalities;

  @StringField(
    description:
        'The Gemini model the agent runs on (e.g. gemini-4-argon, '
        'gemini-3.8-flash). The server picks a default if not set.',
  )
  String? get model;

  @Field(
    description:
        "Built-in tools as maps (e.g. `{'googleSearch': {}}` or "
        "`{'type': 'google_search'}`), sent before the request's tools.",
  )
  List<Map<String, dynamic>>? get tools;
}

@Schema()
abstract class $GoogleGenAiEmbedderOptions {
  @IntegerField(
    description:
        'Optional. reduced dimension for the output embedding. If set, excessive values in the output embedding are truncated from the end.',
  )
  int? get outputDimensionality;

  @StringField(
    description:
        'Optional. Optional task type for which the embedding will be used. Can only be set for models/text-embedding-004.',
    enumValues: [
      'TASK_TYPE_UNSPECIFIED',
      'RETRIEVAL_QUERY',
      'RETRIEVAL_DOCUMENT',
      'SEMANTIC_SIMILARITY',
      'CLASSIFICATION',
      'CLUSTERING',
      'QUESTION_ANSWERING',
      'FACT_VERIFICATION',
      'CODE_RETRIEVAL_QUERY',
    ],
  )
  String? get taskType;

  String? get title;
}
