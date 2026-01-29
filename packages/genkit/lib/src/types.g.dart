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

class Candidate {
  factory Candidate.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Candidate(this._json);

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
      if (usage != null) 'usage': usage.toJson(),
      'finishReason': finishReason,
      if (finishMessage != null) 'finishMessage': finishMessage,
      if (custom != null) 'custom': custom,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Candidate> $schema = _CandidateTypeFactory();

  @override
  double get index {
    return _json['index'] as double;
  }

  set index(double value) {
    _json['index'] = value;
  }

  @override
  Message get message {
    return Message(_json['message'] as Map<String, dynamic>);
  }

  set message(Message value) {
    _json['message'] = value;
  }

  @override
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

  @override
  FinishReason get finishReason {
    return _json['finishReason'] as FinishReason;
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value;
  }

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _CandidateTypeFactory extends SchemanticType<Candidate> {
  const _CandidateTypeFactory();

  @override
  Candidate parse(Object? json) {
    return Candidate(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Candidate',
    definition: Schema.object(
      properties: {
        'index': Schema.number(),
        'message': Schema.fromMap({'\$ref': r'#/$defs/Message'}),
        'usage': Schema.fromMap({'\$ref': r'#/$defs/GenerationUsage'}),
        'finishReason': Schema.any(),
        'finishMessage': Schema.string(),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['index', 'message', 'finishReason'],
    ),
    dependencies: [Message.$schema, GenerationUsage.$schema],
  );
}

class Message {
  factory Message.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Message(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<Message> $schema = _MessageTypeFactory();

  @override
  Role get role {
    return _json['role'] as Role;
  }

  set role(Role value) {
    _json['role'] = value;
  }

  @override
  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
  }

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MessageTypeFactory extends SchemanticType<Message> {
  const _MessageTypeFactory();

  @override
  Message parse(Object? json) {
    return Message(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Message',
    definition: Schema.object(
      properties: {
        'role': Schema.any(),
        'content': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Part'}),
        ),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['role', 'content'],
    ),
    dependencies: [Part.$schema],
  );
}

class ToolDefinition {
  factory ToolDefinition.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolDefinition(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<ToolDefinition> $schema =
      _ToolDefinitionTypeFactory();

  @override
  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  @override
  String get description {
    return _json['description'] as String;
  }

  set description(String value) {
    _json['description'] = value;
  }

  @override
  dynamic get inputSchema {
    return _json['inputSchema'] as dynamic;
  }

  set inputSchema(dynamic value) {
    _json['inputSchema'] = value;
  }

  @override
  dynamic get outputSchema {
    return _json['outputSchema'] as dynamic;
  }

  set outputSchema(dynamic value) {
    _json['outputSchema'] = value;
  }

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ToolDefinitionTypeFactory extends SchemanticType<ToolDefinition> {
  const _ToolDefinitionTypeFactory();

  @override
  ToolDefinition parse(Object? json) {
    return ToolDefinition(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolDefinition',
    definition: Schema.object(
      properties: {
        'name': Schema.string(),
        'description': Schema.string(),
        'inputSchema': Schema.any(),
        'outputSchema': Schema.any(),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['name', 'description', 'inputSchema', 'outputSchema'],
    ),
    dependencies: [],
  );
}

class Part {
  factory Part.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Part(this._json);

  factory Part.from() {
    return Part({});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Part> $schema = _PartTypeFactory();

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _PartTypeFactory extends SchemanticType<Part> {
  const _PartTypeFactory();

  @override
  Part parse(Object? json) {
    return Part(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Part',
    definition: Schema.object(properties: {}, required: []),
    dependencies: [],
  );
}

class TextPart implements Part {
  factory TextPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TextPart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<TextPart> $schema = _TextPartTypeFactory();

  @override
  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _TextPartTypeFactory extends SchemanticType<TextPart> {
  const _TextPartTypeFactory();

  @override
  TextPart parse(Object? json) {
    return TextPart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TextPart',
    definition: Schema.object(
      properties: {
        'text': Schema.string(),
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['text'],
    ),
    dependencies: [],
  );
}

class MediaPart implements Part {
  factory MediaPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  MediaPart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<MediaPart> $schema = _MediaPartTypeFactory();

  @override
  Media get media {
    return Media(_json['media'] as Map<String, dynamic>);
  }

  set media(Media value) {
    _json['media'] = value;
  }

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MediaPartTypeFactory extends SchemanticType<MediaPart> {
  const _MediaPartTypeFactory();

  @override
  MediaPart parse(Object? json) {
    return MediaPart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MediaPart',
    definition: Schema.object(
      properties: {
        'media': Schema.fromMap({'\$ref': r'#/$defs/Media'}),
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['media'],
    ),
    dependencies: [Media.$schema],
  );
}

class ToolRequestPart implements Part {
  factory ToolRequestPart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolRequestPart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<ToolRequestPart> $schema =
      _ToolRequestPartTypeFactory();

  @override
  ToolRequest get toolRequest {
    return ToolRequest(_json['toolRequest'] as Map<String, dynamic>);
  }

  set toolRequest(ToolRequest value) {
    _json['toolRequest'] = value;
  }

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ToolRequestPartTypeFactory extends SchemanticType<ToolRequestPart> {
  const _ToolRequestPartTypeFactory();

  @override
  ToolRequestPart parse(Object? json) {
    return ToolRequestPart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolRequestPart',
    definition: Schema.object(
      properties: {
        'toolRequest': Schema.fromMap({'\$ref': r'#/$defs/ToolRequest'}),
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['toolRequest'],
    ),
    dependencies: [ToolRequest.$schema],
  );
}

class ToolResponsePart implements Part {
  factory ToolResponsePart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolResponsePart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<ToolResponsePart> $schema =
      _ToolResponsePartTypeFactory();

  @override
  ToolResponse get toolResponse {
    return ToolResponse(_json['toolResponse'] as Map<String, dynamic>);
  }

  set toolResponse(ToolResponse value) {
    _json['toolResponse'] = value;
  }

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ToolResponsePartTypeFactory extends SchemanticType<ToolResponsePart> {
  const _ToolResponsePartTypeFactory();

  @override
  ToolResponsePart parse(Object? json) {
    return ToolResponsePart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolResponsePart',
    definition: Schema.object(
      properties: {
        'toolResponse': Schema.fromMap({'\$ref': r'#/$defs/ToolResponse'}),
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['toolResponse'],
    ),
    dependencies: [ToolResponse.$schema],
  );
}

class DataPart implements Part {
  factory DataPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  DataPart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<DataPart> $schema = _DataPartTypeFactory();

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _DataPartTypeFactory extends SchemanticType<DataPart> {
  const _DataPartTypeFactory();

  @override
  DataPart parse(Object? json) {
    return DataPart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'DataPart',
    definition: Schema.object(
      properties: {
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class CustomPart implements Part {
  factory CustomPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  CustomPart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<CustomPart> $schema = _CustomPartTypeFactory();

  @override
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

  @override
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

  @override
  Map<String, dynamic> get custom {
    return _json['custom'] as Map<String, dynamic>;
  }

  set custom(Map<String, dynamic> value) {
    _json['custom'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _CustomPartTypeFactory extends SchemanticType<CustomPart> {
  const _CustomPartTypeFactory();

  @override
  CustomPart parse(Object? json) {
    return CustomPart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CustomPart',
    definition: Schema.object(
      properties: {
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['custom'],
    ),
    dependencies: [],
  );
}

class ReasoningPart implements Part {
  factory ReasoningPart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReasoningPart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<ReasoningPart> $schema =
      _ReasoningPartTypeFactory();

  @override
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

  @override
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

  @override
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

  @override
  String get reasoning {
    return _json['reasoning'] as String;
  }

  set reasoning(String value) {
    _json['reasoning'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ReasoningPartTypeFactory extends SchemanticType<ReasoningPart> {
  const _ReasoningPartTypeFactory();

  @override
  ReasoningPart parse(Object? json) {
    return ReasoningPart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReasoningPart',
    definition: Schema.object(
      properties: {
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'reasoning': Schema.string(),
      },
      required: ['reasoning'],
    ),
    dependencies: [],
  );
}

class ResourcePart implements Part {
  factory ResourcePart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResourcePart(this._json);

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

  @override
  Map<String, dynamic> _json;

  static const SchemanticType<ResourcePart> $schema =
      _ResourcePartTypeFactory();

  @override
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

  @override
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

  @override
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

  @override
  Map<String, dynamic> get resource {
    return _json['resource'] as Map<String, dynamic>;
  }

  set resource(Map<String, dynamic> value) {
    _json['resource'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ResourcePartTypeFactory extends SchemanticType<ResourcePart> {
  const _ResourcePartTypeFactory();

  @override
  ResourcePart parse(Object? json) {
    return ResourcePart(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResourcePart',
    definition: Schema.object(
      properties: {
        'data': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'resource': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['resource'],
    ),
    dependencies: [],
  );
}

class Media {
  factory Media.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Media(this._json);

  factory Media.from({String? contentType, required String url}) {
    return Media({
      if (contentType != null) 'contentType': contentType,
      'url': url,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Media> $schema = _MediaTypeFactory();

  @override
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

  @override
  String get url {
    return _json['url'] as String;
  }

  set url(String value) {
    _json['url'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MediaTypeFactory extends SchemanticType<Media> {
  const _MediaTypeFactory();

  @override
  Media parse(Object? json) {
    return Media(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Media',
    definition: Schema.object(
      properties: {'contentType': Schema.string(), 'url': Schema.string()},
      required: ['url'],
    ),
    dependencies: [],
  );
}

class ToolRequest {
  factory ToolRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolRequest(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<ToolRequest> $schema = _ToolRequestTypeFactory();

  @override
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

  @override
  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ToolRequestTypeFactory extends SchemanticType<ToolRequest> {
  const _ToolRequestTypeFactory();

  @override
  ToolRequest parse(Object? json) {
    return ToolRequest(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolRequest',
    definition: Schema.object(
      properties: {
        'ref': Schema.string(),
        'name': Schema.string(),
        'input': Schema.object(additionalProperties: Schema.any()),
        'partial': Schema.boolean(),
      },
      required: ['name'],
    ),
    dependencies: [],
  );
}

class ToolResponse {
  factory ToolResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolResponse(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<ToolResponse> $schema =
      _ToolResponseTypeFactory();

  @override
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

  @override
  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  @override
  dynamic get output {
    return _json['output'] as dynamic;
  }

  set output(dynamic value) {
    _json['output'] = value;
  }

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ToolResponseTypeFactory extends SchemanticType<ToolResponse> {
  const _ToolResponseTypeFactory();

  @override
  ToolResponse parse(Object? json) {
    return ToolResponse(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolResponse',
    definition: Schema.object(
      properties: {
        'ref': Schema.string(),
        'name': Schema.string(),
        'output': Schema.any(),
        'content': Schema.list(items: Schema.any()),
      },
      required: ['name', 'output'],
    ),
    dependencies: [],
  );
}

class ModelInfo {
  factory ModelInfo.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  ModelInfo(this._json);

  factory ModelInfo.from({
    List<String>? versions,
    String? label,
    Map<String, dynamic>? configSchema,
    Map<String, dynamic>? supports,
    String? stage,
  }) {
    return ModelInfo({
      if (versions != null) 'versions': versions,
      if (label != null) 'label': label,
      if (configSchema != null) 'configSchema': configSchema,
      if (supports != null) 'supports': supports,
      if (stage != null) 'stage': stage,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<ModelInfo> $schema = _ModelInfoTypeFactory();

  @override
  List<String>? get versions {
    return (_json['versions'] as List?)?.cast<String>();
  }

  set versions(List<String>? value) {
    if (value == null) {
      _json.remove('versions');
    } else {
      _json['versions'] = value;
    }
  }

  @override
  String? get label {
    return _json['label'] as String?;
  }

  set label(String? value) {
    if (value == null) {
      _json.remove('label');
    } else {
      _json['label'] = value;
    }
  }

  @override
  Map<String, dynamic>? get configSchema {
    return _json['configSchema'] as Map<String, dynamic>?;
  }

  set configSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('configSchema');
    } else {
      _json['configSchema'] = value;
    }
  }

  @override
  Map<String, dynamic>? get supports {
    return _json['supports'] as Map<String, dynamic>?;
  }

  set supports(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('supports');
    } else {
      _json['supports'] = value;
    }
  }

  @override
  String? get stage {
    return _json['stage'] as String?;
  }

  set stage(String? value) {
    if (value == null) {
      _json.remove('stage');
    } else {
      _json['stage'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ModelInfoTypeFactory extends SchemanticType<ModelInfo> {
  const _ModelInfoTypeFactory();

  @override
  ModelInfo parse(Object? json) {
    return ModelInfo(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelInfo',
    definition: Schema.object(
      properties: {
        'versions': Schema.list(items: Schema.string()),
        'label': Schema.string(),
        'configSchema': Schema.object(additionalProperties: Schema.any()),
        'supports': Schema.object(additionalProperties: Schema.any()),
        'stage': Schema.string(),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class ModelRequest {
  factory ModelRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ModelRequest(this._json);

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
      if (output != null) 'output': output.toJson(),
      if (docs != null) 'docs': docs.map((e) => e.toJson()).toList(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<ModelRequest> $schema =
      _ModelRequestTypeFactory();

  @override
  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ModelRequestTypeFactory extends SchemanticType<ModelRequest> {
  const _ModelRequestTypeFactory();

  @override
  ModelRequest parse(Object? json) {
    return ModelRequest(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelRequest',
    definition: Schema.object(
      properties: {
        'messages': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Message'}),
        ),
        'config': Schema.object(additionalProperties: Schema.any()),
        'tools': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/ToolDefinition'}),
        ),
        'toolChoice': Schema.string(),
        'output': Schema.fromMap({'\$ref': r'#/$defs/OutputConfig'}),
        'docs': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/DocumentData'}),
        ),
      },
      required: ['messages'],
    ),
    dependencies: [
      Message.$schema,
      ToolDefinition.$schema,
      OutputConfig.$schema,
      DocumentData.$schema,
    ],
  );
}

class ModelResponse {
  factory ModelResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ModelResponse(this._json);

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
      if (message != null) 'message': message.toJson(),
      'finishReason': finishReason,
      if (finishMessage != null) 'finishMessage': finishMessage,
      if (latencyMs != null) 'latencyMs': latencyMs,
      if (usage != null) 'usage': usage.toJson(),
      if (custom != null) 'custom': custom,
      if (raw != null) 'raw': raw,
      if (request != null) 'request': request.toJson(),
      if (operation != null) 'operation': operation.toJson(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<ModelResponse> $schema =
      _ModelResponseTypeFactory();

  @override
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

  @override
  FinishReason get finishReason {
    return _json['finishReason'] as FinishReason;
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value;
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ModelResponseTypeFactory extends SchemanticType<ModelResponse> {
  const _ModelResponseTypeFactory();

  @override
  ModelResponse parse(Object? json) {
    return ModelResponse(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelResponse',
    definition: Schema.object(
      properties: {
        'message': Schema.fromMap({'\$ref': r'#/$defs/Message'}),
        'finishReason': Schema.any(),
        'finishMessage': Schema.string(),
        'latencyMs': Schema.number(),
        'usage': Schema.fromMap({'\$ref': r'#/$defs/GenerationUsage'}),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'raw': Schema.object(additionalProperties: Schema.any()),
        'request': Schema.fromMap({'\$ref': r'#/$defs/GenerateRequest'}),
        'operation': Schema.fromMap({'\$ref': r'#/$defs/Operation'}),
      },
      required: ['finishReason'],
    ),
    dependencies: [
      Message.$schema,
      GenerationUsage.$schema,
      GenerateRequest.$schema,
      Operation.$schema,
    ],
  );
}

class ModelResponseChunk {
  factory ModelResponseChunk.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ModelResponseChunk(this._json);

  factory ModelResponseChunk.from({
    Role? role,
    int? index,
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

  Map<String, dynamic> _json;

  static const SchemanticType<ModelResponseChunk> $schema =
      _ModelResponseChunkTypeFactory();

  @override
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

  @override
  int? get index {
    return _json['index'] as int?;
  }

  set index(int? value) {
    if (value == null) {
      _json.remove('index');
    } else {
      _json['index'] = value;
    }
  }

  @override
  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
  }

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ModelResponseChunkTypeFactory
    extends SchemanticType<ModelResponseChunk> {
  const _ModelResponseChunkTypeFactory();

  @override
  ModelResponseChunk parse(Object? json) {
    return ModelResponseChunk(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelResponseChunk',
    definition: Schema.object(
      properties: {
        'role': Schema.any(),
        'index': Schema.integer(),
        'content': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Part'}),
        ),
        'custom': Schema.object(additionalProperties: Schema.any()),
        'aggregated': Schema.boolean(),
      },
      required: ['content'],
    ),
    dependencies: [Part.$schema],
  );
}

class GenerateRequest {
  factory GenerateRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateRequest(this._json);

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
      if (output != null) 'output': output.toJson(),
      if (docs != null) 'docs': docs.map((e) => e.toJson()).toList(),
      if (candidates != null) 'candidates': candidates,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<GenerateRequest> $schema =
      _GenerateRequestTypeFactory();

  @override
  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _GenerateRequestTypeFactory extends SchemanticType<GenerateRequest> {
  const _GenerateRequestTypeFactory();

  @override
  GenerateRequest parse(Object? json) {
    return GenerateRequest(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateRequest',
    definition: Schema.object(
      properties: {
        'messages': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Message'}),
        ),
        'config': Schema.object(additionalProperties: Schema.any()),
        'tools': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/ToolDefinition'}),
        ),
        'toolChoice': Schema.string(),
        'output': Schema.fromMap({'\$ref': r'#/$defs/OutputConfig'}),
        'docs': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/DocumentData'}),
        ),
        'candidates': Schema.number(),
      },
      required: ['messages'],
    ),
    dependencies: [
      Message.$schema,
      ToolDefinition.$schema,
      OutputConfig.$schema,
      DocumentData.$schema,
    ],
  );
}

class GenerationUsage {
  factory GenerationUsage.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerationUsage(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<GenerationUsage> $schema =
      _GenerationUsageTypeFactory();

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _GenerationUsageTypeFactory extends SchemanticType<GenerationUsage> {
  const _GenerationUsageTypeFactory();

  @override
  GenerationUsage parse(Object? json) {
    return GenerationUsage(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerationUsage',
    definition: Schema.object(
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
    ),
    dependencies: [],
  );
}

class Operation {
  factory Operation.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Operation(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<Operation> $schema = _OperationTypeFactory();

  @override
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

  @override
  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _OperationTypeFactory extends SchemanticType<Operation> {
  const _OperationTypeFactory();

  @override
  Operation parse(Object? json) {
    return Operation(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Operation',
    definition: Schema.object(
      properties: {
        'action': Schema.string(),
        'id': Schema.string(),
        'done': Schema.boolean(),
        'output': Schema.object(additionalProperties: Schema.any()),
        'error': Schema.object(additionalProperties: Schema.any()),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['id'],
    ),
    dependencies: [],
  );
}

class OutputConfig {
  factory OutputConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OutputConfig(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<OutputConfig> $schema =
      _OutputConfigTypeFactory();

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _OutputConfigTypeFactory extends SchemanticType<OutputConfig> {
  const _OutputConfigTypeFactory();

  @override
  OutputConfig parse(Object? json) {
    return OutputConfig(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OutputConfig',
    definition: Schema.object(
      properties: {
        'format': Schema.string(),
        'schema': Schema.object(additionalProperties: Schema.any()),
        'constrained': Schema.boolean(),
        'contentType': Schema.string(),
      },
      required: [],
    ),
    dependencies: [],
  );
}

class DocumentData {
  factory DocumentData.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  DocumentData(this._json);

  factory DocumentData.from({
    required List<Part> content,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentData({
      'content': content.map((e) => e.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<DocumentData> $schema =
      _DocumentDataTypeFactory();

  @override
  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
  }

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _DocumentDataTypeFactory extends SchemanticType<DocumentData> {
  const _DocumentDataTypeFactory();

  @override
  DocumentData parse(Object? json) {
    return DocumentData(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'DocumentData',
    definition: Schema.object(
      properties: {
        'content': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Part'}),
        ),
        'metadata': Schema.object(additionalProperties: Schema.any()),
      },
      required: ['content'],
    ),
    dependencies: [Part.$schema],
  );
}

class GenerateActionOptions {
  factory GenerateActionOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateActionOptions(this._json);

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
      if (output != null) 'output': output.toJson(),
      if (resume != null) 'resume': resume,
      if (returnToolRequests != null) 'returnToolRequests': returnToolRequests,
      if (maxTurns != null) 'maxTurns': maxTurns,
      if (stepName != null) 'stepName': stepName,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<GenerateActionOptions> $schema =
      _GenerateActionOptionsTypeFactory();

  @override
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

  @override
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

  @override
  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _GenerateActionOptionsTypeFactory
    extends SchemanticType<GenerateActionOptions> {
  const _GenerateActionOptionsTypeFactory();

  @override
  GenerateActionOptions parse(Object? json) {
    return GenerateActionOptions(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateActionOptions',
    definition: Schema.object(
      properties: {
        'model': Schema.string(),
        'docs': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/DocumentData'}),
        ),
        'messages': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Message'}),
        ),
        'tools': Schema.list(items: Schema.string()),
        'toolChoice': Schema.string(),
        'config': Schema.object(additionalProperties: Schema.any()),
        'output': Schema.fromMap({
          '\$ref': r'#/$defs/GenerateActionOutputConfig',
        }),
        'resume': Schema.object(additionalProperties: Schema.any()),
        'returnToolRequests': Schema.boolean(),
        'maxTurns': Schema.integer(),
        'stepName': Schema.string(),
      },
      required: ['messages'],
    ),
    dependencies: [
      DocumentData.$schema,
      Message.$schema,
      GenerateActionOutputConfig.$schema,
    ],
  );
}

class GenerateActionOutputConfig {
  factory GenerateActionOutputConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateActionOutputConfig(this._json);

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

  Map<String, dynamic> _json;

  static const SchemanticType<GenerateActionOutputConfig> $schema =
      _GenerateActionOutputConfigTypeFactory();

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _GenerateActionOutputConfigTypeFactory
    extends SchemanticType<GenerateActionOutputConfig> {
  const _GenerateActionOutputConfigTypeFactory();

  @override
  GenerateActionOutputConfig parse(Object? json) {
    return GenerateActionOutputConfig(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateActionOutputConfig',
    definition: Schema.object(
      properties: {
        'format': Schema.string(),
        'contentType': Schema.string(),
        'instructions': Schema.boolean(),
        'jsonSchema': Schema.object(additionalProperties: Schema.any()),
        'constrained': Schema.boolean(),
      },
      required: [],
    ),
    dependencies: [],
  );
}
