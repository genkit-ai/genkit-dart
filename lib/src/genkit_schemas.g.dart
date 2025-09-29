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
      finishReason:
          $enumDecodeNullable(_$FinishReasonEnumMap, json['finishReason']),
      finishMessage: json['finishMessage'] as String?,
      custom: json['custom'],
    );

Map<String, dynamic> _$CandidateToJson(Candidate instance) => <String, dynamic>{
      if (instance.index case final value?) 'index': value,
      if (instance.message?.toJson() case final value?) 'message': value,
      if (instance.usage?.toJson() case final value?) 'usage': value,
      if (_$FinishReasonEnumMap[instance.finishReason] case final value?)
        'finishReason': value,
      if (instance.finishMessage case final value?) 'finishMessage': value,
      if (instance.custom case final value?) 'custom': value,
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
          ?.map((e) =>
              e == null ? null : Part.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      if (_$RoleEnumMap[instance.role] case final value?) 'role': value,
      if (instance.content?.map((e) => e?.toJson()).toList() case final value?)
        'content': value,
      if (instance.metadata case final value?) 'metadata': value,
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
      if (instance.name case final value?) 'name': value,
      if (instance.description case final value?) 'description': value,
      if (instance.inputSchema case final value?) 'inputSchema': value,
      if (instance.outputSchema case final value?) 'outputSchema': value,
      if (instance.metadata case final value?) 'metadata': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media case final value?) 'media': value,
      if (instance.toolRequest case final value?) 'toolRequest': value,
      if (instance.toolResponse case final value?) 'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media?.toJson() case final value?) 'media': value,
      if (instance.toolRequest case final value?) 'toolRequest': value,
      if (instance.toolResponse case final value?) 'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media case final value?) 'media': value,
      if (instance.toolRequest?.toJson() case final value?)
        'toolRequest': value,
      if (instance.toolResponse case final value?) 'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media case final value?) 'media': value,
      if (instance.toolRequest case final value?) 'toolRequest': value,
      if (instance.toolResponse?.toJson() case final value?)
        'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media case final value?) 'media': value,
      if (instance.toolRequest case final value?) 'toolRequest': value,
      if (instance.toolResponse case final value?) 'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media case final value?) 'media': value,
      if (instance.toolRequest case final value?) 'toolRequest': value,
      if (instance.toolResponse case final value?) 'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media case final value?) 'media': value,
      if (instance.toolRequest case final value?) 'toolRequest': value,
      if (instance.toolResponse case final value?) 'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
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
      if (instance.text case final value?) 'text': value,
      if (instance.media case final value?) 'media': value,
      if (instance.toolRequest case final value?) 'toolRequest': value,
      if (instance.toolResponse case final value?) 'toolResponse': value,
      if (instance.data case final value?) 'data': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.reasoning case final value?) 'reasoning': value,
      if (instance.resource case final value?) 'resource': value,
    };

Media _$MediaFromJson(Map<String, dynamic> json) => Media(
      contentType: json['contentType'] as String?,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$MediaToJson(Media instance) => <String, dynamic>{
      if (instance.contentType case final value?) 'contentType': value,
      if (instance.url case final value?) 'url': value,
    };

ToolRequest _$ToolRequestFromJson(Map<String, dynamic> json) => ToolRequest(
      ref: json['ref'] as String?,
      name: json['name'] as String?,
      input: json['input'],
    );

Map<String, dynamic> _$ToolRequestToJson(ToolRequest instance) =>
    <String, dynamic>{
      if (instance.ref case final value?) 'ref': value,
      if (instance.name case final value?) 'name': value,
      if (instance.input case final value?) 'input': value,
    };

ToolResponse _$ToolResponseFromJson(Map<String, dynamic> json) => ToolResponse(
      ref: json['ref'] as String?,
      name: json['name'] as String?,
      output: json['output'],
    );

Map<String, dynamic> _$ToolResponseToJson(ToolResponse instance) =>
    <String, dynamic>{
      if (instance.ref case final value?) 'ref': value,
      if (instance.name case final value?) 'name': value,
      if (instance.output case final value?) 'output': value,
    };

GenerateRequest _$GenerateRequestFromJson(Map<String, dynamic> json) =>
    GenerateRequest(
      messages: (json['messages'] as List<dynamic>?)
          ?.map((e) =>
              e == null ? null : Message.fromJson(e as Map<String, dynamic>))
          .toList(),
      config: json['config'],
      tools: (json['tools'] as List<dynamic>?)
          ?.map((e) => e == null
              ? null
              : ToolDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      toolChoice: json['toolChoice'] as String?,
      output: json['output'] == null
          ? null
          : OutputConfig.fromJson(json['output'] as Map<String, dynamic>),
      docs: (json['docs'] as List<dynamic>?)
          ?.map((e) => e == null
              ? null
              : DocumentData.fromJson(e as Map<String, dynamic>))
          .toList(),
      candidates: (json['candidates'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GenerateRequestToJson(GenerateRequest instance) =>
    <String, dynamic>{
      if (instance.messages?.map((e) => e?.toJson()).toList() case final value?)
        'messages': value,
      if (instance.config case final value?) 'config': value,
      if (instance.tools?.map((e) => e?.toJson()).toList() case final value?)
        'tools': value,
      if (instance.toolChoice case final value?) 'toolChoice': value,
      if (instance.output?.toJson() case final value?) 'output': value,
      if (instance.docs?.map((e) => e?.toJson()).toList() case final value?)
        'docs': value,
      if (instance.candidates case final value?) 'candidates': value,
    };

GenerateResponse _$GenerateResponseFromJson(Map<String, dynamic> json) =>
    GenerateResponse(
      message: json['message'] == null
          ? null
          : Message.fromJson(json['message'] as Map<String, dynamic>),
      finishReason:
          $enumDecodeNullable(_$FinishReasonEnumMap, json['finishReason']),
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
          ?.map((e) =>
              e == null ? null : Candidate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GenerateResponseToJson(GenerateResponse instance) =>
    <String, dynamic>{
      if (instance.message?.toJson() case final value?) 'message': value,
      if (_$FinishReasonEnumMap[instance.finishReason] case final value?)
        'finishReason': value,
      if (instance.finishMessage case final value?) 'finishMessage': value,
      if (instance.latencyMs case final value?) 'latencyMs': value,
      if (instance.usage?.toJson() case final value?) 'usage': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.raw case final value?) 'raw': value,
      if (instance.request?.toJson() case final value?) 'request': value,
      if (instance.operation?.toJson() case final value?) 'operation': value,
      if (instance.candidates?.map((e) => e?.toJson()).toList()
          case final value?)
        'candidates': value,
    };

GenerateResponseChunk _$GenerateResponseChunkFromJson(
        Map<String, dynamic> json) =>
    GenerateResponseChunk(
      role: $enumDecodeNullable(_$RoleEnumMap, json['role']),
      index: (json['index'] as num?)?.toDouble(),
      content: (json['content'] as List<dynamic>?)
          ?.map((e) =>
              e == null ? null : Part.fromJson(e as Map<String, dynamic>))
          .toList(),
      custom: json['custom'],
      aggregated: json['aggregated'] as bool?,
    );

Map<String, dynamic> _$GenerateResponseChunkToJson(
        GenerateResponseChunk instance) =>
    <String, dynamic>{
      if (_$RoleEnumMap[instance.role] case final value?) 'role': value,
      if (instance.index case final value?) 'index': value,
      if (instance.content?.map((e) => e?.toJson()).toList() case final value?)
        'content': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.aggregated case final value?) 'aggregated': value,
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
      if (instance.inputTokens case final value?) 'inputTokens': value,
      if (instance.outputTokens case final value?) 'outputTokens': value,
      if (instance.totalTokens case final value?) 'totalTokens': value,
      if (instance.inputCharacters case final value?) 'inputCharacters': value,
      if (instance.outputCharacters case final value?)
        'outputCharacters': value,
      if (instance.inputImages case final value?) 'inputImages': value,
      if (instance.outputImages case final value?) 'outputImages': value,
      if (instance.inputVideos case final value?) 'inputVideos': value,
      if (instance.outputVideos case final value?) 'outputVideos': value,
      if (instance.inputAudioFiles case final value?) 'inputAudioFiles': value,
      if (instance.outputAudioFiles case final value?)
        'outputAudioFiles': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.thoughtsTokens case final value?) 'thoughtsTokens': value,
      if (instance.cachedContentTokens case final value?)
        'cachedContentTokens': value,
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
      if (instance.action case final value?) 'action': value,
      if (instance.id case final value?) 'id': value,
      if (instance.done case final value?) 'done': value,
      if (instance.output case final value?) 'output': value,
      if (instance.error case final value?) 'error': value,
      if (instance.metadata case final value?) 'metadata': value,
    };

OutputConfig _$OutputConfigFromJson(Map<String, dynamic> json) => OutputConfig(
      format: json['format'] as String?,
      schema: json['schema'] as Map<String, dynamic>?,
      constrained: json['constrained'] as bool?,
      contentType: json['contentType'] as String?,
    );

Map<String, dynamic> _$OutputConfigToJson(OutputConfig instance) =>
    <String, dynamic>{
      if (instance.format case final value?) 'format': value,
      if (instance.schema case final value?) 'schema': value,
      if (instance.constrained case final value?) 'constrained': value,
      if (instance.contentType case final value?) 'contentType': value,
    };

DocumentData _$DocumentDataFromJson(Map<String, dynamic> json) => DocumentData(
      content: (json['content'] as List<dynamic>?)
          ?.map((e) =>
              e == null ? null : Part.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DocumentDataToJson(DocumentData instance) =>
    <String, dynamic>{
      if (instance.content?.map((e) => e?.toJson()).toList() case final value?)
        'content': value,
      if (instance.metadata case final value?) 'metadata': value,
    };
