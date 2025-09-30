import 'package:json_annotation/json_annotation.dart';
part 'genkit_schemas.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class Candidate {
  Candidate({
    required this.index,
    required this.message,
    this.usage,
    required this.finishReason,
    this.finishMessage,
    this.custom,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) =>
      _$CandidateFromJson(json);

  final double? index;

  final Message? message;

  final GenerationUsage? usage;

  final FinishReason? finishReason;

  final String? finishMessage;

  final dynamic custom;

  Map<String, dynamic> toJson() => _$CandidateToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class Message {
  Message({required this.role, required this.content, this.metadata});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  final Role? role;

  final List<Part?>? content;

  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ToolDefinition {
  ToolDefinition({
    required this.name,
    required this.description,
    this.inputSchema,
    this.outputSchema,
    this.metadata,
  });

  factory ToolDefinition.fromJson(Map<String, dynamic> json) =>
      _$ToolDefinitionFromJson(json);

  final String? name;

  final String? description;

  final dynamic inputSchema;

  final dynamic outputSchema;

  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => _$ToolDefinitionToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class TextPart extends Part {
  TextPart({
    required this.text,
    this.media,
    this.toolRequest,
    this.toolResponse,
    this.data,
    this.metadata,
    this.custom,
    this.reasoning,
    this.resource,
  });

  factory TextPart.fromJson(Map<String, dynamic> json) =>
      _$TextPartFromJson(json);

  final String? text;

  final dynamic media;

  final dynamic toolRequest;

  final dynamic toolResponse;

  final dynamic data;

  final dynamic metadata;

  final dynamic custom;

  final dynamic reasoning;

  final dynamic resource;

  @override
  Map<String, dynamic> toJson() => _$TextPartToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class MediaPart extends Part {
  MediaPart({
    this.text,
    required this.media,
    this.toolRequest,
    this.toolResponse,
    this.data,
    this.metadata,
    this.custom,
    this.reasoning,
    this.resource,
  });

  factory MediaPart.fromJson(Map<String, dynamic> json) =>
      _$MediaPartFromJson(json);

  final dynamic text;

  final Media? media;

  final dynamic toolRequest;

  final dynamic toolResponse;

  final dynamic data;

  final dynamic metadata;

  final dynamic custom;

  final dynamic reasoning;

  final dynamic resource;

  @override
  Map<String, dynamic> toJson() => _$MediaPartToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ToolRequestPart extends Part {
  ToolRequestPart({
    this.text,
    this.media,
    required this.toolRequest,
    this.toolResponse,
    this.data,
    this.metadata,
    this.custom,
    this.reasoning,
    this.resource,
  });

  factory ToolRequestPart.fromJson(Map<String, dynamic> json) =>
      _$ToolRequestPartFromJson(json);

  final dynamic text;

  final dynamic media;

  final ToolRequest? toolRequest;

  final dynamic toolResponse;

  final dynamic data;

  final dynamic metadata;

  final dynamic custom;

  final dynamic reasoning;

  final dynamic resource;

  @override
  Map<String, dynamic> toJson() => _$ToolRequestPartToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ToolResponsePart extends Part {
  ToolResponsePart({
    this.text,
    this.media,
    this.toolRequest,
    required this.toolResponse,
    this.data,
    this.metadata,
    this.custom,
    this.reasoning,
    this.resource,
  });

  factory ToolResponsePart.fromJson(Map<String, dynamic> json) =>
      _$ToolResponsePartFromJson(json);

  final dynamic text;

  final dynamic media;

  final dynamic toolRequest;

  final ToolResponse? toolResponse;

  final dynamic data;

  final dynamic metadata;

  final dynamic custom;

  final dynamic reasoning;

  final dynamic resource;

  @override
  Map<String, dynamic> toJson() => _$ToolResponsePartToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class DataPart extends Part {
  DataPart({
    this.text,
    this.media,
    this.toolRequest,
    this.toolResponse,
    this.data,
    this.metadata,
    this.custom,
    this.reasoning,
    this.resource,
  });

  factory DataPart.fromJson(Map<String, dynamic> json) =>
      _$DataPartFromJson(json);

  final dynamic text;

  final dynamic media;

  final dynamic toolRequest;

  final dynamic toolResponse;

  final dynamic data;

  final dynamic metadata;

  final Map<String, dynamic>? custom;

  final dynamic reasoning;

  final dynamic resource;

  @override
  Map<String, dynamic> toJson() => _$DataPartToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class CustomPart extends Part {
  CustomPart({
    this.text,
    this.media,
    this.toolRequest,
    this.toolResponse,
    this.data,
    this.metadata,
    required this.custom,
    this.reasoning,
    this.resource,
  });

  factory CustomPart.fromJson(Map<String, dynamic> json) =>
      _$CustomPartFromJson(json);

  final dynamic text;

  final dynamic media;

  final dynamic toolRequest;

  final dynamic toolResponse;

  final dynamic data;

  final Map<String, dynamic>? metadata;

  final Map<String, dynamic>? custom;

  final dynamic reasoning;

  final dynamic resource;

  @override
  Map<String, dynamic> toJson() => _$CustomPartToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ReasoningPart extends Part {
  ReasoningPart({
    this.text,
    this.media,
    this.toolRequest,
    this.toolResponse,
    this.data,
    this.metadata,
    this.custom,
    required this.reasoning,
    this.resource,
  });

  factory ReasoningPart.fromJson(Map<String, dynamic> json) =>
      _$ReasoningPartFromJson(json);

  final dynamic text;

  final dynamic media;

  final dynamic toolRequest;

  final dynamic toolResponse;

  final dynamic data;

  final dynamic metadata;

  final dynamic custom;

  final String? reasoning;

  final dynamic resource;

  @override
  Map<String, dynamic> toJson() => _$ReasoningPartToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ResourcePart extends Part {
  ResourcePart({
    this.text,
    this.media,
    this.toolRequest,
    this.toolResponse,
    this.data,
    this.metadata,
    this.custom,
    this.reasoning,
    required this.resource,
  });

  factory ResourcePart.fromJson(Map<String, dynamic> json) =>
      _$ResourcePartFromJson(json);

  final dynamic text;

  final dynamic media;

  final dynamic toolRequest;

  final dynamic toolResponse;

  final dynamic data;

  final dynamic metadata;

  final dynamic custom;

  final dynamic reasoning;

  final Map<String, dynamic>? resource;

  @override
  Map<String, dynamic> toJson() => _$ResourcePartToJson(this);
}

abstract class Part {
  Part();

  factory Part.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('text')) {
      return TextPart.fromJson(json);
    }
    if (json.containsKey('media')) {
      return MediaPart.fromJson(json);
    }
    if (json.containsKey('toolRequest')) {
      return ToolRequestPart.fromJson(json);
    }
    if (json.containsKey('toolResponse')) {
      return ToolResponsePart.fromJson(json);
    }
    if (json.containsKey('custom')) {
      return CustomPart.fromJson(json);
    }
    if (json.containsKey('reasoning')) {
      return ReasoningPart.fromJson(json);
    }
    if (json.containsKey('resource')) {
      return ResourcePart.fromJson(json);
    }
    throw Exception('Unknown subtype of Part');
  }

  Map<String, dynamic> toJson() {
    if (this is TextPart) return (this as TextPart).toJson();
    if (this is MediaPart) return (this as MediaPart).toJson();
    if (this is ToolRequestPart) return (this as ToolRequestPart).toJson();
    if (this is ToolResponsePart) return (this as ToolResponsePart).toJson();
    if (this is CustomPart) return (this as CustomPart).toJson();
    if (this is ReasoningPart) return (this as ReasoningPart).toJson();
    if (this is ResourcePart) return (this as ResourcePart).toJson();
    throw Exception('Unknown subtype of Part');
  }
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class Media {
  Media({this.contentType, required this.url});

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);

  final String? contentType;

  final String? url;

  Map<String, dynamic> toJson() => _$MediaToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ToolRequest {
  ToolRequest({this.ref, required this.name, this.input});

  factory ToolRequest.fromJson(Map<String, dynamic> json) =>
      _$ToolRequestFromJson(json);

  final String? ref;

  final String? name;

  final dynamic input;

  Map<String, dynamic> toJson() => _$ToolRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ToolResponse {
  ToolResponse({this.ref, required this.name, this.output});

  factory ToolResponse.fromJson(Map<String, dynamic> json) =>
      _$ToolResponseFromJson(json);

  final String? ref;

  final String? name;

  final dynamic output;

  Map<String, dynamic> toJson() => _$ToolResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GenerateRequest {
  GenerateRequest({
    required this.messages,
    this.config,
    this.tools,
    this.toolChoice,
    this.output,
    this.docs,
    this.candidates,
  });

  factory GenerateRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerateRequestFromJson(json);

  final List<Message?>? messages;

  final dynamic config;

  final List<ToolDefinition?>? tools;

  final String? toolChoice;

  final OutputConfig? output;

  final List<DocumentData?>? docs;

  final double? candidates;

  Map<String, dynamic> toJson() => _$GenerateRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GenerateResponse {
  GenerateResponse({
    this.message,
    this.finishReason,
    this.finishMessage,
    this.latencyMs,
    this.usage,
    this.custom,
    this.raw,
    this.request,
    this.operation,
    this.candidates,
  });

  factory GenerateResponse.fromJson(Map<String, dynamic> json) =>
      _$GenerateResponseFromJson(json);

  final Message? message;

  final FinishReason? finishReason;

  final String? finishMessage;

  final double? latencyMs;

  final GenerationUsage? usage;

  final dynamic custom;

  final dynamic raw;

  final GenerateRequest? request;

  final Operation? operation;

  final List<Candidate?>? candidates;

  Map<String, dynamic> toJson() => _$GenerateResponseToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GenerateResponseChunk {
  GenerateResponseChunk({
    this.role,
    this.index,
    required this.content,
    this.custom,
    this.aggregated,
  });

  factory GenerateResponseChunk.fromJson(Map<String, dynamic> json) =>
      _$GenerateResponseChunkFromJson(json);

  final Role? role;

  final double? index;

  final List<Part?>? content;

  final dynamic custom;

  final bool? aggregated;

  Map<String, dynamic> toJson() => _$GenerateResponseChunkToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class GenerationUsage {
  GenerationUsage({
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
    this.inputCharacters,
    this.outputCharacters,
    this.inputImages,
    this.outputImages,
    this.inputVideos,
    this.outputVideos,
    this.inputAudioFiles,
    this.outputAudioFiles,
    this.custom,
    this.thoughtsTokens,
    this.cachedContentTokens,
  });

  factory GenerationUsage.fromJson(Map<String, dynamic> json) =>
      _$GenerationUsageFromJson(json);

  final double? inputTokens;

  final double? outputTokens;

  final double? totalTokens;

  final double? inputCharacters;

  final double? outputCharacters;

  final double? inputImages;

  final double? outputImages;

  final double? inputVideos;

  final double? outputVideos;

  final double? inputAudioFiles;

  final double? outputAudioFiles;

  final Map<String, dynamic>? custom;

  final double? thoughtsTokens;

  final double? cachedContentTokens;

  Map<String, dynamic> toJson() => _$GenerationUsageToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class Operation {
  Operation({
    this.action,
    required this.id,
    this.done,
    this.output,
    this.error,
    this.metadata,
  });

  factory Operation.fromJson(Map<String, dynamic> json) =>
      _$OperationFromJson(json);

  final String? action;

  final String? id;

  final bool? done;

  final dynamic output;

  final Map<String, dynamic>? error;

  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => _$OperationToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class OutputConfig {
  OutputConfig({this.format, this.schema, this.constrained, this.contentType});

  factory OutputConfig.fromJson(Map<String, dynamic> json) =>
      _$OutputConfigFromJson(json);

  final String? format;

  final Map<String, dynamic>? schema;

  final bool? constrained;

  final String? contentType;

  Map<String, dynamic> toJson() => _$OutputConfigToJson(this);
}

enum FinishReason { stop, length, blocked, interrupted, other, unknown }

enum Role { system, user, model, tool }

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class DocumentData {
  DocumentData({required this.content, this.metadata});

  factory DocumentData.fromJson(Map<String, dynamic> json) =>
      _$DocumentDataFromJson(json);

  final List<Part?>? content;

  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => _$DocumentDataToJson(this);
}
