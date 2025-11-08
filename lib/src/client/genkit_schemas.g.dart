// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genkit_schemas.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Candidate _$CandidateFromJson(Map<String, dynamic> json) => Candidate(
  index: (json['index'] as num?)?.toDouble(),
  message: json['message'] == null
      ? null
      : Message.fromJson(json['message'] as Map<String, dynamic>),
  usage: json['usage'] == null
      ? null
      : GenerationUsage.fromJson(json['usage'] as Map<String, dynamic>),
  finishReason: $enumDecodeNullable(
    _$FinishReasonEnumMap,
    json['finishReason'],
  ),
  finishMessage: json['finishMessage'] as String?,
  custom: json['custom'],
);

Map<String, dynamic> _$CandidateToJson(Candidate instance) => <String, dynamic>{
  'index': ?instance.index,
  'message': ?instance.message?.toJson(),
  'usage': ?instance.usage?.toJson(),
  'finishReason': ?_$FinishReasonEnumMap[instance.finishReason],
  'finishMessage': ?instance.finishMessage,
  'custom': ?instance.custom,
};

const _$FinishReasonEnumMap = {
  FinishReason.stop: 'stop',
  FinishReason.length: 'length',
  FinishReason.blocked: 'blocked',
  FinishReason.interrupted: 'interrupted',
  FinishReason.other: 'other',
  FinishReason.unknown: 'unknown',
};

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  role: $enumDecodeNullable(_$RoleEnumMap, json['role']),
  content: (json['content'] as List<dynamic>?)
      ?.map((e) => e == null ? null : Part.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'role': ?_$RoleEnumMap[instance.role],
  'content': ?instance.content?.map((e) => e?.toJson()).toList(),
  'metadata': ?instance.metadata,
};

const _$RoleEnumMap = {
  Role.system: 'system',
  Role.user: 'user',
  Role.model: 'model',
  Role.tool: 'tool',
};

ToolDefinition _$ToolDefinitionFromJson(Map<String, dynamic> json) =>
    ToolDefinition(
      name: json['name'] as String?,
      description: json['description'] as String?,
      inputSchema: json['inputSchema'],
      outputSchema: json['outputSchema'],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ToolDefinitionToJson(ToolDefinition instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'description': ?instance.description,
      'inputSchema': ?instance.inputSchema,
      'outputSchema': ?instance.outputSchema,
      'metadata': ?instance.metadata,
    };

TextPart _$TextPartFromJson(Map<String, dynamic> json) => TextPart(
  text: json['text'] as String?,
  media: json['media'],
  toolRequest: json['toolRequest'],
  toolResponse: json['toolResponse'],
  data: json['data'],
  metadata: json['metadata'],
  custom: json['custom'],
  reasoning: json['reasoning'],
  resource: json['resource'],
);

Map<String, dynamic> _$TextPartToJson(TextPart instance) => <String, dynamic>{
  'text': ?instance.text,
  'media': ?instance.media,
  'toolRequest': ?instance.toolRequest,
  'toolResponse': ?instance.toolResponse,
  'data': ?instance.data,
  'metadata': ?instance.metadata,
  'custom': ?instance.custom,
  'reasoning': ?instance.reasoning,
  'resource': ?instance.resource,
};

MediaPart _$MediaPartFromJson(Map<String, dynamic> json) => MediaPart(
  text: json['text'],
  media: json['media'] == null
      ? null
      : Media.fromJson(json['media'] as Map<String, dynamic>),
  toolRequest: json['toolRequest'],
  toolResponse: json['toolResponse'],
  data: json['data'],
  metadata: json['metadata'],
  custom: json['custom'],
  reasoning: json['reasoning'],
  resource: json['resource'],
);

Map<String, dynamic> _$MediaPartToJson(MediaPart instance) => <String, dynamic>{
  'text': ?instance.text,
  'media': ?instance.media?.toJson(),
  'toolRequest': ?instance.toolRequest,
  'toolResponse': ?instance.toolResponse,
  'data': ?instance.data,
  'metadata': ?instance.metadata,
  'custom': ?instance.custom,
  'reasoning': ?instance.reasoning,
  'resource': ?instance.resource,
};

ToolRequestPart _$ToolRequestPartFromJson(Map<String, dynamic> json) =>
    ToolRequestPart(
      text: json['text'],
      media: json['media'],
      toolRequest: json['toolRequest'] == null
          ? null
          : ToolRequest.fromJson(json['toolRequest'] as Map<String, dynamic>),
      toolResponse: json['toolResponse'],
      data: json['data'],
      metadata: json['metadata'],
      custom: json['custom'],
      reasoning: json['reasoning'],
      resource: json['resource'],
    );

Map<String, dynamic> _$ToolRequestPartToJson(ToolRequestPart instance) =>
    <String, dynamic>{
      'text': ?instance.text,
      'media': ?instance.media,
      'toolRequest': ?instance.toolRequest?.toJson(),
      'toolResponse': ?instance.toolResponse,
      'data': ?instance.data,
      'metadata': ?instance.metadata,
      'custom': ?instance.custom,
      'reasoning': ?instance.reasoning,
      'resource': ?instance.resource,
    };

ToolResponsePart _$ToolResponsePartFromJson(Map<String, dynamic> json) =>
    ToolResponsePart(
      text: json['text'],
      media: json['media'],
      toolRequest: json['toolRequest'],
      toolResponse: json['toolResponse'] == null
          ? null
          : ToolResponse.fromJson(json['toolResponse'] as Map<String, dynamic>),
      data: json['data'],
      metadata: json['metadata'],
      custom: json['custom'],
      reasoning: json['reasoning'],
      resource: json['resource'],
    );

Map<String, dynamic> _$ToolResponsePartToJson(ToolResponsePart instance) =>
    <String, dynamic>{
      'text': ?instance.text,
      'media': ?instance.media,
      'toolRequest': ?instance.toolRequest,
      'toolResponse': ?instance.toolResponse?.toJson(),
      'data': ?instance.data,
      'metadata': ?instance.metadata,
      'custom': ?instance.custom,
      'reasoning': ?instance.reasoning,
      'resource': ?instance.resource,
    };

DataPart _$DataPartFromJson(Map<String, dynamic> json) => DataPart(
  text: json['text'],
  media: json['media'],
  toolRequest: json['toolRequest'],
  toolResponse: json['toolResponse'],
  data: json['data'],
  metadata: json['metadata'],
  custom: json['custom'] as Map<String, dynamic>?,
  reasoning: json['reasoning'],
  resource: json['resource'],
);

Map<String, dynamic> _$DataPartToJson(DataPart instance) => <String, dynamic>{
  'text': ?instance.text,
  'media': ?instance.media,
  'toolRequest': ?instance.toolRequest,
  'toolResponse': ?instance.toolResponse,
  'data': ?instance.data,
  'metadata': ?instance.metadata,
  'custom': ?instance.custom,
  'reasoning': ?instance.reasoning,
  'resource': ?instance.resource,
};

CustomPart _$CustomPartFromJson(Map<String, dynamic> json) => CustomPart(
  text: json['text'],
  media: json['media'],
  toolRequest: json['toolRequest'],
  toolResponse: json['toolResponse'],
  data: json['data'],
  metadata: json['metadata'] as Map<String, dynamic>?,
  custom: json['custom'] as Map<String, dynamic>?,
  reasoning: json['reasoning'],
  resource: json['resource'],
);

Map<String, dynamic> _$CustomPartToJson(CustomPart instance) =>
    <String, dynamic>{
      'text': ?instance.text,
      'media': ?instance.media,
      'toolRequest': ?instance.toolRequest,
      'toolResponse': ?instance.toolResponse,
      'data': ?instance.data,
      'metadata': ?instance.metadata,
      'custom': ?instance.custom,
      'reasoning': ?instance.reasoning,
      'resource': ?instance.resource,
    };

ReasoningPart _$ReasoningPartFromJson(Map<String, dynamic> json) =>
    ReasoningPart(
      text: json['text'],
      media: json['media'],
      toolRequest: json['toolRequest'],
      toolResponse: json['toolResponse'],
      data: json['data'],
      metadata: json['metadata'],
      custom: json['custom'],
      reasoning: json['reasoning'] as String?,
      resource: json['resource'],
    );

Map<String, dynamic> _$ReasoningPartToJson(ReasoningPart instance) =>
    <String, dynamic>{
      'text': ?instance.text,
      'media': ?instance.media,
      'toolRequest': ?instance.toolRequest,
      'toolResponse': ?instance.toolResponse,
      'data': ?instance.data,
      'metadata': ?instance.metadata,
      'custom': ?instance.custom,
      'reasoning': ?instance.reasoning,
      'resource': ?instance.resource,
    };

ResourcePart _$ResourcePartFromJson(Map<String, dynamic> json) => ResourcePart(
  text: json['text'],
  media: json['media'],
  toolRequest: json['toolRequest'],
  toolResponse: json['toolResponse'],
  data: json['data'],
  metadata: json['metadata'],
  custom: json['custom'],
  reasoning: json['reasoning'],
  resource: json['resource'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ResourcePartToJson(ResourcePart instance) =>
    <String, dynamic>{
      'text': ?instance.text,
      'media': ?instance.media,
      'toolRequest': ?instance.toolRequest,
      'toolResponse': ?instance.toolResponse,
      'data': ?instance.data,
      'metadata': ?instance.metadata,
      'custom': ?instance.custom,
      'reasoning': ?instance.reasoning,
      'resource': ?instance.resource,
    };

Media _$MediaFromJson(Map<String, dynamic> json) => Media(
  contentType: json['contentType'] as String?,
  url: json['url'] as String?,
);

Map<String, dynamic> _$MediaToJson(Media instance) => <String, dynamic>{
  'contentType': ?instance.contentType,
  'url': ?instance.url,
};

ToolRequest _$ToolRequestFromJson(Map<String, dynamic> json) => ToolRequest(
  ref: json['ref'] as String?,
  name: json['name'] as String?,
  input: json['input'],
);

Map<String, dynamic> _$ToolRequestToJson(ToolRequest instance) =>
    <String, dynamic>{
      'ref': ?instance.ref,
      'name': ?instance.name,
      'input': ?instance.input,
    };

ToolResponse _$ToolResponseFromJson(Map<String, dynamic> json) => ToolResponse(
  ref: json['ref'] as String?,
  name: json['name'] as String?,
  output: json['output'],
);

Map<String, dynamic> _$ToolResponseToJson(ToolResponse instance) =>
    <String, dynamic>{
      'ref': ?instance.ref,
      'name': ?instance.name,
      'output': ?instance.output,
    };

GenerateRequest _$GenerateRequestFromJson(Map<String, dynamic> json) =>
    GenerateRequest(
      messages: (json['messages'] as List<dynamic>?)
          ?.map(
            (e) =>
                e == null ? null : Message.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      config: json['config'],
      tools: (json['tools'] as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : ToolDefinition.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      toolChoice: json['toolChoice'] as String?,
      output: json['output'] == null
          ? null
          : OutputConfig.fromJson(json['output'] as Map<String, dynamic>),
      docs: (json['docs'] as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : DocumentData.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      candidates: (json['candidates'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GenerateRequestToJson(GenerateRequest instance) =>
    <String, dynamic>{
      'messages': ?instance.messages?.map((e) => e?.toJson()).toList(),
      'config': ?instance.config,
      'tools': ?instance.tools?.map((e) => e?.toJson()).toList(),
      'toolChoice': ?instance.toolChoice,
      'output': ?instance.output?.toJson(),
      'docs': ?instance.docs?.map((e) => e?.toJson()).toList(),
      'candidates': ?instance.candidates,
    };

GenerateResponse _$GenerateResponseFromJson(Map<String, dynamic> json) =>
    GenerateResponse(
      message: json['message'] == null
          ? null
          : Message.fromJson(json['message'] as Map<String, dynamic>),
      finishReason: $enumDecodeNullable(
        _$FinishReasonEnumMap,
        json['finishReason'],
      ),
      finishMessage: json['finishMessage'] as String?,
      latencyMs: (json['latencyMs'] as num?)?.toDouble(),
      usage: json['usage'] == null
          ? null
          : GenerationUsage.fromJson(json['usage'] as Map<String, dynamic>),
      custom: json['custom'],
      raw: json['raw'],
      request: json['request'] == null
          ? null
          : GenerateRequest.fromJson(json['request'] as Map<String, dynamic>),
      operation: json['operation'] == null
          ? null
          : Operation.fromJson(json['operation'] as Map<String, dynamic>),
      candidates: (json['candidates'] as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Candidate.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$GenerateResponseToJson(GenerateResponse instance) =>
    <String, dynamic>{
      'message': ?instance.message?.toJson(),
      'finishReason': ?_$FinishReasonEnumMap[instance.finishReason],
      'finishMessage': ?instance.finishMessage,
      'latencyMs': ?instance.latencyMs,
      'usage': ?instance.usage?.toJson(),
      'custom': ?instance.custom,
      'raw': ?instance.raw,
      'request': ?instance.request?.toJson(),
      'operation': ?instance.operation?.toJson(),
      'candidates': ?instance.candidates?.map((e) => e?.toJson()).toList(),
    };

GenerateResponseChunk _$GenerateResponseChunkFromJson(
  Map<String, dynamic> json,
) => GenerateResponseChunk(
  role: $enumDecodeNullable(_$RoleEnumMap, json['role']),
  index: (json['index'] as num?)?.toDouble(),
  content: (json['content'] as List<dynamic>?)
      ?.map((e) => e == null ? null : Part.fromJson(e as Map<String, dynamic>))
      .toList(),
  custom: json['custom'],
  aggregated: json['aggregated'] as bool?,
);

Map<String, dynamic> _$GenerateResponseChunkToJson(
  GenerateResponseChunk instance,
) => <String, dynamic>{
  'role': ?_$RoleEnumMap[instance.role],
  'index': ?instance.index,
  'content': ?instance.content?.map((e) => e?.toJson()).toList(),
  'custom': ?instance.custom,
  'aggregated': ?instance.aggregated,
};

GenerationUsage _$GenerationUsageFromJson(Map<String, dynamic> json) =>
    GenerationUsage(
      inputTokens: (json['inputTokens'] as num?)?.toDouble(),
      outputTokens: (json['outputTokens'] as num?)?.toDouble(),
      totalTokens: (json['totalTokens'] as num?)?.toDouble(),
      inputCharacters: (json['inputCharacters'] as num?)?.toDouble(),
      outputCharacters: (json['outputCharacters'] as num?)?.toDouble(),
      inputImages: (json['inputImages'] as num?)?.toDouble(),
      outputImages: (json['outputImages'] as num?)?.toDouble(),
      inputVideos: (json['inputVideos'] as num?)?.toDouble(),
      outputVideos: (json['outputVideos'] as num?)?.toDouble(),
      inputAudioFiles: (json['inputAudioFiles'] as num?)?.toDouble(),
      outputAudioFiles: (json['outputAudioFiles'] as num?)?.toDouble(),
      custom: json['custom'] as Map<String, dynamic>?,
      thoughtsTokens: (json['thoughtsTokens'] as num?)?.toDouble(),
      cachedContentTokens: (json['cachedContentTokens'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GenerationUsageToJson(GenerationUsage instance) =>
    <String, dynamic>{
      'inputTokens': ?instance.inputTokens,
      'outputTokens': ?instance.outputTokens,
      'totalTokens': ?instance.totalTokens,
      'inputCharacters': ?instance.inputCharacters,
      'outputCharacters': ?instance.outputCharacters,
      'inputImages': ?instance.inputImages,
      'outputImages': ?instance.outputImages,
      'inputVideos': ?instance.inputVideos,
      'outputVideos': ?instance.outputVideos,
      'inputAudioFiles': ?instance.inputAudioFiles,
      'outputAudioFiles': ?instance.outputAudioFiles,
      'custom': ?instance.custom,
      'thoughtsTokens': ?instance.thoughtsTokens,
      'cachedContentTokens': ?instance.cachedContentTokens,
    };

Operation _$OperationFromJson(Map<String, dynamic> json) => Operation(
  action: json['action'] as String?,
  id: json['id'] as String?,
  done: json['done'] as bool?,
  output: json['output'],
  error: json['error'] as Map<String, dynamic>?,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$OperationToJson(Operation instance) => <String, dynamic>{
  'action': ?instance.action,
  'id': ?instance.id,
  'done': ?instance.done,
  'output': ?instance.output,
  'error': ?instance.error,
  'metadata': ?instance.metadata,
};

OutputConfig _$OutputConfigFromJson(Map<String, dynamic> json) => OutputConfig(
  format: json['format'] as String?,
  schema: json['schema'] as Map<String, dynamic>?,
  constrained: json['constrained'] as bool?,
  contentType: json['contentType'] as String?,
);

Map<String, dynamic> _$OutputConfigToJson(OutputConfig instance) =>
    <String, dynamic>{
      'format': ?instance.format,
      'schema': ?instance.schema,
      'constrained': ?instance.constrained,
      'contentType': ?instance.contentType,
    };

DocumentData _$DocumentDataFromJson(Map<String, dynamic> json) => DocumentData(
  content: (json['content'] as List<dynamic>?)
      ?.map((e) => e == null ? null : Part.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$DocumentDataToJson(DocumentData instance) =>
    <String, dynamic>{
      'content': ?instance.content?.map((e) => e?.toJson()).toList(),
      'metadata': ?instance.metadata,
    };
