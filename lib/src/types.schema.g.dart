// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type Candidate(Map<String, dynamic> _json) {
  factory Candidate.from({
    required double index,
    required Message message,
    GenerationUsage? usage,
    required FinishReason finishReason,
    String? finishMessage,
  }) {
    return Candidate({
      'index': index,
      'message': message.toJson(),
      'usage': usage?.toJson(),
      'finishReason': finishReason,
      'finishMessage': finishMessage,
    });
  }

  double get index {
    return _json['index'] as double;
  }

  set index(double value) {
    _json['index'] = value;
  }

  Message get message {
    return Message(_json['message'] as Map<String, dynamic>);
  }

  set message(Message value) {
    _json['message'] = (value as dynamic)._json;
  }

  GenerationUsage? get usage {
    return _json['usage'] == null
        ? null
        : GenerationUsage(_json['usage'] as Map<String, dynamic>);
  }

  set usage(GenerationUsage? value) {
    if (value == null) {
      _json.remove('usage');
    } else {
      _json['usage'] = (value as dynamic)?._json;
    }
  }

  FinishReason get finishReason {
    return FinishReason.values.byName(_json['finishReason'] as String);
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value.name;
  }

  String? get finishMessage {
    return _json['finishMessage'] as String?;
  }

  set finishMessage(String? value) {
    if (value == null) {
      _json.remove('finishMessage');
    } else {
      _json['finishMessage'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class CandidateTypeFactory implements JsonExtensionType<Candidate> {
  const CandidateTypeFactory();

  @override
  Candidate parse(Object json) {
    return Candidate(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'index': Schema.number(),
        'message': MessageType.jsonSchema,
        'usage': GenerationUsageType.jsonSchema,
        'finishReason': Schema.string(
          enumValues: [
            'stop',
            'length',
            'blocked',
            'interrupted',
            'other',
            'unknown',
          ],
        ),
        'finishMessage': Schema.string(),
      },
      required: ['index', 'message', 'finishReason'],
    );
  }
}

const CandidateType = CandidateTypeFactory();

extension type Message(Map<String, dynamic> _json) {
  factory Message.from({
    required Role role,
    required List<Part> content,
    Map<String, dynamic>? metadata,
  }) {
    return Message({
      'role': role,
      'content': content.map((e) => e.toJson()).toList(),
      'metadata': metadata,
    });
  }

  Role get role {
    return Role.values.byName(_json['role'] as String);
  }

  set role(Role value) {
    _json['role'] = value.name;
  }

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => PartType.parse(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.map((e) => (e as dynamic)._json).toList();
  }

  Map<String, dynamic>? get metadata {
    return _json['metadata'] as Map<String, dynamic>?;
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class MessageTypeFactory implements JsonExtensionType<Message> {
  const MessageTypeFactory();

  @override
  Message parse(Object json) {
    return Message(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'role': Schema.string(enumValues: ['system', 'user', 'model', 'tool']),
        'content': Schema.list(items: PartType.jsonSchema),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['role', 'content'],
    );
  }
}

const MessageType = MessageTypeFactory();

extension type ToolDefinition(Map<String, dynamic> _json) {
  factory ToolDefinition.from({
    required String name,
    required String description,
    dynamic inputSchema,
    dynamic outputSchema,
    Map<String, dynamic>? metadata,
  }) {
    return ToolDefinition({
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
      'outputSchema': outputSchema,
      'metadata': metadata,
    });
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get description {
    return _json['description'] as String;
  }

  set description(String value) {
    _json['description'] = value;
  }

  dynamic get inputSchema {
    return _json['inputSchema'] as dynamic;
  }

  set inputSchema(dynamic value) {
    _json['inputSchema'] = value;
  }

  dynamic get outputSchema {
    return _json['outputSchema'] as dynamic;
  }

  set outputSchema(dynamic value) {
    _json['outputSchema'] = value;
  }

  Map<String, dynamic>? get metadata {
    return _json['metadata'] as Map<String, dynamic>?;
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ToolDefinitionTypeFactory implements JsonExtensionType<ToolDefinition> {
  const ToolDefinitionTypeFactory();

  @override
  ToolDefinition parse(Object json) {
    return ToolDefinition(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'name': Schema.string(),
        'description': Schema.string(),
        'inputSchema': Schema.any(),
        'outputSchema': Schema.any(),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['name', 'description', 'inputSchema', 'outputSchema'],
    );
  }
}

const ToolDefinitionType = ToolDefinitionTypeFactory();

extension type Part(Map<String, dynamic> _json) {
  factory Part.from() {
    return Part({});
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class PartTypeFactory implements JsonExtensionType<Part> {
  const PartTypeFactory();

  @override
  Part parse(Object json) {
    final Map<String, dynamic> jsonMap = json as Map<String, dynamic>;
    if (jsonMap.containsKey('text')) {
      return TextPart(jsonMap);
    }
    if (jsonMap.containsKey('media')) {
      return MediaPart(jsonMap);
    }
    if (jsonMap.containsKey('toolRequest')) {
      return ToolRequestPart(jsonMap);
    }
    if (jsonMap.containsKey('toolResponse')) {
      return ToolResponsePart(jsonMap);
    }
    throw Exception("Invalid JSON for Part");
  }

  @override
  Schema get jsonSchema {
    return Schema.combined(
      anyOf: [
        TextPartType.jsonSchema,
        MediaPartType.jsonSchema,
        ToolRequestPartType.jsonSchema,
        ToolResponsePartType.jsonSchema,
      ],
    );
  }
}

const PartType = PartTypeFactory();

extension type TextPart(Map<String, dynamic> _json) implements Part {
  factory TextPart.from({
    required String text,
    dynamic metadata,
    dynamic custom,
  }) {
    return TextPart({'text': text, 'metadata': metadata, 'custom': custom});
  }

  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  dynamic get metadata {
    return _json['metadata'] as dynamic;
  }

  set metadata(dynamic value) {
    _json['metadata'] = value;
  }

  dynamic get custom {
    return _json['custom'] as dynamic;
  }

  set custom(dynamic value) {
    _json['custom'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class TextPartTypeFactory implements JsonExtensionType<TextPart> {
  const TextPartTypeFactory();

  @override
  TextPart parse(Object json) {
    return TextPart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'text': Schema.string(),
        'metadata': Schema.any(),
        'custom': Schema.any(),
      },
      required: ['text', 'metadata', 'custom'],
    );
  }
}

const TextPartType = TextPartTypeFactory();

extension type MediaPart(Map<String, dynamic> _json) implements Part {
  factory MediaPart.from({
    required Media media,
    dynamic metadata,
    dynamic custom,
  }) {
    return MediaPart({
      'media': media.toJson(),
      'metadata': metadata,
      'custom': custom,
    });
  }

  Media get media {
    return Media(_json['media'] as Map<String, dynamic>);
  }

  set media(Media value) {
    _json['media'] = (value as dynamic)._json;
  }

  dynamic get metadata {
    return _json['metadata'] as dynamic;
  }

  set metadata(dynamic value) {
    _json['metadata'] = value;
  }

  dynamic get custom {
    return _json['custom'] as dynamic;
  }

  set custom(dynamic value) {
    _json['custom'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class MediaPartTypeFactory implements JsonExtensionType<MediaPart> {
  const MediaPartTypeFactory();

  @override
  MediaPart parse(Object json) {
    return MediaPart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'media': MediaType.jsonSchema,
        'metadata': Schema.any(),
        'custom': Schema.any(),
      },
      required: ['media', 'metadata', 'custom'],
    );
  }
}

const MediaPartType = MediaPartTypeFactory();

extension type ToolRequestPart(Map<String, dynamic> _json) implements Part {
  factory ToolRequestPart.from({
    required ToolRequest toolRequest,
    dynamic metadata,
    dynamic custom,
  }) {
    return ToolRequestPart({
      'toolRequest': toolRequest.toJson(),
      'metadata': metadata,
      'custom': custom,
    });
  }

  ToolRequest get toolRequest {
    return ToolRequest(_json['toolRequest'] as Map<String, dynamic>);
  }

  set toolRequest(ToolRequest value) {
    _json['toolRequest'] = (value as dynamic)._json;
  }

  dynamic get metadata {
    return _json['metadata'] as dynamic;
  }

  set metadata(dynamic value) {
    _json['metadata'] = value;
  }

  dynamic get custom {
    return _json['custom'] as dynamic;
  }

  set custom(dynamic value) {
    _json['custom'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ToolRequestPartTypeFactory implements JsonExtensionType<ToolRequestPart> {
  const ToolRequestPartTypeFactory();

  @override
  ToolRequestPart parse(Object json) {
    return ToolRequestPart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'toolRequest': ToolRequestType.jsonSchema,
        'metadata': Schema.any(),
        'custom': Schema.any(),
      },
      required: ['toolRequest', 'metadata', 'custom'],
    );
  }
}

const ToolRequestPartType = ToolRequestPartTypeFactory();

extension type ToolResponsePart(Map<String, dynamic> _json) implements Part {
  factory ToolResponsePart.from({
    required ToolResponse toolResponse,
    dynamic metadata,
    dynamic custom,
  }) {
    return ToolResponsePart({
      'toolResponse': toolResponse.toJson(),
      'metadata': metadata,
      'custom': custom,
    });
  }

  ToolResponse get toolResponse {
    return ToolResponse(_json['toolResponse'] as Map<String, dynamic>);
  }

  set toolResponse(ToolResponse value) {
    _json['toolResponse'] = (value as dynamic)._json;
  }

  dynamic get metadata {
    return _json['metadata'] as dynamic;
  }

  set metadata(dynamic value) {
    _json['metadata'] = value;
  }

  dynamic get custom {
    return _json['custom'] as dynamic;
  }

  set custom(dynamic value) {
    _json['custom'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ToolResponsePartTypeFactory
    implements JsonExtensionType<ToolResponsePart> {
  const ToolResponsePartTypeFactory();

  @override
  ToolResponsePart parse(Object json) {
    return ToolResponsePart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'toolResponse': ToolResponseType.jsonSchema,
        'metadata': Schema.any(),
        'custom': Schema.any(),
      },
      required: ['toolResponse', 'metadata', 'custom'],
    );
  }
}

const ToolResponsePartType = ToolResponsePartTypeFactory();

extension type DataPart(Map<String, dynamic> _json) implements Part {
  factory DataPart.from({dynamic metadata, Map<String, dynamic>? custom}) {
    return DataPart({'metadata': metadata, 'custom': custom});
  }

  dynamic get metadata {
    return _json['metadata'] as dynamic;
  }

  set metadata(dynamic value) {
    _json['metadata'] = value;
  }

  Map<String, dynamic>? get custom {
    return _json['custom'] as Map<String, dynamic>?;
  }

  set custom(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class DataPartTypeFactory implements JsonExtensionType<DataPart> {
  const DataPartTypeFactory();

  @override
  DataPart parse(Object json) {
    return DataPart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'metadata': Schema.any(),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['metadata'],
    );
  }
}

const DataPartType = DataPartTypeFactory();

extension type CustomPart(Map<String, dynamic> _json) implements Part {
  factory CustomPart.from({
    Map<String, dynamic>? metadata,
    required Map<String, dynamic> custom,
  }) {
    return CustomPart({'metadata': metadata, 'custom': custom});
  }

  Map<String, dynamic>? get metadata {
    return _json['metadata'] as Map<String, dynamic>?;
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic> get custom {
    return _json['custom'] as Map<String, dynamic>;
  }

  set custom(Map<String, dynamic> value) {
    _json['custom'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class CustomPartTypeFactory implements JsonExtensionType<CustomPart> {
  const CustomPartTypeFactory();

  @override
  CustomPart parse(Object json) {
    return CustomPart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['custom'],
    );
  }
}

const CustomPartType = CustomPartTypeFactory();

extension type ReasoningPart(Map<String, dynamic> _json) implements Part {
  factory ReasoningPart.from({
    dynamic metadata,
    dynamic custom,
    required String reasoning,
  }) {
    return ReasoningPart({
      'metadata': metadata,
      'custom': custom,
      'reasoning': reasoning,
    });
  }

  dynamic get metadata {
    return _json['metadata'] as dynamic;
  }

  set metadata(dynamic value) {
    _json['metadata'] = value;
  }

  dynamic get custom {
    return _json['custom'] as dynamic;
  }

  set custom(dynamic value) {
    _json['custom'] = value;
  }

  String get reasoning {
    return _json['reasoning'] as String;
  }

  set reasoning(String value) {
    _json['reasoning'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ReasoningPartTypeFactory implements JsonExtensionType<ReasoningPart> {
  const ReasoningPartTypeFactory();

  @override
  ReasoningPart parse(Object json) {
    return ReasoningPart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'metadata': Schema.any(),
        'custom': Schema.any(),
        'reasoning': Schema.string(),
      },
      required: ['metadata', 'custom', 'reasoning'],
    );
  }
}

const ReasoningPartType = ReasoningPartTypeFactory();

extension type ResourcePart(Map<String, dynamic> _json) implements Part {
  factory ResourcePart.from({
    dynamic metadata,
    dynamic custom,
    required Map<String, dynamic> resource,
  }) {
    return ResourcePart({
      'metadata': metadata,
      'custom': custom,
      'resource': resource,
    });
  }

  dynamic get metadata {
    return _json['metadata'] as dynamic;
  }

  set metadata(dynamic value) {
    _json['metadata'] = value;
  }

  dynamic get custom {
    return _json['custom'] as dynamic;
  }

  set custom(dynamic value) {
    _json['custom'] = value;
  }

  Map<String, dynamic> get resource {
    return _json['resource'] as Map<String, dynamic>;
  }

  set resource(Map<String, dynamic> value) {
    _json['resource'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ResourcePartTypeFactory implements JsonExtensionType<ResourcePart> {
  const ResourcePartTypeFactory();

  @override
  ResourcePart parse(Object json) {
    return ResourcePart(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'metadata': Schema.any(),
        'custom': Schema.any(),
        'resource': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['metadata', 'custom', 'resource'],
    );
  }
}

const ResourcePartType = ResourcePartTypeFactory();

extension type Media(Map<String, dynamic> _json) {
  factory Media.from({String? contentType, required String url}) {
    return Media({'contentType': contentType, 'url': url});
  }

  String? get contentType {
    return _json['contentType'] as String?;
  }

  set contentType(String? value) {
    if (value == null) {
      _json.remove('contentType');
    } else {
      _json['contentType'] = value;
    }
  }

  String get url {
    return _json['url'] as String;
  }

  set url(String value) {
    _json['url'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class MediaTypeFactory implements JsonExtensionType<Media> {
  const MediaTypeFactory();

  @override
  Media parse(Object json) {
    return Media(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'contentType': Schema.string(), 'url': Schema.string()},
      required: ['url'],
    );
  }
}

const MediaType = MediaTypeFactory();

extension type ToolRequest(Map<String, dynamic> _json) {
  factory ToolRequest.from({String? ref, required String name}) {
    return ToolRequest({'ref': ref, 'name': name});
  }

  String? get ref {
    return _json['ref'] as String?;
  }

  set ref(String? value) {
    if (value == null) {
      _json.remove('ref');
    } else {
      _json['ref'] = value;
    }
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ToolRequestTypeFactory implements JsonExtensionType<ToolRequest> {
  const ToolRequestTypeFactory();

  @override
  ToolRequest parse(Object json) {
    return ToolRequest(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'ref': Schema.string(), 'name': Schema.string()},
      required: ['name'],
    );
  }
}

const ToolRequestType = ToolRequestTypeFactory();

extension type ToolResponse(Map<String, dynamic> _json) {
  factory ToolResponse.from({String? ref, required String name}) {
    return ToolResponse({'ref': ref, 'name': name});
  }

  String? get ref {
    return _json['ref'] as String?;
  }

  set ref(String? value) {
    if (value == null) {
      _json.remove('ref');
    } else {
      _json['ref'] = value;
    }
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ToolResponseTypeFactory implements JsonExtensionType<ToolResponse> {
  const ToolResponseTypeFactory();

  @override
  ToolResponse parse(Object json) {
    return ToolResponse(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'ref': Schema.string(), 'name': Schema.string()},
      required: ['name'],
    );
  }
}

const ToolResponseType = ToolResponseTypeFactory();

extension type ModelRequest(Map<String, dynamic> _json) {
  factory ModelRequest.from({
    dynamic messages,
    dynamic tools,
    dynamic toolChoice,
    dynamic output,
    dynamic docs,
  }) {
    return ModelRequest({
      'messages': messages,
      'tools': tools,
      'toolChoice': toolChoice,
      'output': output,
      'docs': docs,
    });
  }

  dynamic get messages {
    return _json['messages'] as dynamic;
  }

  set messages(dynamic value) {
    _json['messages'] = value;
  }

  dynamic get tools {
    return _json['tools'] as dynamic;
  }

  set tools(dynamic value) {
    _json['tools'] = value;
  }

  dynamic get toolChoice {
    return _json['toolChoice'] as dynamic;
  }

  set toolChoice(dynamic value) {
    _json['toolChoice'] = value;
  }

  dynamic get output {
    return _json['output'] as dynamic;
  }

  set output(dynamic value) {
    _json['output'] = value;
  }

  dynamic get docs {
    return _json['docs'] as dynamic;
  }

  set docs(dynamic value) {
    _json['docs'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ModelRequestTypeFactory implements JsonExtensionType<ModelRequest> {
  const ModelRequestTypeFactory();

  @override
  ModelRequest parse(Object json) {
    return ModelRequest(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'messages': Schema.any(),
        'tools': Schema.any(),
        'toolChoice': Schema.any(),
        'output': Schema.any(),
        'docs': Schema.any(),
      },
      required: ['messages', 'tools', 'toolChoice', 'output', 'docs'],
    );
  }
}

const ModelRequestType = ModelRequestTypeFactory();

extension type ModelResponse(Map<String, dynamic> _json) {
  factory ModelResponse.from({
    dynamic message,
    required FinishReason finishReason,
    dynamic finishMessage,
    dynamic latencyMs,
    dynamic usage,
    dynamic request,
    dynamic operation,
  }) {
    return ModelResponse({
      'message': message,
      'finishReason': finishReason,
      'finishMessage': finishMessage,
      'latencyMs': latencyMs,
      'usage': usage,
      'request': request,
      'operation': operation,
    });
  }

  dynamic get message {
    return _json['message'] as dynamic;
  }

  set message(dynamic value) {
    _json['message'] = value;
  }

  FinishReason get finishReason {
    return FinishReason.values.byName(_json['finishReason'] as String);
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value.name;
  }

  dynamic get finishMessage {
    return _json['finishMessage'] as dynamic;
  }

  set finishMessage(dynamic value) {
    _json['finishMessage'] = value;
  }

  dynamic get latencyMs {
    return _json['latencyMs'] as dynamic;
  }

  set latencyMs(dynamic value) {
    _json['latencyMs'] = value;
  }

  dynamic get usage {
    return _json['usage'] as dynamic;
  }

  set usage(dynamic value) {
    _json['usage'] = value;
  }

  dynamic get request {
    return _json['request'] as dynamic;
  }

  set request(dynamic value) {
    _json['request'] = value;
  }

  dynamic get operation {
    return _json['operation'] as dynamic;
  }

  set operation(dynamic value) {
    _json['operation'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ModelResponseTypeFactory implements JsonExtensionType<ModelResponse> {
  const ModelResponseTypeFactory();

  @override
  ModelResponse parse(Object json) {
    return ModelResponse(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'message': Schema.any(),
        'finishReason': Schema.string(
          enumValues: [
            'stop',
            'length',
            'blocked',
            'interrupted',
            'other',
            'unknown',
          ],
        ),
        'finishMessage': Schema.any(),
        'latencyMs': Schema.any(),
        'usage': Schema.any(),
        'request': Schema.any(),
        'operation': Schema.any(),
      },
      required: [
        'message',
        'finishReason',
        'finishMessage',
        'latencyMs',
        'usage',
        'request',
        'operation',
      ],
    );
  }
}

const ModelResponseType = ModelResponseTypeFactory();

extension type ModelResponseChunk(Map<String, dynamic> _json) {
  factory ModelResponseChunk.from({
    dynamic role,
    dynamic index,
    dynamic content,
    dynamic aggregated,
  }) {
    return ModelResponseChunk({
      'role': role,
      'index': index,
      'content': content,
      'aggregated': aggregated,
    });
  }

  dynamic get role {
    return _json['role'] as dynamic;
  }

  set role(dynamic value) {
    _json['role'] = value;
  }

  dynamic get index {
    return _json['index'] as dynamic;
  }

  set index(dynamic value) {
    _json['index'] = value;
  }

  dynamic get content {
    return _json['content'] as dynamic;
  }

  set content(dynamic value) {
    _json['content'] = value;
  }

  dynamic get aggregated {
    return _json['aggregated'] as dynamic;
  }

  set aggregated(dynamic value) {
    _json['aggregated'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ModelResponseChunkTypeFactory
    implements JsonExtensionType<ModelResponseChunk> {
  const ModelResponseChunkTypeFactory();

  @override
  ModelResponseChunk parse(Object json) {
    return ModelResponseChunk(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'role': Schema.any(),
        'index': Schema.any(),
        'content': Schema.any(),
        'aggregated': Schema.any(),
      },
      required: ['role', 'index', 'content', 'aggregated'],
    );
  }
}

const ModelResponseChunkType = ModelResponseChunkTypeFactory();

extension type GenerationUsage(Map<String, dynamic> _json) {
  factory GenerationUsage.from({
    double? inputTokens,
    double? outputTokens,
    double? totalTokens,
    double? inputCharacters,
    double? outputCharacters,
    double? inputImages,
    double? outputImages,
    double? inputVideos,
    double? outputVideos,
    double? inputAudioFiles,
    double? outputAudioFiles,
    Map<String, dynamic>? custom,
    double? thoughtsTokens,
    double? cachedContentTokens,
  }) {
    return GenerationUsage({
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'totalTokens': totalTokens,
      'inputCharacters': inputCharacters,
      'outputCharacters': outputCharacters,
      'inputImages': inputImages,
      'outputImages': outputImages,
      'inputVideos': inputVideos,
      'outputVideos': outputVideos,
      'inputAudioFiles': inputAudioFiles,
      'outputAudioFiles': outputAudioFiles,
      'custom': custom,
      'thoughtsTokens': thoughtsTokens,
      'cachedContentTokens': cachedContentTokens,
    });
  }

  double? get inputTokens {
    return _json['inputTokens'] as double?;
  }

  set inputTokens(double? value) {
    if (value == null) {
      _json.remove('inputTokens');
    } else {
      _json['inputTokens'] = value;
    }
  }

  double? get outputTokens {
    return _json['outputTokens'] as double?;
  }

  set outputTokens(double? value) {
    if (value == null) {
      _json.remove('outputTokens');
    } else {
      _json['outputTokens'] = value;
    }
  }

  double? get totalTokens {
    return _json['totalTokens'] as double?;
  }

  set totalTokens(double? value) {
    if (value == null) {
      _json.remove('totalTokens');
    } else {
      _json['totalTokens'] = value;
    }
  }

  double? get inputCharacters {
    return _json['inputCharacters'] as double?;
  }

  set inputCharacters(double? value) {
    if (value == null) {
      _json.remove('inputCharacters');
    } else {
      _json['inputCharacters'] = value;
    }
  }

  double? get outputCharacters {
    return _json['outputCharacters'] as double?;
  }

  set outputCharacters(double? value) {
    if (value == null) {
      _json.remove('outputCharacters');
    } else {
      _json['outputCharacters'] = value;
    }
  }

  double? get inputImages {
    return _json['inputImages'] as double?;
  }

  set inputImages(double? value) {
    if (value == null) {
      _json.remove('inputImages');
    } else {
      _json['inputImages'] = value;
    }
  }

  double? get outputImages {
    return _json['outputImages'] as double?;
  }

  set outputImages(double? value) {
    if (value == null) {
      _json.remove('outputImages');
    } else {
      _json['outputImages'] = value;
    }
  }

  double? get inputVideos {
    return _json['inputVideos'] as double?;
  }

  set inputVideos(double? value) {
    if (value == null) {
      _json.remove('inputVideos');
    } else {
      _json['inputVideos'] = value;
    }
  }

  double? get outputVideos {
    return _json['outputVideos'] as double?;
  }

  set outputVideos(double? value) {
    if (value == null) {
      _json.remove('outputVideos');
    } else {
      _json['outputVideos'] = value;
    }
  }

  double? get inputAudioFiles {
    return _json['inputAudioFiles'] as double?;
  }

  set inputAudioFiles(double? value) {
    if (value == null) {
      _json.remove('inputAudioFiles');
    } else {
      _json['inputAudioFiles'] = value;
    }
  }

  double? get outputAudioFiles {
    return _json['outputAudioFiles'] as double?;
  }

  set outputAudioFiles(double? value) {
    if (value == null) {
      _json.remove('outputAudioFiles');
    } else {
      _json['outputAudioFiles'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return _json['custom'] as Map<String, dynamic>?;
  }

  set custom(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
    }
  }

  double? get thoughtsTokens {
    return _json['thoughtsTokens'] as double?;
  }

  set thoughtsTokens(double? value) {
    if (value == null) {
      _json.remove('thoughtsTokens');
    } else {
      _json['thoughtsTokens'] = value;
    }
  }

  double? get cachedContentTokens {
    return _json['cachedContentTokens'] as double?;
  }

  set cachedContentTokens(double? value) {
    if (value == null) {
      _json.remove('cachedContentTokens');
    } else {
      _json['cachedContentTokens'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GenerationUsageTypeFactory implements JsonExtensionType<GenerationUsage> {
  const GenerationUsageTypeFactory();

  @override
  GenerationUsage parse(Object json) {
    return GenerationUsage(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'inputTokens': Schema.number(),
        'outputTokens': Schema.number(),
        'totalTokens': Schema.number(),
        'inputCharacters': Schema.number(),
        'outputCharacters': Schema.number(),
        'inputImages': Schema.number(),
        'outputImages': Schema.number(),
        'inputVideos': Schema.number(),
        'outputVideos': Schema.number(),
        'inputAudioFiles': Schema.number(),
        'outputAudioFiles': Schema.number(),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'thoughtsTokens': Schema.number(),
        'cachedContentTokens': Schema.number(),
      },
      required: [],
    );
  }
}

const GenerationUsageType = GenerationUsageTypeFactory();

extension type Operation(Map<String, dynamic> _json) {
  factory Operation.from({
    String? action,
    required String id,
    bool? done,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  }) {
    return Operation({
      'action': action,
      'id': id,
      'done': done,
      'error': error,
      'metadata': metadata,
    });
  }

  String? get action {
    return _json['action'] as String?;
  }

  set action(String? value) {
    if (value == null) {
      _json.remove('action');
    } else {
      _json['action'] = value;
    }
  }

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  bool? get done {
    return _json['done'] as bool?;
  }

  set done(bool? value) {
    if (value == null) {
      _json.remove('done');
    } else {
      _json['done'] = value;
    }
  }

  Map<String, dynamic>? get error {
    return _json['error'] as Map<String, dynamic>?;
  }

  set error(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('error');
    } else {
      _json['error'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return _json['metadata'] as Map<String, dynamic>?;
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class OperationTypeFactory implements JsonExtensionType<Operation> {
  const OperationTypeFactory();

  @override
  Operation parse(Object json) {
    return Operation(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'action': Schema.string(),
        'id': Schema.string(),
        'done': Schema.boolean(),
        'error': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['id'],
    );
  }
}

const OperationType = OperationTypeFactory();

extension type OutputConfig(Map<String, dynamic> _json) {
  factory OutputConfig.from({
    String? format,
    Map<String, dynamic>? schema,
    bool? constrained,
    String? contentType,
  }) {
    return OutputConfig({
      'format': format,
      'schema': schema,
      'constrained': constrained,
      'contentType': contentType,
    });
  }

  String? get format {
    return _json['format'] as String?;
  }

  set format(String? value) {
    if (value == null) {
      _json.remove('format');
    } else {
      _json['format'] = value;
    }
  }

  Map<String, dynamic>? get schema {
    return _json['schema'] as Map<String, dynamic>?;
  }

  set schema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('schema');
    } else {
      _json['schema'] = value;
    }
  }

  bool? get constrained {
    return _json['constrained'] as bool?;
  }

  set constrained(bool? value) {
    if (value == null) {
      _json.remove('constrained');
    } else {
      _json['constrained'] = value;
    }
  }

  String? get contentType {
    return _json['contentType'] as String?;
  }

  set contentType(String? value) {
    if (value == null) {
      _json.remove('contentType');
    } else {
      _json['contentType'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class OutputConfigTypeFactory implements JsonExtensionType<OutputConfig> {
  const OutputConfigTypeFactory();

  @override
  OutputConfig parse(Object json) {
    return OutputConfig(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'format': Schema.string(),
        'schema': Schema.object(additionalProperties: Schema.any()),
        'constrained': Schema.boolean(),
        'contentType': Schema.string(),
      },
      required: [],
    );
  }
}

const OutputConfigType = OutputConfigTypeFactory();

extension type DocumentData(Map<String, dynamic> _json) {
  factory DocumentData.from({
    required List<Part> content,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentData({
      'content': content.map((e) => e.toJson()).toList(),
      'metadata': metadata,
    });
  }

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => PartType.parse(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.map((e) => (e as dynamic)._json).toList();
  }

  Map<String, dynamic>? get metadata {
    return _json['metadata'] as Map<String, dynamic>?;
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class DocumentDataTypeFactory implements JsonExtensionType<DocumentData> {
  const DocumentDataTypeFactory();

  @override
  DocumentData parse(Object json) {
    return DocumentData(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'content': Schema.list(items: PartType.jsonSchema),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['content'],
    );
  }
}

const DocumentDataType = DocumentDataTypeFactory();

extension type GenerateActionOptions(Map<String, dynamic> _json) {
  factory GenerateActionOptions.from({
    required String model,
    List<DocumentData>? docs,
    required List<Message> messages,
    List<String>? tools,
    String? toolChoice,
    GenerateActionOutputConfig? output,
    Map<String, dynamic>? resume,
    bool? returnToolRequests,
    double? maxTurns,
    String? stepName,
  }) {
    return GenerateActionOptions({
      'model': model,
      'docs': docs?.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'tools': tools,
      'toolChoice': toolChoice,
      'output': output?.toJson(),
      'resume': resume,
      'returnToolRequests': returnToolRequests,
      'maxTurns': maxTurns,
      'stepName': stepName,
    });
  }

  String get model {
    return _json['model'] as String;
  }

  set model(String value) {
    _json['model'] = value;
  }

  List<DocumentData>? get docs {
    return (_json['docs'] as List?)
        ?.map((e) => DocumentData(e as Map<String, dynamic>))
        .toList();
  }

  set docs(List<DocumentData>? value) {
    if (value == null) {
      _json.remove('docs');
    } else {
      _json['docs'] = value?.map((e) => (e as dynamic)._json).toList();
    }
  }

  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.map((e) => (e as dynamic)._json).toList();
  }

  List<String>? get tools {
    return (_json['tools'] as List?)?.cast<String>();
  }

  set tools(List<String>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value;
    }
  }

  String? get toolChoice {
    return _json['toolChoice'] as String?;
  }

  set toolChoice(String? value) {
    if (value == null) {
      _json.remove('toolChoice');
    } else {
      _json['toolChoice'] = value;
    }
  }

  GenerateActionOutputConfig? get output {
    return _json['output'] == null
        ? null
        : GenerateActionOutputConfig(_json['output'] as Map<String, dynamic>);
  }

  set output(GenerateActionOutputConfig? value) {
    if (value == null) {
      _json.remove('output');
    } else {
      _json['output'] = (value as dynamic)?._json;
    }
  }

  Map<String, dynamic>? get resume {
    return _json['resume'] as Map<String, dynamic>?;
  }

  set resume(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('resume');
    } else {
      _json['resume'] = value;
    }
  }

  bool? get returnToolRequests {
    return _json['returnToolRequests'] as bool?;
  }

  set returnToolRequests(bool? value) {
    if (value == null) {
      _json.remove('returnToolRequests');
    } else {
      _json['returnToolRequests'] = value;
    }
  }

  double? get maxTurns {
    return _json['maxTurns'] as double?;
  }

  set maxTurns(double? value) {
    if (value == null) {
      _json.remove('maxTurns');
    } else {
      _json['maxTurns'] = value;
    }
  }

  String? get stepName {
    return _json['stepName'] as String?;
  }

  set stepName(String? value) {
    if (value == null) {
      _json.remove('stepName');
    } else {
      _json['stepName'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GenerateActionOptionsTypeFactory
    implements JsonExtensionType<GenerateActionOptions> {
  const GenerateActionOptionsTypeFactory();

  @override
  GenerateActionOptions parse(Object json) {
    return GenerateActionOptions(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'model': Schema.string(),
        'docs': Schema.list(items: DocumentDataType.jsonSchema),
        'messages': Schema.list(items: MessageType.jsonSchema),
        'tools': Schema.list(items: Schema.string()),
        'toolChoice': Schema.string(),
        'output': GenerateActionOutputConfigType.jsonSchema,
        'resume': Schema.object(additionalProperties: Schema.any()),
        'returnToolRequests': Schema.boolean(),
        'maxTurns': Schema.number(),
        'stepName': Schema.string(),
      },
      required: ['model', 'messages'],
    );
  }
}

const GenerateActionOptionsType = GenerateActionOptionsTypeFactory();

extension type GenerateActionOutputConfig(Map<String, dynamic> _json) {
  factory GenerateActionOutputConfig.from({
    String? format,
    String? contentType,
    bool? instructions,
    bool? constrained,
  }) {
    return GenerateActionOutputConfig({
      'format': format,
      'contentType': contentType,
      'instructions': instructions,
      'constrained': constrained,
    });
  }

  String? get format {
    return _json['format'] as String?;
  }

  set format(String? value) {
    if (value == null) {
      _json.remove('format');
    } else {
      _json['format'] = value;
    }
  }

  String? get contentType {
    return _json['contentType'] as String?;
  }

  set contentType(String? value) {
    if (value == null) {
      _json.remove('contentType');
    } else {
      _json['contentType'] = value;
    }
  }

  bool? get instructions {
    return _json['instructions'] as bool?;
  }

  set instructions(bool? value) {
    if (value == null) {
      _json.remove('instructions');
    } else {
      _json['instructions'] = value;
    }
  }

  bool? get constrained {
    return _json['constrained'] as bool?;
  }

  set constrained(bool? value) {
    if (value == null) {
      _json.remove('constrained');
    } else {
      _json['constrained'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GenerateActionOutputConfigTypeFactory
    implements JsonExtensionType<GenerateActionOutputConfig> {
  const GenerateActionOutputConfigTypeFactory();

  @override
  GenerateActionOutputConfig parse(Object json) {
    return GenerateActionOutputConfig(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'format': Schema.string(),
        'contentType': Schema.string(),
        'instructions': Schema.boolean(),
        'constrained': Schema.boolean(),
      },
      required: [],
    );
  }
}

const GenerateActionOutputConfigType = GenerateActionOutputConfigTypeFactory();
