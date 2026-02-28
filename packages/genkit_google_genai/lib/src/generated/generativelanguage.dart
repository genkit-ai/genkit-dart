// ignore_for_file: unnecessary_cast, unused_import

import 'dart:convert';
import 'package:http/http.dart' as http;

/// The response message for Operations.ListOperations.
extension type ListOperationsResponse._(Map<String, Object?> _data) {
  ListOperationsResponse({
    List<Operation>? operations,
    String? nextPageToken,
    List<String>? unreachable,
  }) : this._({
    if (operations != null) 'operations': operations,
    if (nextPageToken != null) 'nextPageToken': nextPageToken,
    if (unreachable != null) 'unreachable': unreachable,
  });

  ListOperationsResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// A list of operations that matches the specified filter in the request.
  List<Operation>? get operations { final v = _data['operations']; if (v == null) return null; return (v as List).map((e) => Operation._(e as Map<String, Object?>)).toList(); }
  set operations(List<Operation>? value) => _data['operations'] = value;
  /// The standard List next-page token.
  String? get nextPageToken { final v = _data['nextPageToken']; if (v == null) return null; return v as String; }
  set nextPageToken(String? value) => _data['nextPageToken'] = value;
  /// Unordered list. Unreachable resources. Populated when the request sets `ListOperationsRequest.return_partial_success` and reads across collections. For example, when attempting to list all resources across all supported locations.
  List<String>? get unreachable { final v = _data['unreachable']; if (v == null) return null; return (v as List).cast<String>(); }
  set unreachable(List<String>? value) => _data['unreachable'] = value;
}

/// This resource represents a long-running operation that is the result of a network API call.
extension type Operation._(Map<String, Object?> _data) {
  Operation({
    String? name,
    Map<String, Object>? metadata,
    bool? done,
    Status? error,
    Map<String, Object>? response,
  }) : this._({
    if (name != null) 'name': name,
    if (metadata != null) 'metadata': metadata,
    if (done != null) 'done': done,
    if (error != null) 'error': error,
    if (response != null) 'response': response,
  });

  Operation.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The server-assigned name, which is only unique within the same service that originally returns it. If you use the default HTTP mapping, the `name` should be a resource name ending with `operations/{unique_id}`.
  String? get name { final v = _data['name']; if (v == null) return null; return v as String; }
  set name(String? value) => _data['name'] = value;
  /// Service-specific metadata associated with the operation. It typically contains progress information and common metadata such as create time. Some services might not provide such metadata. Any method that returns a long-running operation should document the metadata type, if any.
  Map<String, Object>? get metadata { final v = _data['metadata']; if (v == null) return null; return v as Map<String, Object>; }
  set metadata(Map<String, Object>? value) => _data['metadata'] = value;
  /// If the value is `false`, it means the operation is still in progress. If `true`, the operation is completed, and either `error` or `response` is available.
  bool? get done { final v = _data['done']; if (v == null) return null; return v as bool; }
  set done(bool? value) => _data['done'] = value;
  /// The error result of the operation in case of failure or cancellation.
  Status? get error { final v = _data['error']; if (v == null) return null; return Status._(v as Map<String, Object?>); }
  set error(Status? value) => _data['error'] = value;
  /// The normal, successful response of the operation. If the original method returns no data on success, such as `Delete`, the response is `google.protobuf.Empty`. If the original method is standard `Get`/`Create`/`Update`, the response should be the resource. For other methods, the response should have the type `XxxResponse`, where `Xxx` is the original method name. For example, if the original method name is `TakeSnapshot()`, the inferred response type is `TakeSnapshotResponse`.
  Map<String, Object>? get response { final v = _data['response']; if (v == null) return null; return v as Map<String, Object>; }
  set response(Map<String, Object>? value) => _data['response'] = value;
}

/// The `Status` type defines a logical error model that is suitable for different programming environments, including REST APIs and RPC APIs. It is used by [gRPC](https://github.com/grpc). Each `Status` message contains three pieces of data: error code, error message, and error details. You can find out more about this error model and how to work with it in the [API Design Guide](https://cloud.google.com/apis/design/errors).
extension type Status._(Map<String, Object?> _data) {
  Status({
    int? code,
    String? message,
    List<Map<String, Object>>? details,
  }) : this._({
    if (code != null) 'code': code,
    if (message != null) 'message': message,
    if (details != null) 'details': details,
  });

  Status.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The status code, which should be an enum value of google.rpc.Code.
  int? get code { final v = _data['code']; if (v == null) return null; return v as int; }
  set code(int? value) => _data['code'] = value;
  /// A developer-facing error message, which should be in English. Any user-facing error message should be localized and sent in the google.rpc.Status.details field, or localized by the client.
  String? get message { final v = _data['message']; if (v == null) return null; return v as String; }
  set message(String? value) => _data['message'] = value;
  /// A list of messages that carry the error details. There is a common set of message types for APIs to use.
  List<Map<String, Object>>? get details { final v = _data['details']; if (v == null) return null; return (v as List).cast<Map<String, Object>>(); }
  set details(List<Map<String, Object>>? value) => _data['details'] = value;
}

/// A generic empty message that you can re-use to avoid defining duplicated empty messages in your APIs. A typical example is to use it as the request or the response type of an API method. For instance: service Foo { rpc Bar(google.protobuf.Empty) returns (google.protobuf.Empty); }
extension type Empty._(Map<String, Object?> _data) {
  Empty() : this._({});

}

/// The request message for Operations.CancelOperation.
extension type CancelOperationRequest._(Map<String, Object?> _data) {
  CancelOperationRequest() : this._({});

}

/// Request to generate a completion from the model.
extension type GenerateContentRequest._(Map<String, Object?> _data) {
  GenerateContentRequest({
    String? model,
    List<Content>? contents,
    List<SafetySetting>? safetySettings,
    GenerationConfig? generationConfig,
    List<Tool>? tools,
    ToolConfig? toolConfig,
    Content? systemInstruction,
  }) : this._({
    if (model != null) 'model': model,
    if (contents != null) 'contents': contents,
    if (safetySettings != null) 'safetySettings': safetySettings,
    if (generationConfig != null) 'generationConfig': generationConfig,
    if (tools != null) 'tools': tools,
    if (toolConfig != null) 'toolConfig': toolConfig,
    if (systemInstruction != null) 'systemInstruction': systemInstruction,
  });

  GenerateContentRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The name of the `Model` to use for generating the completion. Format: `models/{model}`.
  String? get model { final v = _data['model']; if (v == null) return null; return v as String; }
  set model(String? value) => _data['model'] = value;
  /// Required. The content of the current conversation with the model. For single-turn queries, this is a single instance. For multi-turn queries like [chat](https://ai.google.dev/gemini-api/docs/text-generation#chat), this is a repeated field that contains the conversation history and the latest request.
  List<Content>? get contents { final v = _data['contents']; if (v == null) return null; return (v as List).map((e) => Content._(e as Map<String, Object?>)).toList(); }
  set contents(List<Content>? value) => _data['contents'] = value;
  /// Optional. A list of unique `SafetySetting` instances for blocking unsafe content. This will be enforced on the `GenerateContentRequest.contents` and `GenerateContentResponse.candidates`. There should not be more than one setting for each `SafetyCategory` type. The API will block any contents and responses that fail to meet the thresholds set by these settings. This list overrides the default settings for each `SafetyCategory` specified in the safety_settings. If there is no `SafetySetting` for a given `SafetyCategory` provided in the list, the API will use the default safety setting for that category. Harm categories HARM_CATEGORY_HATE_SPEECH, HARM_CATEGORY_SEXUALLY_EXPLICIT, HARM_CATEGORY_DANGEROUS_CONTENT, HARM_CATEGORY_HARASSMENT, HARM_CATEGORY_CIVIC_INTEGRITY are supported. Refer to the [guide](https://ai.google.dev/gemini-api/docs/safety-settings) for detailed information on available safety settings. Also refer to the [Safety guidance](https://ai.google.dev/gemini-api/docs/safety-guidance) to learn how to incorporate safety considerations in your AI applications.
  List<SafetySetting>? get safetySettings { final v = _data['safetySettings']; if (v == null) return null; return (v as List).map((e) => SafetySetting._(e as Map<String, Object?>)).toList(); }
  set safetySettings(List<SafetySetting>? value) => _data['safetySettings'] = value;
  /// Optional. Configuration options for model generation and outputs.
  GenerationConfig? get generationConfig { final v = _data['generationConfig']; if (v == null) return null; return GenerationConfig._(v as Map<String, Object?>); }
  set generationConfig(GenerationConfig? value) => _data['generationConfig'] = value;
  List<Tool>? get tools { final v = _data['tools']; if (v == null) return null; return (v as List).map((e) => Tool._(e as Map<String, Object?>)).toList(); }
  set tools(List<Tool>? value) => _data['tools'] = value;
  ToolConfig? get toolConfig { final v = _data['toolConfig']; if (v == null) return null; return ToolConfig._(v as Map<String, Object?>); }
  set toolConfig(ToolConfig? value) => _data['toolConfig'] = value;
  Content? get systemInstruction { final v = _data['systemInstruction']; if (v == null) return null; return Content._(v as Map<String, Object?>); }
  set systemInstruction(Content? value) => _data['systemInstruction'] = value;
}

/// The base structured datatype containing multi-part content of a message. A `Content` includes a `role` field designating the producer of the `Content` and a `parts` field containing multi-part data that contains the content of the message turn.
extension type Content._(Map<String, Object?> _data) {
  Content({
    List<Part>? parts,
    String? role,
  }) : this._({
    if (parts != null) 'parts': parts,
    if (role != null) 'role': role,
  });

  Content.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Ordered `Parts` that constitute a single message. Parts may have different MIME types.
  List<Part>? get parts { final v = _data['parts']; if (v == null) return null; return (v as List).map((e) => Part._(e as Map<String, Object?>)).toList(); }
  set parts(List<Part>? value) => _data['parts'] = value;
  /// Optional. The producer of the content. Must be either 'user' or 'model'. Useful to set for multi-turn conversations, otherwise can be left blank or unset.
  String? get role { final v = _data['role']; if (v == null) return null; return v as String; }
  set role(String? value) => _data['role'] = value;
}

/// A datatype containing media that is part of a multi-part `Content` message. A `Part` consists of data which has an associated datatype. A `Part` can only contain one of the accepted types in `Part.data`. A `Part` must have a fixed IANA MIME type identifying the type and subtype of the media if the `inline_data` field is filled with raw bytes.
extension type Part._(Map<String, Object?> _data) {
  Part({
    String? text,
    Blob? inlineData,
    VideoMetadata? videoMetadata,
    FunctionCall? functionCall,
    FunctionResponse? functionResponse,
    ExecutableCode? executableCode,
    CodeExecutionResult? codeExecutionResult,
    FileData? fileData,
    String? thoughtSignature,
    bool? thought,
  }) : this._({
    if (text != null) 'text': text,
    if (inlineData != null) 'inlineData': inlineData,
    if (videoMetadata != null) 'videoMetadata': videoMetadata,
    if (functionCall != null) 'functionCall': functionCall,
    if (functionResponse != null) 'functionResponse': functionResponse,
    if (executableCode != null) 'executableCode': executableCode,
    if (codeExecutionResult != null) 'codeExecutionResult': codeExecutionResult,
    if (fileData != null) 'fileData': fileData,
    if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
    if (thought != null) 'thought': thought,
  });

  Part.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Inline text.
  String? get text { final v = _data['text']; if (v == null) return null; return v as String; }
  set text(String? value) => _data['text'] = value;
  Blob? get inlineData { final v = _data['inlineData']; if (v == null) return null; return Blob._(v as Map<String, Object?>); }
  set inlineData(Blob? value) => _data['inlineData'] = value;
  /// Optional. Video metadata. The metadata should only be specified while the video data is presented in inline_data or file_data.
  VideoMetadata? get videoMetadata { final v = _data['videoMetadata']; if (v == null) return null; return VideoMetadata._(v as Map<String, Object?>); }
  set videoMetadata(VideoMetadata? value) => _data['videoMetadata'] = value;
  FunctionCall? get functionCall { final v = _data['functionCall']; if (v == null) return null; return FunctionCall._(v as Map<String, Object?>); }
  set functionCall(FunctionCall? value) => _data['functionCall'] = value;
  FunctionResponse? get functionResponse { final v = _data['functionResponse']; if (v == null) return null; return FunctionResponse._(v as Map<String, Object?>); }
  set functionResponse(FunctionResponse? value) => _data['functionResponse'] = value;
  ExecutableCode? get executableCode { final v = _data['executableCode']; if (v == null) return null; return ExecutableCode._(v as Map<String, Object?>); }
  set executableCode(ExecutableCode? value) => _data['executableCode'] = value;
  CodeExecutionResult? get codeExecutionResult { final v = _data['codeExecutionResult']; if (v == null) return null; return CodeExecutionResult._(v as Map<String, Object?>); }
  set codeExecutionResult(CodeExecutionResult? value) => _data['codeExecutionResult'] = value;
  FileData? get fileData { final v = _data['fileData']; if (v == null) return null; return FileData._(v as Map<String, Object?>); }
  set fileData(FileData? value) => _data['fileData'] = value;
  String? get thoughtSignature { final v = _data['thoughtSignature']; if (v == null) return null; return v as String; }
  set thoughtSignature(String? value) => _data['thoughtSignature'] = value;
  bool? get thought { final v = _data['thought']; if (v == null) return null; return v as bool; }
  set thought(bool? value) => _data['thought'] = value;
}

/// Raw media bytes. Text should not be sent as raw bytes, use the 'text' field.
extension type Blob._(Map<String, Object?> _data) {
  Blob({
    String? mimeType,
    String? data,
  }) : this._({
    if (mimeType != null) 'mimeType': mimeType,
    if (data != null) 'data': data,
  });

  Blob.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get mimeType { final v = _data['mimeType']; if (v == null) return null; return v as String; }
  set mimeType(String? value) => _data['mimeType'] = value;
  String? get data { final v = _data['data']; if (v == null) return null; return v as String; }
  set data(String? value) => _data['data'] = value;
}

/// Deprecated: Use `GenerateContentRequest.processing_options` instead. Metadata describes the input video content.
extension type VideoMetadata._(Map<String, Object?> _data) {
  VideoMetadata({
    String? startOffset,
    String? endOffset,
    double? fps,
  }) : this._({
    if (startOffset != null) 'startOffset': startOffset,
    if (endOffset != null) 'endOffset': endOffset,
    if (fps != null) 'fps': fps,
  });

  VideoMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. The start offset of the video.
  String? get startOffset { final v = _data['startOffset']; if (v == null) return null; return v as String; }
  set startOffset(String? value) => _data['startOffset'] = value;
  /// Optional. The end offset of the video.
  String? get endOffset { final v = _data['endOffset']; if (v == null) return null; return v as String; }
  set endOffset(String? value) => _data['endOffset'] = value;
  /// Optional. The frame rate of the video sent to the model. If not specified, the default value will be 1.0. The fps range is (0.0, 24.0].
  double? get fps { final v = _data['fps']; if (v == null) return null; return (v as num).toDouble(); }
  set fps(double? value) => _data['fps'] = value;
}

/// Safety setting, affecting the safety-blocking behavior. Passing a safety setting for a category changes the allowed probability that content is blocked.
extension type SafetySetting._(Map<String, Object?> _data) {
  SafetySetting({
    String? category,
    String? threshold,
  }) : this._({
    if (category != null) 'category': category,
    if (threshold != null) 'threshold': threshold,
  });

  SafetySetting.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The category for this setting.
  String? get category { final v = _data['category']; if (v == null) return null; return v as String; }
  set category(String? value) => _data['category'] = value;
  /// Required. Controls the probability threshold at which harm is blocked.
  String? get threshold { final v = _data['threshold']; if (v == null) return null; return v as String; }
  set threshold(String? value) => _data['threshold'] = value;
}

/// Configuration options for model generation and outputs. Not all parameters are configurable for every model.
extension type GenerationConfig._(Map<String, Object?> _data) {
  GenerationConfig({
    int? candidateCount,
    List<String>? stopSequences,
    int? maxOutputTokens,
    double? temperature,
    double? topP,
    int? topK,
    int? seed,
    Object? responseJsonSchema,
    double? presencePenalty,
    double? frequencyPenalty,
    bool? responseLogprobs,
    int? logprobs,
    bool? enableEnhancedCivicAnswers,
    String? responseMimeType,
    List<String>? responseModalities,
    SpeechConfig? speechConfig,
    ThinkingConfig? thinkingConfig,
  }) : this._({
    if (candidateCount != null) 'candidateCount': candidateCount,
    if (stopSequences != null) 'stopSequences': stopSequences,
    if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
    if (temperature != null) 'temperature': temperature,
    if (topP != null) 'topP': topP,
    if (topK != null) 'topK': topK,
    if (seed != null) 'seed': seed,
    if (responseJsonSchema != null) 'responseJsonSchema': responseJsonSchema,
    if (presencePenalty != null) 'presencePenalty': presencePenalty,
    if (frequencyPenalty != null) 'frequencyPenalty': frequencyPenalty,
    if (responseLogprobs != null) 'responseLogprobs': responseLogprobs,
    if (logprobs != null) 'logprobs': logprobs,
    if (enableEnhancedCivicAnswers != null) 'enableEnhancedCivicAnswers': enableEnhancedCivicAnswers,
    if (responseMimeType != null) 'responseMimeType': responseMimeType,
    if (responseModalities != null) 'responseModalities': responseModalities,
    if (speechConfig != null) 'speechConfig': speechConfig,
    if (thinkingConfig != null) 'thinkingConfig': thinkingConfig,
  });

  GenerationConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. Number of generated responses to return. If unset, this will default to 1. Please note that this doesn't work for previous generation models (Gemini 1.0 family)
  int? get candidateCount { final v = _data['candidateCount']; if (v == null) return null; return v as int; }
  set candidateCount(int? value) => _data['candidateCount'] = value;
  /// Optional. The set of character sequences (up to 5) that will stop output generation. If specified, the API will stop at the first appearance of a `stop_sequence`. The stop sequence will not be included as part of the response.
  List<String>? get stopSequences { final v = _data['stopSequences']; if (v == null) return null; return (v as List).cast<String>(); }
  set stopSequences(List<String>? value) => _data['stopSequences'] = value;
  /// Optional. The maximum number of tokens to include in a response candidate. Note: The default value varies by model, see the `Model.output_token_limit` attribute of the `Model` returned from the `getModel` function.
  int? get maxOutputTokens { final v = _data['maxOutputTokens']; if (v == null) return null; return v as int; }
  set maxOutputTokens(int? value) => _data['maxOutputTokens'] = value;
  /// Optional. Controls the randomness of the output. Note: The default value varies by model, see the `Model.temperature` attribute of the `Model` returned from the `getModel` function. Values can range from [0.0, 2.0].
  double? get temperature { final v = _data['temperature']; if (v == null) return null; return (v as num).toDouble(); }
  set temperature(double? value) => _data['temperature'] = value;
  /// Optional. The maximum cumulative probability of tokens to consider when sampling. The model uses combined Top-k and Top-p (nucleus) sampling. Tokens are sorted based on their assigned probabilities so that only the most likely tokens are considered. Top-k sampling directly limits the maximum number of tokens to consider, while Nucleus sampling limits the number of tokens based on the cumulative probability. Note: The default value varies by `Model` and is specified by the`Model.top_p` attribute returned from the `getModel` function. An empty `top_k` attribute indicates that the model doesn't apply top-k sampling and doesn't allow setting `top_k` on requests.
  double? get topP { final v = _data['topP']; if (v == null) return null; return (v as num).toDouble(); }
  set topP(double? value) => _data['topP'] = value;
  /// Optional. The maximum number of tokens to consider when sampling. Gemini models use Top-p (nucleus) sampling or a combination of Top-k and nucleus sampling. Top-k sampling considers the set of `top_k` most probable tokens. Models running with nucleus sampling don't allow top_k setting. Note: The default value varies by `Model` and is specified by the`Model.top_p` attribute returned from the `getModel` function. An empty `top_k` attribute indicates that the model doesn't apply top-k sampling and doesn't allow setting `top_k` on requests.
  int? get topK { final v = _data['topK']; if (v == null) return null; return v as int; }
  set topK(int? value) => _data['topK'] = value;
  /// Optional. Seed used in decoding. If not set, the request uses a randomly generated seed.
  int? get seed { final v = _data['seed']; if (v == null) return null; return v as int; }
  set seed(int? value) => _data['seed'] = value;
  /// Optional. An internal detail. Use `responseJsonSchema` rather than this field.
  Object? get responseJsonSchema { final v = _data['responseJsonSchema']; if (v == null) return null; return v as Object; }
  set responseJsonSchema(Object? value) => _data['responseJsonSchema'] = value;
  /// Optional. Presence penalty applied to the next token's logprobs if the token has already been seen in the response. This penalty is binary on/off and not dependant on the number of times the token is used (after the first). Use frequency_penalty for a penalty that increases with each use. A positive penalty will discourage the use of tokens that have already been used in the response, increasing the vocabulary. A negative penalty will encourage the use of tokens that have already been used in the response, decreasing the vocabulary.
  double? get presencePenalty { final v = _data['presencePenalty']; if (v == null) return null; return (v as num).toDouble(); }
  set presencePenalty(double? value) => _data['presencePenalty'] = value;
  /// Optional. Frequency penalty applied to the next token's logprobs, multiplied by the number of times each token has been seen in the respponse so far. A positive penalty will discourage the use of tokens that have already been used, proportional to the number of times the token has been used: The more a token is used, the more difficult it is for the model to use that token again increasing the vocabulary of responses. Caution: A _negative_ penalty will encourage the model to reuse tokens proportional to the number of times the token has been used. Small negative values will reduce the vocabulary of a response. Larger negative values will cause the model to start repeating a common token until it hits the max_output_tokens limit.
  double? get frequencyPenalty { final v = _data['frequencyPenalty']; if (v == null) return null; return (v as num).toDouble(); }
  set frequencyPenalty(double? value) => _data['frequencyPenalty'] = value;
  /// Optional. If true, export the logprobs results in response.
  bool? get responseLogprobs { final v = _data['responseLogprobs']; if (v == null) return null; return v as bool; }
  set responseLogprobs(bool? value) => _data['responseLogprobs'] = value;
  /// Optional. Only valid if response_logprobs=True. This sets the number of top logprobs to return at each decoding step in the Candidate.logprobs_result. The number must be in the range of [0, 20].
  int? get logprobs { final v = _data['logprobs']; if (v == null) return null; return v as int; }
  set logprobs(int? value) => _data['logprobs'] = value;
  /// Optional. Enables enhanced civic answers. It may not be available for all models.
  bool? get enableEnhancedCivicAnswers { final v = _data['enableEnhancedCivicAnswers']; if (v == null) return null; return v as bool; }
  set enableEnhancedCivicAnswers(bool? value) => _data['enableEnhancedCivicAnswers'] = value;
  String? get responseMimeType { final v = _data['responseMimeType']; if (v == null) return null; return v as String; }
  set responseMimeType(String? value) => _data['responseMimeType'] = value;
  List<String>? get responseModalities { final v = _data['responseModalities']; if (v == null) return null; return (v as List).cast<String>(); }
  set responseModalities(List<String>? value) => _data['responseModalities'] = value;
  SpeechConfig? get speechConfig { final v = _data['speechConfig']; if (v == null) return null; return SpeechConfig._(v as Map<String, Object?>); }
  set speechConfig(SpeechConfig? value) => _data['speechConfig'] = value;
  ThinkingConfig? get thinkingConfig { final v = _data['thinkingConfig']; if (v == null) return null; return ThinkingConfig._(v as Map<String, Object?>); }
  set thinkingConfig(ThinkingConfig? value) => _data['thinkingConfig'] = value;
}

/// Response from the model supporting multiple candidate responses. Safety ratings and content filtering are reported for both prompt in `GenerateContentResponse.prompt_feedback` and for each candidate in `finish_reason` and in `safety_ratings`. The API: - Returns either all requested candidates or none of them - Returns no candidates at all only if there was something wrong with the prompt (check `prompt_feedback`) - Reports feedback on each candidate in `finish_reason` and `safety_ratings`.
extension type GenerateContentResponse._(Map<String, Object?> _data) {
  GenerateContentResponse({
    List<Candidate>? candidates,
    PromptFeedback? promptFeedback,
    UsageMetadata? usageMetadata,
    String? modelVersion,
    String? responseId,
    ModelStatus? modelStatus,
  }) : this._({
    if (candidates != null) 'candidates': candidates,
    if (promptFeedback != null) 'promptFeedback': promptFeedback,
    if (usageMetadata != null) 'usageMetadata': usageMetadata,
    if (modelVersion != null) 'modelVersion': modelVersion,
    if (responseId != null) 'responseId': responseId,
    if (modelStatus != null) 'modelStatus': modelStatus,
  });

  GenerateContentResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Candidate responses from the model.
  List<Candidate>? get candidates { final v = _data['candidates']; if (v == null) return null; return (v as List).map((e) => Candidate._(e as Map<String, Object?>)).toList(); }
  set candidates(List<Candidate>? value) => _data['candidates'] = value;
  /// Returns the prompt's feedback related to the content filters.
  PromptFeedback? get promptFeedback { final v = _data['promptFeedback']; if (v == null) return null; return PromptFeedback._(v as Map<String, Object?>); }
  set promptFeedback(PromptFeedback? value) => _data['promptFeedback'] = value;
  /// Output only. Metadata on the generation requests' token usage.
  UsageMetadata? get usageMetadata { final v = _data['usageMetadata']; if (v == null) return null; return UsageMetadata._(v as Map<String, Object?>); }
  set usageMetadata(UsageMetadata? value) => _data['usageMetadata'] = value;
  /// Output only. The model version used to generate the response.
  String? get modelVersion { final v = _data['modelVersion']; if (v == null) return null; return v as String; }
  set modelVersion(String? value) => _data['modelVersion'] = value;
  /// Output only. response_id is used to identify each response.
  String? get responseId { final v = _data['responseId']; if (v == null) return null; return v as String; }
  set responseId(String? value) => _data['responseId'] = value;
  /// Output only. The current model status of this model.
  ModelStatus? get modelStatus { final v = _data['modelStatus']; if (v == null) return null; return ModelStatus._(v as Map<String, Object?>); }
  set modelStatus(ModelStatus? value) => _data['modelStatus'] = value;
}

/// A response candidate generated from the model.
extension type Candidate._(Map<String, Object?> _data) {
  Candidate({
    int? index,
    Content? content,
    String? finishReason,
    String? finishMessage,
    List<SafetyRating>? safetyRatings,
    CitationMetadata? citationMetadata,
    int? tokenCount,
    GroundingMetadata? groundingMetadata,
    double? avgLogprobs,
    LogprobsResult? logprobsResult,
    UrlContextMetadata? urlContextMetadata,
  }) : this._({
    if (index != null) 'index': index,
    if (content != null) 'content': content,
    if (finishReason != null) 'finishReason': finishReason,
    if (finishMessage != null) 'finishMessage': finishMessage,
    if (safetyRatings != null) 'safetyRatings': safetyRatings,
    if (citationMetadata != null) 'citationMetadata': citationMetadata,
    if (tokenCount != null) 'tokenCount': tokenCount,
    if (groundingMetadata != null) 'groundingMetadata': groundingMetadata,
    if (avgLogprobs != null) 'avgLogprobs': avgLogprobs,
    if (logprobsResult != null) 'logprobsResult': logprobsResult,
    if (urlContextMetadata != null) 'urlContextMetadata': urlContextMetadata,
  });

  Candidate.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. Index of the candidate in the list of response candidates.
  int? get index { final v = _data['index']; if (v == null) return null; return v as int; }
  set index(int? value) => _data['index'] = value;
  /// Output only. Generated content returned from the model.
  Content? get content { final v = _data['content']; if (v == null) return null; return Content._(v as Map<String, Object?>); }
  set content(Content? value) => _data['content'] = value;
  /// Optional. Output only. The reason why the model stopped generating tokens. If empty, the model has not stopped generating tokens.
  String? get finishReason { final v = _data['finishReason']; if (v == null) return null; return v as String; }
  set finishReason(String? value) => _data['finishReason'] = value;
  /// Optional. Output only. Details the reason why the model stopped generating tokens. This is populated only when `finish_reason` is set.
  String? get finishMessage { final v = _data['finishMessage']; if (v == null) return null; return v as String; }
  set finishMessage(String? value) => _data['finishMessage'] = value;
  /// List of ratings for the safety of a response candidate. There is at most one rating per category.
  List<SafetyRating>? get safetyRatings { final v = _data['safetyRatings']; if (v == null) return null; return (v as List).map((e) => SafetyRating._(e as Map<String, Object?>)).toList(); }
  set safetyRatings(List<SafetyRating>? value) => _data['safetyRatings'] = value;
  /// Output only. Citation information for model-generated candidate. This field may be populated with recitation information for any text included in the `content`. These are passages that are "recited" from copyrighted material in the foundational LLM's training data.
  CitationMetadata? get citationMetadata { final v = _data['citationMetadata']; if (v == null) return null; return CitationMetadata._(v as Map<String, Object?>); }
  set citationMetadata(CitationMetadata? value) => _data['citationMetadata'] = value;
  /// Output only. Token count for this candidate.
  int? get tokenCount { final v = _data['tokenCount']; if (v == null) return null; return v as int; }
  set tokenCount(int? value) => _data['tokenCount'] = value;
  /// Output only. Grounding metadata for the candidate. This field is populated for `GenerateContent` calls.
  GroundingMetadata? get groundingMetadata { final v = _data['groundingMetadata']; if (v == null) return null; return GroundingMetadata._(v as Map<String, Object?>); }
  set groundingMetadata(GroundingMetadata? value) => _data['groundingMetadata'] = value;
  /// Output only. Average log probability score of the candidate.
  double? get avgLogprobs { final v = _data['avgLogprobs']; if (v == null) return null; return (v as num).toDouble(); }
  set avgLogprobs(double? value) => _data['avgLogprobs'] = value;
  /// Output only. Log-likelihood scores for the response tokens and top tokens
  LogprobsResult? get logprobsResult { final v = _data['logprobsResult']; if (v == null) return null; return LogprobsResult._(v as Map<String, Object?>); }
  set logprobsResult(LogprobsResult? value) => _data['logprobsResult'] = value;
  /// Output only. Metadata related to url context retrieval tool.
  UrlContextMetadata? get urlContextMetadata { final v = _data['urlContextMetadata']; if (v == null) return null; return UrlContextMetadata._(v as Map<String, Object?>); }
  set urlContextMetadata(UrlContextMetadata? value) => _data['urlContextMetadata'] = value;
}

/// Safety rating for a piece of content. The safety rating contains the category of harm and the harm probability level in that category for a piece of content. Content is classified for safety across a number of harm categories and the probability of the harm classification is included here.
extension type SafetyRating._(Map<String, Object?> _data) {
  SafetyRating({
    String? category,
    String? probability,
    bool? blocked,
  }) : this._({
    if (category != null) 'category': category,
    if (probability != null) 'probability': probability,
    if (blocked != null) 'blocked': blocked,
  });

  SafetyRating.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The category for this rating.
  String? get category { final v = _data['category']; if (v == null) return null; return v as String; }
  set category(String? value) => _data['category'] = value;
  /// Required. The probability of harm for this content.
  String? get probability { final v = _data['probability']; if (v == null) return null; return v as String; }
  set probability(String? value) => _data['probability'] = value;
  /// Was this content blocked because of this rating?
  bool? get blocked { final v = _data['blocked']; if (v == null) return null; return v as bool; }
  set blocked(bool? value) => _data['blocked'] = value;
}

/// A collection of source attributions for a piece of content.
extension type CitationMetadata._(Map<String, Object?> _data) {
  CitationMetadata({
    List<CitationSource>? citationSources,
  }) : this._({
    if (citationSources != null) 'citationSources': citationSources,
  });

  CitationMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Citations to sources for a specific response.
  List<CitationSource>? get citationSources { final v = _data['citationSources']; if (v == null) return null; return (v as List).map((e) => CitationSource._(e as Map<String, Object?>)).toList(); }
  set citationSources(List<CitationSource>? value) => _data['citationSources'] = value;
}

/// A citation to a source for a portion of a specific response.
extension type CitationSource._(Map<String, Object?> _data) {
  CitationSource({
    int? startIndex,
    int? endIndex,
    String? uri,
    String? license,
  }) : this._({
    if (startIndex != null) 'startIndex': startIndex,
    if (endIndex != null) 'endIndex': endIndex,
    if (uri != null) 'uri': uri,
    if (license != null) 'license': license,
  });

  CitationSource.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. Start of segment of the response that is attributed to this source. Index indicates the start of the segment, measured in bytes.
  int? get startIndex { final v = _data['startIndex']; if (v == null) return null; return v as int; }
  set startIndex(int? value) => _data['startIndex'] = value;
  /// Optional. End of the attributed segment, exclusive.
  int? get endIndex { final v = _data['endIndex']; if (v == null) return null; return v as int; }
  set endIndex(int? value) => _data['endIndex'] = value;
  /// Optional. URI that is attributed as a source for a portion of the text.
  String? get uri { final v = _data['uri']; if (v == null) return null; return v as String; }
  set uri(String? value) => _data['uri'] = value;
  /// Optional. License for the GitHub project that is attributed as a source for segment. License info is required for code citations.
  String? get license { final v = _data['license']; if (v == null) return null; return v as String; }
  set license(String? value) => _data['license'] = value;
}

/// Metadata returned to client when grounding is enabled.
extension type GroundingMetadata._(Map<String, Object?> _data) {
  GroundingMetadata({
    SearchEntryPoint? searchEntryPoint,
    List<GroundingChunk>? groundingChunks,
    List<GroundingSupport>? groundingSupports,
    RetrievalMetadata? retrievalMetadata,
    List<String>? webSearchQueries,
    List<String>? imageSearchQueries,
    String? googleMapsWidgetContextToken,
  }) : this._({
    if (searchEntryPoint != null) 'searchEntryPoint': searchEntryPoint,
    if (groundingChunks != null) 'groundingChunks': groundingChunks,
    if (groundingSupports != null) 'groundingSupports': groundingSupports,
    if (retrievalMetadata != null) 'retrievalMetadata': retrievalMetadata,
    if (webSearchQueries != null) 'webSearchQueries': webSearchQueries,
    if (imageSearchQueries != null) 'imageSearchQueries': imageSearchQueries,
    if (googleMapsWidgetContextToken != null) 'googleMapsWidgetContextToken': googleMapsWidgetContextToken,
  });

  GroundingMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. Google search entry for the following-up web searches.
  SearchEntryPoint? get searchEntryPoint { final v = _data['searchEntryPoint']; if (v == null) return null; return SearchEntryPoint._(v as Map<String, Object?>); }
  set searchEntryPoint(SearchEntryPoint? value) => _data['searchEntryPoint'] = value;
  /// List of supporting references retrieved from specified grounding source. When streaming, this only contains the grounding chunks that have not been included in the grounding metadata of previous responses.
  List<GroundingChunk>? get groundingChunks { final v = _data['groundingChunks']; if (v == null) return null; return (v as List).map((e) => GroundingChunk._(e as Map<String, Object?>)).toList(); }
  set groundingChunks(List<GroundingChunk>? value) => _data['groundingChunks'] = value;
  /// List of grounding support.
  List<GroundingSupport>? get groundingSupports { final v = _data['groundingSupports']; if (v == null) return null; return (v as List).map((e) => GroundingSupport._(e as Map<String, Object?>)).toList(); }
  set groundingSupports(List<GroundingSupport>? value) => _data['groundingSupports'] = value;
  /// Metadata related to retrieval in the grounding flow.
  RetrievalMetadata? get retrievalMetadata { final v = _data['retrievalMetadata']; if (v == null) return null; return RetrievalMetadata._(v as Map<String, Object?>); }
  set retrievalMetadata(RetrievalMetadata? value) => _data['retrievalMetadata'] = value;
  /// Web search queries for the following-up web search.
  List<String>? get webSearchQueries { final v = _data['webSearchQueries']; if (v == null) return null; return (v as List).cast<String>(); }
  set webSearchQueries(List<String>? value) => _data['webSearchQueries'] = value;
  /// Image search queries used for grounding.
  List<String>? get imageSearchQueries { final v = _data['imageSearchQueries']; if (v == null) return null; return (v as List).cast<String>(); }
  set imageSearchQueries(List<String>? value) => _data['imageSearchQueries'] = value;
  /// Optional. Resource name of the Google Maps widget context token that can be used with the PlacesContextElement widget in order to render contextual data. Only populated in the case that grounding with Google Maps is enabled.
  String? get googleMapsWidgetContextToken { final v = _data['googleMapsWidgetContextToken']; if (v == null) return null; return v as String; }
  set googleMapsWidgetContextToken(String? value) => _data['googleMapsWidgetContextToken'] = value;
}

/// Google search entry point.
extension type SearchEntryPoint._(Map<String, Object?> _data) {
  SearchEntryPoint({
    String? renderedContent,
    String? sdkBlob,
  }) : this._({
    if (renderedContent != null) 'renderedContent': renderedContent,
    if (sdkBlob != null) 'sdkBlob': sdkBlob,
  });

  SearchEntryPoint.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. Web content snippet that can be embedded in a web page or an app webview.
  String? get renderedContent { final v = _data['renderedContent']; if (v == null) return null; return v as String; }
  set renderedContent(String? value) => _data['renderedContent'] = value;
  /// Optional. Base64 encoded JSON representing array of tuple.
  String? get sdkBlob { final v = _data['sdkBlob']; if (v == null) return null; return v as String; }
  set sdkBlob(String? value) => _data['sdkBlob'] = value;
}

/// A `GroundingChunk` represents a segment of supporting evidence that grounds the model's response. It can be a chunk from the web, a retrieved context from a file, or information from Google Maps.
extension type GroundingChunk._(Map<String, Object?> _data) {
  GroundingChunk({
    Web? web,
  }) : this._({
    if (web != null) 'web': web,
  });

  GroundingChunk.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Grounding chunk from the web.
  Web? get web { final v = _data['web']; if (v == null) return null; return Web._(v as Map<String, Object?>); }
  set web(Web? value) => _data['web'] = value;
}

/// Chunk from the web.
extension type Web._(Map<String, Object?> _data) {
  Web({
    String? uri,
    String? title,
  }) : this._({
    if (uri != null) 'uri': uri,
    if (title != null) 'title': title,
  });

  Web.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. URI reference of the chunk.
  String? get uri { final v = _data['uri']; if (v == null) return null; return v as String; }
  set uri(String? value) => _data['uri'] = value;
  /// Output only. Title of the chunk.
  String? get title { final v = _data['title']; if (v == null) return null; return v as String; }
  set title(String? value) => _data['title'] = value;
}

/// Grounding support.
extension type GroundingSupport._(Map<String, Object?> _data) {
  GroundingSupport({
    Segment? segment,
    List<int>? groundingChunkIndices,
    List<double>? confidenceScores,
  }) : this._({
    if (segment != null) 'segment': segment,
    if (groundingChunkIndices != null) 'groundingChunkIndices': groundingChunkIndices,
    if (confidenceScores != null) 'confidenceScores': confidenceScores,
  });

  GroundingSupport.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Segment of the content this support belongs to.
  Segment? get segment { final v = _data['segment']; if (v == null) return null; return Segment._(v as Map<String, Object?>); }
  set segment(Segment? value) => _data['segment'] = value;
  /// Optional. A list of indices (into 'grounding_chunk' in `response.candidate.grounding_metadata`) specifying the citations associated with the claim. For instance [1,3,4] means that grounding_chunk[1], grounding_chunk[3], grounding_chunk[4] are the retrieved content attributed to the claim. If the response is streaming, the grounding_chunk_indices refer to the indices across all responses. It is the client's responsibility to accumulate the grounding chunks from all responses (while maintaining the same order).
  List<int>? get groundingChunkIndices { final v = _data['groundingChunkIndices']; if (v == null) return null; return (v as List).cast<int>(); }
  set groundingChunkIndices(List<int>? value) => _data['groundingChunkIndices'] = value;
  /// Optional. Confidence score of the support references. Ranges from 0 to 1. 1 is the most confident. This list must have the same size as the grounding_chunk_indices.
  List<double>? get confidenceScores { final v = _data['confidenceScores']; if (v == null) return null; return (v as List).cast<double>(); }
  set confidenceScores(List<double>? value) => _data['confidenceScores'] = value;
}

/// Segment of the content.
extension type Segment._(Map<String, Object?> _data) {
  Segment({
    int? partIndex,
    int? startIndex,
    int? endIndex,
    String? text,
  }) : this._({
    if (partIndex != null) 'partIndex': partIndex,
    if (startIndex != null) 'startIndex': startIndex,
    if (endIndex != null) 'endIndex': endIndex,
    if (text != null) 'text': text,
  });

  Segment.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The index of a Part object within its parent Content object.
  int? get partIndex { final v = _data['partIndex']; if (v == null) return null; return v as int; }
  set partIndex(int? value) => _data['partIndex'] = value;
  /// Start index in the given Part, measured in bytes. Offset from the start of the Part, inclusive, starting at zero.
  int? get startIndex { final v = _data['startIndex']; if (v == null) return null; return v as int; }
  set startIndex(int? value) => _data['startIndex'] = value;
  /// End index in the given Part, measured in bytes. Offset from the start of the Part, exclusive, starting at zero.
  int? get endIndex { final v = _data['endIndex']; if (v == null) return null; return v as int; }
  set endIndex(int? value) => _data['endIndex'] = value;
  /// The text corresponding to the segment from the response.
  String? get text { final v = _data['text']; if (v == null) return null; return v as String; }
  set text(String? value) => _data['text'] = value;
}

/// Metadata related to retrieval in the grounding flow.
extension type RetrievalMetadata._(Map<String, Object?> _data) {
  RetrievalMetadata({
    double? googleSearchDynamicRetrievalScore,
  }) : this._({
    if (googleSearchDynamicRetrievalScore != null) 'googleSearchDynamicRetrievalScore': googleSearchDynamicRetrievalScore,
  });

  RetrievalMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. Score indicating how likely information from google search could help answer the prompt. The score is in the range [0, 1], where 0 is the least likely and 1 is the most likely. This score is only populated when google search grounding and dynamic retrieval is enabled. It will be compared to the threshold to determine whether to trigger google search.
  double? get googleSearchDynamicRetrievalScore { final v = _data['googleSearchDynamicRetrievalScore']; if (v == null) return null; return (v as num).toDouble(); }
  set googleSearchDynamicRetrievalScore(double? value) => _data['googleSearchDynamicRetrievalScore'] = value;
}

/// Logprobs Result
extension type LogprobsResult._(Map<String, Object?> _data) {
  LogprobsResult({
    double? logProbabilitySum,
    List<TopCandidates>? topCandidates,
    List<LogprobsResultCandidate>? chosenCandidates,
  }) : this._({
    if (logProbabilitySum != null) 'logProbabilitySum': logProbabilitySum,
    if (topCandidates != null) 'topCandidates': topCandidates,
    if (chosenCandidates != null) 'chosenCandidates': chosenCandidates,
  });

  LogprobsResult.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Sum of log probabilities for all tokens.
  double? get logProbabilitySum { final v = _data['logProbabilitySum']; if (v == null) return null; return (v as num).toDouble(); }
  set logProbabilitySum(double? value) => _data['logProbabilitySum'] = value;
  /// Length = total number of decoding steps.
  List<TopCandidates>? get topCandidates { final v = _data['topCandidates']; if (v == null) return null; return (v as List).map((e) => TopCandidates._(e as Map<String, Object?>)).toList(); }
  set topCandidates(List<TopCandidates>? value) => _data['topCandidates'] = value;
  /// Length = total number of decoding steps. The chosen candidates may or may not be in top_candidates.
  List<LogprobsResultCandidate>? get chosenCandidates { final v = _data['chosenCandidates']; if (v == null) return null; return (v as List).map((e) => LogprobsResultCandidate._(e as Map<String, Object?>)).toList(); }
  set chosenCandidates(List<LogprobsResultCandidate>? value) => _data['chosenCandidates'] = value;
}

/// Candidates with top log probabilities at each decoding step.
extension type TopCandidates._(Map<String, Object?> _data) {
  TopCandidates({
    List<LogprobsResultCandidate>? candidates,
  }) : this._({
    if (candidates != null) 'candidates': candidates,
  });

  TopCandidates.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Sorted by log probability in descending order.
  List<LogprobsResultCandidate>? get candidates { final v = _data['candidates']; if (v == null) return null; return (v as List).map((e) => LogprobsResultCandidate._(e as Map<String, Object?>)).toList(); }
  set candidates(List<LogprobsResultCandidate>? value) => _data['candidates'] = value;
}

/// Candidate for the logprobs token and score.
extension type LogprobsResultCandidate._(Map<String, Object?> _data) {
  LogprobsResultCandidate({
    String? token,
    int? tokenId,
    double? logProbability,
  }) : this._({
    if (token != null) 'token': token,
    if (tokenId != null) 'tokenId': tokenId,
    if (logProbability != null) 'logProbability': logProbability,
  });

  LogprobsResultCandidate.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The candidate’s token string value.
  String? get token { final v = _data['token']; if (v == null) return null; return v as String; }
  set token(String? value) => _data['token'] = value;
  /// The candidate’s token id value.
  int? get tokenId { final v = _data['tokenId']; if (v == null) return null; return v as int; }
  set tokenId(int? value) => _data['tokenId'] = value;
  /// The candidate's log probability.
  double? get logProbability { final v = _data['logProbability']; if (v == null) return null; return (v as num).toDouble(); }
  set logProbability(double? value) => _data['logProbability'] = value;
}

/// Metadata related to url context retrieval tool.
extension type UrlContextMetadata._(Map<String, Object?> _data) {
  UrlContextMetadata({
    List<UrlMetadata>? urlMetadata,
  }) : this._({
    if (urlMetadata != null) 'urlMetadata': urlMetadata,
  });

  UrlContextMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// List of url context.
  List<UrlMetadata>? get urlMetadata { final v = _data['urlMetadata']; if (v == null) return null; return (v as List).map((e) => UrlMetadata._(e as Map<String, Object?>)).toList(); }
  set urlMetadata(List<UrlMetadata>? value) => _data['urlMetadata'] = value;
}

/// Context of the a single url retrieval.
extension type UrlMetadata._(Map<String, Object?> _data) {
  UrlMetadata({
    String? retrievedUrl,
    String? urlRetrievalStatus,
  }) : this._({
    if (retrievedUrl != null) 'retrievedUrl': retrievedUrl,
    if (urlRetrievalStatus != null) 'urlRetrievalStatus': urlRetrievalStatus,
  });

  UrlMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Retrieved url by the tool.
  String? get retrievedUrl { final v = _data['retrievedUrl']; if (v == null) return null; return v as String; }
  set retrievedUrl(String? value) => _data['retrievedUrl'] = value;
  /// Status of the url retrieval.
  String? get urlRetrievalStatus { final v = _data['urlRetrievalStatus']; if (v == null) return null; return v as String; }
  set urlRetrievalStatus(String? value) => _data['urlRetrievalStatus'] = value;
}

/// A set of the feedback metadata the prompt specified in `GenerateContentRequest.content`.
extension type PromptFeedback._(Map<String, Object?> _data) {
  PromptFeedback({
    String? blockReason,
    List<SafetyRating>? safetyRatings,
  }) : this._({
    if (blockReason != null) 'blockReason': blockReason,
    if (safetyRatings != null) 'safetyRatings': safetyRatings,
  });

  PromptFeedback.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. If set, the prompt was blocked and no candidates are returned. Rephrase the prompt.
  String? get blockReason { final v = _data['blockReason']; if (v == null) return null; return v as String; }
  set blockReason(String? value) => _data['blockReason'] = value;
  /// Ratings for safety of the prompt. There is at most one rating per category.
  List<SafetyRating>? get safetyRatings { final v = _data['safetyRatings']; if (v == null) return null; return (v as List).map((e) => SafetyRating._(e as Map<String, Object?>)).toList(); }
  set safetyRatings(List<SafetyRating>? value) => _data['safetyRatings'] = value;
}

/// Metadata on the generation request's token usage.
extension type UsageMetadata._(Map<String, Object?> _data) {
  UsageMetadata({
    int? promptTokenCount,
    int? candidatesTokenCount,
    int? toolUsePromptTokenCount,
    int? thoughtsTokenCount,
    int? totalTokenCount,
    List<ModalityTokenCount>? promptTokensDetails,
    List<ModalityTokenCount>? cacheTokensDetails,
    List<ModalityTokenCount>? candidatesTokensDetails,
    List<ModalityTokenCount>? toolUsePromptTokensDetails,
    int? cachedContentTokenCount,
  }) : this._({
    if (promptTokenCount != null) 'promptTokenCount': promptTokenCount,
    if (candidatesTokenCount != null) 'candidatesTokenCount': candidatesTokenCount,
    if (toolUsePromptTokenCount != null) 'toolUsePromptTokenCount': toolUsePromptTokenCount,
    if (thoughtsTokenCount != null) 'thoughtsTokenCount': thoughtsTokenCount,
    if (totalTokenCount != null) 'totalTokenCount': totalTokenCount,
    if (promptTokensDetails != null) 'promptTokensDetails': promptTokensDetails,
    if (cacheTokensDetails != null) 'cacheTokensDetails': cacheTokensDetails,
    if (candidatesTokensDetails != null) 'candidatesTokensDetails': candidatesTokensDetails,
    if (toolUsePromptTokensDetails != null) 'toolUsePromptTokensDetails': toolUsePromptTokensDetails,
    if (cachedContentTokenCount != null) 'cachedContentTokenCount': cachedContentTokenCount,
  });

  UsageMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Number of tokens in the prompt. When `cached_content` is set, this is still the total effective prompt size meaning this includes the number of tokens in the cached content.
  int? get promptTokenCount { final v = _data['promptTokenCount']; if (v == null) return null; return v as int; }
  set promptTokenCount(int? value) => _data['promptTokenCount'] = value;
  /// Total number of tokens across all the generated response candidates.
  int? get candidatesTokenCount { final v = _data['candidatesTokenCount']; if (v == null) return null; return v as int; }
  set candidatesTokenCount(int? value) => _data['candidatesTokenCount'] = value;
  int? get toolUsePromptTokenCount { final v = _data['toolUsePromptTokenCount']; if (v == null) return null; return v as int; }
  set toolUsePromptTokenCount(int? value) => _data['toolUsePromptTokenCount'] = value;
  int? get thoughtsTokenCount { final v = _data['thoughtsTokenCount']; if (v == null) return null; return v as int; }
  set thoughtsTokenCount(int? value) => _data['thoughtsTokenCount'] = value;
  /// Total token count for the generation request (prompt + response candidates).
  int? get totalTokenCount { final v = _data['totalTokenCount']; if (v == null) return null; return v as int; }
  set totalTokenCount(int? value) => _data['totalTokenCount'] = value;
  /// Output only. List of modalities that were processed in the request input.
  List<ModalityTokenCount>? get promptTokensDetails { final v = _data['promptTokensDetails']; if (v == null) return null; return (v as List).map((e) => ModalityTokenCount._(e as Map<String, Object?>)).toList(); }
  set promptTokensDetails(List<ModalityTokenCount>? value) => _data['promptTokensDetails'] = value;
  /// Output only. List of modalities of the cached content in the request input.
  List<ModalityTokenCount>? get cacheTokensDetails { final v = _data['cacheTokensDetails']; if (v == null) return null; return (v as List).map((e) => ModalityTokenCount._(e as Map<String, Object?>)).toList(); }
  set cacheTokensDetails(List<ModalityTokenCount>? value) => _data['cacheTokensDetails'] = value;
  /// Output only. List of modalities that were returned in the response.
  List<ModalityTokenCount>? get candidatesTokensDetails { final v = _data['candidatesTokensDetails']; if (v == null) return null; return (v as List).map((e) => ModalityTokenCount._(e as Map<String, Object?>)).toList(); }
  set candidatesTokensDetails(List<ModalityTokenCount>? value) => _data['candidatesTokensDetails'] = value;
  /// Output only. List of modalities that were processed for tool-use request inputs.
  List<ModalityTokenCount>? get toolUsePromptTokensDetails { final v = _data['toolUsePromptTokensDetails']; if (v == null) return null; return (v as List).map((e) => ModalityTokenCount._(e as Map<String, Object?>)).toList(); }
  set toolUsePromptTokensDetails(List<ModalityTokenCount>? value) => _data['toolUsePromptTokensDetails'] = value;
  int? get cachedContentTokenCount { final v = _data['cachedContentTokenCount']; if (v == null) return null; return v as int; }
  set cachedContentTokenCount(int? value) => _data['cachedContentTokenCount'] = value;
}

/// Represents token counting info for a single modality.
extension type ModalityTokenCount._(Map<String, Object?> _data) {
  ModalityTokenCount({
    String? modality,
    int? tokenCount,
  }) : this._({
    if (modality != null) 'modality': modality,
    if (tokenCount != null) 'tokenCount': tokenCount,
  });

  ModalityTokenCount.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The modality associated with this token count.
  String? get modality { final v = _data['modality']; if (v == null) return null; return v as String; }
  set modality(String? value) => _data['modality'] = value;
  /// Number of tokens.
  int? get tokenCount { final v = _data['tokenCount']; if (v == null) return null; return v as int; }
  set tokenCount(int? value) => _data['tokenCount'] = value;
}

/// The status of the underlying model. This is used to indicate the stage of the underlying model and the retirement time if applicable.
extension type ModelStatus._(Map<String, Object?> _data) {
  ModelStatus({
    String? modelStage,
    String? retirementTime,
    String? message,
  }) : this._({
    if (modelStage != null) 'modelStage': modelStage,
    if (retirementTime != null) 'retirementTime': retirementTime,
    if (message != null) 'message': message,
  });

  ModelStatus.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The stage of the underlying model.
  String? get modelStage { final v = _data['modelStage']; if (v == null) return null; return v as String; }
  set modelStage(String? value) => _data['modelStage'] = value;
  /// The time at which the model will be retired.
  String? get retirementTime { final v = _data['retirementTime']; if (v == null) return null; return v as String; }
  set retirementTime(String? value) => _data['retirementTime'] = value;
  /// A message explaining the model status.
  String? get message { final v = _data['message']; if (v == null) return null; return v as String; }
  set message(String? value) => _data['message'] = value;
}

/// Request containing the `Content` for the model to embed.
extension type EmbedContentRequest._(Map<String, Object?> _data) {
  EmbedContentRequest({
    String? model,
    Content? content,
    String? taskType,
    String? title,
    int? outputDimensionality,
  }) : this._({
    if (model != null) 'model': model,
    if (content != null) 'content': content,
    if (taskType != null) 'taskType': taskType,
    if (title != null) 'title': title,
    if (outputDimensionality != null) 'outputDimensionality': outputDimensionality,
  });

  EmbedContentRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The model's resource name. This serves as an ID for the Model to use. This name should match a model name returned by the `ListModels` method. Format: `models/{model}`
  String? get model { final v = _data['model']; if (v == null) return null; return v as String; }
  set model(String? value) => _data['model'] = value;
  /// Required. The content to embed. Only the `parts.text` fields will be counted.
  Content? get content { final v = _data['content']; if (v == null) return null; return Content._(v as Map<String, Object?>); }
  set content(Content? value) => _data['content'] = value;
  /// Optional. Optional task type for which the embeddings will be used. Not supported on earlier models (`models/embedding-001`).
  String? get taskType { final v = _data['taskType']; if (v == null) return null; return v as String; }
  set taskType(String? value) => _data['taskType'] = value;
  /// Optional. An optional title for the text. Only applicable when TaskType is `RETRIEVAL_DOCUMENT`. Note: Specifying a `title` for `RETRIEVAL_DOCUMENT` provides better quality embeddings for retrieval.
  String? get title { final v = _data['title']; if (v == null) return null; return v as String; }
  set title(String? value) => _data['title'] = value;
  /// Optional. Optional reduced dimension for the output embedding. If set, excessive values in the output embedding are truncated from the end. Supported by newer models since 2024 only. You cannot set this value if using the earlier model (`models/embedding-001`).
  int? get outputDimensionality { final v = _data['outputDimensionality']; if (v == null) return null; return v as int; }
  set outputDimensionality(int? value) => _data['outputDimensionality'] = value;
}

/// The response to an `EmbedContentRequest`.
extension type EmbedContentResponse._(Map<String, Object?> _data) {
  EmbedContentResponse({
    ContentEmbedding? embedding,
  }) : this._({
    if (embedding != null) 'embedding': embedding,
  });

  EmbedContentResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The embedding generated from the input content.
  ContentEmbedding? get embedding { final v = _data['embedding']; if (v == null) return null; return ContentEmbedding._(v as Map<String, Object?>); }
  set embedding(ContentEmbedding? value) => _data['embedding'] = value;
}

/// A list of floats representing an embedding.
extension type ContentEmbedding._(Map<String, Object?> _data) {
  ContentEmbedding({
    List<double>? values,
    List<int>? shape,
  }) : this._({
    if (values != null) 'values': values,
    if (shape != null) 'shape': shape,
  });

  ContentEmbedding.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The embedding values. This is for 3P users only and will not be populated for 1P calls.
  List<double>? get values { final v = _data['values']; if (v == null) return null; return (v as List).cast<double>(); }
  set values(List<double>? value) => _data['values'] = value;
  /// This field stores the soft tokens tensor frame shape (e.g. [1, 1, 256, 2048]).
  List<int>? get shape { final v = _data['shape']; if (v == null) return null; return (v as List).cast<int>(); }
  set shape(List<int>? value) => _data['shape'] = value;
}

/// Batch request to get embeddings from the model for a list of prompts.
extension type BatchEmbedContentsRequest._(Map<String, Object?> _data) {
  BatchEmbedContentsRequest({
    List<EmbedContentRequest>? requests,
  }) : this._({
    if (requests != null) 'requests': requests,
  });

  BatchEmbedContentsRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. Embed requests for the batch. The model in each of these requests must match the model specified `BatchEmbedContentsRequest.model`.
  List<EmbedContentRequest>? get requests { final v = _data['requests']; if (v == null) return null; return (v as List).map((e) => EmbedContentRequest._(e as Map<String, Object?>)).toList(); }
  set requests(List<EmbedContentRequest>? value) => _data['requests'] = value;
}

/// The response to a `BatchEmbedContentsRequest`.
extension type BatchEmbedContentsResponse._(Map<String, Object?> _data) {
  BatchEmbedContentsResponse({
    List<ContentEmbedding>? embeddings,
  }) : this._({
    if (embeddings != null) 'embeddings': embeddings,
  });

  BatchEmbedContentsResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The embeddings for each request, in the same order as provided in the batch request.
  List<ContentEmbedding>? get embeddings { final v = _data['embeddings']; if (v == null) return null; return (v as List).map((e) => ContentEmbedding._(e as Map<String, Object?>)).toList(); }
  set embeddings(List<ContentEmbedding>? value) => _data['embeddings'] = value;
}

/// Counts the number of tokens in the `prompt` sent to a model. Models may tokenize text differently, so each model may return a different `token_count`.
extension type CountTokensRequest._(Map<String, Object?> _data) {
  CountTokensRequest({
    List<Content>? contents,
    GenerateContentRequest? generateContentRequest,
  }) : this._({
    if (contents != null) 'contents': contents,
    if (generateContentRequest != null) 'generateContentRequest': generateContentRequest,
  });

  CountTokensRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Optional. The input given to the model as a prompt. This field is ignored when `generate_content_request` is set.
  List<Content>? get contents { final v = _data['contents']; if (v == null) return null; return (v as List).map((e) => Content._(e as Map<String, Object?>)).toList(); }
  set contents(List<Content>? value) => _data['contents'] = value;
  /// Optional. The overall input given to the `Model`. This includes the prompt as well as other model steering information like [system instructions](https://ai.google.dev/gemini-api/docs/system-instructions), and/or function declarations for [function calling](https://ai.google.dev/gemini-api/docs/function-calling). `Model`s/`Content`s and `generate_content_request`s are mutually exclusive. You can either send `Model` + `Content`s or a `generate_content_request`, but never both.
  GenerateContentRequest? get generateContentRequest { final v = _data['generateContentRequest']; if (v == null) return null; return GenerateContentRequest._(v as Map<String, Object?>); }
  set generateContentRequest(GenerateContentRequest? value) => _data['generateContentRequest'] = value;
}

/// A response from `CountTokens`. It returns the model's `token_count` for the `prompt`.
extension type CountTokensResponse._(Map<String, Object?> _data) {
  CountTokensResponse({
    int? totalTokens,
    List<ModalityTokenCount>? promptTokensDetails,
    List<ModalityTokenCount>? cacheTokensDetails,
  }) : this._({
    if (totalTokens != null) 'totalTokens': totalTokens,
    if (promptTokensDetails != null) 'promptTokensDetails': promptTokensDetails,
    if (cacheTokensDetails != null) 'cacheTokensDetails': cacheTokensDetails,
  });

  CountTokensResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The number of tokens that the `Model` tokenizes the `prompt` into. Always non-negative.
  int? get totalTokens { final v = _data['totalTokens']; if (v == null) return null; return v as int; }
  set totalTokens(int? value) => _data['totalTokens'] = value;
  /// Output only. List of modalities that were processed in the request input.
  List<ModalityTokenCount>? get promptTokensDetails { final v = _data['promptTokensDetails']; if (v == null) return null; return (v as List).map((e) => ModalityTokenCount._(e as Map<String, Object?>)).toList(); }
  set promptTokensDetails(List<ModalityTokenCount>? value) => _data['promptTokensDetails'] = value;
  /// Output only. List of modalities that were processed in the cached content.
  List<ModalityTokenCount>? get cacheTokensDetails { final v = _data['cacheTokensDetails']; if (v == null) return null; return (v as List).map((e) => ModalityTokenCount._(e as Map<String, Object?>)).toList(); }
  set cacheTokensDetails(List<ModalityTokenCount>? value) => _data['cacheTokensDetails'] = value;
}

/// Request for a `BatchGenerateContent` operation.
extension type BatchGenerateContentRequest._(Map<String, Object?> _data) {
  BatchGenerateContentRequest({
    GenerateContentBatch? batch,
  }) : this._({
    if (batch != null) 'batch': batch,
  });

  BatchGenerateContentRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The batch to create.
  GenerateContentBatch? get batch { final v = _data['batch']; if (v == null) return null; return GenerateContentBatch._(v as Map<String, Object?>); }
  set batch(GenerateContentBatch? value) => _data['batch'] = value;
}

/// A resource representing a batch of `GenerateContent` requests.
extension type GenerateContentBatch._(Map<String, Object?> _data) {
  GenerateContentBatch({
    String? model,
    String? name,
    String? displayName,
    InputConfig? inputConfig,
    GenerateContentBatchOutput? output,
    String? createTime,
    String? endTime,
    String? updateTime,
    BatchStats? batchStats,
    String? state,
    String? priority,
  }) : this._({
    if (model != null) 'model': model,
    if (name != null) 'name': name,
    if (displayName != null) 'displayName': displayName,
    if (inputConfig != null) 'inputConfig': inputConfig,
    if (output != null) 'output': output,
    if (createTime != null) 'createTime': createTime,
    if (endTime != null) 'endTime': endTime,
    if (updateTime != null) 'updateTime': updateTime,
    if (batchStats != null) 'batchStats': batchStats,
    if (state != null) 'state': state,
    if (priority != null) 'priority': priority,
  });

  GenerateContentBatch.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The name of the `Model` to use for generating the completion. Format: `models/{model}`.
  String? get model { final v = _data['model']; if (v == null) return null; return v as String; }
  set model(String? value) => _data['model'] = value;
  /// Output only. Identifier. Resource name of the batch. Format: `batches/{batch_id}`.
  String? get name { final v = _data['name']; if (v == null) return null; return v as String; }
  set name(String? value) => _data['name'] = value;
  /// Required. The user-defined name of this batch.
  String? get displayName { final v = _data['displayName']; if (v == null) return null; return v as String; }
  set displayName(String? value) => _data['displayName'] = value;
  /// Required. Input configuration of the instances on which batch processing are performed.
  InputConfig? get inputConfig { final v = _data['inputConfig']; if (v == null) return null; return InputConfig._(v as Map<String, Object?>); }
  set inputConfig(InputConfig? value) => _data['inputConfig'] = value;
  /// Output only. The output of the batch request.
  GenerateContentBatchOutput? get output { final v = _data['output']; if (v == null) return null; return GenerateContentBatchOutput._(v as Map<String, Object?>); }
  set output(GenerateContentBatchOutput? value) => _data['output'] = value;
  /// Output only. The time at which the batch was created.
  String? get createTime { final v = _data['createTime']; if (v == null) return null; return v as String; }
  set createTime(String? value) => _data['createTime'] = value;
  /// Output only. The time at which the batch processing completed.
  String? get endTime { final v = _data['endTime']; if (v == null) return null; return v as String; }
  set endTime(String? value) => _data['endTime'] = value;
  /// Output only. The time at which the batch was last updated.
  String? get updateTime { final v = _data['updateTime']; if (v == null) return null; return v as String; }
  set updateTime(String? value) => _data['updateTime'] = value;
  /// Output only. Stats about the batch.
  BatchStats? get batchStats { final v = _data['batchStats']; if (v == null) return null; return BatchStats._(v as Map<String, Object?>); }
  set batchStats(BatchStats? value) => _data['batchStats'] = value;
  /// Output only. The state of the batch.
  String? get state { final v = _data['state']; if (v == null) return null; return v as String; }
  set state(String? value) => _data['state'] = value;
  /// Optional. The priority of the batch. Batches with a higher priority value will be processed before batches with a lower priority value. Negative values are allowed. Default is 0.
  String? get priority { final v = _data['priority']; if (v == null) return null; return v as String; }
  set priority(String? value) => _data['priority'] = value;
}

/// Configures the input to the batch request.
extension type InputConfig._(Map<String, Object?> _data) {
  InputConfig({
    String? fileName,
    InlinedRequests? requests,
  }) : this._({
    if (fileName != null) 'fileName': fileName,
    if (requests != null) 'requests': requests,
  });

  InputConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The name of the `File` containing the input requests.
  String? get fileName { final v = _data['fileName']; if (v == null) return null; return v as String; }
  set fileName(String? value) => _data['fileName'] = value;
  /// The requests to be processed in the batch.
  InlinedRequests? get requests { final v = _data['requests']; if (v == null) return null; return InlinedRequests._(v as Map<String, Object?>); }
  set requests(InlinedRequests? value) => _data['requests'] = value;
}

/// The requests to be processed in the batch if provided as part of the batch creation request.
extension type InlinedRequests._(Map<String, Object?> _data) {
  InlinedRequests({
    List<InlinedRequest>? requests,
  }) : this._({
    if (requests != null) 'requests': requests,
  });

  InlinedRequests.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The requests to be processed in the batch.
  List<InlinedRequest>? get requests { final v = _data['requests']; if (v == null) return null; return (v as List).map((e) => InlinedRequest._(e as Map<String, Object?>)).toList(); }
  set requests(List<InlinedRequest>? value) => _data['requests'] = value;
}

/// The request to be processed in the batch.
extension type InlinedRequest._(Map<String, Object?> _data) {
  InlinedRequest({
    GenerateContentRequest? request,
    Map<String, Object>? metadata,
  }) : this._({
    if (request != null) 'request': request,
    if (metadata != null) 'metadata': metadata,
  });

  InlinedRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The request to be processed in the batch.
  GenerateContentRequest? get request { final v = _data['request']; if (v == null) return null; return GenerateContentRequest._(v as Map<String, Object?>); }
  set request(GenerateContentRequest? value) => _data['request'] = value;
  /// Optional. The metadata to be associated with the request.
  Map<String, Object>? get metadata { final v = _data['metadata']; if (v == null) return null; return v as Map<String, Object>; }
  set metadata(Map<String, Object>? value) => _data['metadata'] = value;
}

/// The output of a batch request. This is returned in the `BatchGenerateContentResponse` or the `GenerateContentBatch.output` field.
extension type GenerateContentBatchOutput._(Map<String, Object?> _data) {
  GenerateContentBatchOutput({
    String? responsesFile,
    InlinedResponses? inlinedResponses,
  }) : this._({
    if (responsesFile != null) 'responsesFile': responsesFile,
    if (inlinedResponses != null) 'inlinedResponses': inlinedResponses,
  });

  GenerateContentBatchOutput.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The file ID of the file containing the responses. The file will be a JSONL file with a single response per line. The responses will be `GenerateContentResponse` messages formatted as JSON. The responses will be written in the same order as the input requests.
  String? get responsesFile { final v = _data['responsesFile']; if (v == null) return null; return v as String; }
  set responsesFile(String? value) => _data['responsesFile'] = value;
  /// Output only. The responses to the requests in the batch. Returned when the batch was built using inlined requests. The responses will be in the same order as the input requests.
  InlinedResponses? get inlinedResponses { final v = _data['inlinedResponses']; if (v == null) return null; return InlinedResponses._(v as Map<String, Object?>); }
  set inlinedResponses(InlinedResponses? value) => _data['inlinedResponses'] = value;
}

/// The responses to the requests in the batch.
extension type InlinedResponses._(Map<String, Object?> _data) {
  InlinedResponses({
    List<InlinedResponse>? inlinedResponses,
  }) : this._({
    if (inlinedResponses != null) 'inlinedResponses': inlinedResponses,
  });

  InlinedResponses.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The responses to the requests in the batch.
  List<InlinedResponse>? get inlinedResponses { final v = _data['inlinedResponses']; if (v == null) return null; return (v as List).map((e) => InlinedResponse._(e as Map<String, Object?>)).toList(); }
  set inlinedResponses(List<InlinedResponse>? value) => _data['inlinedResponses'] = value;
}

/// The response to a single request in the batch.
extension type InlinedResponse._(Map<String, Object?> _data) {
  InlinedResponse({
    Status? error,
    GenerateContentResponse? response,
    Map<String, Object>? metadata,
  }) : this._({
    if (error != null) 'error': error,
    if (response != null) 'response': response,
    if (metadata != null) 'metadata': metadata,
  });

  InlinedResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The error encountered while processing the request.
  Status? get error { final v = _data['error']; if (v == null) return null; return Status._(v as Map<String, Object?>); }
  set error(Status? value) => _data['error'] = value;
  /// Output only. The response to the request.
  GenerateContentResponse? get response { final v = _data['response']; if (v == null) return null; return GenerateContentResponse._(v as Map<String, Object?>); }
  set response(GenerateContentResponse? value) => _data['response'] = value;
  /// Output only. The metadata associated with the request.
  Map<String, Object>? get metadata { final v = _data['metadata']; if (v == null) return null; return v as Map<String, Object>; }
  set metadata(Map<String, Object>? value) => _data['metadata'] = value;
}

/// Stats about the batch.
extension type BatchStats._(Map<String, Object?> _data) {
  BatchStats({
    String? requestCount,
    String? successfulRequestCount,
    String? failedRequestCount,
    String? pendingRequestCount,
  }) : this._({
    if (requestCount != null) 'requestCount': requestCount,
    if (successfulRequestCount != null) 'successfulRequestCount': successfulRequestCount,
    if (failedRequestCount != null) 'failedRequestCount': failedRequestCount,
    if (pendingRequestCount != null) 'pendingRequestCount': pendingRequestCount,
  });

  BatchStats.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The number of requests in the batch.
  String? get requestCount { final v = _data['requestCount']; if (v == null) return null; return v as String; }
  set requestCount(String? value) => _data['requestCount'] = value;
  /// Output only. The number of requests that were successfully processed.
  String? get successfulRequestCount { final v = _data['successfulRequestCount']; if (v == null) return null; return v as String; }
  set successfulRequestCount(String? value) => _data['successfulRequestCount'] = value;
  /// Output only. The number of requests that failed to be processed.
  String? get failedRequestCount { final v = _data['failedRequestCount']; if (v == null) return null; return v as String; }
  set failedRequestCount(String? value) => _data['failedRequestCount'] = value;
  /// Output only. The number of requests that are still pending processing.
  String? get pendingRequestCount { final v = _data['pendingRequestCount']; if (v == null) return null; return v as String; }
  set pendingRequestCount(String? value) => _data['pendingRequestCount'] = value;
}

/// Request for an `AsyncBatchEmbedContent` operation.
extension type AsyncBatchEmbedContentRequest._(Map<String, Object?> _data) {
  AsyncBatchEmbedContentRequest({
    EmbedContentBatch? batch,
  }) : this._({
    if (batch != null) 'batch': batch,
  });

  AsyncBatchEmbedContentRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The batch to create.
  EmbedContentBatch? get batch { final v = _data['batch']; if (v == null) return null; return EmbedContentBatch._(v as Map<String, Object?>); }
  set batch(EmbedContentBatch? value) => _data['batch'] = value;
}

/// A resource representing a batch of `EmbedContent` requests.
extension type EmbedContentBatch._(Map<String, Object?> _data) {
  EmbedContentBatch({
    String? model,
    String? name,
    String? displayName,
    InputEmbedContentConfig? inputConfig,
    EmbedContentBatchOutput? output,
    String? createTime,
    String? endTime,
    String? updateTime,
    EmbedContentBatchStats? batchStats,
    String? state,
    String? priority,
  }) : this._({
    if (model != null) 'model': model,
    if (name != null) 'name': name,
    if (displayName != null) 'displayName': displayName,
    if (inputConfig != null) 'inputConfig': inputConfig,
    if (output != null) 'output': output,
    if (createTime != null) 'createTime': createTime,
    if (endTime != null) 'endTime': endTime,
    if (updateTime != null) 'updateTime': updateTime,
    if (batchStats != null) 'batchStats': batchStats,
    if (state != null) 'state': state,
    if (priority != null) 'priority': priority,
  });

  EmbedContentBatch.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The name of the `Model` to use for generating the completion. Format: `models/{model}`.
  String? get model { final v = _data['model']; if (v == null) return null; return v as String; }
  set model(String? value) => _data['model'] = value;
  /// Output only. Identifier. Resource name of the batch. Format: `batches/{batch_id}`.
  String? get name { final v = _data['name']; if (v == null) return null; return v as String; }
  set name(String? value) => _data['name'] = value;
  /// Required. The user-defined name of this batch.
  String? get displayName { final v = _data['displayName']; if (v == null) return null; return v as String; }
  set displayName(String? value) => _data['displayName'] = value;
  /// Required. Input configuration of the instances on which batch processing are performed.
  InputEmbedContentConfig? get inputConfig { final v = _data['inputConfig']; if (v == null) return null; return InputEmbedContentConfig._(v as Map<String, Object?>); }
  set inputConfig(InputEmbedContentConfig? value) => _data['inputConfig'] = value;
  /// Output only. The output of the batch request.
  EmbedContentBatchOutput? get output { final v = _data['output']; if (v == null) return null; return EmbedContentBatchOutput._(v as Map<String, Object?>); }
  set output(EmbedContentBatchOutput? value) => _data['output'] = value;
  /// Output only. The time at which the batch was created.
  String? get createTime { final v = _data['createTime']; if (v == null) return null; return v as String; }
  set createTime(String? value) => _data['createTime'] = value;
  /// Output only. The time at which the batch processing completed.
  String? get endTime { final v = _data['endTime']; if (v == null) return null; return v as String; }
  set endTime(String? value) => _data['endTime'] = value;
  /// Output only. The time at which the batch was last updated.
  String? get updateTime { final v = _data['updateTime']; if (v == null) return null; return v as String; }
  set updateTime(String? value) => _data['updateTime'] = value;
  /// Output only. Stats about the batch.
  EmbedContentBatchStats? get batchStats { final v = _data['batchStats']; if (v == null) return null; return EmbedContentBatchStats._(v as Map<String, Object?>); }
  set batchStats(EmbedContentBatchStats? value) => _data['batchStats'] = value;
  /// Output only. The state of the batch.
  String? get state { final v = _data['state']; if (v == null) return null; return v as String; }
  set state(String? value) => _data['state'] = value;
  /// Optional. The priority of the batch. Batches with a higher priority value will be processed before batches with a lower priority value. Negative values are allowed. Default is 0.
  String? get priority { final v = _data['priority']; if (v == null) return null; return v as String; }
  set priority(String? value) => _data['priority'] = value;
}

/// Configures the input to the batch request.
extension type InputEmbedContentConfig._(Map<String, Object?> _data) {
  InputEmbedContentConfig({
    String? fileName,
    InlinedEmbedContentRequests? requests,
  }) : this._({
    if (fileName != null) 'fileName': fileName,
    if (requests != null) 'requests': requests,
  });

  InputEmbedContentConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The name of the `File` containing the input requests.
  String? get fileName { final v = _data['fileName']; if (v == null) return null; return v as String; }
  set fileName(String? value) => _data['fileName'] = value;
  /// The requests to be processed in the batch.
  InlinedEmbedContentRequests? get requests { final v = _data['requests']; if (v == null) return null; return InlinedEmbedContentRequests._(v as Map<String, Object?>); }
  set requests(InlinedEmbedContentRequests? value) => _data['requests'] = value;
}

/// The requests to be processed in the batch if provided as part of the batch creation request.
extension type InlinedEmbedContentRequests._(Map<String, Object?> _data) {
  InlinedEmbedContentRequests({
    List<InlinedEmbedContentRequest>? requests,
  }) : this._({
    if (requests != null) 'requests': requests,
  });

  InlinedEmbedContentRequests.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The requests to be processed in the batch.
  List<InlinedEmbedContentRequest>? get requests { final v = _data['requests']; if (v == null) return null; return (v as List).map((e) => InlinedEmbedContentRequest._(e as Map<String, Object?>)).toList(); }
  set requests(List<InlinedEmbedContentRequest>? value) => _data['requests'] = value;
}

/// The request to be processed in the batch.
extension type InlinedEmbedContentRequest._(Map<String, Object?> _data) {
  InlinedEmbedContentRequest({
    EmbedContentRequest? request,
    Map<String, Object>? metadata,
  }) : this._({
    if (request != null) 'request': request,
    if (metadata != null) 'metadata': metadata,
  });

  InlinedEmbedContentRequest.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The request to be processed in the batch.
  EmbedContentRequest? get request { final v = _data['request']; if (v == null) return null; return EmbedContentRequest._(v as Map<String, Object?>); }
  set request(EmbedContentRequest? value) => _data['request'] = value;
  /// Optional. The metadata to be associated with the request.
  Map<String, Object>? get metadata { final v = _data['metadata']; if (v == null) return null; return v as Map<String, Object>; }
  set metadata(Map<String, Object>? value) => _data['metadata'] = value;
}

/// The output of a batch request. This is returned in the `AsyncBatchEmbedContentResponse` or the `EmbedContentBatch.output` field.
extension type EmbedContentBatchOutput._(Map<String, Object?> _data) {
  EmbedContentBatchOutput({
    String? responsesFile,
    InlinedEmbedContentResponses? inlinedResponses,
  }) : this._({
    if (responsesFile != null) 'responsesFile': responsesFile,
    if (inlinedResponses != null) 'inlinedResponses': inlinedResponses,
  });

  EmbedContentBatchOutput.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The file ID of the file containing the responses. The file will be a JSONL file with a single response per line. The responses will be `EmbedContentResponse` messages formatted as JSON. The responses will be written in the same order as the input requests.
  String? get responsesFile { final v = _data['responsesFile']; if (v == null) return null; return v as String; }
  set responsesFile(String? value) => _data['responsesFile'] = value;
  /// Output only. The responses to the requests in the batch. Returned when the batch was built using inlined requests. The responses will be in the same order as the input requests.
  InlinedEmbedContentResponses? get inlinedResponses { final v = _data['inlinedResponses']; if (v == null) return null; return InlinedEmbedContentResponses._(v as Map<String, Object?>); }
  set inlinedResponses(InlinedEmbedContentResponses? value) => _data['inlinedResponses'] = value;
}

/// The responses to the requests in the batch.
extension type InlinedEmbedContentResponses._(Map<String, Object?> _data) {
  InlinedEmbedContentResponses({
    List<InlinedEmbedContentResponse>? inlinedResponses,
  }) : this._({
    if (inlinedResponses != null) 'inlinedResponses': inlinedResponses,
  });

  InlinedEmbedContentResponses.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The responses to the requests in the batch.
  List<InlinedEmbedContentResponse>? get inlinedResponses { final v = _data['inlinedResponses']; if (v == null) return null; return (v as List).map((e) => InlinedEmbedContentResponse._(e as Map<String, Object?>)).toList(); }
  set inlinedResponses(List<InlinedEmbedContentResponse>? value) => _data['inlinedResponses'] = value;
}

/// The response to a single request in the batch.
extension type InlinedEmbedContentResponse._(Map<String, Object?> _data) {
  InlinedEmbedContentResponse({
    Status? error,
    EmbedContentResponse? response,
    Map<String, Object>? metadata,
  }) : this._({
    if (error != null) 'error': error,
    if (response != null) 'response': response,
    if (metadata != null) 'metadata': metadata,
  });

  InlinedEmbedContentResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The error encountered while processing the request.
  Status? get error { final v = _data['error']; if (v == null) return null; return Status._(v as Map<String, Object?>); }
  set error(Status? value) => _data['error'] = value;
  /// Output only. The response to the request.
  EmbedContentResponse? get response { final v = _data['response']; if (v == null) return null; return EmbedContentResponse._(v as Map<String, Object?>); }
  set response(EmbedContentResponse? value) => _data['response'] = value;
  /// Output only. The metadata associated with the request.
  Map<String, Object>? get metadata { final v = _data['metadata']; if (v == null) return null; return v as Map<String, Object>; }
  set metadata(Map<String, Object>? value) => _data['metadata'] = value;
}

/// Stats about the batch.
extension type EmbedContentBatchStats._(Map<String, Object?> _data) {
  EmbedContentBatchStats({
    String? requestCount,
    String? successfulRequestCount,
    String? failedRequestCount,
    String? pendingRequestCount,
  }) : this._({
    if (requestCount != null) 'requestCount': requestCount,
    if (successfulRequestCount != null) 'successfulRequestCount': successfulRequestCount,
    if (failedRequestCount != null) 'failedRequestCount': failedRequestCount,
    if (pendingRequestCount != null) 'pendingRequestCount': pendingRequestCount,
  });

  EmbedContentBatchStats.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The number of requests in the batch.
  String? get requestCount { final v = _data['requestCount']; if (v == null) return null; return v as String; }
  set requestCount(String? value) => _data['requestCount'] = value;
  /// Output only. The number of requests that were successfully processed.
  String? get successfulRequestCount { final v = _data['successfulRequestCount']; if (v == null) return null; return v as String; }
  set successfulRequestCount(String? value) => _data['successfulRequestCount'] = value;
  /// Output only. The number of requests that failed to be processed.
  String? get failedRequestCount { final v = _data['failedRequestCount']; if (v == null) return null; return v as String; }
  set failedRequestCount(String? value) => _data['failedRequestCount'] = value;
  /// Output only. The number of requests that are still pending processing.
  String? get pendingRequestCount { final v = _data['pendingRequestCount']; if (v == null) return null; return v as String; }
  set pendingRequestCount(String? value) => _data['pendingRequestCount'] = value;
}

/// Information about a Generative Language Model.
extension type Model._(Map<String, Object?> _data) {
  Model({
    String? name,
    String? baseModelId,
    String? version,
    String? displayName,
    String? description,
    int? inputTokenLimit,
    int? outputTokenLimit,
    List<String>? supportedGenerationMethods,
    double? temperature,
    double? maxTemperature,
    double? topP,
    int? topK,
    bool? thinking,
  }) : this._({
    if (name != null) 'name': name,
    if (baseModelId != null) 'baseModelId': baseModelId,
    if (version != null) 'version': version,
    if (displayName != null) 'displayName': displayName,
    if (description != null) 'description': description,
    if (inputTokenLimit != null) 'inputTokenLimit': inputTokenLimit,
    if (outputTokenLimit != null) 'outputTokenLimit': outputTokenLimit,
    if (supportedGenerationMethods != null) 'supportedGenerationMethods': supportedGenerationMethods,
    if (temperature != null) 'temperature': temperature,
    if (maxTemperature != null) 'maxTemperature': maxTemperature,
    if (topP != null) 'topP': topP,
    if (topK != null) 'topK': topK,
    if (thinking != null) 'thinking': thinking,
  });

  Model.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Required. The resource name of the `Model`. Refer to [Model variants](https://ai.google.dev/gemini-api/docs/models/gemini#model-variations) for all allowed values. Format: `models/{model}` with a `{model}` naming convention of: * "{base_model_id}-{version}" Examples: * `models/gemini-1.5-flash-001`
  String? get name { final v = _data['name']; if (v == null) return null; return v as String; }
  set name(String? value) => _data['name'] = value;
  /// Required. The name of the base model, pass this to the generation request. Examples: * `gemini-1.5-flash`
  String? get baseModelId { final v = _data['baseModelId']; if (v == null) return null; return v as String; }
  set baseModelId(String? value) => _data['baseModelId'] = value;
  /// Required. The version number of the model. This represents the major version (`1.0` or `1.5`)
  String? get version { final v = _data['version']; if (v == null) return null; return v as String; }
  set version(String? value) => _data['version'] = value;
  /// The human-readable name of the model. E.g. "Gemini 1.5 Flash". The name can be up to 128 characters long and can consist of any UTF-8 characters.
  String? get displayName { final v = _data['displayName']; if (v == null) return null; return v as String; }
  set displayName(String? value) => _data['displayName'] = value;
  /// A short description of the model.
  String? get description { final v = _data['description']; if (v == null) return null; return v as String; }
  set description(String? value) => _data['description'] = value;
  /// Maximum number of input tokens allowed for this model.
  int? get inputTokenLimit { final v = _data['inputTokenLimit']; if (v == null) return null; return v as int; }
  set inputTokenLimit(int? value) => _data['inputTokenLimit'] = value;
  /// Maximum number of output tokens available for this model.
  int? get outputTokenLimit { final v = _data['outputTokenLimit']; if (v == null) return null; return v as int; }
  set outputTokenLimit(int? value) => _data['outputTokenLimit'] = value;
  /// The model's supported generation methods. The corresponding API method names are defined as Pascal case strings, such as `generateMessage` and `generateContent`.
  List<String>? get supportedGenerationMethods { final v = _data['supportedGenerationMethods']; if (v == null) return null; return (v as List).cast<String>(); }
  set supportedGenerationMethods(List<String>? value) => _data['supportedGenerationMethods'] = value;
  /// Controls the randomness of the output. Values can range over `[0.0,max_temperature]`, inclusive. A higher value will produce responses that are more varied, while a value closer to `0.0` will typically result in less surprising responses from the model. This value specifies default to be used by the backend while making the call to the model.
  double? get temperature { final v = _data['temperature']; if (v == null) return null; return (v as num).toDouble(); }
  set temperature(double? value) => _data['temperature'] = value;
  /// The maximum temperature this model can use.
  double? get maxTemperature { final v = _data['maxTemperature']; if (v == null) return null; return (v as num).toDouble(); }
  set maxTemperature(double? value) => _data['maxTemperature'] = value;
  /// For [Nucleus sampling](https://ai.google.dev/gemini-api/docs/prompting-strategies#top-p). Nucleus sampling considers the smallest set of tokens whose probability sum is at least `top_p`. This value specifies default to be used by the backend while making the call to the model.
  double? get topP { final v = _data['topP']; if (v == null) return null; return (v as num).toDouble(); }
  set topP(double? value) => _data['topP'] = value;
  /// For Top-k sampling. Top-k sampling considers the set of `top_k` most probable tokens. This value specifies default to be used by the backend while making the call to the model. If empty, indicates the model doesn't use top-k sampling, and `top_k` isn't allowed as a generation parameter.
  int? get topK { final v = _data['topK']; if (v == null) return null; return v as int; }
  set topK(int? value) => _data['topK'] = value;
  /// Whether the model supports thinking.
  bool? get thinking { final v = _data['thinking']; if (v == null) return null; return v as bool; }
  set thinking(bool? value) => _data['thinking'] = value;
}

/// Response from `ListModel` containing a paginated list of Models.
extension type ListModelsResponse._(Map<String, Object?> _data) {
  ListModelsResponse({
    List<Model>? models,
    String? nextPageToken,
  }) : this._({
    if (models != null) 'models': models,
    if (nextPageToken != null) 'nextPageToken': nextPageToken,
  });

  ListModelsResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// The returned Models.
  List<Model>? get models { final v = _data['models']; if (v == null) return null; return (v as List).map((e) => Model._(e as Map<String, Object?>)).toList(); }
  set models(List<Model>? value) => _data['models'] = value;
  /// A token, which can be sent as `page_token` to retrieve the next page. If this field is omitted, there are no more pages.
  String? get nextPageToken { final v = _data['nextPageToken']; if (v == null) return null; return v as String; }
  set nextPageToken(String? value) => _data['nextPageToken'] = value;
}

/// Metadata about the state and progress of creating a tuned model returned from the long-running operation
extension type CreateTunedModelMetadata._(Map<String, Object?> _data) {
  CreateTunedModelMetadata({
    String? tunedModel,
    int? totalSteps,
    int? completedSteps,
    double? completedPercent,
    List<TuningSnapshot>? snapshots,
  }) : this._({
    if (tunedModel != null) 'tunedModel': tunedModel,
    if (totalSteps != null) 'totalSteps': totalSteps,
    if (completedSteps != null) 'completedSteps': completedSteps,
    if (completedPercent != null) 'completedPercent': completedPercent,
    if (snapshots != null) 'snapshots': snapshots,
  });

  CreateTunedModelMetadata.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Name of the tuned model associated with the tuning operation.
  String? get tunedModel { final v = _data['tunedModel']; if (v == null) return null; return v as String; }
  set tunedModel(String? value) => _data['tunedModel'] = value;
  /// The total number of tuning steps.
  int? get totalSteps { final v = _data['totalSteps']; if (v == null) return null; return v as int; }
  set totalSteps(int? value) => _data['totalSteps'] = value;
  /// The number of steps completed.
  int? get completedSteps { final v = _data['completedSteps']; if (v == null) return null; return v as int; }
  set completedSteps(int? value) => _data['completedSteps'] = value;
  /// The completed percentage for the tuning operation.
  double? get completedPercent { final v = _data['completedPercent']; if (v == null) return null; return (v as num).toDouble(); }
  set completedPercent(double? value) => _data['completedPercent'] = value;
  /// Metrics collected during tuning.
  List<TuningSnapshot>? get snapshots { final v = _data['snapshots']; if (v == null) return null; return (v as List).map((e) => TuningSnapshot._(e as Map<String, Object?>)).toList(); }
  set snapshots(List<TuningSnapshot>? value) => _data['snapshots'] = value;
}

/// Record for a single tuning step.
extension type TuningSnapshot._(Map<String, Object?> _data) {
  TuningSnapshot({
    int? step,
    int? epoch,
    double? meanLoss,
    String? computeTime,
  }) : this._({
    if (step != null) 'step': step,
    if (epoch != null) 'epoch': epoch,
    if (meanLoss != null) 'meanLoss': meanLoss,
    if (computeTime != null) 'computeTime': computeTime,
  });

  TuningSnapshot.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  /// Output only. The tuning step.
  int? get step { final v = _data['step']; if (v == null) return null; return v as int; }
  set step(int? value) => _data['step'] = value;
  /// Output only. The epoch this step was part of.
  int? get epoch { final v = _data['epoch']; if (v == null) return null; return v as int; }
  set epoch(int? value) => _data['epoch'] = value;
  /// Output only. The mean loss of the training examples for this step.
  double? get meanLoss { final v = _data['meanLoss']; if (v == null) return null; return (v as num).toDouble(); }
  set meanLoss(double? value) => _data['meanLoss'] = value;
  /// Output only. The timestamp when this metric was computed.
  String? get computeTime { final v = _data['computeTime']; if (v == null) return null; return v as String; }
  set computeTime(String? value) => _data['computeTime'] = value;
}

extension type SpeechConfig._(Map<String, Object?> _data) {
  SpeechConfig({
    VoiceConfig? voiceConfig,
    MultiSpeakerVoiceConfig? multiSpeakerVoiceConfig,
  }) : this._({
    if (voiceConfig != null) 'voiceConfig': voiceConfig,
    if (multiSpeakerVoiceConfig != null) 'multiSpeakerVoiceConfig': multiSpeakerVoiceConfig,
  });

  SpeechConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  VoiceConfig? get voiceConfig { final v = _data['voiceConfig']; if (v == null) return null; return VoiceConfig._(v as Map<String, Object?>); }
  set voiceConfig(VoiceConfig? value) => _data['voiceConfig'] = value;
  MultiSpeakerVoiceConfig? get multiSpeakerVoiceConfig { final v = _data['multiSpeakerVoiceConfig']; if (v == null) return null; return MultiSpeakerVoiceConfig._(v as Map<String, Object?>); }
  set multiSpeakerVoiceConfig(MultiSpeakerVoiceConfig? value) => _data['multiSpeakerVoiceConfig'] = value;
}

extension type VoiceConfig._(Map<String, Object?> _data) {
  VoiceConfig({
    PrebuiltVoiceConfig? prebuiltVoiceConfig,
  }) : this._({
    if (prebuiltVoiceConfig != null) 'prebuiltVoiceConfig': prebuiltVoiceConfig,
  });

  VoiceConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  PrebuiltVoiceConfig? get prebuiltVoiceConfig { final v = _data['prebuiltVoiceConfig']; if (v == null) return null; return PrebuiltVoiceConfig._(v as Map<String, Object?>); }
  set prebuiltVoiceConfig(PrebuiltVoiceConfig? value) => _data['prebuiltVoiceConfig'] = value;
}

extension type PrebuiltVoiceConfig._(Map<String, Object?> _data) {
  PrebuiltVoiceConfig({
    String? voiceName,
  }) : this._({
    if (voiceName != null) 'voiceName': voiceName,
  });

  PrebuiltVoiceConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get voiceName { final v = _data['voiceName']; if (v == null) return null; return v as String; }
  set voiceName(String? value) => _data['voiceName'] = value;
}

extension type MultiSpeakerVoiceConfig._(Map<String, Object?> _data) {
  MultiSpeakerVoiceConfig({
    List<SpeakerVoiceConfig>? speakerVoiceConfigs,
  }) : this._({
    if (speakerVoiceConfigs != null) 'speakerVoiceConfigs': speakerVoiceConfigs,
  });

  MultiSpeakerVoiceConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  List<SpeakerVoiceConfig>? get speakerVoiceConfigs { final v = _data['speakerVoiceConfigs']; if (v == null) return null; return (v as List).map((e) => SpeakerVoiceConfig._(e as Map<String, Object?>)).toList(); }
  set speakerVoiceConfigs(List<SpeakerVoiceConfig>? value) => _data['speakerVoiceConfigs'] = value;
}

extension type SpeakerVoiceConfig._(Map<String, Object?> _data) {
  SpeakerVoiceConfig({
    String? speaker,
    VoiceConfig? voiceConfig,
  }) : this._({
    if (speaker != null) 'speaker': speaker,
    if (voiceConfig != null) 'voiceConfig': voiceConfig,
  });

  SpeakerVoiceConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get speaker { final v = _data['speaker']; if (v == null) return null; return v as String; }
  set speaker(String? value) => _data['speaker'] = value;
  VoiceConfig? get voiceConfig { final v = _data['voiceConfig']; if (v == null) return null; return VoiceConfig._(v as Map<String, Object?>); }
  set voiceConfig(VoiceConfig? value) => _data['voiceConfig'] = value;
}

extension type ThinkingConfig._(Map<String, Object?> _data) {
  ThinkingConfig({
    bool? includeThoughts,
    int? thinkingBudget,
    String? thinkingLevel,
  }) : this._({
    if (includeThoughts != null) 'includeThoughts': includeThoughts,
    if (thinkingBudget != null) 'thinkingBudget': thinkingBudget,
    if (thinkingLevel != null) 'thinkingLevel': thinkingLevel,
  });

  ThinkingConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  bool? get includeThoughts { final v = _data['includeThoughts']; if (v == null) return null; return v as bool; }
  set includeThoughts(bool? value) => _data['includeThoughts'] = value;
  int? get thinkingBudget { final v = _data['thinkingBudget']; if (v == null) return null; return v as int; }
  set thinkingBudget(int? value) => _data['thinkingBudget'] = value;
  String? get thinkingLevel { final v = _data['thinkingLevel']; if (v == null) return null; return v as String; }
  set thinkingLevel(String? value) => _data['thinkingLevel'] = value;
}

extension type FileData._(Map<String, Object?> _data) {
  FileData({
    String? mimeType,
    String? fileUri,
  }) : this._({
    if (mimeType != null) 'mimeType': mimeType,
    if (fileUri != null) 'fileUri': fileUri,
  });

  FileData.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get mimeType { final v = _data['mimeType']; if (v == null) return null; return v as String; }
  set mimeType(String? value) => _data['mimeType'] = value;
  String? get fileUri { final v = _data['fileUri']; if (v == null) return null; return v as String; }
  set fileUri(String? value) => _data['fileUri'] = value;
}

extension type Tool._(Map<String, Object?> _data) {
  Tool({
    List<FunctionDeclaration>? functionDeclarations,
    GoogleSearch? googleSearch,
    CodeExecution? codeExecution,
  }) : this._({
    if (functionDeclarations != null) 'functionDeclarations': functionDeclarations,
    if (googleSearch != null) 'googleSearch': googleSearch,
    if (codeExecution != null) 'codeExecution': codeExecution,
  });

  Tool.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  List<FunctionDeclaration>? get functionDeclarations { final v = _data['functionDeclarations']; if (v == null) return null; return (v as List).map((e) => FunctionDeclaration._(e as Map<String, Object?>)).toList(); }
  set functionDeclarations(List<FunctionDeclaration>? value) => _data['functionDeclarations'] = value;
  GoogleSearch? get googleSearch { final v = _data['googleSearch']; if (v == null) return null; return GoogleSearch._(v as Map<String, Object?>); }
  set googleSearch(GoogleSearch? value) => _data['googleSearch'] = value;
  CodeExecution? get codeExecution { final v = _data['codeExecution']; if (v == null) return null; return CodeExecution._(v as Map<String, Object?>); }
  set codeExecution(CodeExecution? value) => _data['codeExecution'] = value;
}

extension type ToolConfig._(Map<String, Object?> _data) {
  ToolConfig({
    FunctionCallingConfig? functionCallingConfig,
  }) : this._({
    if (functionCallingConfig != null) 'functionCallingConfig': functionCallingConfig,
  });

  ToolConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  FunctionCallingConfig? get functionCallingConfig { final v = _data['functionCallingConfig']; if (v == null) return null; return FunctionCallingConfig._(v as Map<String, Object?>); }
  set functionCallingConfig(FunctionCallingConfig? value) => _data['functionCallingConfig'] = value;
}

extension type FunctionCallingConfig._(Map<String, Object?> _data) {
  FunctionCallingConfig({
    String? mode,
    List<String>? allowedFunctionNames,
  }) : this._({
    if (mode != null) 'mode': mode,
    if (allowedFunctionNames != null) 'allowedFunctionNames': allowedFunctionNames,
  });

  FunctionCallingConfig.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get mode { final v = _data['mode']; if (v == null) return null; return v as String; }
  set mode(String? value) => _data['mode'] = value;
  List<String>? get allowedFunctionNames { final v = _data['allowedFunctionNames']; if (v == null) return null; return (v as List).cast<String>(); }
  set allowedFunctionNames(List<String>? value) => _data['allowedFunctionNames'] = value;
}

extension type FunctionDeclaration._(Map<String, Object?> _data) {
  FunctionDeclaration({
    String? name,
    String? description,
    Map<String, Object?>? parametersJsonSchema,
  }) : this._({
    if (name != null) 'name': name,
    if (description != null) 'description': description,
    if (parametersJsonSchema != null) 'parametersJsonSchema': parametersJsonSchema,
  });

  FunctionDeclaration.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get name { final v = _data['name']; if (v == null) return null; return v as String; }
  set name(String? value) => _data['name'] = value;
  String? get description { final v = _data['description']; if (v == null) return null; return v as String; }
  set description(String? value) => _data['description'] = value;
  Map<String, Object?>? get parametersJsonSchema { final v = _data['parametersJsonSchema']; if (v == null) return null; return v as Map<String, Object?>; }
  set parametersJsonSchema(Map<String, Object?>? value) => _data['parametersJsonSchema'] = value;
}

extension type FunctionCall._(Map<String, Object?> _data) {
  FunctionCall({
    String? id,
    String? name,
    Map<String, Object?>? args,
  }) : this._({
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    if (args != null) 'args': args,
  });

  FunctionCall.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get id { final v = _data['id']; if (v == null) return null; return v as String; }
  set id(String? value) => _data['id'] = value;
  String? get name { final v = _data['name']; if (v == null) return null; return v as String; }
  set name(String? value) => _data['name'] = value;
  Map<String, Object?>? get args { final v = _data['args']; if (v == null) return null; return v as Map<String, Object?>; }
  set args(Map<String, Object?>? value) => _data['args'] = value;
}

extension type FunctionResponse._(Map<String, Object?> _data) {
  FunctionResponse({
    String? id,
    String? name,
    Map<String, Object?>? response,
  }) : this._({
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    if (response != null) 'response': response,
  });

  FunctionResponse.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get id { final v = _data['id']; if (v == null) return null; return v as String; }
  set id(String? value) => _data['id'] = value;
  String? get name { final v = _data['name']; if (v == null) return null; return v as String; }
  set name(String? value) => _data['name'] = value;
  Map<String, Object?>? get response { final v = _data['response']; if (v == null) return null; return v as Map<String, Object?>; }
  set response(Map<String, Object?>? value) => _data['response'] = value;
}

extension type ExecutableCode._(Map<String, Object?> _data) {
  ExecutableCode({
    String? language,
    String? code,
  }) : this._({
    if (language != null) 'language': language,
    if (code != null) 'code': code,
  });

  ExecutableCode.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get language { final v = _data['language']; if (v == null) return null; return v as String; }
  set language(String? value) => _data['language'] = value;
  String? get code { final v = _data['code']; if (v == null) return null; return v as String; }
  set code(String? value) => _data['code'] = value;
}

extension type CodeExecutionResult._(Map<String, Object?> _data) {
  CodeExecutionResult({
    String? outcome,
    String? output,
  }) : this._({
    if (outcome != null) 'outcome': outcome,
    if (output != null) 'output': output,
  });

  CodeExecutionResult.fromJson(Map<String, dynamic> json) : this._(json);
  Map<String, dynamic> toJson() => _data as Map<String, dynamic>;

  String? get outcome { final v = _data['outcome']; if (v == null) return null; return v as String; }
  set outcome(String? value) => _data['outcome'] = value;
  String? get output { final v = _data['output']; if (v == null) return null; return v as String; }
  set output(String? value) => _data['output'] = value;
}

extension type GoogleSearch._(Map<String, Object?> _data) {
  GoogleSearch() : this._({});

}

extension type CodeExecution._(Map<String, Object?> _data) {
  CodeExecution() : this._({});

}

