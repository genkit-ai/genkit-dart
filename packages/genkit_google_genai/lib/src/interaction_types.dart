// Copyright 2026 Google LLC
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

// Wire types for the Gemini Interactions API (steps schema).
//
// Mirrors js/plugins/google-genai/src/common/interaction-types.ts: same type
// names, same order. Keep the two in step: change JS first, then translate.
//
// Not ported yet (translate from the JS file when the feature arrives):
// - DynamicAgentConfig, DeepResearchAgentConfig and the request field
//   background: need background models (Deep Research).
// - InteractionStreamResult: comes with the client (its Dart shape depends
//   on the stream reader).
//
// How the JS types map to Dart:
// - Each type is an extension type over the JSON map itself, so unknown
//   fields and new types pass through unchanged (and `raw` stays exact).
//   `json` is the wire object: send it as is.
// - Type names are the JS names. Fields are lowerCamelCase getters over the
//   API's snake_case keys (e.g. `callId` reads `call_id`).
// - Every getter is nullable: JS doesn't check responses at runtime, so a
//   missing field is `undefined` there and `null` here. Constructors take
//   what the JS type requires as `required` parameters.
// - Unnamed constructors exist for the objects the plugin builds (requests,
//   and history sent back); response-only types only have `fromJson`.
// - A JS union of object types (e.g. `Step`) is a base extension type with
//   `type`; check `type`, then wrap with the variant's `fromJson`.
// - JS unions that mix in primitives, inline object types and free-form
//   records stay raw (`Object?`, `Map<String, Object?>`).
// - Named open string unions (`'a' | 'b' | (string & {})`) are
//   `extension type const X(String value)` with constants, like genkit's
//   `EvalStatus`.
// - Setters exist only where the JS code assigns the field after building
//   the object. Setting `null` removes the key, as `undefined` does in JS.

/// A tool that can be used by the model.
///
/// See https://ai.google.dev/gemini-api/docs/function-calling
extension type InteractionFunctionTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionFunctionTool({
    required String name,
    String? description,
    Map<String, Object?>? parameters,
  }) : this.fromJson({
         'type': 'function',
         'name': name,
         'description': ?description,
         'parameters': ?parameters,
       });

  /// The name of the function to call.
  String? get name => json['name'] as String?;

  /// Description and purpose of the function.
  String? get description => json['description'] as String?;

  /// The function's parameters, as a JSON schema.
  Map<String, Object?>? get parameters => _map(json['parameters']);
}

/// A tool that can be used by the model to search Google.
///
/// See https://ai.google.dev/gemini-api/docs/grounding
extension type InteractionGoogleSearchTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionGoogleSearchTool({List<String>? searchTypes})
    : this.fromJson({'type': 'google_search', 'search_types': ?searchTypes});

  /// `web_search`, `image_search` or `enterprise_web_search`. Unknown search
  /// types are passed through for forward compatibility.
  List<String>? get searchTypes => _list(json['search_types']);
}

/// A tool that can be used by the model to execute code.
///
/// See https://ai.google.dev/gemini-api/docs/code-execution
extension type InteractionCodeExecutionTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionCodeExecutionTool() : this.fromJson({'type': 'code_execution'});
}

/// A tool that can be used by the model to read and summarize web page
/// content.
extension type InteractionUrlContextTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionUrlContextTool() : this.fromJson({'type': 'url_context'});
}

/// A tool that can be used by the model to search uploaded document corpora.
extension type InteractionFileSearchTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionFileSearchTool({
    List<String>? fileSearchStoreNames,
    String? metadataFilter,
    int? topK,
  }) : this.fromJson({
         'type': 'file_search',
         'file_search_store_names': ?fileSearchStoreNames,
         'metadata_filter': ?metadataFilter,
         'top_k': ?topK,
       });

  List<String>? get fileSearchStoreNames =>
      _list(json['file_search_store_names']);
  String? get metadataFilter => json['metadata_filter'] as String?;
  int? get topK => _int(json['top_k']);
}

extension type InteractionAllowedTools.fromJson(Map<String, Object?> json) {
  InteractionAllowedTools({String? mode, List<String>? tools})
    : this.fromJson({'mode': ?mode, 'tools': ?tools});

  String? get mode => json['mode'] as String?;
  List<String>? get tools => _list(json['tools']);
}

extension type InteractionToolChoiceConfig.fromJson(Map<String, Object?> json) {
  InteractionToolChoiceConfig({InteractionAllowedTools? allowedTools})
    : this.fromJson({'allowed_tools': ?allowedTools});

  InteractionAllowedTools? get allowedTools =>
      _wrap(json['allowed_tools'], InteractionAllowedTools.fromJson);
}

/// A tool that can be used by the model to connect to remote MCP servers.
extension type InteractionMcpServerTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionMcpServerTool({
    String? name,
    String? url,
    Map<String, String>? headers,
    List<InteractionAllowedTools>? allowedTools,
  }) : this.fromJson({
         'type': 'mcp_server',
         'name': ?name,
         'url': ?url,
         'headers': ?headers,
         'allowed_tools': ?allowedTools,
       });

  String? get name => json['name'] as String?;
  String? get url => json['url'] as String?;
  Map<String, String>? get headers =>
      _map(json['headers'])?.cast<String, String>();
  List<InteractionAllowedTools>? get allowedTools =>
      _wrapAll(json['allowed_tools'], InteractionAllowedTools.fromJson);
}

extension type InteractionGoogleMapsTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionGoogleMapsTool({
    bool? enableWidget,
    double? latitude,
    double? longitude,
  }) : this.fromJson({
         'type': 'google_maps',
         'enable_widget': ?enableWidget,
         'latitude': ?latitude,
         'longitude': ?longitude,
       });

  bool? get enableWidget => json['enable_widget'] as bool?;
  double? get latitude => _double(json['latitude']);
  double? get longitude => _double(json['longitude']);
}

extension type InteractionComputerUseTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionComputerUseTool({
    List<String>? disabledSafetyPolicies,
    bool? enablePromptInjectionDetection,
    String? environment,
    List<String>? excludedPredefinedFunctions,
  }) : this.fromJson({
         'type': 'computer_use',
         'disabled_safety_policies': ?disabledSafetyPolicies,
         'enable_prompt_injection_detection': ?enablePromptInjectionDetection,
         'environment': ?environment,
         'excluded_predefined_functions': ?excludedPredefinedFunctions,
       });

  List<String>? get disabledSafetyPolicies =>
      _list(json['disabled_safety_policies']);
  bool? get enablePromptInjectionDetection =>
      json['enable_prompt_injection_detection'] as bool?;
  String? get environment => json['environment'] as String?;
  List<String>? get excludedPredefinedFunctions =>
      _list(json['excluded_predefined_functions']);
}

extension type InteractionRetrievalTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionRetrievalTool({
    Map<String, Object?>? exaAiSearchConfig,
    Map<String, Object?>? parallelAiSearchConfig,
    Map<String, Object?>? ragStoreConfig,
    List<String>? retrievalTypes,
    Map<String, Object?>? vertexAiSearchConfig,
  }) : this.fromJson({
         'type': 'retrieval',
         'exa_ai_search_config': ?exaAiSearchConfig,
         'parallel_ai_search_config': ?parallelAiSearchConfig,
         'rag_store_config': ?ragStoreConfig,
         'retrieval_types': ?retrievalTypes,
         'vertex_ai_search_config': ?vertexAiSearchConfig,
       });

  Map<String, Object?>? get exaAiSearchConfig =>
      _map(json['exa_ai_search_config']);
  Map<String, Object?>? get parallelAiSearchConfig =>
      _map(json['parallel_ai_search_config']);
  Map<String, Object?>? get ragStoreConfig => _map(json['rag_store_config']);
  List<String>? get retrievalTypes => _list(json['retrieval_types']);
  Map<String, Object?>? get vertexAiSearchConfig =>
      _map(json['vertex_ai_search_config']);
}

/// A tool this file has no type for, sent with its own `type` and fields
/// (already in the API's snake_case).
extension type InteractionDynamicTool.fromJson(Map<String, Object?> json)
    implements InteractionTool {
  InteractionDynamicTool(String type, [Map<String, Object?> fields = const {}])
    : this.fromJson({...fields, 'type': type});
}

/// A tool that can be used by the model.
///
/// One of the `Interaction*Tool` types above, told apart by [type].
extension type InteractionTool.fromJson(Map<String, Object?> json) {
  String? get type => json['type'] as String?;
}

// Text annotations. JS defines these as Zod schemas (`*Schema`, used to check
// them at runtime) with types derived from them. The schemas aren't ported:
// wrapping the map is the parse step here, and unknown fields stay in it.

/// An annotation on text content, told apart by [type].
///
/// Holds the fields shared by all text annotations.
extension type TextAnnotation.fromJson(Map<String, Object?> json) {
  String? get type => json['type'] as String?;

  /// Start of the annotated segment (in bytes).
  int? get startIndex => _int(json['start_index']);

  /// End of the annotated segment, exclusive.
  int? get endIndex => _int(json['end_index']);
}

/// A URL citation annotation.
extension type UrlCitation.fromJson(Map<String, Object?> json)
    implements TextAnnotation {
  /// The URL.
  String? get url => json['url'] as String?;

  /// The title of the URL.
  String? get title => json['title'] as String?;
}

/// A file citation annotation.
extension type FileCitation.fromJson(Map<String, Object?> json)
    implements TextAnnotation {
  /// The URI of the file.
  String? get documentUri => json['document_uri'] as String?;

  /// The name of the file.
  String? get fileName => json['file_name'] as String?;

  /// Source attributed for a portion of the text.
  String? get source => json['source'] as String?;

  /// Page number of the cited document, if applicable.
  int? get pageNumber => _int(json['page_number']);

  /// Media ID in case of image citations, if applicable.
  String? get mediaId => json['media_id'] as String?;

  /// User-provided metadata about the retrieved context.
  Map<String, Object?>? get customMetadata => _map(json['custom_metadata']);
}

/// A place (Google Maps) citation annotation.
extension type PlaceCitation.fromJson(Map<String, Object?> json)
    implements TextAnnotation {
  /// Title of the place.
  String? get name => json['name'] as String?;

  /// The ID of the place, in `places/{place_id}` format.
  String? get placeId => json['place_id'] as String?;

  /// URI reference of the place.
  String? get url => json['url'] as String?;

  /// Review snippets about features of the place: `{review_id, title, url}`.
  List<Map<String, Object?>>? get reviewSnippets =>
      _wrapAll(json['review_snippets'], (m) => m);
}

/// Speech annotation for text content. Used as input to TTS models to assign
/// a turn to a speaker and set its delivery style.
extension type SpeechAnnotation.fromJson(Map<String, Object?> json)
    implements TextAnnotation {
  SpeechAnnotation({String? speaker, String? style})
    : this.fromJson({
        'type': 'speech_metadata',
        'speaker': ?speaker,
        'style': ?style,
      });

  /// The speaker to associate with this turn.
  String? get speaker => json['speaker'] as String?;

  /// Style instruction for the speech synthesis.
  String? get style => json['style'] as String?;
}

/// Word-level speech recognition annotation for transcription output.
extension type WordInfo.fromJson(Map<String, Object?> json)
    implements TextAnnotation {
  /// The transcribed word.
  String? get text => json['text'] as String?;

  /// Start offset in time of the word relative to the start of the audio.
  String? get startOffset => json['start_offset'] as String?;

  /// End offset in time of the word relative to the start of the audio.
  String? get endOffset => json['end_offset'] as String?;

  /// Speaker label for this word (e.g. "spk_1").
  String? get speaker => json['speaker'] as String?;
}

/// A text content block.
extension type TextContent.fromJson(Map<String, Object?> json)
    implements Content {
  TextContent({String? text, List<TextAnnotation>? annotations})
    : this.fromJson({
        'type': 'text',
        'text': ?text,
        'annotations': ?annotations,
      });

  /// The text content.
  String? get text => json['text'] as String?;

  /// Annotations on the text: citations on model output, or speech metadata
  /// on TTS input.
  List<TextAnnotation>? get annotations =>
      _wrapAll(json['annotations'], TextAnnotation.fromJson);
  set annotations(List<TextAnnotation>? value) =>
      _set(json, 'annotations', value);
}

/// The resolution of the media.
extension type const MediaResolution(String value) {
  static const low = MediaResolution('low');
  static const medium = MediaResolution('medium');
  static const high = MediaResolution('high');
  static const ultraHigh = MediaResolution('ultra_high');
}

/// An image content block.
extension type ImageContent.fromJson(Map<String, Object?> json)
    implements Content {
  ImageContent({
    String? data,
    String? uri,
    String? mimeType,
    MediaResolution? resolution,
  }) : this.fromJson({
         'type': 'image',
         'data': ?data,
         'uri': ?uri,
         'mime_type': ?mimeType,
         'resolution': ?resolution,
       });

  /// The image content (base64).
  String? get data => json['data'] as String?;

  /// The URI of the image.
  String? get uri => json['uri'] as String?;

  /// The mime type of the image.
  String? get mimeType => json['mime_type'] as String?;

  /// The resolution of the media.
  MediaResolution? get resolution =>
      _wrap(json['resolution'], MediaResolution.new);
}

/// An audio content block.
extension type AudioContent.fromJson(Map<String, Object?> json)
    implements Content {
  AudioContent({String? data, String? uri, String? mimeType})
    : this.fromJson({
        'type': 'audio',
        'data': ?data,
        'uri': ?uri,
        'mime_type': ?mimeType,
      });

  /// The audio content (base64).
  String? get data => json['data'] as String?;

  /// The URI of the audio.
  String? get uri => json['uri'] as String?;

  /// The mime type of the audio.
  String? get mimeType => json['mime_type'] as String?;
}

/// A document content block.
extension type DocumentContent.fromJson(Map<String, Object?> json)
    implements Content {
  DocumentContent({String? data, String? uri, String? mimeType})
    : this.fromJson({
        'type': 'document',
        'data': ?data,
        'uri': ?uri,
        'mime_type': ?mimeType,
      });

  /// The document content (base64).
  String? get data => json['data'] as String?;

  /// The URI of the document.
  String? get uri => json['uri'] as String?;

  /// The mime type of the document.
  String? get mimeType => json['mime_type'] as String?;
}

/// A video content block.
extension type VideoContent.fromJson(Map<String, Object?> json)
    implements Content {
  VideoContent({
    String? data,
    String? uri,
    String? mimeType,
    MediaResolution? resolution,
    VideoProcessing? processing,
  }) : this.fromJson({
         'type': 'video',
         'data': ?data,
         'uri': ?uri,
         'mime_type': ?mimeType,
         'resolution': ?resolution,
         'processing': ?processing,
       });

  /// The video content (base64).
  String? get data => json['data'] as String?;

  /// The URI of the video.
  String? get uri => json['uri'] as String?;

  /// The mime type of the video.
  String? get mimeType => json['mime_type'] as String?;

  /// The resolution of the media.
  MediaResolution? get resolution =>
      _wrap(json['resolution'], MediaResolution.new);

  /// How the model reads the video: `static` (frames at 1 FPS, the default)
  /// or `agentic` (the model explores the timeline and loads only what it
  /// needs; supported by newer models).
  VideoProcessing? get processing =>
      _wrap(json['processing'], VideoProcessing.new);
}

/// How the model reads a video input.
extension type const VideoProcessing(String value) {
  static const static_ = VideoProcessing('static');
  static const agentic = VideoProcessing('agentic');
}

/// A thought content block.
extension type ThoughtContent.fromJson(Map<String, Object?> json)
    implements Content {
  ThoughtContent({String? signature, List<Content>? summary})
    : this.fromJson({
        'type': 'thought',
        'signature': ?signature,
        'summary': ?summary,
      });

  /// Signature to match the backend source to be part of the generation.
  String? get signature => json['signature'] as String?;

  /// A summary of the thought: [TextContent] or [ImageContent] items.
  List<Content>? get summary => _wrapAll(json['summary'], Content.fromJson);
}

/// A function tool call content block.
extension type FunctionCallContent.fromJson(Map<String, Object?> json)
    implements Content {
  FunctionCallContent({
    required String name,
    required String id,
    Map<String, Object?>? arguments,
  }) : this.fromJson({
         'type': 'function_call',
         'name': name,
         'arguments': ?arguments,
         'id': id,
       });

  /// The name of the tool to call.
  String? get name => json['name'] as String?;

  /// The arguments to pass to the function.
  Map<String, Object?>? get arguments => _map(json['arguments']);

  /// A unique ID for this specific tool call.
  String? get id => json['id'] as String?;
}

/// A function tool result content block.
extension type FunctionResultContent.fromJson(Map<String, Object?> json)
    implements Content {
  FunctionResultContent({
    required String name,
    required String callId,
    bool? isError,
    Object? result,
  }) : this.fromJson({
         'type': 'function_result',
         'name': name,
         'is_error': ?isError,
         'result': ?result,
         'call_id': callId,
       });

  /// The name of the tool that was called.
  String? get name => json['name'] as String?;

  /// Whether the tool call resulted in an error.
  bool? get isError => json['is_error'] as bool?;

  /// The result of the tool call: a map or a string.
  Object? get result => json['result'];

  /// ID to match the ID from the function call block.
  String? get callId => json['call_id'] as String?;
}

/// The content of the response.
///
/// One of the `*Content` types above, told apart by [type]. JS also allows a
/// content block where a [Step] is expected, so this implements [Step].
extension type Content.fromJson(Map<String, Object?> json) implements Step {}

/// Model output: content the model generated.
extension type ModelOutputStep.fromJson(Map<String, Object?> json)
    implements Step {
  ModelOutputStep({List<Content>? content})
    : this.fromJson({'type': 'model_output', 'content': ?content});

  /// Optional in the spec: the server can end a response with an empty
  /// `{type: 'model_output'}` step (seen live on vertexAI with Google Maps).
  List<Content>? get content => _wrapAll(json['content'], Content.fromJson);
}

/// User input: content sent to the model.
extension type UserInputStep.fromJson(Map<String, Object?> json)
    implements Step {
  UserInputStep({required List<Content> content})
    : this.fromJson({'type': 'user_input', 'content': content});

  List<Content>? get content => _wrapAll(json['content'], Content.fromJson);
}

// Tool call/result steps: only `type` and the ids are required here. The spec
// marks more fields as required, but the platform omits them at times (e.g.
// a `google_search_call` without `arguments`, a `google_search_result`
// without `result`, seen live on vertexAI), so every content field is
// optional and only sent back when present.

extension type GoogleSearchCallStep.fromJson(Map<String, Object?> json)
    implements Step {
  GoogleSearchCallStep({
    required String id,
    Map<String, Object?>? arguments,
    String? searchType,
    String? signature,
  }) : this.fromJson({
         'type': 'google_search_call',
         'id': id,
         'arguments': ?arguments,
         'search_type': ?searchType,
         'signature': ?signature,
       });

  String? get id => json['id'] as String?;

  /// `{queries?: string[]}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);

  /// `web_search`, `image_search` or `enterprise_web_search`.
  String? get searchType => json['search_type'] as String?;
  String? get signature => json['signature'] as String?;
}

extension type GoogleSearchResultStep.fromJson(Map<String, Object?> json)
    implements Step {
  GoogleSearchResultStep({
    required String callId,
    Object? result,
    bool? isError,
    String? signature,
  }) : this.fromJson({
         'type': 'google_search_result',
         'call_id': callId,
         'result': ?result,
         'is_error': ?isError,
         'signature': ?signature,
       });

  String? get callId => json['call_id'] as String?;

  /// The search results: a list of maps (e.g. `[{search_suggestions}]`) or a
  /// map.
  Object? get result => json['result'];
  bool? get isError => json['is_error'] as bool?;
  String? get signature => json['signature'] as String?;
}

extension type CodeExecutionCallStep.fromJson(Map<String, Object?> json)
    implements Step {
  CodeExecutionCallStep({
    required String id,
    required Map<String, Object?> arguments,
    String? signature,
  }) : this.fromJson({
         'type': 'code_execution_call',
         'id': id,
         'arguments': arguments,
         'signature': ?signature,
       });

  String? get id => json['id'] as String?;

  /// `{code: string, language?: string, ...}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);
  String? get signature => json['signature'] as String?;
}

extension type CodeExecutionResultStep.fromJson(Map<String, Object?> json)
    implements Step {
  CodeExecutionResultStep({
    required String callId,
    required Object result,
    String? signature,
  }) : this.fromJson({
         'type': 'code_execution_result',
         'call_id': callId,
         'result': result,
         'signature': ?signature,
       });

  String? get callId => json['call_id'] as String?;

  /// A map or a string.
  Object? get result => json['result'];
  String? get signature => json['signature'] as String?;
}

extension type FunctionCallStep.fromJson(Map<String, Object?> json)
    implements Step {
  FunctionCallStep({
    required String name,
    required String id,
    Map<String, Object?>? arguments,
    String? signature,
  }) : this.fromJson({
         'type': 'function_call',
         'name': name,
         'arguments': ?arguments,
         'id': id,
         'signature': ?signature,
       });

  String? get name => json['name'] as String?;
  Map<String, Object?>? get arguments => _map(json['arguments']);
  set arguments(Map<String, Object?>? value) => _set(json, 'arguments', value);
  String? get id => json['id'] as String?;
  String? get signature => json['signature'] as String?;
}

extension type FunctionResultStep.fromJson(Map<String, Object?> json)
    implements Step {
  FunctionResultStep({
    required String callId,
    required Object result,
    String? name,
    bool? isError,
    String? signature,
  }) : this.fromJson({
         'type': 'function_result',
         'name': ?name,
         'call_id': callId,
         'is_error': ?isError,
         'result': result,
         'signature': ?signature,
       });

  String? get name => json['name'] as String?;
  String? get callId => json['call_id'] as String?;
  bool? get isError => json['is_error'] as bool?;

  /// A map, a string, or a list of [ImageContent] / [TextContent] maps.
  Object? get result => json['result'];
  String? get signature => json['signature'] as String?;
}

extension type ThoughtStep.fromJson(Map<String, Object?> json) implements Step {
  ThoughtStep({String? signature, List<Content>? summary})
    : this.fromJson({
        'type': 'thought',
        'signature': ?signature,
        'summary': ?summary,
      });

  String? get signature => json['signature'] as String?;
  set signature(String? value) => _set(json, 'signature', value);

  /// [TextContent] or [ImageContent] items.
  List<Content>? get summary => _wrapAll(json['summary'], Content.fromJson);
}

/// Agentic video understanding: the model asked to load part of a video (a
/// segment, frames or the transcript). Needs no reply.
extension type ProcessingCallStep.fromJson(Map<String, Object?> json)
    implements Step {
  ProcessingCallStep({required String id, String? signature})
    : this.fromJson({
        'type': 'processing_call',
        'id': id,
        'signature': ?signature,
      });

  String? get id => json['id'] as String?;
  String? get signature => json['signature'] as String?;
}

/// Agentic video understanding: the result of a `processing_call`.
extension type ProcessingResultStep.fromJson(Map<String, Object?> json)
    implements Step {
  ProcessingResultStep({required String callId, String? signature})
    : this.fromJson({
        'type': 'processing_result',
        'call_id': callId,
        'signature': ?signature,
      });

  String? get callId => json['call_id'] as String?;
  String? get signature => json['signature'] as String?;
}

// Server-side built-in tool steps. The server runs these tools itself; the
// steps (with their signatures) must be sent back in the history so the
// model keeps the tool results in later turns.

extension type UrlContextCallStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  UrlContextCallStep({
    required String id,
    Map<String, Object?>? arguments,
    String? signature,
  }) : this.fromJson({
         'type': 'url_context_call',
         'id': id,
         'arguments': ?arguments,
         'signature': ?signature,
       });

  String? get id => json['id'] as String?;

  /// `{urls?: string[]}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);
  String? get signature => json['signature'] as String?;
}

extension type UrlContextResultStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  UrlContextResultStep({
    required String callId,
    List<Map<String, Object?>>? result,
    bool? isError,
    String? signature,
  }) : this.fromJson({
         'type': 'url_context_result',
         'call_id': callId,
         'result': ?result,
         'is_error': ?isError,
         'signature': ?signature,
       });

  String? get callId => json['call_id'] as String?;

  /// One entry per URL: `{url, status}` (`success`, `error`, ...).
  List<Map<String, Object?>>? get result => _wrapAll(json['result'], (m) => m);
  bool? get isError => json['is_error'] as bool?;
  String? get signature => json['signature'] as String?;
}

extension type FileSearchCallStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  FileSearchCallStep({required String id, String? signature})
    : this.fromJson({
        'type': 'file_search_call',
        'id': id,
        'signature': ?signature,
      });

  String? get id => json['id'] as String?;
  String? get signature => json['signature'] as String?;
}

extension type FileSearchResultStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  FileSearchResultStep({
    required String callId,
    List<Map<String, Object?>>? result,
    String? signature,
  }) : this.fromJson({
         'type': 'file_search_result',
         'call_id': callId,
         'result': ?result,
         'signature': ?signature,
       });

  String? get callId => json['call_id'] as String?;

  /// Not in the spec's step schema, but the streamed delta carries it (and
  /// the stream assembly copies it into the step), so it's kept.
  List<Map<String, Object?>>? get result => _wrapAll(json['result'], (m) => m);
  String? get signature => json['signature'] as String?;
}

extension type GoogleMapsCallStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  GoogleMapsCallStep({
    required String id,
    Map<String, Object?>? arguments,
    String? signature,
  }) : this.fromJson({
         'type': 'google_maps_call',
         'id': id,
         'arguments': ?arguments,
         'signature': ?signature,
       });

  String? get id => json['id'] as String?;

  /// `{queries?: string[]}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);
  String? get signature => json['signature'] as String?;
}

extension type GoogleMapsResultStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  GoogleMapsResultStep({
    required String callId,
    List<Map<String, Object?>>? result,
    String? signature,
  }) : this.fromJson({
         'type': 'google_maps_result',
         'call_id': callId,
         'result': ?result,
         'signature': ?signature,
       });

  String? get callId => json['call_id'] as String?;

  /// e.g. `[{places: [{place_id, name, url}]}]`.
  List<Map<String, Object?>>? get result => _wrapAll(json['result'], (m) => m);
  String? get signature => json['signature'] as String?;
}

extension type McpServerToolCallStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  McpServerToolCallStep({
    required String id,
    String? name,
    String? serverName,
    Map<String, Object?>? arguments,
  }) : this.fromJson({
         'type': 'mcp_server_tool_call',
         'id': id,
         'name': ?name,
         'server_name': ?serverName,
         'arguments': ?arguments,
       });

  String? get id => json['id'] as String?;
  String? get name => json['name'] as String?;
  String? get serverName => json['server_name'] as String?;
  Map<String, Object?>? get arguments => _map(json['arguments']);
}

extension type McpServerToolResultStep.fromJson(Map<String, Object?> json)
    implements BuiltInToolStep {
  McpServerToolResultStep({
    required String callId,
    String? name,
    String? serverName,
    Object? result,
  }) : this.fromJson({
         'type': 'mcp_server_tool_result',
         'call_id': callId,
         'name': ?name,
         'server_name': ?serverName,
         'result': ?result,
       });

  String? get callId => json['call_id'] as String?;
  String? get name => json['name'] as String?;
  String? get serverName => json['server_name'] as String?;

  /// A map, a string, or a list of [ImageContent] / [TextContent] maps.
  Object? get result => json['result'];
}

/// One of the server-side built-in tool steps above.
extension type BuiltInToolStep.fromJson(Map<String, Object?> json)
    implements Step {}

/// A step in the interaction: one of the `*Step` types above, or a
/// [Content] block, told apart by [type].
extension type Step.fromJson(Map<String, Object?> json) {
  String? get type => json['type'] as String?;
}

/// The token count for a single response modality.
extension type ModalityTokens.fromJson(Map<String, Object?> json) {
  /// The modality associated with the token count.
  ResponseModality? get modality =>
      _wrap(json['modality'], ResponseModality.new);

  /// Number of tokens for the modality.
  int? get tokens => _int(json['tokens']);
}

/// The number of times a grounding tool was used.
extension type GroundingToolCount.fromJson(Map<String, Object?> json) {
  /// The grounding tool, e.g. `google_search` or `google_maps`.
  String? get type => json['type'] as String?;

  /// The number of times the tool was used.
  int? get count => _int(json['count']);
}

/// Statistics on the interaction request's token usage.
extension type Usage.fromJson(Map<String, Object?> json) {
  /// Number of tokens in the prompt (context).
  int? get totalInputTokens => _int(json['total_input_tokens']);

  /// A breakdown of input token usage by modality.
  List<ModalityTokens>? get inputTokensByModality =>
      _wrapAll(json['input_tokens_by_modality'], ModalityTokens.fromJson);

  /// Number of tokens in the cached part of the prompt (the cached content).
  int? get totalCachedTokens => _int(json['total_cached_tokens']);

  /// A breakdown of cached token usage by modality.
  List<ModalityTokens>? get cachedTokensByModality =>
      _wrapAll(json['cached_tokens_by_modality'], ModalityTokens.fromJson);

  /// Total number of tokens across all the generated responses.
  int? get totalOutputTokens => _int(json['total_output_tokens']);

  /// A breakdown of output token usage by modality.
  List<ModalityTokens>? get outputTokensByModality =>
      _wrapAll(json['output_tokens_by_modality'], ModalityTokens.fromJson);

  /// Number of tokens present in tool-use prompt(s).
  int? get totalToolUseTokens => _int(json['total_tool_use_tokens']);

  /// A breakdown of tool-use token usage by modality.
  List<ModalityTokens>? get toolUseTokensByModality =>
      _wrapAll(json['tool_use_tokens_by_modality'], ModalityTokens.fromJson);

  /// Number of tokens of thoughts for thinking models.
  int? get totalThoughtTokens => _int(json['total_thought_tokens']);

  /// Total token count for the interaction request (prompt + responses +
  /// other internal tokens).
  int? get totalTokens => _int(json['total_tokens']);

  /// How many times each grounding tool was used.
  List<GroundingToolCount>? get groundingToolCount =>
      _wrapAll(json['grounding_tool_count'], GroundingToolCount.fromJson);
}

/// The configuration for speech interaction.
extension type SpeechConfig.fromJson(Map<String, Object?> json) {
  SpeechConfig({String? voice, String? language, String? speaker})
    : this.fromJson({
        'voice': ?voice,
        'language': ?language,
        'speaker': ?speaker,
      });

  /// The voice of the speaker.
  String? get voice => json['voice'] as String?;

  /// The language of the speech.
  String? get language => json['language'] as String?;

  /// The speaker's name; it should match the speaker name given in the
  /// prompt.
  String? get speaker => json['speaker'] as String?;
}

/// The configuration for image interaction.
extension type ImageConfig.fromJson(Map<String, Object?> json) {
  ImageConfig({String? aspectRatio, String? imageSize})
    : this.fromJson({'aspect_ratio': ?aspectRatio, 'image_size': ?imageSize});

  /// The aspect ratio of the image.
  String? get aspectRatio => json['aspect_ratio'] as String?;

  /// The size of the image.
  String? get imageSize => json['image_size'] as String?;
}

/// The configuration for video generation (e.g. gemini-omni-1.1-flash).
extension type VideoConfig.fromJson(Map<String, Object?> json) {
  VideoConfig({String? task}) : this.fromJson({'task': ?task});

  /// The kind of generation: `text_to_video`, `image_to_video`,
  /// `reference_to_video`, `edit` or `extend`. Inferred from the prompt if
  /// not set.
  String? get task => json['task'] as String?;
}

/// Configuration parameters for model interactions.
extension type ModelGenerationConfig.fromJson(Map<String, Object?> json) {
  ModelGenerationConfig({
    double? temperature,
    double? topP,
    int? seed,
    List<String>? stopSequences,
    Object? toolChoice,
    String? thinkingLevel,
    String? thinkingSummaries,
    int? maxOutputTokens,
    Object? speechConfig,
    ImageConfig? imageConfig,
    VideoConfig? videoConfig,
  }) : this.fromJson({
         'temperature': ?temperature,
         'top_p': ?topP,
         'seed': ?seed,
         'stop_sequences': ?stopSequences,
         'tool_choice': ?toolChoice,
         'thinking_level': ?thinkingLevel,
         'thinking_summaries': ?thinkingSummaries,
         'max_output_tokens': ?maxOutputTokens,
         'speech_config': ?speechConfig,
         'image_config': ?imageConfig,
         'video_config': ?videoConfig,
       });

  /// Controls the randomness of the output.
  double? get temperature => _double(json['temperature']);

  /// The maximum cumulative probability of tokens to consider when sampling.
  double? get topP => _double(json['top_p']);

  /// Seed used in decoding for reproducibility.
  int? get seed => _int(json['seed']);

  /// A list of character sequences that will stop output interaction.
  List<String>? get stopSequences => _list(json['stop_sequences']);

  /// The tool choice for the interaction: a string (`auto`, `any`, `none`,
  /// `validated`) or an [InteractionToolChoiceConfig] map.
  Object? get toolChoice => json['tool_choice'];
  set toolChoice(Object? value) => _set(json, 'tool_choice', value);

  /// The level of thought tokens that the model should generate:
  /// `minimal`, `low`, `medium` or `high`.
  String? get thinkingLevel => json['thinking_level'] as String?;
  set thinkingLevel(String? value) => _set(json, 'thinking_level', value);

  /// Whether to include thought summaries in the response: `auto` or `none`.
  String? get thinkingSummaries => json['thinking_summaries'] as String?;
  set thinkingSummaries(String? value) =>
      _set(json, 'thinking_summaries', value);

  /// The maximum number of tokens to include in the response.
  int? get maxOutputTokens => _int(json['max_output_tokens']);

  /// Speech configuration: a list of [SpeechConfig] maps for a single
  /// speaker, or `{speakers: [...]}` for multi-speaker.
  Object? get speechConfig => json['speech_config'];
  set speechConfig(Object? value) => _set(json, 'speech_config', value);

  /// Deprecated by the API: image settings go in a `response_format` image
  /// entry. The plugin doesn't send it.
  ImageConfig? get imageConfig =>
      _wrap(json['image_config'], ImageConfig.fromJson);

  /// Configuration for video generation.
  VideoConfig? get videoConfig =>
      _wrap(json['video_config'], VideoConfig.fromJson);
}

/// Configuration for the Antigravity agent.
extension type AntigravityAgentConfig.fromJson(Map<String, Object?> json)
    implements InteractionsAgentConfig {
  AntigravityAgentConfig({String? model})
    : this.fromJson({'type': 'antigravity', 'model': ?model});

  /// The Gemini model the agent runs on (defaults to the agent's default).
  String? get model => json['model'] as String?;
}

/// The service tier.
extension type const ServiceTier(String value) {
  static const flex = ServiceTier('flex');
  static const standard = ServiceTier('standard');
  static const priority = ServiceTier('priority');
}

/// Configuration for the agent.
///
/// One of the `*AgentConfig` types (only [AntigravityAgentConfig] is ported
/// so far), told apart by [type].
extension type InteractionsAgentConfig.fromJson(Map<String, Object?> json) {
  String? get type => json['type'] as String?;
}

/// Indicates the model should return text, images, or audio.
extension type const ResponseModality(String value) {
  static const text = ResponseModality('text');
  static const image = ResponseModality('image');
  static const audio = ResponseModality('audio');
}

/// A safety setting: the threshold for blocking one harm category.
/// vertexAI only (googleAI rejects `safety_settings` with a 400).
extension type InteractionSafetySetting.fromJson(Map<String, Object?> json) {
  InteractionSafetySetting({
    required String type,
    required String threshold,
    String? method,
  }) : this.fromJson({'type': type, 'threshold': threshold, 'method': ?method});

  /// The harm category, e.g. `hate_speech`.
  String? get type => json['type'] as String?;

  /// The blocking threshold, e.g. `block_low_and_above`.
  String? get threshold => json['threshold'] as String?;

  /// Whether to block by probability (default) or by severity.
  String? get method => json['method'] as String?;
}

/// Parameters for creating interactions.
extension type CreateInteractionRequest.fromJson(Map<String, Object?> json) {
  CreateInteractionRequest({
    required Object input,
    String? previousInteractionId,
    String? model,
    String? agent,
    Object? environment,
    String? systemInstruction,
    List<InteractionTool>? tools,
    Object? responseFormat,
    List<ResponseModality>? responseModalities,
    bool? stream,
    bool? store,
    ModelGenerationConfig? generationConfig,
    InteractionsAgentConfig? agentConfig,
    ServiceTier? serviceTier,
    List<InteractionSafetySetting>? safetySettings,
    Map<String, String>? labels,
  }) : this.fromJson({
         'previous_interaction_id': ?previousInteractionId,
         'model': ?model,
         'agent': ?agent,
         'environment': ?environment,
         'input': input,
         'system_instruction': ?systemInstruction,
         'tools': ?tools,
         'response_format': ?responseFormat,
         'response_modalities': ?responseModalities,
         'stream': ?stream,
         'store': ?store,
         'generation_config': ?generationConfig,
         'agent_config': ?agentConfig,
         'service_tier': ?serviceTier,
         'safety_settings': ?safetySettings,
         'labels': ?labels,
       });

  /// The ID of the previous interaction, if any.
  String? get previousInteractionId =>
      json['previous_interaction_id'] as String?;
  set previousInteractionId(String? value) =>
      _set(json, 'previous_interaction_id', value);

  /// The model to use for this request (mutually exclusive with [agent]).
  String? get model => json['model'] as String?;

  /// The agent to use for this request (mutually exclusive with [model]).
  String? get agent => json['agent'] as String?;

  /// The environment configuration for the sandbox: a string (e.g.
  /// `remote`, or an environment ID) or a configuration map.
  Object? get environment => json['environment'];

  /// The inputs for the interaction: a string, a list of [Step] maps or one
  /// [Step] map.
  Object? get input => json['input'];

  /// System instruction for the interaction.
  String? get systemInstruction => json['system_instruction'] as String?;

  /// A list of tool declarations the model may call during interaction.
  List<InteractionTool>? get tools =>
      _wrapAll(json['tools'], InteractionTool.fromJson);

  /// The output types and their settings: one entry (`{type: 'text' |
  /// 'image' | 'audio' | 'video', ...}`) or a list of them. See
  /// toInteractionResponseFormat.
  Object? get responseFormat => json['response_format'];
  set responseFormat(Object? value) => _set(json, 'response_format', value);

  /// Deprecated by the API in favor of `response_format` entries; the plugin
  /// doesn't send it.
  List<ResponseModality>? get responseModalities => _list<String>(
    json['response_modalities'],
  )?.map(ResponseModality.new).toList();

  /// Whether the interaction will be streamed.
  bool? get stream => json['stream'] as bool?;

  /// Whether to store the response and request for later retrieval.
  bool? get store => json['store'] as bool?;

  /// Configuration parameters for the model interaction.
  ModelGenerationConfig? get generationConfig =>
      _wrap(json['generation_config'], ModelGenerationConfig.fromJson);

  /// Configuration for the agent.
  InteractionsAgentConfig? get agentConfig =>
      _wrap(json['agent_config'], InteractionsAgentConfig.fromJson);

  ServiceTier? get serviceTier => _wrap(json['service_tier'], ServiceTier.new);

  /// Safety settings. vertexAI only (googleAI rejects it with a 400).
  List<InteractionSafetySetting>? get safetySettings =>
      _wrapAll(json['safety_settings'], InteractionSafetySetting.fromJson);

  /// Key-value labels for cost tracking. vertexAI only.
  Map<String, String>? get labels =>
      (json['labels'] as Map?)?.cast<String, String>();
}

// Stream deltas (the `delta` of a `step.delta` event). Response-only.

extension type TextDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get text => json['text'] as String?;
}

extension type ImageDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get data => json['data'] as String?;
  String? get uri => json['uri'] as String?;
  String? get mimeType => json['mime_type'] as String?;
  MediaResolution? get resolution =>
      _wrap(json['resolution'], MediaResolution.new);
}

extension type AudioDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get data => json['data'] as String?;
  String? get uri => json['uri'] as String?;
  String? get mimeType => json['mime_type'] as String?;
  int? get sampleRate => _int(json['sample_rate']);
  int? get channels => _int(json['channels']);
}

extension type DocumentDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get data => json['data'] as String?;
  String? get uri => json['uri'] as String?;
  String? get mimeType => json['mime_type'] as String?;
}

extension type VideoDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get data => json['data'] as String?;
  String? get uri => json['uri'] as String?;
  String? get mimeType => json['mime_type'] as String?;
  MediaResolution? get resolution =>
      _wrap(json['resolution'], MediaResolution.new);
}

extension type ThoughtSummaryDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  Content? get content => _wrap(json['content'], Content.fromJson);
}

extension type ThoughtSignatureDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get signature => json['signature'] as String?;
}

extension type ArgumentsDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  /// A fragment of the function call's arguments, as JSON text.
  String? get arguments => json['arguments'] as String?;
}

extension type CodeExecutionCallDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  /// `{code?: string, language?: string, ...}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);
  String? get signature => json['signature'] as String?;
}

extension type UrlContextCallDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  /// `{urls?: string[]}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);
  String? get signature => json['signature'] as String?;
}

extension type GoogleSearchCallDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  /// `{queries?: string[]}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);
  String? get signature => json['signature'] as String?;
}

extension type McpServerToolCallDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get name => json['name'] as String?;
  String? get serverName => json['server_name'] as String?;
  Map<String, Object?>? get arguments => _map(json['arguments']);
}

extension type FileSearchCallDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get signature => json['signature'] as String?;
}

extension type GoogleMapsCallDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  /// `{queries?: string[]}`.
  Map<String, Object?>? get arguments => _map(json['arguments']);
  String? get signature => json['signature'] as String?;
}

extension type FunctionResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get name => json['name'] as String?;
  String? get callId => json['call_id'] as String?;
  bool? get isError => json['is_error'] as bool?;

  /// A map, a string, or a list of [ImageContent] / [TextContent] maps.
  Object? get result => json['result'];
}

extension type CodeExecutionResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get result => json['result'] as String?;
  bool? get isError => json['is_error'] as bool?;
  String? get signature => json['signature'] as String?;
}

extension type UrlContextResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  List<Map<String, Object?>>? get result => _wrapAll(json['result'], (m) => m);
  bool? get isError => json['is_error'] as bool?;
  String? get signature => json['signature'] as String?;
}

extension type GoogleSearchResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  List<Map<String, Object?>>? get result => _wrapAll(json['result'], (m) => m);
  bool? get isError => json['is_error'] as bool?;
  String? get signature => json['signature'] as String?;
}

extension type McpServerToolResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get name => json['name'] as String?;
  String? get serverName => json['server_name'] as String?;

  /// A map, a string, or a list of [ImageContent] / [TextContent] maps.
  Object? get result => json['result'];
}

extension type FileSearchResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  List<Map<String, Object?>>? get result => _wrapAll(json['result'], (m) => m);
  String? get signature => json['signature'] as String?;
}

extension type GoogleMapsResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  List<Map<String, Object?>>? get result => _wrapAll(json['result'], (m) => m);
  String? get signature => json['signature'] as String?;
}

extension type ProcessingCallDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get signature => json['signature'] as String?;
}

extension type ProcessingResultDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  String? get signature => json['signature'] as String?;
}

extension type TextAnnotationDelta.fromJson(Map<String, Object?> json)
    implements StepDeltaData {
  List<TextAnnotation>? get annotations =>
      _wrapAll(json['annotations'], TextAnnotation.fromJson);
}

/// A streamed step delta: one of the `*Delta` types above, told apart by
/// [type].
extension type StepDeltaData.fromJson(Map<String, Object?> json) {
  String? get type => json['type'] as String?;
}

// Stream events. JS writes `InteractionSseEvent` as one union of inline
// object types; here it's the base [InteractionSseEvent] (told apart by
// `eventType`) plus a type per event, named after the spec's schemas.

/// An event in an Interactions SSE stream, told apart by [eventType].
extension type InteractionSseEvent.fromJson(Map<String, Object?> json) {
  /// `interaction.created`, `interaction.completed`,
  /// `interaction.status_update`, `error`, `step.start`, `step.delta` or
  /// `step.stop`.
  String? get eventType => json['event_type'] as String?;

  /// The token to resume the stream from this event.
  String? get eventId => json['event_id'] as String?;
}

/// `interaction.created` and `interaction.completed`: the interaction so far
/// (partial: steps arrive in step events).
extension type InteractionEvent.fromJson(Map<String, Object?> json)
    implements InteractionSseEvent {
  GeminiInteraction? get interaction =>
      _wrap(json['interaction'], GeminiInteraction.fromJson);
}

/// `interaction.status_update`.
extension type InteractionStatusUpdate.fromJson(Map<String, Object?> json)
    implements InteractionSseEvent {
  /// Only present when the interaction is stored (`store: true`).
  String? get interactionId => json['interaction_id'] as String?;

  /// See [GeminiInteraction.status].
  String? get status => json['status'] as String?;
}

/// `error`.
extension type ErrorEvent.fromJson(Map<String, Object?> json)
    implements InteractionSseEvent {
  InteractionError? get error =>
      _wrap(json['error'], InteractionError.fromJson);
}

/// `step.start`: a new step at [index].
extension type StepStart.fromJson(Map<String, Object?> json)
    implements InteractionSseEvent {
  int? get index => _int(json['index']);
  Step? get step => _wrap(json['step'], Step.fromJson);
}

/// `step.delta`: more of the step at [index].
extension type StepDelta.fromJson(Map<String, Object?> json)
    implements InteractionSseEvent {
  int? get index => _int(json['index']);
  StepDeltaData? get delta => _wrap(json['delta'], StepDeltaData.fromJson);
}

/// `step.stop`: the step at [index] is complete.
extension type StepStop.fromJson(Map<String, Object?> json)
    implements InteractionSseEvent {
  int? get index => _int(json['index']);

  /// Usage so far in the interaction (sent by vertexAI).
  Usage? get usage => _wrap(json['usage'], Usage.fromJson);

  /// Usage of this step.
  Usage? get stepUsage => _wrap(json['step_usage'], Usage.fromJson);
}

/// An interaction: the response of the Interactions API.
extension type GeminiInteraction.fromJson(Map<String, Object?> json) {
  /// The name of the Model used for generating the interaction.
  String? get model => json['model'] as String?;

  /// The name of the Agent used for generating the interaction.
  String? get agent => json['agent'] as String?;

  /// The environment ID for the sandbox, if used.
  String? get environmentId => json['environment_id'] as String?;

  /// The unique identifier for the interaction: the ID to continue it with
  /// in a later request (`previous_interaction_id`).
  String? get id => json['id'] as String?;
  set id(String? value) => _set(json, 'id', value);

  /// The ID of the previous interaction, if any.
  String? get previousInteractionId =>
      json['previous_interaction_id'] as String?;

  /// The status of the interaction: `in_progress`, `queued`,
  /// `requires_action`, `completed`, `incomplete`, `failed` or `cancelled`.
  String? get status => json['status'] as String?;
  set status(String? value) => _set(json, 'status', value);

  /// The time at which the response was created in ISO 8601 format.
  String? get created => json['created'] as String?;

  /// The time at which the response was last updated in ISO 8601 format.
  String? get updated => json['updated'] as String?;

  /// The role of the interaction.
  String? get role => json['role'] as String?;

  /// Steps comprising the interaction timeline.
  ///
  /// A new list of views over the step maps: change the steps through the
  /// views, or replace the list with the setter.
  List<Step>? get steps => _wrapAll(json['steps'], Step.fromJson);
  set steps(List<Step>? value) => _set(json, 'steps', value);

  /// Statistics on the interaction request's token usage.
  Usage? get usage => _wrap(json['usage'], Usage.fromJson);
  set usage(Usage? value) => _set(json, 'usage', value);

  /// Output only. Errors recorded on the interaction. Populated when
  /// `status` is `failed` (e.g. a safety block or an unrecoverable tool-call
  /// error).
  List<InteractionError>? get errors =>
      _wrapAll(json['errors'], InteractionError.fromJson);
  set errors(List<InteractionError>? value) => _set(json, 'errors', value);
}

/// An error recorded on an interaction or sent in an SSE `error` event.
extension type InteractionError.fromJson(Map<String, Object?> json) {
  /// Error code, e.g. `safety` or `malformed_function_call`.
  String? get code => json['code'] as String?;

  /// Human-readable error message.
  String? get message => json['message'] as String?;
}

// Helpers for the getters and setters above. JSON numbers can arrive as int
// or double, and nested maps and lists as Map<String, dynamic> /
// List<dynamic>, so values are converted rather than cast.

Map<String, Object?>? _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : null;

List<T>? _list<T>(Object? value) => value is List ? value.cast<T>() : null;

int? _int(Object? value) => (value as num?)?.toInt();

double? _double(Object? value) => (value as num?)?.toDouble();

/// Wraps a nested value with [wrap] (an extension type's constructor).
R? _wrap<V, R>(Object? value, R Function(V) wrap) =>
    value is V ? wrap(value) : null;

/// Wraps each map of a nested list with [wrap].
List<R>? _wrapAll<R>(Object? value, R Function(Map<String, Object?>) wrap) =>
    value is List
    ? [for (final item in value) wrap((item as Map).cast<String, Object?>())]
    : null;

/// Sets [key] to [value], or removes it when [value] is null (like assigning
/// `undefined` in JS, which JSON.stringify leaves out).
void _set(Map<String, Object?> json, String key, Object? value) {
  if (value == null) {
    json.remove(key);
  } else {
    json[key] = value;
  }
}
