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
    Map<String, dynamic>? custom,
  }) {
    return Candidate({
      'index': index,
      'message': message.toJson(),
      if (usage != null) 'usage': usage?.toJson(),
      'finishReason': finishReason,
      if (finishMessage != null) 'finishMessage': finishMessage,
      if (custom != null) 'custom': custom,
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
    _json['message'] = value;
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
      _json['usage'] = value;
    }
  }

  FinishReason get finishReason {
    return _json['finishReason'] as FinishReason;
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value;
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
        'finishReason': Schema.any(),
        'finishMessage': Schema.string(),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['index', 'message', 'finishReason'],
    );
  }
}

// ignore: constant_identifier_names
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
      if (metadata != null) 'metadata': metadata,
    });
  }

  Role get role {
    return _json['role'] as Role;
  }

  set role(Role value) {
    _json['role'] = value;
  }

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
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
        'role': Schema.any(),
        'content': Schema.list(items: PartType.jsonSchema),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['role', 'content'],
    );
  }
}

// ignore: constant_identifier_names
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
      if (inputSchema != null) 'inputSchema': inputSchema,
      if (outputSchema != null) 'outputSchema': outputSchema,
      if (metadata != null) 'metadata': metadata,
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

// ignore: constant_identifier_names
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
    return Part(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(properties: {}, required: []);
  }
}

// ignore: constant_identifier_names
const PartType = PartTypeFactory();

extension type TextPart(Map<String, dynamic> _json) implements Part {
  factory TextPart.from({
    required String text,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    return TextPart({
      'text': text,
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
    });
  }

  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['text'],
    );
  }
}

// ignore: constant_identifier_names
const TextPartType = TextPartTypeFactory();

extension type MediaPart(Map<String, dynamic> _json) implements Part {
  factory MediaPart.from({
    required Media media,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    return MediaPart({
      'media': media.toJson(),
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
    });
  }

  Media get media {
    return Media(_json['media'] as Map<String, dynamic>);
  }

  set media(Media value) {
    _json['media'] = value;
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['media'],
    );
  }
}

// ignore: constant_identifier_names
const MediaPartType = MediaPartTypeFactory();

extension type ToolRequestPart(Map<String, dynamic> _json) implements Part {
  factory ToolRequestPart.from({
    required ToolRequest toolRequest,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    return ToolRequestPart({
      'toolRequest': toolRequest.toJson(),
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
    });
  }

  ToolRequest get toolRequest {
    return ToolRequest(_json['toolRequest'] as Map<String, dynamic>);
  }

  set toolRequest(ToolRequest value) {
    _json['toolRequest'] = value;
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['toolRequest'],
    );
  }
}

// ignore: constant_identifier_names
const ToolRequestPartType = ToolRequestPartTypeFactory();

extension type ToolResponsePart(Map<String, dynamic> _json) implements Part {
  factory ToolResponsePart.from({
    required ToolResponse toolResponse,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    return ToolResponsePart({
      'toolResponse': toolResponse.toJson(),
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
    });
  }

  ToolResponse get toolResponse {
    return ToolResponse(_json['toolResponse'] as Map<String, dynamic>);
  }

  set toolResponse(ToolResponse value) {
    _json['toolResponse'] = value;
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['toolResponse'],
    );
  }
}

// ignore: constant_identifier_names
const ToolResponsePartType = ToolResponsePartTypeFactory();

extension type DataPart(Map<String, dynamic> _json) implements Part {
  factory DataPart.from({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    return DataPart({
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
    });
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: [],
    );
  }
}

// ignore: constant_identifier_names
const DataPartType = DataPartTypeFactory();

extension type CustomPart(Map<String, dynamic> _json) implements Part {
  factory CustomPart.from({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    required Map<String, dynamic> custom,
  }) {
    return CustomPart({
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      'custom': custom,
    });
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['custom'],
    );
  }
}

// ignore: constant_identifier_names
const CustomPartType = CustomPartTypeFactory();

extension type ReasoningPart(Map<String, dynamic> _json) implements Part {
  factory ReasoningPart.from({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
    required String reasoning,
  }) {
    return ReasoningPart({
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
      'reasoning': reasoning,
    });
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'reasoning': Schema.string(),
      },
      required: ['reasoning'],
    );
  }
}

// ignore: constant_identifier_names
const ReasoningPartType = ReasoningPartTypeFactory();

extension type ResourcePart(Map<String, dynamic> _json) implements Part {
  factory ResourcePart.from({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
    required Map<String, dynamic> resource,
  }) {
    return ResourcePart({
      if (data != null) 'data': data,
      if (metadata != null) 'metadata': metadata,
      if (custom != null) 'custom': custom,
      'resource': resource,
    });
  }

  Map<String, dynamic>? get data {
    return _json['data'] as Map<String, dynamic>?;
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
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
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'resource': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['resource'],
    );
  }
}

// ignore: constant_identifier_names
const ResourcePartType = ResourcePartTypeFactory();

extension type Media(Map<String, dynamic> _json) {
  factory Media.from({String? contentType, required String url}) {
    return Media({
      if (contentType != null) 'contentType': contentType,
      'url': url,
    });
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

// ignore: constant_identifier_names
const MediaType = MediaTypeFactory();

extension type ToolRequest(Map<String, dynamic> _json) {
  factory ToolRequest.from({
    String? ref,
    required String name,
    Map<String, dynamic>? input,
    bool? partial,
  }) {
    return ToolRequest({
      if (ref != null) 'ref': ref,
      'name': name,
      if (input != null) 'input': input,
      if (partial != null) 'partial': partial,
    });
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

  Map<String, dynamic>? get input {
    return _json['input'] as Map<String, dynamic>?;
  }

  set input(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('input');
    } else {
      _json['input'] = value;
    }
  }

  bool? get partial {
    return _json['partial'] as bool?;
  }

  set partial(bool? value) {
    if (value == null) {
      _json.remove('partial');
    } else {
      _json['partial'] = value;
    }
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
      properties: {
        'ref': Schema.string(),
        'name': Schema.string(),
        'input': Schema.object(additionalProperties: Schema.any()),
        'partial': Schema.boolean(),
      },
      required: ['name'],
    );
  }
}

// ignore: constant_identifier_names
const ToolRequestType = ToolRequestTypeFactory();

extension type ToolResponse(Map<String, dynamic> _json) {
  factory ToolResponse.from({
    String? ref,
    required String name,
    dynamic output,
    List<dynamic>? content,
  }) {
    return ToolResponse({
      if (ref != null) 'ref': ref,
      'name': name,
      if (output != null) 'output': output,
      if (content != null) 'content': content,
    });
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

  dynamic get output {
    return _json['output'] as dynamic;
  }

  set output(dynamic value) {
    _json['output'] = value;
  }

  List<dynamic>? get content {
    return (_json['content'] as List?)?.cast<dynamic>();
  }

  set content(List<dynamic>? value) {
    if (value == null) {
      _json.remove('content');
    } else {
      _json['content'] = value;
    }
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
      properties: {
        'ref': Schema.string(),
        'name': Schema.string(),
        'output': Schema.any(),
        'content': Schema.list(items: Schema.any()),
      },
      required: ['name', 'output'],
    );
  }
}

// ignore: constant_identifier_names
const ToolResponseType = ToolResponseTypeFactory();

extension type ModelRequest(Map<String, dynamic> _json) {
  factory ModelRequest.from({
    required List<Message> messages,
    Map<String, dynamic>? config,
    List<ToolDefinition>? tools,
    String? toolChoice,
    OutputConfig? output,
    List<DocumentData>? docs,
  }) {
    return ModelRequest({
      'messages': messages.map((e) => e.toJson()).toList(),
      if (config != null) 'config': config,
      if (tools != null) 'tools': tools.map((e) => e.toJson()).toList(),
      if (toolChoice != null) 'toolChoice': toolChoice,
      if (output != null) 'output': output?.toJson(),
      if (docs != null) 'docs': docs.map((e) => e.toJson()).toList(),
    });
  }

  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
  }

  Map<String, dynamic>? get config {
    return _json['config'] as Map<String, dynamic>?;
  }

  set config(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('config');
    } else {
      _json['config'] = value;
    }
  }

  List<ToolDefinition>? get tools {
    return (_json['tools'] as List?)
        ?.map((e) => ToolDefinition(e as Map<String, dynamic>))
        .toList();
  }

  set tools(List<ToolDefinition>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value.toList();
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

  OutputConfig? get output {
    return _json['output'] == null
        ? null
        : OutputConfig(_json['output'] as Map<String, dynamic>);
  }

  set output(OutputConfig? value) {
    if (value == null) {
      _json.remove('output');
    } else {
      _json['output'] = value;
    }
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
      _json['docs'] = value.toList();
    }
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
        'messages': Schema.list(items: MessageType.jsonSchema),
        'config': Schema.object(additionalProperties: Schema.any()),
        'tools': Schema.list(items: ToolDefinitionType.jsonSchema),
        'toolChoice': Schema.string(),
        'output': OutputConfigType.jsonSchema,
        'docs': Schema.list(items: DocumentDataType.jsonSchema),
      },
      required: ['messages'],
    );
  }
}

// ignore: constant_identifier_names
const ModelRequestType = ModelRequestTypeFactory();

extension type ModelResponse(Map<String, dynamic> _json) {
  factory ModelResponse.from({
    Message? message,
    required FinishReason finishReason,
    String? finishMessage,
    double? latencyMs,
    GenerationUsage? usage,
    Map<String, dynamic>? custom,
    Map<String, dynamic>? raw,
    GenerateRequest? request,
    Operation? operation,
  }) {
    return ModelResponse({
      if (message != null) 'message': message?.toJson(),
      'finishReason': finishReason,
      if (finishMessage != null) 'finishMessage': finishMessage,
      if (latencyMs != null) 'latencyMs': latencyMs,
      if (usage != null) 'usage': usage?.toJson(),
      if (custom != null) 'custom': custom,
      if (raw != null) 'raw': raw,
      if (request != null) 'request': request?.toJson(),
      if (operation != null) 'operation': operation?.toJson(),
    });
  }

  Message? get message {
    return _json['message'] == null
        ? null
        : Message(_json['message'] as Map<String, dynamic>);
  }

  set message(Message? value) {
    if (value == null) {
      _json.remove('message');
    } else {
      _json['message'] = value;
    }
  }

  FinishReason get finishReason {
    return _json['finishReason'] as FinishReason;
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value;
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

  double? get latencyMs {
    return _json['latencyMs'] as double?;
  }

  set latencyMs(double? value) {
    if (value == null) {
      _json.remove('latencyMs');
    } else {
      _json['latencyMs'] = value;
    }
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
      _json['usage'] = value;
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

  Map<String, dynamic>? get raw {
    return _json['raw'] as Map<String, dynamic>?;
  }

  set raw(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('raw');
    } else {
      _json['raw'] = value;
    }
  }

  GenerateRequest? get request {
    return _json['request'] == null
        ? null
        : GenerateRequest(_json['request'] as Map<String, dynamic>);
  }

  set request(GenerateRequest? value) {
    if (value == null) {
      _json.remove('request');
    } else {
      _json['request'] = value;
    }
  }

  Operation? get operation {
    return _json['operation'] == null
        ? null
        : Operation(_json['operation'] as Map<String, dynamic>);
  }

  set operation(Operation? value) {
    if (value == null) {
      _json.remove('operation');
    } else {
      _json['operation'] = value;
    }
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
        'message': MessageType.jsonSchema,
        'finishReason': Schema.any(),
        'finishMessage': Schema.string(),
        'latencyMs': Schema.number(),
        'usage': GenerationUsageType.jsonSchema,
        'custom': Schema.object(additionalProperties: Schema.any()),
        'raw': Schema.object(additionalProperties: Schema.any()),
        'request': GenerateRequestType.jsonSchema,
        'operation': OperationType.jsonSchema,
      },
      required: ['finishReason'],
    );
  }
}

// ignore: constant_identifier_names
const ModelResponseType = ModelResponseTypeFactory();

extension type ModelResponseChunk(Map<String, dynamic> _json) {
  factory ModelResponseChunk.from({
    Role? role,
    double? index,
    required List<Part> content,
    Map<String, dynamic>? custom,
    bool? aggregated,
  }) {
    return ModelResponseChunk({
      if (role != null) 'role': role,
      if (index != null) 'index': index,
      'content': content.map((e) => e.toJson()).toList(),
      if (custom != null) 'custom': custom,
      if (aggregated != null) 'aggregated': aggregated,
    });
  }

  Role? get role {
    return _json['role'] as Role?;
  }

  set role(Role? value) {
    if (value == null) {
      _json.remove('role');
    } else {
      _json['role'] = value;
    }
  }

  double? get index {
    return _json['index'] as double?;
  }

  set index(double? value) {
    if (value == null) {
      _json.remove('index');
    } else {
      _json['index'] = value;
    }
  }

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
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

  bool? get aggregated {
    return _json['aggregated'] as bool?;
  }

  set aggregated(bool? value) {
    if (value == null) {
      _json.remove('aggregated');
    } else {
      _json['aggregated'] = value;
    }
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
        'index': Schema.number(),
        'content': Schema.list(items: PartType.jsonSchema),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'aggregated': Schema.boolean(),
      },
      required: ['content'],
    );
  }
}

// ignore: constant_identifier_names
const ModelResponseChunkType = ModelResponseChunkTypeFactory();

extension type GenerateRequest(Map<String, dynamic> _json) {
  factory GenerateRequest.from({
    required List<Message> messages,
    Map<String, dynamic>? config,
    List<ToolDefinition>? tools,
    String? toolChoice,
    OutputConfig? output,
    List<DocumentData>? docs,
    double? candidates,
  }) {
    return GenerateRequest({
      'messages': messages.map((e) => e.toJson()).toList(),
      if (config != null) 'config': config,
      if (tools != null) 'tools': tools.map((e) => e.toJson()).toList(),
      if (toolChoice != null) 'toolChoice': toolChoice,
      if (output != null) 'output': output?.toJson(),
      if (docs != null) 'docs': docs.map((e) => e.toJson()).toList(),
      if (candidates != null) 'candidates': candidates,
    });
  }

  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
  }

  Map<String, dynamic>? get config {
    return _json['config'] as Map<String, dynamic>?;
  }

  set config(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('config');
    } else {
      _json['config'] = value;
    }
  }

  List<ToolDefinition>? get tools {
    return (_json['tools'] as List?)
        ?.map((e) => ToolDefinition(e as Map<String, dynamic>))
        .toList();
  }

  set tools(List<ToolDefinition>? value) {
    if (value == null) {
      _json.remove('tools');
    } else {
      _json['tools'] = value.toList();
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

  OutputConfig? get output {
    return _json['output'] == null
        ? null
        : OutputConfig(_json['output'] as Map<String, dynamic>);
  }

  set output(OutputConfig? value) {
    if (value == null) {
      _json.remove('output');
    } else {
      _json['output'] = value;
    }
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
      _json['docs'] = value.toList();
    }
  }

  double? get candidates {
    return _json['candidates'] as double?;
  }

  set candidates(double? value) {
    if (value == null) {
      _json.remove('candidates');
    } else {
      _json['candidates'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GenerateRequestTypeFactory implements JsonExtensionType<GenerateRequest> {
  const GenerateRequestTypeFactory();

  @override
  GenerateRequest parse(Object json) {
    return GenerateRequest(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'messages': Schema.list(items: MessageType.jsonSchema),
        'config': Schema.object(additionalProperties: Schema.any()),
        'tools': Schema.list(items: ToolDefinitionType.jsonSchema),
        'toolChoice': Schema.string(),
        'output': OutputConfigType.jsonSchema,
        'docs': Schema.list(items: DocumentDataType.jsonSchema),
        'candidates': Schema.number(),
      },
      required: ['messages'],
    );
  }
}

// ignore: constant_identifier_names
const GenerateRequestType = GenerateRequestTypeFactory();

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
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (totalTokens != null) 'totalTokens': totalTokens,
      if (inputCharacters != null) 'inputCharacters': inputCharacters,
      if (outputCharacters != null) 'outputCharacters': outputCharacters,
      if (inputImages != null) 'inputImages': inputImages,
      if (outputImages != null) 'outputImages': outputImages,
      if (inputVideos != null) 'inputVideos': inputVideos,
      if (outputVideos != null) 'outputVideos': outputVideos,
      if (inputAudioFiles != null) 'inputAudioFiles': inputAudioFiles,
      if (outputAudioFiles != null) 'outputAudioFiles': outputAudioFiles,
      if (custom != null) 'custom': custom,
      if (thoughtsTokens != null) 'thoughtsTokens': thoughtsTokens,
      if (cachedContentTokens != null)
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

// ignore: constant_identifier_names
const GenerationUsageType = GenerationUsageTypeFactory();

extension type Operation(Map<String, dynamic> _json) {
  factory Operation.from({
    String? action,
    required String id,
    bool? done,
    Map<String, dynamic>? output,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  }) {
    return Operation({
      if (action != null) 'action': action,
      'id': id,
      if (done != null) 'done': done,
      if (output != null) 'output': output,
      if (error != null) 'error': error,
      if (metadata != null) 'metadata': metadata,
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

  Map<String, dynamic>? get output {
    return _json['output'] as Map<String, dynamic>?;
  }

  set output(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('output');
    } else {
      _json['output'] = value;
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
        'output': Schema.object(additionalProperties: Schema.any()),
        'error': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['id'],
    );
  }
}

// ignore: constant_identifier_names
const OperationType = OperationTypeFactory();

extension type OutputConfig(Map<String, dynamic> _json) {
  factory OutputConfig.from({
    String? format,
    Map<String, dynamic>? schema,
    bool? constrained,
    String? contentType,
  }) {
    return OutputConfig({
      if (format != null) 'format': format,
      if (schema != null) 'schema': schema,
      if (constrained != null) 'constrained': constrained,
      if (contentType != null) 'contentType': contentType,
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

// ignore: constant_identifier_names
const OutputConfigType = OutputConfigTypeFactory();

extension type DocumentData(Map<String, dynamic> _json) {
  factory DocumentData.from({
    required List<Part> content,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentData({
      'content': content.map((e) => e.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    });
  }

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
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

// ignore: constant_identifier_names
const DocumentDataType = DocumentDataTypeFactory();

extension type GenerateActionOptions(Map<String, dynamic> _json) {
  factory GenerateActionOptions.from({
    String? model,
    List<DocumentData>? docs,
    required List<Message> messages,
    List<String>? tools,
    String? toolChoice,
    Map<String, dynamic>? config,
    GenerateActionOutputConfig? output,
    Map<String, dynamic>? resume,
    bool? returnToolRequests,
    int? maxTurns,
    String? stepName,
  }) {
    return GenerateActionOptions({
      if (model != null) 'model': model,
      if (docs != null) 'docs': docs.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      if (tools != null) 'tools': tools,
      if (toolChoice != null) 'toolChoice': toolChoice,
      if (config != null) 'config': config,
      if (output != null) 'output': output?.toJson(),
      if (resume != null) 'resume': resume,
      if (returnToolRequests != null) 'returnToolRequests': returnToolRequests,
      if (maxTurns != null) 'maxTurns': maxTurns,
      if (stepName != null) 'stepName': stepName,
    });
  }

  String? get model {
    return _json['model'] as String?;
  }

  set model(String? value) {
    if (value == null) {
      _json.remove('model');
    } else {
      _json['model'] = value;
    }
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
      _json['docs'] = value.toList();
    }
  }

  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
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

  Map<String, dynamic>? get config {
    return _json['config'] as Map<String, dynamic>?;
  }

  set config(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('config');
    } else {
      _json['config'] = value;
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
      _json['output'] = value;
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

  int? get maxTurns {
    return _json['maxTurns'] as int?;
  }

  set maxTurns(int? value) {
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
        'config': Schema.object(additionalProperties: Schema.any()),
        'output': GenerateActionOutputConfigType.jsonSchema,
        'resume': Schema.object(additionalProperties: Schema.any()),
        'returnToolRequests': Schema.boolean(),
        'maxTurns': Schema.integer(),
        'stepName': Schema.string(),
      },
      required: ['messages'],
    );
  }
}

// ignore: constant_identifier_names
const GenerateActionOptionsType = GenerateActionOptionsTypeFactory();

extension type GenerateActionOutputConfig(Map<String, dynamic> _json) {
  factory GenerateActionOutputConfig.from({
    String? format,
    String? contentType,
    bool? instructions,
    Map<String, dynamic>? jsonSchema,
    bool? constrained,
  }) {
    return GenerateActionOutputConfig({
      if (format != null) 'format': format,
      if (contentType != null) 'contentType': contentType,
      if (instructions != null) 'instructions': instructions,
      if (jsonSchema != null) 'jsonSchema': jsonSchema,
      if (constrained != null) 'constrained': constrained,
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

  Map<String, dynamic>? get jsonSchema {
    return _json['jsonSchema'] as Map<String, dynamic>?;
  }

  set jsonSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('jsonSchema');
    } else {
      _json['jsonSchema'] = value;
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
        'jsonSchema': Schema.object(additionalProperties: Schema.any()),
        'constrained': Schema.boolean(),
      },
      required: [],
    );
  }
}

// ignore: constant_identifier_names
const GenerateActionOutputConfigType = GenerateActionOutputConfigTypeFactory();
