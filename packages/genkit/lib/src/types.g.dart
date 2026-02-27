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

base class Candidate {
  factory Candidate.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Candidate._(this._json);

  Candidate({
    required double index,
    required Message message,
    GenerationUsage? usage,
    required FinishReason finishReason,
    String? finishMessage,
    Map<String, dynamic>? custom,
  }) {
    _json = {
      'index': index,
      'message': message.toJson(),
      'usage': ?usage?.toJson(),
      'finishReason': finishReason,
      'finishMessage': ?finishMessage,
      'custom': ?custom,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Candidate> $schema = _CandidateTypeFactory();

  double get index {
    return (_json['index'] as num).toDouble();
  }

  set index(double value) {
    _json['index'] = value;
  }

  Message get message {
    return Message.fromJson(_json['message'] as Map<String, dynamic>);
  }

  set message(Message value) {
    _json['message'] = value;
  }

  GenerationUsage? get usage {
    return _json['usage'] == null
        ? null
        : GenerationUsage.fromJson(_json['usage'] as Map<String, dynamic>);
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
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

base class _CandidateTypeFactory extends SchemanticType<Candidate> {
  const _CandidateTypeFactory();

  @override
  Candidate parse(Object? json) {
    return Candidate._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Candidate',
    definition: $Schema
        .object(
          properties: {
            'index': $Schema.number(),
            'message': $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            'usage': $Schema.fromMap({'\$ref': r'#/$defs/GenerationUsage'}),
            'finishReason': $Schema.any(),
            'finishMessage': $Schema.string(),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['index', 'message', 'finishReason'],
        )
        .value,
    dependencies: [Message.$schema, GenerationUsage.$schema],
  );
}

base class Message {
  factory Message.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Message._(this._json);

  Message({
    required Role role,
    required List<Part> content,
    Map<String, dynamic>? metadata,
  }) {
    _json = {
      'role': role,
      'content': content.map((e) => e.toJson()).toList(),
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Message> $schema = _MessageTypeFactory();

  Role get role {
    return _json['role'] as Role;
  }

  set role(Role value) {
    _json['role'] = value;
  }

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
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

base class _MessageTypeFactory extends SchemanticType<Message> {
  const _MessageTypeFactory();

  @override
  Message parse(Object? json) {
    return Message._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Message',
    definition: $Schema
        .object(
          properties: {
            'role': $Schema.any(),
            'content': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Part'}),
            ),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['role', 'content'],
        )
        .value,
    dependencies: [Part.$schema],
  );
}

base class ToolDefinition {
  factory ToolDefinition.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolDefinition._(this._json);

  ToolDefinition({
    required String name,
    required String description,
    Map<String, dynamic>? inputSchema,
    Map<String, dynamic>? outputSchema,
    Map<String, dynamic>? metadata,
  }) {
    _json = {
      'name': name,
      'description': description,
      'inputSchema': ?inputSchema,
      'outputSchema': ?outputSchema,
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolDefinition> $schema =
      _ToolDefinitionTypeFactory();

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

  Map<String, dynamic>? get inputSchema {
    return (_json['inputSchema'] as Map?)?.cast<String, dynamic>();
  }

  set inputSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('inputSchema');
    } else {
      _json['inputSchema'] = value;
    }
  }

  Map<String, dynamic>? get outputSchema {
    return (_json['outputSchema'] as Map?)?.cast<String, dynamic>();
  }

  set outputSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('outputSchema');
    } else {
      _json['outputSchema'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
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

base class _ToolDefinitionTypeFactory extends SchemanticType<ToolDefinition> {
  const _ToolDefinitionTypeFactory();

  @override
  ToolDefinition parse(Object? json) {
    return ToolDefinition._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolDefinition',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'description': $Schema.string(),
            'inputSchema': $Schema.object(additionalProperties: $Schema.any()),
            'outputSchema': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['name', 'description'],
        )
        .value,
    dependencies: [],
  );
}

base class Part {
  factory Part.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Part._(this._json);

  Part() {
    _json = {};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Part> $schema = _PartTypeFactory();

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _PartTypeFactory extends SchemanticType<Part> {
  const _PartTypeFactory();

  @override
  Part parse(Object? json) {
    return Part._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Part',
    definition: $Schema.object(properties: {}, required: []).value,
    dependencies: [],
  );
}

base class TextPart implements Part {
  factory TextPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TextPart._(this._json);

  TextPart({
    required String text,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    _json = {
      'text': text,
      'data': ?data,
      'metadata': ?metadata,
      'custom': ?custom,
    };
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<TextPart> $schema = _TextPartTypeFactory();

  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

base class _TextPartTypeFactory extends SchemanticType<TextPart> {
  const _TextPartTypeFactory();

  @override
  TextPart parse(Object? json) {
    return TextPart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TextPart',
    definition: $Schema
        .object(
          properties: {
            'text': $Schema.string(),
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['text'],
        )
        .value,
    dependencies: [],
  );
}

base class MediaPart implements Part {
  factory MediaPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  MediaPart._(this._json);

  MediaPart({
    required Media media,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    _json = {
      'media': media.toJson(),
      'data': ?data,
      'metadata': ?metadata,
      'custom': ?custom,
    };
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<MediaPart> $schema = _MediaPartTypeFactory();

  Media get media {
    return Media.fromJson(_json['media'] as Map<String, dynamic>);
  }

  set media(Media value) {
    _json['media'] = value;
  }

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

base class _MediaPartTypeFactory extends SchemanticType<MediaPart> {
  const _MediaPartTypeFactory();

  @override
  MediaPart parse(Object? json) {
    return MediaPart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MediaPart',
    definition: $Schema
        .object(
          properties: {
            'media': $Schema.fromMap({'\$ref': r'#/$defs/Media'}),
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['media'],
        )
        .value,
    dependencies: [Media.$schema],
  );
}

base class ToolRequestPart implements Part {
  factory ToolRequestPart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolRequestPart._(this._json);

  ToolRequestPart({
    required ToolRequest toolRequest,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    _json = {
      'toolRequest': toolRequest.toJson(),
      'data': ?data,
      'metadata': ?metadata,
      'custom': ?custom,
    };
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolRequestPart> $schema =
      _ToolRequestPartTypeFactory();

  ToolRequest get toolRequest {
    return ToolRequest.fromJson(_json['toolRequest'] as Map<String, dynamic>);
  }

  set toolRequest(ToolRequest value) {
    _json['toolRequest'] = value;
  }

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

base class _ToolRequestPartTypeFactory extends SchemanticType<ToolRequestPart> {
  const _ToolRequestPartTypeFactory();

  @override
  ToolRequestPart parse(Object? json) {
    return ToolRequestPart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolRequestPart',
    definition: $Schema
        .object(
          properties: {
            'toolRequest': $Schema.fromMap({'\$ref': r'#/$defs/ToolRequest'}),
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['toolRequest'],
        )
        .value,
    dependencies: [ToolRequest.$schema],
  );
}

base class ToolResponsePart implements Part {
  factory ToolResponsePart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolResponsePart._(this._json);

  ToolResponsePart({
    required ToolResponse toolResponse,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    _json = {
      'toolResponse': toolResponse.toJson(),
      'data': ?data,
      'metadata': ?metadata,
      'custom': ?custom,
    };
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolResponsePart> $schema =
      _ToolResponsePartTypeFactory();

  ToolResponse get toolResponse {
    return ToolResponse.fromJson(_json['toolResponse'] as Map<String, dynamic>);
  }

  set toolResponse(ToolResponse value) {
    _json['toolResponse'] = value;
  }

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

base class _ToolResponsePartTypeFactory
    extends SchemanticType<ToolResponsePart> {
  const _ToolResponsePartTypeFactory();

  @override
  ToolResponsePart parse(Object? json) {
    return ToolResponsePart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolResponsePart',
    definition: $Schema
        .object(
          properties: {
            'toolResponse': $Schema.fromMap({'\$ref': r'#/$defs/ToolResponse'}),
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['toolResponse'],
        )
        .value,
    dependencies: [ToolResponse.$schema],
  );
}

base class DataPart implements Part {
  factory DataPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  DataPart._(this._json);

  DataPart({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
  }) {
    _json = {'data': ?data, 'metadata': ?metadata, 'custom': ?custom};
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<DataPart> $schema = _DataPartTypeFactory();

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

base class _DataPartTypeFactory extends SchemanticType<DataPart> {
  const _DataPartTypeFactory();

  @override
  DataPart parse(Object? json) {
    return DataPart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'DataPart',
    definition: $Schema
        .object(
          properties: {
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

base class CustomPart implements Part {
  factory CustomPart.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  CustomPart._(this._json);

  CustomPart({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    required Map<String, dynamic> custom,
  }) {
    _json = {'data': ?data, 'metadata': ?metadata, 'custom': custom};
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<CustomPart> $schema = _CustomPartTypeFactory();

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic> get custom {
    return (_json['custom'] as Map).cast<String, dynamic>();
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

base class _CustomPartTypeFactory extends SchemanticType<CustomPart> {
  const _CustomPartTypeFactory();

  @override
  CustomPart parse(Object? json) {
    return CustomPart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CustomPart',
    definition: $Schema
        .object(
          properties: {
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['custom'],
        )
        .value,
    dependencies: [],
  );
}

base class ReasoningPart implements Part {
  factory ReasoningPart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReasoningPart._(this._json);

  ReasoningPart({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
    required String reasoning,
  }) {
    _json = {
      'data': ?data,
      'metadata': ?metadata,
      'custom': ?custom,
      'reasoning': reasoning,
    };
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<ReasoningPart> $schema =
      _ReasoningPartTypeFactory();

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

  @override
  String toString() {
    return _json.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReasoningPartTypeFactory extends SchemanticType<ReasoningPart> {
  const _ReasoningPartTypeFactory();

  @override
  ReasoningPart parse(Object? json) {
    return ReasoningPart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReasoningPart',
    definition: $Schema
        .object(
          properties: {
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
            'reasoning': $Schema.string(),
          },
          required: ['reasoning'],
        )
        .value,
    dependencies: [],
  );
}

base class ResourcePart implements Part {
  factory ResourcePart.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResourcePart._(this._json);

  ResourcePart({
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? custom,
    required Map<String, dynamic> resource,
  }) {
    _json = {
      'data': ?data,
      'metadata': ?metadata,
      'custom': ?custom,
      'resource': resource,
    };
  }

  @override
  late final Map<String, dynamic> _json;

  static const SchemanticType<ResourcePart> $schema =
      _ResourcePartTypeFactory();

  Map<String, dynamic>? get data {
    return (_json['data'] as Map?)?.cast<String, dynamic>();
  }

  set data(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('data');
    } else {
      _json['data'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
  }

  set metadata(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('metadata');
    } else {
      _json['metadata'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
  }

  set custom(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
    }
  }

  Map<String, dynamic> get resource {
    return (_json['resource'] as Map).cast<String, dynamic>();
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

base class _ResourcePartTypeFactory extends SchemanticType<ResourcePart> {
  const _ResourcePartTypeFactory();

  @override
  ResourcePart parse(Object? json) {
    return ResourcePart._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResourcePart',
    definition: $Schema
        .object(
          properties: {
            'data': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
            'resource': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['resource'],
        )
        .value,
    dependencies: [],
  );
}

base class Media {
  factory Media.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Media._(this._json);

  Media({String? contentType, required String url}) {
    _json = {'contentType': ?contentType, 'url': url};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Media> $schema = _MediaTypeFactory();

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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _MediaTypeFactory extends SchemanticType<Media> {
  const _MediaTypeFactory();

  @override
  Media parse(Object? json) {
    return Media._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Media',
    definition: $Schema
        .object(
          properties: {
            'contentType': $Schema.string(),
            'url': $Schema.string(),
          },
          required: ['url'],
        )
        .value,
    dependencies: [],
  );
}

base class ToolRequest {
  factory ToolRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolRequest._(this._json);

  ToolRequest({
    String? ref,
    required String name,
    Map<String, dynamic>? input,
    bool? partial,
  }) {
    _json = {'ref': ?ref, 'name': name, 'input': ?input, 'partial': ?partial};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolRequest> $schema = _ToolRequestTypeFactory();

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
    return (_json['input'] as Map?)?.cast<String, dynamic>();
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ToolRequestTypeFactory extends SchemanticType<ToolRequest> {
  const _ToolRequestTypeFactory();

  @override
  ToolRequest parse(Object? json) {
    return ToolRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolRequest',
    definition: $Schema
        .object(
          properties: {
            'ref': $Schema.string(),
            'name': $Schema.string(),
            'input': $Schema.object(additionalProperties: $Schema.any()),
            'partial': $Schema.boolean(),
          },
          required: ['name'],
        )
        .value,
    dependencies: [],
  );
}

base class ToolResponse {
  factory ToolResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolResponse._(this._json);

  ToolResponse({
    String? ref,
    required String name,
    dynamic output,
    List<dynamic>? content,
  }) {
    _json = {'ref': ?ref, 'name': name, 'output': ?output, 'content': ?content};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolResponse> $schema =
      _ToolResponseTypeFactory();

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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ToolResponseTypeFactory extends SchemanticType<ToolResponse> {
  const _ToolResponseTypeFactory();

  @override
  ToolResponse parse(Object? json) {
    return ToolResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolResponse',
    definition: $Schema
        .object(
          properties: {
            'ref': $Schema.string(),
            'name': $Schema.string(),
            'output': $Schema.any(),
            'content': $Schema.list(items: $Schema.any()),
          },
          required: ['name', 'output'],
        )
        .value,
    dependencies: [],
  );
}

base class ModelInfo {
  factory ModelInfo.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  ModelInfo._(this._json);

  ModelInfo({
    List<String>? versions,
    String? label,
    Map<String, dynamic>? configSchema,
    Map<String, dynamic>? supports,
    String? stage,
  }) {
    _json = {
      'versions': ?versions,
      'label': ?label,
      'configSchema': ?configSchema,
      'supports': ?supports,
      'stage': ?stage,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ModelInfo> $schema = _ModelInfoTypeFactory();

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

  Map<String, dynamic>? get configSchema {
    return (_json['configSchema'] as Map?)?.cast<String, dynamic>();
  }

  set configSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('configSchema');
    } else {
      _json['configSchema'] = value;
    }
  }

  Map<String, dynamic>? get supports {
    return (_json['supports'] as Map?)?.cast<String, dynamic>();
  }

  set supports(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('supports');
    } else {
      _json['supports'] = value;
    }
  }

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

base class _ModelInfoTypeFactory extends SchemanticType<ModelInfo> {
  const _ModelInfoTypeFactory();

  @override
  ModelInfo parse(Object? json) {
    return ModelInfo._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelInfo',
    definition: $Schema
        .object(
          properties: {
            'versions': $Schema.list(items: $Schema.string()),
            'label': $Schema.string(),
            'configSchema': $Schema.object(additionalProperties: $Schema.any()),
            'supports': $Schema.object(additionalProperties: $Schema.any()),
            'stage': $Schema.string(),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

base class ModelRequest {
  factory ModelRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ModelRequest._(this._json);

  ModelRequest({
    required List<Message> messages,
    Map<String, dynamic>? config,
    List<ToolDefinition>? tools,
    String? toolChoice,
    OutputConfig? output,
    List<DocumentData>? docs,
  }) {
    _json = {
      'messages': messages.map((e) => e.toJson()).toList(),
      'config': ?config,
      'tools': ?tools?.map((e) => e.toJson()).toList(),
      'toolChoice': ?toolChoice,
      'output': ?output?.toJson(),
      'docs': ?docs?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ModelRequest> $schema =
      _ModelRequestTypeFactory();

  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
  }

  Map<String, dynamic>? get config {
    return (_json['config'] as Map?)?.cast<String, dynamic>();
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
        ?.map((e) => ToolDefinition.fromJson(e as Map<String, dynamic>))
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
        : OutputConfig.fromJson(_json['output'] as Map<String, dynamic>);
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
        ?.map((e) => DocumentData.fromJson(e as Map<String, dynamic>))
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

base class _ModelRequestTypeFactory extends SchemanticType<ModelRequest> {
  const _ModelRequestTypeFactory();

  @override
  ModelRequest parse(Object? json) {
    return ModelRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelRequest',
    definition: $Schema
        .object(
          properties: {
            'messages': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            ),
            'config': $Schema.object(additionalProperties: $Schema.any()),
            'tools': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/ToolDefinition'}),
            ),
            'toolChoice': $Schema.string(),
            'output': $Schema.fromMap({'\$ref': r'#/$defs/OutputConfig'}),
            'docs': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/DocumentData'}),
            ),
          },
          required: ['messages'],
        )
        .value,
    dependencies: [
      Message.$schema,
      ToolDefinition.$schema,
      OutputConfig.$schema,
      DocumentData.$schema,
    ],
  );
}

base class ModelResponse {
  factory ModelResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ModelResponse._(this._json);

  ModelResponse({
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
    _json = {
      'message': ?message?.toJson(),
      'finishReason': finishReason,
      'finishMessage': ?finishMessage,
      'latencyMs': ?latencyMs,
      'usage': ?usage?.toJson(),
      'custom': ?custom,
      'raw': ?raw,
      'request': ?request?.toJson(),
      'operation': ?operation?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ModelResponse> $schema =
      _ModelResponseTypeFactory();

  Message? get message {
    return _json['message'] == null
        ? null
        : Message.fromJson(_json['message'] as Map<String, dynamic>);
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
    return (_json['latencyMs'] as num?)?.toDouble();
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
        : GenerationUsage.fromJson(_json['usage'] as Map<String, dynamic>);
  }

  set usage(GenerationUsage? value) {
    if (value == null) {
      _json.remove('usage');
    } else {
      _json['usage'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
  }

  set custom(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
    }
  }

  Map<String, dynamic>? get raw {
    return (_json['raw'] as Map?)?.cast<String, dynamic>();
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
        : GenerateRequest.fromJson(_json['request'] as Map<String, dynamic>);
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
        : Operation.fromJson(_json['operation'] as Map<String, dynamic>);
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

base class _ModelResponseTypeFactory extends SchemanticType<ModelResponse> {
  const _ModelResponseTypeFactory();

  @override
  ModelResponse parse(Object? json) {
    return ModelResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelResponse',
    definition: $Schema
        .object(
          properties: {
            'message': $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            'finishReason': $Schema.any(),
            'finishMessage': $Schema.string(),
            'latencyMs': $Schema.number(),
            'usage': $Schema.fromMap({'\$ref': r'#/$defs/GenerationUsage'}),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
            'raw': $Schema.object(additionalProperties: $Schema.any()),
            'request': $Schema.fromMap({'\$ref': r'#/$defs/GenerateRequest'}),
            'operation': $Schema.fromMap({'\$ref': r'#/$defs/Operation'}),
          },
          required: ['finishReason'],
        )
        .value,
    dependencies: [
      Message.$schema,
      GenerationUsage.$schema,
      GenerateRequest.$schema,
      Operation.$schema,
    ],
  );
}

base class ModelResponseChunk {
  factory ModelResponseChunk.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ModelResponseChunk._(this._json);

  ModelResponseChunk({
    Role? role,
    int? index,
    required List<Part> content,
    Map<String, dynamic>? custom,
    bool? aggregated,
  }) {
    _json = {
      'role': ?role,
      'index': ?index,
      'content': content.map((e) => e.toJson()).toList(),
      'custom': ?custom,
      'aggregated': ?aggregated,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ModelResponseChunk> $schema =
      _ModelResponseChunkTypeFactory();

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

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ModelResponseChunkTypeFactory
    extends SchemanticType<ModelResponseChunk> {
  const _ModelResponseChunkTypeFactory();

  @override
  ModelResponseChunk parse(Object? json) {
    return ModelResponseChunk._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ModelResponseChunk',
    definition: $Schema
        .object(
          properties: {
            'role': $Schema.any(),
            'index': $Schema.integer(),
            'content': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Part'}),
            ),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
            'aggregated': $Schema.boolean(),
          },
          required: ['content'],
        )
        .value,
    dependencies: [Part.$schema],
  );
}

base class GenerateResponse {
  factory GenerateResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateResponse._(this._json);

  GenerateResponse({
    Message? message,
    FinishReason? finishReason,
    String? finishMessage,
    double? latencyMs,
    GenerationUsage? usage,
    Map<String, dynamic>? custom,
    Map<String, dynamic>? raw,
    GenerateRequest? request,
    Operation? operation,
    List<Candidate>? candidates,
  }) {
    _json = {
      'message': ?message?.toJson(),
      'finishReason': ?finishReason,
      'finishMessage': ?finishMessage,
      'latencyMs': ?latencyMs,
      'usage': ?usage?.toJson(),
      'custom': ?custom,
      'raw': ?raw,
      'request': ?request?.toJson(),
      'operation': ?operation?.toJson(),
      'candidates': ?candidates?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<GenerateResponse> $schema =
      _GenerateResponseTypeFactory();

  Message? get message {
    return _json['message'] == null
        ? null
        : Message.fromJson(_json['message'] as Map<String, dynamic>);
  }

  set message(Message? value) {
    if (value == null) {
      _json.remove('message');
    } else {
      _json['message'] = value;
    }
  }

  FinishReason? get finishReason {
    return _json['finishReason'] as FinishReason?;
  }

  set finishReason(FinishReason? value) {
    if (value == null) {
      _json.remove('finishReason');
    } else {
      _json['finishReason'] = value;
    }
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
    return (_json['latencyMs'] as num?)?.toDouble();
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
        : GenerationUsage.fromJson(_json['usage'] as Map<String, dynamic>);
  }

  set usage(GenerationUsage? value) {
    if (value == null) {
      _json.remove('usage');
    } else {
      _json['usage'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
  }

  set custom(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
    }
  }

  Map<String, dynamic>? get raw {
    return (_json['raw'] as Map?)?.cast<String, dynamic>();
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
        : GenerateRequest.fromJson(_json['request'] as Map<String, dynamic>);
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
        : Operation.fromJson(_json['operation'] as Map<String, dynamic>);
  }

  set operation(Operation? value) {
    if (value == null) {
      _json.remove('operation');
    } else {
      _json['operation'] = value;
    }
  }

  List<Candidate>? get candidates {
    return (_json['candidates'] as List?)
        ?.map((e) => Candidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set candidates(List<Candidate>? value) {
    if (value == null) {
      _json.remove('candidates');
    } else {
      _json['candidates'] = value.toList();
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

base class _GenerateResponseTypeFactory
    extends SchemanticType<GenerateResponse> {
  const _GenerateResponseTypeFactory();

  @override
  GenerateResponse parse(Object? json) {
    return GenerateResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateResponse',
    definition: $Schema
        .object(
          properties: {
            'message': $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            'finishReason': $Schema.any(),
            'finishMessage': $Schema.string(),
            'latencyMs': $Schema.number(),
            'usage': $Schema.fromMap({'\$ref': r'#/$defs/GenerationUsage'}),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
            'raw': $Schema.object(additionalProperties: $Schema.any()),
            'request': $Schema.fromMap({'\$ref': r'#/$defs/GenerateRequest'}),
            'operation': $Schema.fromMap({'\$ref': r'#/$defs/Operation'}),
            'candidates': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Candidate'}),
            ),
          },
          required: [],
        )
        .value,
    dependencies: [
      Message.$schema,
      GenerationUsage.$schema,
      GenerateRequest.$schema,
      Operation.$schema,
      Candidate.$schema,
    ],
  );
}

base class GenerateRequest {
  factory GenerateRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateRequest._(this._json);

  GenerateRequest({
    required List<Message> messages,
    Map<String, dynamic>? config,
    List<ToolDefinition>? tools,
    String? toolChoice,
    OutputConfig? output,
    List<DocumentData>? docs,
    double? candidates,
  }) {
    _json = {
      'messages': messages.map((e) => e.toJson()).toList(),
      'config': ?config,
      'tools': ?tools?.map((e) => e.toJson()).toList(),
      'toolChoice': ?toolChoice,
      'output': ?output?.toJson(),
      'docs': ?docs?.map((e) => e.toJson()).toList(),
      'candidates': ?candidates,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<GenerateRequest> $schema =
      _GenerateRequestTypeFactory();

  List<Message> get messages {
    return (_json['messages'] as List)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message> value) {
    _json['messages'] = value.toList();
  }

  Map<String, dynamic>? get config {
    return (_json['config'] as Map?)?.cast<String, dynamic>();
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
        ?.map((e) => ToolDefinition.fromJson(e as Map<String, dynamic>))
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
        : OutputConfig.fromJson(_json['output'] as Map<String, dynamic>);
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
        ?.map((e) => DocumentData.fromJson(e as Map<String, dynamic>))
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
    return (_json['candidates'] as num?)?.toDouble();
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

base class _GenerateRequestTypeFactory extends SchemanticType<GenerateRequest> {
  const _GenerateRequestTypeFactory();

  @override
  GenerateRequest parse(Object? json) {
    return GenerateRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateRequest',
    definition: $Schema
        .object(
          properties: {
            'messages': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            ),
            'config': $Schema.object(additionalProperties: $Schema.any()),
            'tools': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/ToolDefinition'}),
            ),
            'toolChoice': $Schema.string(),
            'output': $Schema.fromMap({'\$ref': r'#/$defs/OutputConfig'}),
            'docs': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/DocumentData'}),
            ),
            'candidates': $Schema.number(),
          },
          required: ['messages'],
        )
        .value,
    dependencies: [
      Message.$schema,
      ToolDefinition.$schema,
      OutputConfig.$schema,
      DocumentData.$schema,
    ],
  );
}

base class GenerationUsage {
  factory GenerationUsage.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerationUsage._(this._json);

  GenerationUsage({
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
    _json = {
      'inputTokens': ?inputTokens,
      'outputTokens': ?outputTokens,
      'totalTokens': ?totalTokens,
      'inputCharacters': ?inputCharacters,
      'outputCharacters': ?outputCharacters,
      'inputImages': ?inputImages,
      'outputImages': ?outputImages,
      'inputVideos': ?inputVideos,
      'outputVideos': ?outputVideos,
      'inputAudioFiles': ?inputAudioFiles,
      'outputAudioFiles': ?outputAudioFiles,
      'custom': ?custom,
      'thoughtsTokens': ?thoughtsTokens,
      'cachedContentTokens': ?cachedContentTokens,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<GenerationUsage> $schema =
      _GenerationUsageTypeFactory();

  double? get inputTokens {
    return (_json['inputTokens'] as num?)?.toDouble();
  }

  set inputTokens(double? value) {
    if (value == null) {
      _json.remove('inputTokens');
    } else {
      _json['inputTokens'] = value;
    }
  }

  double? get outputTokens {
    return (_json['outputTokens'] as num?)?.toDouble();
  }

  set outputTokens(double? value) {
    if (value == null) {
      _json.remove('outputTokens');
    } else {
      _json['outputTokens'] = value;
    }
  }

  double? get totalTokens {
    return (_json['totalTokens'] as num?)?.toDouble();
  }

  set totalTokens(double? value) {
    if (value == null) {
      _json.remove('totalTokens');
    } else {
      _json['totalTokens'] = value;
    }
  }

  double? get inputCharacters {
    return (_json['inputCharacters'] as num?)?.toDouble();
  }

  set inputCharacters(double? value) {
    if (value == null) {
      _json.remove('inputCharacters');
    } else {
      _json['inputCharacters'] = value;
    }
  }

  double? get outputCharacters {
    return (_json['outputCharacters'] as num?)?.toDouble();
  }

  set outputCharacters(double? value) {
    if (value == null) {
      _json.remove('outputCharacters');
    } else {
      _json['outputCharacters'] = value;
    }
  }

  double? get inputImages {
    return (_json['inputImages'] as num?)?.toDouble();
  }

  set inputImages(double? value) {
    if (value == null) {
      _json.remove('inputImages');
    } else {
      _json['inputImages'] = value;
    }
  }

  double? get outputImages {
    return (_json['outputImages'] as num?)?.toDouble();
  }

  set outputImages(double? value) {
    if (value == null) {
      _json.remove('outputImages');
    } else {
      _json['outputImages'] = value;
    }
  }

  double? get inputVideos {
    return (_json['inputVideos'] as num?)?.toDouble();
  }

  set inputVideos(double? value) {
    if (value == null) {
      _json.remove('inputVideos');
    } else {
      _json['inputVideos'] = value;
    }
  }

  double? get outputVideos {
    return (_json['outputVideos'] as num?)?.toDouble();
  }

  set outputVideos(double? value) {
    if (value == null) {
      _json.remove('outputVideos');
    } else {
      _json['outputVideos'] = value;
    }
  }

  double? get inputAudioFiles {
    return (_json['inputAudioFiles'] as num?)?.toDouble();
  }

  set inputAudioFiles(double? value) {
    if (value == null) {
      _json.remove('inputAudioFiles');
    } else {
      _json['inputAudioFiles'] = value;
    }
  }

  double? get outputAudioFiles {
    return (_json['outputAudioFiles'] as num?)?.toDouble();
  }

  set outputAudioFiles(double? value) {
    if (value == null) {
      _json.remove('outputAudioFiles');
    } else {
      _json['outputAudioFiles'] = value;
    }
  }

  Map<String, dynamic>? get custom {
    return (_json['custom'] as Map?)?.cast<String, dynamic>();
  }

  set custom(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
    }
  }

  double? get thoughtsTokens {
    return (_json['thoughtsTokens'] as num?)?.toDouble();
  }

  set thoughtsTokens(double? value) {
    if (value == null) {
      _json.remove('thoughtsTokens');
    } else {
      _json['thoughtsTokens'] = value;
    }
  }

  double? get cachedContentTokens {
    return (_json['cachedContentTokens'] as num?)?.toDouble();
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

base class _GenerationUsageTypeFactory extends SchemanticType<GenerationUsage> {
  const _GenerationUsageTypeFactory();

  @override
  GenerationUsage parse(Object? json) {
    return GenerationUsage._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerationUsage',
    definition: $Schema
        .object(
          properties: {
            'inputTokens': $Schema.number(),
            'outputTokens': $Schema.number(),
            'totalTokens': $Schema.number(),
            'inputCharacters': $Schema.number(),
            'outputCharacters': $Schema.number(),
            'inputImages': $Schema.number(),
            'outputImages': $Schema.number(),
            'inputVideos': $Schema.number(),
            'outputVideos': $Schema.number(),
            'inputAudioFiles': $Schema.number(),
            'outputAudioFiles': $Schema.number(),
            'custom': $Schema.object(additionalProperties: $Schema.any()),
            'thoughtsTokens': $Schema.number(),
            'cachedContentTokens': $Schema.number(),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

base class Operation {
  factory Operation.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Operation._(this._json);

  Operation({
    String? action,
    required String id,
    bool? done,
    Map<String, dynamic>? output,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  }) {
    _json = {
      'action': ?action,
      'id': id,
      'done': ?done,
      'output': ?output,
      'error': ?error,
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Operation> $schema = _OperationTypeFactory();

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
    return (_json['output'] as Map?)?.cast<String, dynamic>();
  }

  set output(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('output');
    } else {
      _json['output'] = value;
    }
  }

  Map<String, dynamic>? get error {
    return (_json['error'] as Map?)?.cast<String, dynamic>();
  }

  set error(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('error');
    } else {
      _json['error'] = value;
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
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

base class _OperationTypeFactory extends SchemanticType<Operation> {
  const _OperationTypeFactory();

  @override
  Operation parse(Object? json) {
    return Operation._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Operation',
    definition: $Schema
        .object(
          properties: {
            'action': $Schema.string(),
            'id': $Schema.string(),
            'done': $Schema.boolean(),
            'output': $Schema.object(additionalProperties: $Schema.any()),
            'error': $Schema.object(additionalProperties: $Schema.any()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['id'],
        )
        .value,
    dependencies: [],
  );
}

base class OutputConfig {
  factory OutputConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OutputConfig._(this._json);

  OutputConfig({
    String? format,
    Map<String, dynamic>? schema,
    bool? constrained,
    String? contentType,
  }) {
    _json = {
      'format': ?format,
      'schema': ?schema,
      'constrained': ?constrained,
      'contentType': ?contentType,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<OutputConfig> $schema =
      _OutputConfigTypeFactory();

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
    return (_json['schema'] as Map?)?.cast<String, dynamic>();
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _OutputConfigTypeFactory extends SchemanticType<OutputConfig> {
  const _OutputConfigTypeFactory();

  @override
  OutputConfig parse(Object? json) {
    return OutputConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OutputConfig',
    definition: $Schema
        .object(
          properties: {
            'format': $Schema.string(),
            'schema': $Schema.object(additionalProperties: $Schema.any()),
            'constrained': $Schema.boolean(),
            'contentType': $Schema.string(),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

base class DocumentData {
  factory DocumentData.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  DocumentData._(this._json);

  DocumentData({required List<Part> content, Map<String, dynamic>? metadata}) {
    _json = {
      'content': content.map((e) => e.toJson()).toList(),
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<DocumentData> $schema =
      _DocumentDataTypeFactory();

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
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

base class _DocumentDataTypeFactory extends SchemanticType<DocumentData> {
  const _DocumentDataTypeFactory();

  @override
  DocumentData parse(Object? json) {
    return DocumentData._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'DocumentData',
    definition: $Schema
        .object(
          properties: {
            'content': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Part'}),
            ),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['content'],
        )
        .value,
    dependencies: [Part.$schema],
  );
}

base class GenerateActionOptions {
  factory GenerateActionOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateActionOptions._(this._json);

  GenerateActionOptions({
    String? model,
    List<DocumentData>? docs,
    required List<Message> messages,
    List<String>? tools,
    String? toolChoice,
    Map<String, dynamic>? config,
    GenerateActionOutputConfig? output,
    GenerateResumeOptions? resume,
    bool? returnToolRequests,
    int? maxTurns,
    String? stepName,
  }) {
    _json = {
      'model': ?model,
      'docs': ?docs?.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'tools': ?tools,
      'toolChoice': ?toolChoice,
      'config': ?config,
      'output': ?output?.toJson(),
      'resume': ?resume?.toJson(),
      'returnToolRequests': ?returnToolRequests,
      'maxTurns': ?maxTurns,
      'stepName': ?stepName,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<GenerateActionOptions> $schema =
      _GenerateActionOptionsTypeFactory();

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
        ?.map((e) => DocumentData.fromJson(e as Map<String, dynamic>))
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
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
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
    return (_json['config'] as Map?)?.cast<String, dynamic>();
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
        : GenerateActionOutputConfig.fromJson(
            _json['output'] as Map<String, dynamic>,
          );
  }

  set output(GenerateActionOutputConfig? value) {
    if (value == null) {
      _json.remove('output');
    } else {
      _json['output'] = value;
    }
  }

  GenerateResumeOptions? get resume {
    return _json['resume'] == null
        ? null
        : GenerateResumeOptions.fromJson(
            _json['resume'] as Map<String, dynamic>,
          );
  }

  set resume(GenerateResumeOptions? value) {
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GenerateActionOptionsTypeFactory
    extends SchemanticType<GenerateActionOptions> {
  const _GenerateActionOptionsTypeFactory();

  @override
  GenerateActionOptions parse(Object? json) {
    return GenerateActionOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateActionOptions',
    definition: $Schema
        .object(
          properties: {
            'model': $Schema.string(),
            'docs': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/DocumentData'}),
            ),
            'messages': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            ),
            'tools': $Schema.list(items: $Schema.string()),
            'toolChoice': $Schema.string(),
            'config': $Schema.object(additionalProperties: $Schema.any()),
            'output': $Schema.fromMap({
              '\$ref': r'#/$defs/GenerateActionOutputConfig',
            }),
            'resume': $Schema.fromMap({
              '\$ref': r'#/$defs/GenerateResumeOptions',
            }),
            'returnToolRequests': $Schema.boolean(),
            'maxTurns': $Schema.integer(),
            'stepName': $Schema.string(),
          },
          required: ['messages'],
        )
        .value,
    dependencies: [
      DocumentData.$schema,
      Message.$schema,
      GenerateActionOutputConfig.$schema,
      GenerateResumeOptions.$schema,
    ],
  );
}

base class GenerateResumeOptions {
  factory GenerateResumeOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateResumeOptions._(this._json);

  GenerateResumeOptions({
    List<ToolResponsePart>? respond,
    List<ToolRequestPart>? restart,
    Map<String, dynamic>? metadata,
  }) {
    _json = {
      'respond': ?respond?.map((e) => e.toJson()).toList(),
      'restart': ?restart?.map((e) => e.toJson()).toList(),
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<GenerateResumeOptions> $schema =
      _GenerateResumeOptionsTypeFactory();

  List<ToolResponsePart>? get respond {
    return (_json['respond'] as List?)
        ?.map((e) => ToolResponsePart.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set respond(List<ToolResponsePart>? value) {
    if (value == null) {
      _json.remove('respond');
    } else {
      _json['respond'] = value.toList();
    }
  }

  List<ToolRequestPart>? get restart {
    return (_json['restart'] as List?)
        ?.map((e) => ToolRequestPart.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set restart(List<ToolRequestPart>? value) {
    if (value == null) {
      _json.remove('restart');
    } else {
      _json['restart'] = value.toList();
    }
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
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

base class _GenerateResumeOptionsTypeFactory
    extends SchemanticType<GenerateResumeOptions> {
  const _GenerateResumeOptionsTypeFactory();

  @override
  GenerateResumeOptions parse(Object? json) {
    return GenerateResumeOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateResumeOptions',
    definition: $Schema
        .object(
          properties: {
            'respond': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/ToolResponsePart'}),
            ),
            'restart': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/ToolRequestPart'}),
            ),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: [],
        )
        .value,
    dependencies: [ToolResponsePart.$schema, ToolRequestPart.$schema],
  );
}

base class GenerateActionOutputConfig {
  factory GenerateActionOutputConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateActionOutputConfig._(this._json);

  GenerateActionOutputConfig({
    String? format,
    String? contentType,
    GenerateActionOutputConfigInstructions? instructions,
    Map<String, dynamic>? jsonSchema,
    bool? constrained,
  }) {
    _json = {
      'format': ?format,
      'contentType': ?contentType,
      if (instructions != null) 'instructions': instructions.value,
      'jsonSchema': ?jsonSchema,
      'constrained': ?constrained,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<GenerateActionOutputConfig> $schema =
      _GenerateActionOutputConfigTypeFactory();

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

  set instructions(GenerateActionOutputConfigInstructions value) {
    _json['instructions'] = value.value;
  }

  // Possible return values are `bool`, `String`
  Object? get instructions {
    return _json['instructions'] as Object?;
  }

  Map<String, dynamic>? get jsonSchema {
    return (_json['jsonSchema'] as Map?)?.cast<String, dynamic>();
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

final class GenerateActionOutputConfigInstructions {
  GenerateActionOutputConfigInstructions.bool(bool this.value);

  GenerateActionOutputConfigInstructions.string(String this.value);

  final Object? value;
}

base class _GenerateActionOutputConfigTypeFactory
    extends SchemanticType<GenerateActionOutputConfig> {
  const _GenerateActionOutputConfigTypeFactory();

  @override
  GenerateActionOutputConfig parse(Object? json) {
    return GenerateActionOutputConfig._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GenerateActionOutputConfig',
    definition: $Schema
        .object(
          properties: {
            'format': $Schema.string(),
            'contentType': $Schema.string(),
            'instructions': $Schema.combined(
              anyOf: [$Schema.boolean(), $Schema.string()],
            ),
            'jsonSchema': $Schema.object(additionalProperties: $Schema.any()),
            'constrained': $Schema.boolean(),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

base class EmbedRequest {
  factory EmbedRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  EmbedRequest._(this._json);

  EmbedRequest({
    required List<DocumentData> input,
    Map<String, dynamic>? options,
  }) {
    _json = {
      'input': input.map((e) => e.toJson()).toList(),
      'options': ?options,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<EmbedRequest> $schema =
      _EmbedRequestTypeFactory();

  List<DocumentData> get input {
    return (_json['input'] as List)
        .map((e) => DocumentData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set input(List<DocumentData> value) {
    _json['input'] = value.toList();
  }

  Map<String, dynamic>? get options {
    return (_json['options'] as Map?)?.cast<String, dynamic>();
  }

  set options(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('options');
    } else {
      _json['options'] = value;
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

base class _EmbedRequestTypeFactory extends SchemanticType<EmbedRequest> {
  const _EmbedRequestTypeFactory();

  @override
  EmbedRequest parse(Object? json) {
    return EmbedRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'EmbedRequest',
    definition: $Schema
        .object(
          properties: {
            'input': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/DocumentData'}),
            ),
            'options': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['input'],
        )
        .value,
    dependencies: [DocumentData.$schema],
  );
}

base class EmbedResponse {
  factory EmbedResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  EmbedResponse._(this._json);

  EmbedResponse({required List<Embedding> embeddings}) {
    _json = {'embeddings': embeddings.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<EmbedResponse> $schema =
      _EmbedResponseTypeFactory();

  List<Embedding> get embeddings {
    return (_json['embeddings'] as List)
        .map((e) => Embedding.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set embeddings(List<Embedding> value) {
    _json['embeddings'] = value.toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _EmbedResponseTypeFactory extends SchemanticType<EmbedResponse> {
  const _EmbedResponseTypeFactory();

  @override
  EmbedResponse parse(Object? json) {
    return EmbedResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'EmbedResponse',
    definition: $Schema
        .object(
          properties: {
            'embeddings': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Embedding'}),
            ),
          },
          required: ['embeddings'],
        )
        .value,
    dependencies: [Embedding.$schema],
  );
}

base class Embedding {
  factory Embedding.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Embedding._(this._json);

  Embedding({required List<double> embedding, Map<String, dynamic>? metadata}) {
    _json = {'embedding': embedding, 'metadata': ?metadata};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Embedding> $schema = _EmbeddingTypeFactory();

  List<double> get embedding {
    return (_json['embedding'] as List).cast<double>();
  }

  set embedding(List<double> value) {
    _json['embedding'] = value;
  }

  Map<String, dynamic>? get metadata {
    return (_json['metadata'] as Map?)?.cast<String, dynamic>();
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

base class _EmbeddingTypeFactory extends SchemanticType<Embedding> {
  const _EmbeddingTypeFactory();

  @override
  Embedding parse(Object? json) {
    return Embedding._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Embedding',
    definition: $Schema
        .object(
          properties: {
            'embedding': $Schema.list(items: $Schema.number()),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['embedding'],
        )
        .value,
    dependencies: [],
  );
}
