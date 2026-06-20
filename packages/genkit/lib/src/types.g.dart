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
  /// Creates a [Candidate] from a JSON map.
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
      'finishReason': finishReason.value,
      'finishMessage': ?finishMessage,
      'custom': ?custom,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Candidate].
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
    final value = _json['finishReason'] as String;
    return FinishReason(value);
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value.value;
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

  /// Serializes this [Candidate] to a JSON map.
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
  /// Creates a [Message] from a JSON map.
  factory Message.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Message._(this._json);

  Message({
    required Role role,
    required List<Part> content,
    Map<String, dynamic>? metadata,
  }) {
    _json = {
      'role': role.value,
      'content': content.map((e) => e.toJson()).toList(),
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Message].
  static const SchemanticType<Message> $schema = _MessageTypeFactory();

  Role get role {
    final value = _json['role'] as String;
    return Role(value);
  }

  set role(Role value) {
    _json['role'] = value.value;
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

  /// Serializes this [Message] to a JSON map.
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
  /// Creates a [ToolDefinition] from a JSON map.
  factory ToolDefinition.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolDefinition._(this._json);

  ToolDefinition({
    required String name,
    String? key,
    required String description,
    Map<String, dynamic>? inputSchema,
    Map<String, dynamic>? outputSchema,
    Map<String, dynamic>? metadata,
  }) {
    _json = {
      'name': name,
      'key': ?key,
      'description': description,
      'inputSchema': ?inputSchema,
      'outputSchema': ?outputSchema,
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ToolDefinition].
  static const SchemanticType<ToolDefinition> $schema =
      _ToolDefinitionTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String? get key {
    return _json['key'] as String?;
  }

  set key(String? value) {
    if (value == null) {
      _json.remove('key');
    } else {
      _json['key'] = value;
    }
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

  /// Serializes this [ToolDefinition] to a JSON map.
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
            'key': $Schema.string(),
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
  /// Creates a [Part] from a JSON map.
  factory Part.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Part._(this._json);

  Part() {
    _json = {};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Part].
  static const SchemanticType<Part> $schema = _PartTypeFactory();

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Part] to a JSON map.
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
    definition: $Schema.object(properties: {}).value,
    dependencies: [],
  );
}

base class TextPart implements Part {
  /// Creates a [TextPart] from a JSON map.
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

  /// The JSON schema and type descriptor for [TextPart].
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

  /// Serializes this [TextPart] to a JSON map.
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
  /// Creates a [MediaPart] from a JSON map.
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

  /// The JSON schema and type descriptor for [MediaPart].
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

  /// Serializes this [MediaPart] to a JSON map.
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
  /// Creates a [ToolRequestPart] from a JSON map.
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

  /// The JSON schema and type descriptor for [ToolRequestPart].
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

  /// Serializes this [ToolRequestPart] to a JSON map.
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
  /// Creates a [ToolResponsePart] from a JSON map.
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

  /// The JSON schema and type descriptor for [ToolResponsePart].
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

  /// Serializes this [ToolResponsePart] to a JSON map.
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
  /// Creates a [DataPart] from a JSON map.
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

  /// The JSON schema and type descriptor for [DataPart].
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

  /// Serializes this [DataPart] to a JSON map.
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
        )
        .value,
    dependencies: [],
  );
}

base class CustomPart implements Part {
  /// Creates a [CustomPart] from a JSON map.
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

  /// The JSON schema and type descriptor for [CustomPart].
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

  /// Serializes this [CustomPart] to a JSON map.
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
  /// Creates a [ReasoningPart] from a JSON map.
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

  /// The JSON schema and type descriptor for [ReasoningPart].
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

  /// Serializes this [ReasoningPart] to a JSON map.
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
  /// Creates a [ResourcePart] from a JSON map.
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

  /// The JSON schema and type descriptor for [ResourcePart].
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

  /// Serializes this [ResourcePart] to a JSON map.
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

base class BaseDataPoint {
  /// Creates a [BaseDataPoint] from a JSON map.
  factory BaseDataPoint.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  BaseDataPoint._(this._json);

  BaseDataPoint({
    Map<String, dynamic>? input,
    Map<String, dynamic>? output,
    List<Map<String, dynamic>>? context,
    Map<String, dynamic>? reference,
    String? testCaseId,
    List<String>? traceIds,
  }) {
    _json = {
      'input': ?input,
      'output': ?output,
      'context': ?context,
      'reference': ?reference,
      'testCaseId': ?testCaseId,
      'traceIds': ?traceIds,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [BaseDataPoint].
  static const SchemanticType<BaseDataPoint> $schema =
      _BaseDataPointTypeFactory();

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

  List<Map<String, dynamic>>? get context {
    return (_json['context'] as List?)?.cast<Map<String, dynamic>>();
  }

  set context(List<Map<String, dynamic>>? value) {
    if (value == null) {
      _json.remove('context');
    } else {
      _json['context'] = value;
    }
  }

  Map<String, dynamic>? get reference {
    return (_json['reference'] as Map?)?.cast<String, dynamic>();
  }

  set reference(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('reference');
    } else {
      _json['reference'] = value;
    }
  }

  String? get testCaseId {
    return _json['testCaseId'] as String?;
  }

  set testCaseId(String? value) {
    if (value == null) {
      _json.remove('testCaseId');
    } else {
      _json['testCaseId'] = value;
    }
  }

  List<String>? get traceIds {
    return (_json['traceIds'] as List?)?.cast<String>();
  }

  set traceIds(List<String>? value) {
    if (value == null) {
      _json.remove('traceIds');
    } else {
      _json['traceIds'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [BaseDataPoint] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _BaseDataPointTypeFactory extends SchemanticType<BaseDataPoint> {
  const _BaseDataPointTypeFactory();

  @override
  BaseDataPoint parse(Object? json) {
    return BaseDataPoint._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'BaseDataPoint',
    definition: $Schema
        .object(
          properties: {
            'input': $Schema.object(additionalProperties: $Schema.any()),
            'output': $Schema.object(additionalProperties: $Schema.any()),
            'context': $Schema.list(
              items: $Schema.object(additionalProperties: $Schema.any()),
            ),
            'reference': $Schema.object(additionalProperties: $Schema.any()),
            'testCaseId': $Schema.string(),
            'traceIds': $Schema.list(items: $Schema.string()),
          },
        )
        .value,
    dependencies: [],
  );
}

base class EvalRequest {
  /// Creates a [EvalRequest] from a JSON map.
  factory EvalRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  EvalRequest._(this._json);

  EvalRequest({
    required List<BaseDataPoint> dataset,
    required String evalRunId,
    Map<String, dynamic>? options,
  }) {
    _json = {
      'dataset': dataset.map((e) => e.toJson()).toList(),
      'evalRunId': evalRunId,
      'options': ?options,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [EvalRequest].
  static const SchemanticType<EvalRequest> $schema = _EvalRequestTypeFactory();

  List<BaseDataPoint> get dataset {
    return (_json['dataset'] as List)
        .map((e) => BaseDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set dataset(List<BaseDataPoint> value) {
    _json['dataset'] = value.toList();
  }

  String get evalRunId {
    return _json['evalRunId'] as String;
  }

  set evalRunId(String value) {
    _json['evalRunId'] = value;
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

  /// Serializes this [EvalRequest] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _EvalRequestTypeFactory extends SchemanticType<EvalRequest> {
  const _EvalRequestTypeFactory();

  @override
  EvalRequest parse(Object? json) {
    return EvalRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'EvalRequest',
    definition: $Schema
        .object(
          properties: {
            'dataset': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/BaseDataPoint'}),
            ),
            'evalRunId': $Schema.string(),
            'options': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['dataset', 'evalRunId'],
        )
        .value,
    dependencies: [BaseDataPoint.$schema],
  );
}

base class EvalFnResponse {
  /// Creates a [EvalFnResponse] from a JSON map.
  factory EvalFnResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  EvalFnResponse._(this._json);

  EvalFnResponse({
    double? sampleIndex,
    required String testCaseId,
    String? traceId,
    String? spanId,
    EvalFnResponseEvaluation? evaluation,
  }) {
    _json = {
      'sampleIndex': ?sampleIndex,
      'testCaseId': testCaseId,
      'traceId': ?traceId,
      'spanId': ?spanId,
      if (evaluation != null) 'evaluation': evaluation.value,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [EvalFnResponse].
  static const SchemanticType<EvalFnResponse> $schema =
      _EvalFnResponseTypeFactory();

  double? get sampleIndex {
    return (_json['sampleIndex'] as num?)?.toDouble();
  }

  set sampleIndex(double? value) {
    if (value == null) {
      _json.remove('sampleIndex');
    } else {
      _json['sampleIndex'] = value;
    }
  }

  String get testCaseId {
    return _json['testCaseId'] as String;
  }

  set testCaseId(String value) {
    _json['testCaseId'] = value;
  }

  String? get traceId {
    return _json['traceId'] as String?;
  }

  set traceId(String? value) {
    if (value == null) {
      _json.remove('traceId');
    } else {
      _json['traceId'] = value;
    }
  }

  String? get spanId {
    return _json['spanId'] as String?;
  }

  set spanId(String? value) {
    if (value == null) {
      _json.remove('spanId');
    } else {
      _json['spanId'] = value;
    }
  }

  set evaluation(EvalFnResponseEvaluation value) {
    _json['evaluation'] = value.value;
  }

  // Possible return values are `$Score`, `List<$Score>`
  Object? get evaluation {
    return _json['evaluation'] as Object?;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [EvalFnResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

final class EvalFnResponseEvaluation {
  EvalFnResponseEvaluation.score(Score value) : value = value.toJson();

  EvalFnResponseEvaluation.listScore(List<Score> this.value);

  final Object? value;
}

base class _EvalFnResponseTypeFactory extends SchemanticType<EvalFnResponse> {
  const _EvalFnResponseTypeFactory();

  @override
  EvalFnResponse parse(Object? json) {
    return EvalFnResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'EvalFnResponse',
    definition: $Schema
        .object(
          properties: {
            'sampleIndex': $Schema.number(),
            'testCaseId': $Schema.string(),
            'traceId': $Schema.string(),
            'spanId': $Schema.string(),
            'evaluation': $Schema.combined(
              anyOf: [
                $Schema.fromMap({'\$ref': r'#/$defs/Score'}),
                $Schema.list(
                  items: $Schema.fromMap({'\$ref': r'#/$defs/Score'}),
                ),
              ],
            ),
          },
          required: ['testCaseId'],
        )
        .value,
    dependencies: [Score.$schema],
  );
}

base class Score {
  /// Creates a [Score] from a JSON map.
  factory Score.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Score._(this._json);

  Score({
    String? id,
    ScoreScore? score,
    EvalStatusEnum? status,
    String? error,
    Map<String, dynamic>? details,
  }) {
    _json = {
      'id': ?id,
      if (score != null) 'score': score.value,
      'status': ?status?.value,
      'error': ?error,
      'details': ?details,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Score].
  static const SchemanticType<Score> $schema = _ScoreTypeFactory();

  String? get id {
    return _json['id'] as String?;
  }

  set id(String? value) {
    if (value == null) {
      _json.remove('id');
    } else {
      _json['id'] = value;
    }
  }

  set score(ScoreScore value) {
    _json['score'] = value.value;
  }

  // Possible return values are `double`, `String`, `bool`
  Object? get score {
    return _json['score'] as Object?;
  }

  EvalStatusEnum? get status {
    return _json['status'] as EvalStatusEnum?;
  }

  set status(EvalStatusEnum? value) {
    if (value == null) {
      _json.remove('status');
    } else {
      _json['status'] = value;
    }
  }

  String? get error {
    return _json['error'] as String?;
  }

  set error(String? value) {
    if (value == null) {
      _json.remove('error');
    } else {
      _json['error'] = value;
    }
  }

  Map<String, dynamic>? get details {
    return (_json['details'] as Map?)?.cast<String, dynamic>();
  }

  set details(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('details');
    } else {
      _json['details'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Score] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

final class ScoreScore {
  ScoreScore.double(double this.value);

  ScoreScore.string(String this.value);

  ScoreScore.bool(bool this.value);

  final Object? value;
}

base class _ScoreTypeFactory extends SchemanticType<Score> {
  const _ScoreTypeFactory();

  @override
  Score parse(Object? json) {
    return Score._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Score',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.string(),
            'score': $Schema.combined(
              anyOf: [$Schema.number(), $Schema.string(), $Schema.boolean()],
            ),
            'status': $Schema.any(),
            'error': $Schema.string(),
            'details': $Schema.object(additionalProperties: $Schema.any()),
          },
        )
        .value,
    dependencies: [],
  );
}

base class Media {
  /// Creates a [Media] from a JSON map.
  factory Media.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Media._(this._json);

  Media({String? contentType, required String url}) {
    _json = {'contentType': ?contentType, 'url': url};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Media].
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

  /// Serializes this [Media] to a JSON map.
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
  /// Creates a [ToolRequest] from a JSON map.
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

  /// The JSON schema and type descriptor for [ToolRequest].
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

  /// Serializes this [ToolRequest] to a JSON map.
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
  /// Creates a [ToolResponse] from a JSON map.
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

  /// The JSON schema and type descriptor for [ToolResponse].
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

  /// Serializes this [ToolResponse] to a JSON map.
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
  /// Creates a [ModelInfo] from a JSON map.
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

  /// The JSON schema and type descriptor for [ModelInfo].
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

  /// Serializes this [ModelInfo] to a JSON map.
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
        )
        .value,
    dependencies: [],
  );
}

base class ModelRequest {
  /// Creates a [ModelRequest] from a JSON map.
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

  /// The JSON schema and type descriptor for [ModelRequest].
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

  /// Serializes this [ModelRequest] to a JSON map.
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
  /// Creates a [ModelResponse] from a JSON map.
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
      'finishReason': finishReason.value,
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

  /// The JSON schema and type descriptor for [ModelResponse].
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
    final value = _json['finishReason'] as String;
    return FinishReason(value);
  }

  set finishReason(FinishReason value) {
    _json['finishReason'] = value.value;
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

  /// Serializes this [ModelResponse] to a JSON map.
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
  /// Creates a [ModelResponseChunk] from a JSON map.
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
      'role': ?role?.value,
      'index': ?index,
      'content': content.map((e) => e.toJson()).toList(),
      'custom': ?custom,
      'aggregated': ?aggregated,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ModelResponseChunk].
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

  /// Serializes this [ModelResponseChunk] to a JSON map.
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

base class MiddlewareRef {
  /// Creates a [MiddlewareRef] from a JSON map.
  factory MiddlewareRef.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MiddlewareRef._(this._json);

  MiddlewareRef({required String name, Map<String, dynamic>? config}) {
    _json = {'name': name, 'config': ?config};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [MiddlewareRef].
  static const SchemanticType<MiddlewareRef> $schema =
      _MiddlewareRefTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
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

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [MiddlewareRef] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _MiddlewareRefTypeFactory extends SchemanticType<MiddlewareRef> {
  const _MiddlewareRefTypeFactory();

  @override
  MiddlewareRef parse(Object? json) {
    return MiddlewareRef._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MiddlewareRef',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'config': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['name'],
        )
        .value,
    dependencies: [],
  );
}

base class GenerateResponse {
  /// Creates a [GenerateResponse] from a JSON map.
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
      'finishReason': ?finishReason?.value,
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

  /// The JSON schema and type descriptor for [GenerateResponse].
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

  /// Serializes this [GenerateResponse] to a JSON map.
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
  /// Creates a [GenerateRequest] from a JSON map.
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

  /// The JSON schema and type descriptor for [GenerateRequest].
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

  /// Serializes this [GenerateRequest] to a JSON map.
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
  /// Creates a [GenerationUsage] from a JSON map.
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

  /// The JSON schema and type descriptor for [GenerationUsage].
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

  /// Serializes this [GenerationUsage] to a JSON map.
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
        )
        .value,
    dependencies: [],
  );
}

base class Operation {
  /// Creates a [Operation] from a JSON map.
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

  /// The JSON schema and type descriptor for [Operation].
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

  /// Serializes this [Operation] to a JSON map.
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
  /// Creates a [OutputConfig] from a JSON map.
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

  /// The JSON schema and type descriptor for [OutputConfig].
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

  /// Serializes this [OutputConfig] to a JSON map.
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
        )
        .value,
    dependencies: [],
  );
}

base class DocumentData {
  /// Creates a [DocumentData] from a JSON map.
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

  /// The JSON schema and type descriptor for [DocumentData].
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

  /// Serializes this [DocumentData] to a JSON map.
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
  /// Creates a [GenerateActionOptions] from a JSON map.
  factory GenerateActionOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateActionOptions._(this._json);

  GenerateActionOptions({
    String? model,
    List<DocumentData>? docs,
    required List<Message> messages,
    List<String>? tools,
    List<String>? resources,
    String? toolChoice,
    Map<String, dynamic>? config,
    GenerateActionOutputConfig? output,
    GenerateResumeOptions? resume,
    bool? returnToolRequests,
    int? maxTurns,
    String? stepName,
    List<MiddlewareRef>? use,
  }) {
    _json = {
      'model': ?model,
      'docs': ?docs?.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'tools': ?tools,
      'resources': ?resources,
      'toolChoice': ?toolChoice,
      'config': ?config,
      'output': ?output?.toJson(),
      'resume': ?resume?.toJson(),
      'returnToolRequests': ?returnToolRequests,
      'maxTurns': ?maxTurns,
      'stepName': ?stepName,
      'use': ?use?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GenerateActionOptions].
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

  List<String>? get resources {
    return (_json['resources'] as List?)?.cast<String>();
  }

  set resources(List<String>? value) {
    if (value == null) {
      _json.remove('resources');
    } else {
      _json['resources'] = value;
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

  List<MiddlewareRef>? get use {
    return (_json['use'] as List?)
        ?.map((e) => MiddlewareRef.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set use(List<MiddlewareRef>? value) {
    if (value == null) {
      _json.remove('use');
    } else {
      _json['use'] = value.toList();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GenerateActionOptions] to a JSON map.
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
            'resources': $Schema.list(items: $Schema.string()),
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
            'use': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/MiddlewareRef'}),
            ),
          },
          required: ['messages'],
        )
        .value,
    dependencies: [
      DocumentData.$schema,
      Message.$schema,
      GenerateActionOutputConfig.$schema,
      GenerateResumeOptions.$schema,
      MiddlewareRef.$schema,
    ],
  );
}

base class GenerateResumeOptions {
  /// Creates a [GenerateResumeOptions] from a JSON map.
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

  /// The JSON schema and type descriptor for [GenerateResumeOptions].
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

  /// Serializes this [GenerateResumeOptions] to a JSON map.
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
        )
        .value,
    dependencies: [ToolResponsePart.$schema, ToolRequestPart.$schema],
  );
}

base class GenerateActionOutputConfig {
  /// Creates a [GenerateActionOutputConfig] from a JSON map.
  factory GenerateActionOutputConfig.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GenerateActionOutputConfig._(this._json);

  GenerateActionOutputConfig({
    String? format,
    String? contentType,
    GenerateActionOutputConfigInstructions? instructions,
    Map<String, dynamic>? jsonSchema,
    bool? constrained,
    bool? defaultInstructions,
  }) {
    _json = {
      'format': ?format,
      'contentType': ?contentType,
      if (instructions != null) 'instructions': instructions.value,
      'jsonSchema': ?jsonSchema,
      'constrained': ?constrained,
      'defaultInstructions': ?defaultInstructions,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GenerateActionOutputConfig].
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

  bool? get defaultInstructions {
    return _json['defaultInstructions'] as bool?;
  }

  set defaultInstructions(bool? value) {
    if (value == null) {
      _json.remove('defaultInstructions');
    } else {
      _json['defaultInstructions'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GenerateActionOutputConfig] to a JSON map.
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
            'defaultInstructions': $Schema.boolean(),
          },
        )
        .value,
    dependencies: [],
  );
}

base class EmbedRequest {
  /// Creates a [EmbedRequest] from a JSON map.
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

  /// The JSON schema and type descriptor for [EmbedRequest].
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

  /// Serializes this [EmbedRequest] to a JSON map.
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
  /// Creates a [EmbedResponse] from a JSON map.
  factory EmbedResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  EmbedResponse._(this._json);

  EmbedResponse({required List<Embedding> embeddings}) {
    _json = {'embeddings': embeddings.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [EmbedResponse].
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

  /// Serializes this [EmbedResponse] to a JSON map.
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
  /// Creates a [Embedding] from a JSON map.
  factory Embedding.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Embedding._(this._json);

  Embedding({required List<double> embedding, Map<String, dynamic>? metadata}) {
    _json = {'embedding': embedding, 'metadata': ?metadata};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Embedding].
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

  /// Serializes this [Embedding] to a JSON map.
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

base class ReflectionCancelActionParams {
  /// Creates a [ReflectionCancelActionParams] from a JSON map.
  factory ReflectionCancelActionParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionCancelActionParams._(this._json);

  ReflectionCancelActionParams({required String traceId}) {
    _json = {'traceId': traceId};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionCancelActionParams].
  static const SchemanticType<ReflectionCancelActionParams> $schema =
      _ReflectionCancelActionParamsTypeFactory();

  String get traceId {
    return _json['traceId'] as String;
  }

  set traceId(String value) {
    _json['traceId'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionCancelActionParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionCancelActionParamsTypeFactory
    extends SchemanticType<ReflectionCancelActionParams> {
  const _ReflectionCancelActionParamsTypeFactory();

  @override
  ReflectionCancelActionParams parse(Object? json) {
    return ReflectionCancelActionParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionCancelActionParams',
    definition: $Schema
        .object(
          properties: {'traceId': $Schema.string()},
          required: ['traceId'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionCancelActionResponse {
  /// Creates a [ReflectionCancelActionResponse] from a JSON map.
  factory ReflectionCancelActionResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionCancelActionResponse._(this._json);

  ReflectionCancelActionResponse({required String message}) {
    _json = {'message': message};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionCancelActionResponse].
  static const SchemanticType<ReflectionCancelActionResponse> $schema =
      _ReflectionCancelActionResponseTypeFactory();

  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionCancelActionResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionCancelActionResponseTypeFactory
    extends SchemanticType<ReflectionCancelActionResponse> {
  const _ReflectionCancelActionResponseTypeFactory();

  @override
  ReflectionCancelActionResponse parse(Object? json) {
    return ReflectionCancelActionResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionCancelActionResponse',
    definition: $Schema
        .object(
          properties: {'message': $Schema.string()},
          required: ['message'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionConfigureParams {
  /// Creates a [ReflectionConfigureParams] from a JSON map.
  factory ReflectionConfigureParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionConfigureParams._(this._json);

  ReflectionConfigureParams({String? telemetryServerUrl}) {
    _json = {'telemetryServerUrl': ?telemetryServerUrl};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionConfigureParams].
  static const SchemanticType<ReflectionConfigureParams> $schema =
      _ReflectionConfigureParamsTypeFactory();

  String? get telemetryServerUrl {
    return _json['telemetryServerUrl'] as String?;
  }

  set telemetryServerUrl(String? value) {
    if (value == null) {
      _json.remove('telemetryServerUrl');
    } else {
      _json['telemetryServerUrl'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionConfigureParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionConfigureParamsTypeFactory
    extends SchemanticType<ReflectionConfigureParams> {
  const _ReflectionConfigureParamsTypeFactory();

  @override
  ReflectionConfigureParams parse(Object? json) {
    return ReflectionConfigureParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionConfigureParams',
    definition: $Schema
        .object(properties: {'telemetryServerUrl': $Schema.string()})
        .value,
    dependencies: [],
  );
}

base class ReflectionEndInputStreamParams {
  /// Creates a [ReflectionEndInputStreamParams] from a JSON map.
  factory ReflectionEndInputStreamParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionEndInputStreamParams._(this._json);

  ReflectionEndInputStreamParams({required String requestId}) {
    _json = {'requestId': requestId};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionEndInputStreamParams].
  static const SchemanticType<ReflectionEndInputStreamParams> $schema =
      _ReflectionEndInputStreamParamsTypeFactory();

  String get requestId {
    return _json['requestId'] as String;
  }

  set requestId(String value) {
    _json['requestId'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionEndInputStreamParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionEndInputStreamParamsTypeFactory
    extends SchemanticType<ReflectionEndInputStreamParams> {
  const _ReflectionEndInputStreamParamsTypeFactory();

  @override
  ReflectionEndInputStreamParams parse(Object? json) {
    return ReflectionEndInputStreamParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionEndInputStreamParams',
    definition: $Schema
        .object(
          properties: {'requestId': $Schema.string()},
          required: ['requestId'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionListActionsResponse {
  /// Creates a [ReflectionListActionsResponse] from a JSON map.
  factory ReflectionListActionsResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionListActionsResponse._(this._json);

  ReflectionListActionsResponse({required Map<String, dynamic> actions}) {
    _json = {'actions': actions};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionListActionsResponse].
  static const SchemanticType<ReflectionListActionsResponse> $schema =
      _ReflectionListActionsResponseTypeFactory();

  Map<String, dynamic> get actions {
    return (_json['actions'] as Map).cast<String, dynamic>();
  }

  set actions(Map<String, dynamic> value) {
    _json['actions'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionListActionsResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionListActionsResponseTypeFactory
    extends SchemanticType<ReflectionListActionsResponse> {
  const _ReflectionListActionsResponseTypeFactory();

  @override
  ReflectionListActionsResponse parse(Object? json) {
    return ReflectionListActionsResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionListActionsResponse',
    definition: $Schema
        .object(
          properties: {
            'actions': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['actions'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionListValuesParams {
  /// Creates a [ReflectionListValuesParams] from a JSON map.
  factory ReflectionListValuesParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionListValuesParams._(this._json);

  ReflectionListValuesParams({required String type}) {
    _json = {'type': type};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionListValuesParams].
  static const SchemanticType<ReflectionListValuesParams> $schema =
      _ReflectionListValuesParamsTypeFactory();

  String get type {
    return _json['type'] as String;
  }

  set type(String value) {
    _json['type'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionListValuesParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionListValuesParamsTypeFactory
    extends SchemanticType<ReflectionListValuesParams> {
  const _ReflectionListValuesParamsTypeFactory();

  @override
  ReflectionListValuesParams parse(Object? json) {
    return ReflectionListValuesParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionListValuesParams',
    definition: $Schema
        .object(properties: {'type': $Schema.string()}, required: ['type'])
        .value,
    dependencies: [],
  );
}

base class ReflectionListValuesResponse {
  /// Creates a [ReflectionListValuesResponse] from a JSON map.
  factory ReflectionListValuesResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionListValuesResponse._(this._json);

  ReflectionListValuesResponse({required Map<String, dynamic> values}) {
    _json = {'values': values};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionListValuesResponse].
  static const SchemanticType<ReflectionListValuesResponse> $schema =
      _ReflectionListValuesResponseTypeFactory();

  Map<String, dynamic> get values {
    return (_json['values'] as Map).cast<String, dynamic>();
  }

  set values(Map<String, dynamic> value) {
    _json['values'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionListValuesResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionListValuesResponseTypeFactory
    extends SchemanticType<ReflectionListValuesResponse> {
  const _ReflectionListValuesResponseTypeFactory();

  @override
  ReflectionListValuesResponse parse(Object? json) {
    return ReflectionListValuesResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionListValuesResponse',
    definition: $Schema
        .object(
          properties: {
            'values': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['values'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionRegisterParams {
  /// Creates a [ReflectionRegisterParams] from a JSON map.
  factory ReflectionRegisterParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionRegisterParams._(this._json);

  ReflectionRegisterParams({
    required String id,
    int? pid,
    String? name,
    String? genkitVersion,
    double? reflectionApiSpecVersion,
    List<String>? envs,
  }) {
    _json = {
      'id': id,
      'pid': ?pid,
      'name': ?name,
      'genkitVersion': ?genkitVersion,
      'reflectionApiSpecVersion': ?reflectionApiSpecVersion,
      'envs': ?envs,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionRegisterParams].
  static const SchemanticType<ReflectionRegisterParams> $schema =
      _ReflectionRegisterParamsTypeFactory();

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  int? get pid {
    return _json['pid'] as int?;
  }

  set pid(int? value) {
    if (value == null) {
      _json.remove('pid');
    } else {
      _json['pid'] = value;
    }
  }

  String? get name {
    return _json['name'] as String?;
  }

  set name(String? value) {
    if (value == null) {
      _json.remove('name');
    } else {
      _json['name'] = value;
    }
  }

  String? get genkitVersion {
    return _json['genkitVersion'] as String?;
  }

  set genkitVersion(String? value) {
    if (value == null) {
      _json.remove('genkitVersion');
    } else {
      _json['genkitVersion'] = value;
    }
  }

  double? get reflectionApiSpecVersion {
    return (_json['reflectionApiSpecVersion'] as num?)?.toDouble();
  }

  set reflectionApiSpecVersion(double? value) {
    if (value == null) {
      _json.remove('reflectionApiSpecVersion');
    } else {
      _json['reflectionApiSpecVersion'] = value;
    }
  }

  List<String>? get envs {
    return (_json['envs'] as List?)?.cast<String>();
  }

  set envs(List<String>? value) {
    if (value == null) {
      _json.remove('envs');
    } else {
      _json['envs'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionRegisterParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionRegisterParamsTypeFactory
    extends SchemanticType<ReflectionRegisterParams> {
  const _ReflectionRegisterParamsTypeFactory();

  @override
  ReflectionRegisterParams parse(Object? json) {
    return ReflectionRegisterParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionRegisterParams',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.string(),
            'pid': $Schema.integer(),
            'name': $Schema.string(),
            'genkitVersion': $Schema.string(),
            'reflectionApiSpecVersion': $Schema.number(),
            'envs': $Schema.list(items: $Schema.string()),
          },
          required: ['id'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionRunActionParams {
  /// Creates a [ReflectionRunActionParams] from a JSON map.
  factory ReflectionRunActionParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionRunActionParams._(this._json);

  ReflectionRunActionParams({
    String? runtimeId,
    required String key,
    dynamic input,
    dynamic init,
    dynamic context,
    Map<String, dynamic>? telemetryLabels,
    bool? stream,
    bool? streamInput,
  }) {
    _json = {
      'runtimeId': ?runtimeId,
      'key': key,
      'input': ?input,
      'init': ?init,
      'context': ?context,
      'telemetryLabels': ?telemetryLabels,
      'stream': ?stream,
      'streamInput': ?streamInput,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionRunActionParams].
  static const SchemanticType<ReflectionRunActionParams> $schema =
      _ReflectionRunActionParamsTypeFactory();

  String? get runtimeId {
    return _json['runtimeId'] as String?;
  }

  set runtimeId(String? value) {
    if (value == null) {
      _json.remove('runtimeId');
    } else {
      _json['runtimeId'] = value;
    }
  }

  String get key {
    return _json['key'] as String;
  }

  set key(String value) {
    _json['key'] = value;
  }

  dynamic get input {
    return _json['input'] as dynamic;
  }

  set input(dynamic value) {
    _json['input'] = value;
  }

  dynamic get init {
    return _json['init'] as dynamic;
  }

  set init(dynamic value) {
    _json['init'] = value;
  }

  dynamic get context {
    return _json['context'] as dynamic;
  }

  set context(dynamic value) {
    _json['context'] = value;
  }

  Map<String, dynamic>? get telemetryLabels {
    return (_json['telemetryLabels'] as Map?)?.cast<String, dynamic>();
  }

  set telemetryLabels(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('telemetryLabels');
    } else {
      _json['telemetryLabels'] = value;
    }
  }

  bool? get stream {
    return _json['stream'] as bool?;
  }

  set stream(bool? value) {
    if (value == null) {
      _json.remove('stream');
    } else {
      _json['stream'] = value;
    }
  }

  bool? get streamInput {
    return _json['streamInput'] as bool?;
  }

  set streamInput(bool? value) {
    if (value == null) {
      _json.remove('streamInput');
    } else {
      _json['streamInput'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionRunActionParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionRunActionParamsTypeFactory
    extends SchemanticType<ReflectionRunActionParams> {
  const _ReflectionRunActionParamsTypeFactory();

  @override
  ReflectionRunActionParams parse(Object? json) {
    return ReflectionRunActionParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionRunActionParams',
    definition: $Schema
        .object(
          properties: {
            'runtimeId': $Schema.string(),
            'key': $Schema.string(),
            'input': $Schema.any(),
            'init': $Schema.any(),
            'context': $Schema.any(),
            'telemetryLabels': $Schema.object(
              additionalProperties: $Schema.any(),
            ),
            'stream': $Schema.boolean(),
            'streamInput': $Schema.boolean(),
          },
          required: ['key', 'input', 'init', 'context'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionRunActionStateParams {
  /// Creates a [ReflectionRunActionStateParams] from a JSON map.
  factory ReflectionRunActionStateParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionRunActionStateParams._(this._json);

  ReflectionRunActionStateParams({
    required String requestId,
    Map<String, dynamic>? state,
  }) {
    _json = {'requestId': requestId, 'state': ?state};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionRunActionStateParams].
  static const SchemanticType<ReflectionRunActionStateParams> $schema =
      _ReflectionRunActionStateParamsTypeFactory();

  String get requestId {
    return _json['requestId'] as String;
  }

  set requestId(String value) {
    _json['requestId'] = value;
  }

  Map<String, dynamic>? get state {
    return (_json['state'] as Map?)?.cast<String, dynamic>();
  }

  set state(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('state');
    } else {
      _json['state'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionRunActionStateParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionRunActionStateParamsTypeFactory
    extends SchemanticType<ReflectionRunActionStateParams> {
  const _ReflectionRunActionStateParamsTypeFactory();

  @override
  ReflectionRunActionStateParams parse(Object? json) {
    return ReflectionRunActionStateParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionRunActionStateParams',
    definition: $Schema
        .object(
          properties: {
            'requestId': $Schema.string(),
            'state': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['requestId'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionSendInputStreamChunkParams {
  /// Creates a [ReflectionSendInputStreamChunkParams] from a JSON map.
  factory ReflectionSendInputStreamChunkParams.fromJson(
    Map<String, dynamic> json,
  ) => $schema.parse(json);

  ReflectionSendInputStreamChunkParams._(this._json);

  ReflectionSendInputStreamChunkParams({
    required String requestId,
    Map<String, dynamic>? chunk,
  }) {
    _json = {'requestId': requestId, 'chunk': ?chunk};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionSendInputStreamChunkParams].
  static const SchemanticType<ReflectionSendInputStreamChunkParams> $schema =
      _ReflectionSendInputStreamChunkParamsTypeFactory();

  String get requestId {
    return _json['requestId'] as String;
  }

  set requestId(String value) {
    _json['requestId'] = value;
  }

  Map<String, dynamic>? get chunk {
    return (_json['chunk'] as Map?)?.cast<String, dynamic>();
  }

  set chunk(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('chunk');
    } else {
      _json['chunk'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionSendInputStreamChunkParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionSendInputStreamChunkParamsTypeFactory
    extends SchemanticType<ReflectionSendInputStreamChunkParams> {
  const _ReflectionSendInputStreamChunkParamsTypeFactory();

  @override
  ReflectionSendInputStreamChunkParams parse(Object? json) {
    return ReflectionSendInputStreamChunkParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionSendInputStreamChunkParams',
    definition: $Schema
        .object(
          properties: {
            'requestId': $Schema.string(),
            'chunk': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['requestId'],
        )
        .value,
    dependencies: [],
  );
}

base class ReflectionStreamChunkParams {
  /// Creates a [ReflectionStreamChunkParams] from a JSON map.
  factory ReflectionStreamChunkParams.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReflectionStreamChunkParams._(this._json);

  ReflectionStreamChunkParams({required String requestId, dynamic chunk}) {
    _json = {'requestId': requestId, 'chunk': ?chunk};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReflectionStreamChunkParams].
  static const SchemanticType<ReflectionStreamChunkParams> $schema =
      _ReflectionStreamChunkParamsTypeFactory();

  String get requestId {
    return _json['requestId'] as String;
  }

  set requestId(String value) {
    _json['requestId'] = value;
  }

  dynamic get chunk {
    return _json['chunk'] as dynamic;
  }

  set chunk(dynamic value) {
    _json['chunk'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ReflectionStreamChunkParams] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReflectionStreamChunkParamsTypeFactory
    extends SchemanticType<ReflectionStreamChunkParams> {
  const _ReflectionStreamChunkParamsTypeFactory();

  @override
  ReflectionStreamChunkParams parse(Object? json) {
    return ReflectionStreamChunkParams._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReflectionStreamChunkParams',
    definition: $Schema
        .object(
          properties: {'requestId': $Schema.string(), 'chunk': $Schema.any()},
          required: ['requestId', 'chunk'],
        )
        .value,
    dependencies: [],
  );
}

base class AgentInit {
  /// Creates a [AgentInit] from a JSON map.
  factory AgentInit.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  AgentInit._(this._json);

  AgentInit({String? sessionId, String? snapshotId, SessionState? state}) {
    _json = {
      'sessionId': ?sessionId,
      'snapshotId': ?snapshotId,
      'state': ?state?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentInit].
  static const SchemanticType<AgentInit> $schema = _AgentInitTypeFactory();

  String? get sessionId {
    return _json['sessionId'] as String?;
  }

  set sessionId(String? value) {
    if (value == null) {
      _json.remove('sessionId');
    } else {
      _json['sessionId'] = value;
    }
  }

  String? get snapshotId {
    return _json['snapshotId'] as String?;
  }

  set snapshotId(String? value) {
    if (value == null) {
      _json.remove('snapshotId');
    } else {
      _json['snapshotId'] = value;
    }
  }

  SessionState? get state {
    return _json['state'] == null
        ? null
        : SessionState.fromJson(_json['state'] as Map<String, dynamic>);
  }

  set state(SessionState? value) {
    if (value == null) {
      _json.remove('state');
    } else {
      _json['state'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentInit] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentInitTypeFactory extends SchemanticType<AgentInit> {
  const _AgentInitTypeFactory();

  @override
  AgentInit parse(Object? json) {
    return AgentInit._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentInit',
    definition: $Schema
        .object(
          properties: {
            'sessionId': $Schema.string(),
            'snapshotId': $Schema.string(),
            'state': $Schema.fromMap({'\$ref': r'#/$defs/SessionState'}),
          },
        )
        .value,
    dependencies: [SessionState.$schema],
  );
}

base class AgentInput {
  /// Creates a [AgentInput] from a JSON map.
  factory AgentInput.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  AgentInput._(this._json);

  AgentInput({bool? detach, Message? message, AgentResume? resume}) {
    _json = {
      'detach': ?detach,
      'message': ?message?.toJson(),
      'resume': ?resume?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentInput].
  static const SchemanticType<AgentInput> $schema = _AgentInputTypeFactory();

  bool? get detach {
    return _json['detach'] as bool?;
  }

  set detach(bool? value) {
    if (value == null) {
      _json.remove('detach');
    } else {
      _json['detach'] = value;
    }
  }

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

  AgentResume? get resume {
    return _json['resume'] == null
        ? null
        : AgentResume.fromJson(_json['resume'] as Map<String, dynamic>);
  }

  set resume(AgentResume? value) {
    if (value == null) {
      _json.remove('resume');
    } else {
      _json['resume'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentInputTypeFactory extends SchemanticType<AgentInput> {
  const _AgentInputTypeFactory();

  @override
  AgentInput parse(Object? json) {
    return AgentInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentInput',
    definition: $Schema
        .object(
          properties: {
            'detach': $Schema.boolean(),
            'message': $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            'resume': $Schema.fromMap({'\$ref': r'#/$defs/AgentResume'}),
          },
        )
        .value,
    dependencies: [Message.$schema, AgentResume.$schema],
  );
}

base class AgentResume {
  /// Creates a [AgentResume] from a JSON map.
  factory AgentResume.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentResume._(this._json);

  AgentResume({
    List<ToolResponsePart>? respond,
    List<ToolRequestPart>? restart,
  }) {
    _json = {
      'respond': ?respond?.map((e) => e.toJson()).toList(),
      'restart': ?restart?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentResume].
  static const SchemanticType<AgentResume> $schema = _AgentResumeTypeFactory();

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

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentResume] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentResumeTypeFactory extends SchemanticType<AgentResume> {
  const _AgentResumeTypeFactory();

  @override
  AgentResume parse(Object? json) {
    return AgentResume._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentResume',
    definition: $Schema
        .object(
          properties: {
            'respond': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/ToolResponsePart'}),
            ),
            'restart': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/ToolRequestPart'}),
            ),
          },
        )
        .value,
    dependencies: [ToolResponsePart.$schema, ToolRequestPart.$schema],
  );
}

base class AgentOutput {
  /// Creates a [AgentOutput] from a JSON map.
  factory AgentOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentOutput._(this._json);

  AgentOutput({
    String? sessionId,
    String? snapshotId,
    SessionState? state,
    Message? message,
    List<Artifact>? artifacts,
    AgentFinishReason? finishReason,
    AgentErrorInfo? error,
  }) {
    _json = {
      'sessionId': ?sessionId,
      'snapshotId': ?snapshotId,
      'state': ?state?.toJson(),
      'message': ?message?.toJson(),
      'artifacts': ?artifacts?.map((e) => e.toJson()).toList(),
      'finishReason': ?finishReason?.value,
      'error': ?error?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentOutput].
  static const SchemanticType<AgentOutput> $schema = _AgentOutputTypeFactory();

  String? get sessionId {
    return _json['sessionId'] as String?;
  }

  set sessionId(String? value) {
    if (value == null) {
      _json.remove('sessionId');
    } else {
      _json['sessionId'] = value;
    }
  }

  String? get snapshotId {
    return _json['snapshotId'] as String?;
  }

  set snapshotId(String? value) {
    if (value == null) {
      _json.remove('snapshotId');
    } else {
      _json['snapshotId'] = value;
    }
  }

  SessionState? get state {
    return _json['state'] == null
        ? null
        : SessionState.fromJson(_json['state'] as Map<String, dynamic>);
  }

  set state(SessionState? value) {
    if (value == null) {
      _json.remove('state');
    } else {
      _json['state'] = value;
    }
  }

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

  List<Artifact>? get artifacts {
    return (_json['artifacts'] as List?)
        ?.map((e) => Artifact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set artifacts(List<Artifact>? value) {
    if (value == null) {
      _json.remove('artifacts');
    } else {
      _json['artifacts'] = value.toList();
    }
  }

  AgentFinishReason? get finishReason {
    return _json['finishReason'] as AgentFinishReason?;
  }

  set finishReason(AgentFinishReason? value) {
    if (value == null) {
      _json.remove('finishReason');
    } else {
      _json['finishReason'] = value;
    }
  }

  AgentErrorInfo? get error {
    return _json['error'] == null
        ? null
        : AgentErrorInfo.fromJson(_json['error'] as Map<String, dynamic>);
  }

  set error(AgentErrorInfo? value) {
    if (value == null) {
      _json.remove('error');
    } else {
      _json['error'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentOutputTypeFactory extends SchemanticType<AgentOutput> {
  const _AgentOutputTypeFactory();

  @override
  AgentOutput parse(Object? json) {
    return AgentOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentOutput',
    definition: $Schema
        .object(
          properties: {
            'sessionId': $Schema.string(),
            'snapshotId': $Schema.string(),
            'state': $Schema.fromMap({'\$ref': r'#/$defs/SessionState'}),
            'message': $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            'artifacts': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Artifact'}),
            ),
            'finishReason': $Schema.any(),
            'error': $Schema.fromMap({'\$ref': r'#/$defs/AgentErrorInfo'}),
          },
        )
        .value,
    dependencies: [
      SessionState.$schema,
      Message.$schema,
      Artifact.$schema,
      AgentErrorInfo.$schema,
    ],
  );
}

base class AgentErrorInfo {
  /// Creates a [AgentErrorInfo] from a JSON map.
  factory AgentErrorInfo.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentErrorInfo._(this._json);

  AgentErrorInfo({String? status, required String message, dynamic details}) {
    _json = {'status': ?status, 'message': message, 'details': ?details};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentErrorInfo].
  static const SchemanticType<AgentErrorInfo> $schema =
      _AgentErrorInfoTypeFactory();

  String? get status {
    return _json['status'] as String?;
  }

  set status(String? value) {
    if (value == null) {
      _json.remove('status');
    } else {
      _json['status'] = value;
    }
  }

  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
  }

  dynamic get details {
    return _json['details'] as dynamic;
  }

  set details(dynamic value) {
    _json['details'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentErrorInfo] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentErrorInfoTypeFactory extends SchemanticType<AgentErrorInfo> {
  const _AgentErrorInfoTypeFactory();

  @override
  AgentErrorInfo parse(Object? json) {
    return AgentErrorInfo._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentErrorInfo',
    definition: $Schema
        .object(
          properties: {
            'status': $Schema.string(),
            'message': $Schema.string(),
            'details': $Schema.any(),
          },
          required: ['message', 'details'],
        )
        .value,
    dependencies: [],
  );
}

base class AgentResult {
  /// Creates a [AgentResult] from a JSON map.
  factory AgentResult.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentResult._(this._json);

  AgentResult({
    Message? message,
    List<Artifact>? artifacts,
    AgentFinishReason? finishReason,
  }) {
    _json = {
      'message': ?message?.toJson(),
      'artifacts': ?artifacts?.map((e) => e.toJson()).toList(),
      'finishReason': ?finishReason?.value,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentResult].
  static const SchemanticType<AgentResult> $schema = _AgentResultTypeFactory();

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

  List<Artifact>? get artifacts {
    return (_json['artifacts'] as List?)
        ?.map((e) => Artifact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set artifacts(List<Artifact>? value) {
    if (value == null) {
      _json.remove('artifacts');
    } else {
      _json['artifacts'] = value.toList();
    }
  }

  AgentFinishReason? get finishReason {
    return _json['finishReason'] as AgentFinishReason?;
  }

  set finishReason(AgentFinishReason? value) {
    if (value == null) {
      _json.remove('finishReason');
    } else {
      _json['finishReason'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentResult] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentResultTypeFactory extends SchemanticType<AgentResult> {
  const _AgentResultTypeFactory();

  @override
  AgentResult parse(Object? json) {
    return AgentResult._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentResult',
    definition: $Schema
        .object(
          properties: {
            'message': $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            'artifacts': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Artifact'}),
            ),
            'finishReason': $Schema.any(),
          },
        )
        .value,
    dependencies: [Message.$schema, Artifact.$schema],
  );
}

base class AgentStreamChunk {
  /// Creates a [AgentStreamChunk] from a JSON map.
  factory AgentStreamChunk.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentStreamChunk._(this._json);

  AgentStreamChunk({
    ModelResponseChunk? modelChunk,
    List<JsonPatchOperation>? customPatch,
    Artifact? artifact,
    TurnEnd? turnEnd,
  }) {
    _json = {
      'modelChunk': ?modelChunk?.toJson(),
      'customPatch': ?customPatch?.map((e) => e.toJson()).toList(),
      'artifact': ?artifact?.toJson(),
      'turnEnd': ?turnEnd?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentStreamChunk].
  static const SchemanticType<AgentStreamChunk> $schema =
      _AgentStreamChunkTypeFactory();

  ModelResponseChunk? get modelChunk {
    return _json['modelChunk'] == null
        ? null
        : ModelResponseChunk.fromJson(
            _json['modelChunk'] as Map<String, dynamic>,
          );
  }

  set modelChunk(ModelResponseChunk? value) {
    if (value == null) {
      _json.remove('modelChunk');
    } else {
      _json['modelChunk'] = value;
    }
  }

  List<JsonPatchOperation>? get customPatch {
    return (_json['customPatch'] as List?)
        ?.map((e) => JsonPatchOperation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set customPatch(List<JsonPatchOperation>? value) {
    if (value == null) {
      _json.remove('customPatch');
    } else {
      _json['customPatch'] = value.toList();
    }
  }

  Artifact? get artifact {
    return _json['artifact'] == null
        ? null
        : Artifact.fromJson(_json['artifact'] as Map<String, dynamic>);
  }

  set artifact(Artifact? value) {
    if (value == null) {
      _json.remove('artifact');
    } else {
      _json['artifact'] = value;
    }
  }

  TurnEnd? get turnEnd {
    return _json['turnEnd'] == null
        ? null
        : TurnEnd.fromJson(_json['turnEnd'] as Map<String, dynamic>);
  }

  set turnEnd(TurnEnd? value) {
    if (value == null) {
      _json.remove('turnEnd');
    } else {
      _json['turnEnd'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentStreamChunk] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentStreamChunkTypeFactory
    extends SchemanticType<AgentStreamChunk> {
  const _AgentStreamChunkTypeFactory();

  @override
  AgentStreamChunk parse(Object? json) {
    return AgentStreamChunk._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentStreamChunk',
    definition: $Schema
        .object(
          properties: {
            'modelChunk': $Schema.fromMap({
              '\$ref': r'#/$defs/ModelResponseChunk',
            }),
            'customPatch': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/JsonPatchOperation'}),
            ),
            'artifact': $Schema.fromMap({'\$ref': r'#/$defs/Artifact'}),
            'turnEnd': $Schema.fromMap({'\$ref': r'#/$defs/TurnEnd'}),
          },
        )
        .value,
    dependencies: [
      ModelResponseChunk.$schema,
      JsonPatchOperation.$schema,
      Artifact.$schema,
      TurnEnd.$schema,
    ],
  );
}

base class TurnEnd {
  /// Creates a [TurnEnd] from a JSON map.
  factory TurnEnd.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TurnEnd._(this._json);

  TurnEnd({String? snapshotId, AgentFinishReason? finishReason}) {
    _json = {'snapshotId': ?snapshotId, 'finishReason': ?finishReason?.value};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TurnEnd].
  static const SchemanticType<TurnEnd> $schema = _TurnEndTypeFactory();

  String? get snapshotId {
    return _json['snapshotId'] as String?;
  }

  set snapshotId(String? value) {
    if (value == null) {
      _json.remove('snapshotId');
    } else {
      _json['snapshotId'] = value;
    }
  }

  AgentFinishReason? get finishReason {
    return _json['finishReason'] as AgentFinishReason?;
  }

  set finishReason(AgentFinishReason? value) {
    if (value == null) {
      _json.remove('finishReason');
    } else {
      _json['finishReason'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [TurnEnd] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TurnEndTypeFactory extends SchemanticType<TurnEnd> {
  const _TurnEndTypeFactory();

  @override
  TurnEnd parse(Object? json) {
    return TurnEnd._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TurnEnd',
    definition: $Schema
        .object(
          properties: {
            'snapshotId': $Schema.string(),
            'finishReason': $Schema.any(),
          },
        )
        .value,
    dependencies: [],
  );
}

base class Artifact {
  /// Creates a [Artifact] from a JSON map.
  factory Artifact.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Artifact._(this._json);

  Artifact({
    String? name,
    required List<Part> parts,
    Map<String, dynamic>? metadata,
  }) {
    _json = {
      'name': ?name,
      'parts': parts.map((e) => e.toJson()).toList(),
      'metadata': ?metadata,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Artifact].
  static const SchemanticType<Artifact> $schema = _ArtifactTypeFactory();

  String? get name {
    return _json['name'] as String?;
  }

  set name(String? value) {
    if (value == null) {
      _json.remove('name');
    } else {
      _json['name'] = value;
    }
  }

  List<Part> get parts {
    return (_json['parts'] as List)
        .map((e) => Part.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set parts(List<Part> value) {
    _json['parts'] = value.toList();
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

  /// Serializes this [Artifact] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ArtifactTypeFactory extends SchemanticType<Artifact> {
  const _ArtifactTypeFactory();

  @override
  Artifact parse(Object? json) {
    return Artifact._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Artifact',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'parts': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Part'}),
            ),
            'metadata': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['parts'],
        )
        .value,
    dependencies: [Part.$schema],
  );
}

base class GetSnapshotDataInput {
  /// Creates a [GetSnapshotDataInput] from a JSON map.
  factory GetSnapshotDataInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetSnapshotDataInput._(this._json);

  GetSnapshotDataInput({String? snapshotId, String? sessionId}) {
    _json = {'snapshotId': ?snapshotId, 'sessionId': ?sessionId};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetSnapshotDataInput].
  static const SchemanticType<GetSnapshotDataInput> $schema =
      _GetSnapshotDataInputTypeFactory();

  String? get snapshotId {
    return _json['snapshotId'] as String?;
  }

  set snapshotId(String? value) {
    if (value == null) {
      _json.remove('snapshotId');
    } else {
      _json['snapshotId'] = value;
    }
  }

  String? get sessionId {
    return _json['sessionId'] as String?;
  }

  set sessionId(String? value) {
    if (value == null) {
      _json.remove('sessionId');
    } else {
      _json['sessionId'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetSnapshotDataInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetSnapshotDataInputTypeFactory
    extends SchemanticType<GetSnapshotDataInput> {
  const _GetSnapshotDataInputTypeFactory();

  @override
  GetSnapshotDataInput parse(Object? json) {
    return GetSnapshotDataInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetSnapshotDataInput',
    definition: $Schema
        .object(
          properties: {
            'snapshotId': $Schema.string(),
            'sessionId': $Schema.string(),
          },
        )
        .value,
    dependencies: [],
  );
}

base class JsonPatchOperation {
  /// Creates a [JsonPatchOperation] from a JSON map.
  factory JsonPatchOperation.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  JsonPatchOperation._(this._json);

  JsonPatchOperation({
    required String op,
    required String path,
    String? from,
    dynamic value,
  }) {
    _json = {'op': op, 'path': path, 'from': ?from, 'value': ?value};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [JsonPatchOperation].
  static const SchemanticType<JsonPatchOperation> $schema =
      _JsonPatchOperationTypeFactory();

  String get op {
    return _json['op'] as String;
  }

  set op(String value) {
    _json['op'] = value;
  }

  String get path {
    return _json['path'] as String;
  }

  set path(String value) {
    _json['path'] = value;
  }

  String? get from {
    return _json['from'] as String?;
  }

  set from(String? value) {
    if (value == null) {
      _json.remove('from');
    } else {
      _json['from'] = value;
    }
  }

  dynamic get value {
    return _json['value'] as dynamic;
  }

  set value(dynamic value) {
    _json['value'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [JsonPatchOperation] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _JsonPatchOperationTypeFactory
    extends SchemanticType<JsonPatchOperation> {
  const _JsonPatchOperationTypeFactory();

  @override
  JsonPatchOperation parse(Object? json) {
    return JsonPatchOperation._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'JsonPatchOperation',
    definition: $Schema
        .object(
          properties: {
            'op': $Schema.string(),
            'path': $Schema.string(),
            'from': $Schema.string(),
            'value': $Schema.any(),
          },
          required: ['op', 'path', 'value'],
        )
        .value,
    dependencies: [],
  );
}

base class SessionSnapshot {
  /// Creates a [SessionSnapshot] from a JSON map.
  factory SessionSnapshot.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SessionSnapshot._(this._json);

  SessionSnapshot({
    required String snapshotId,
    String? sessionId,
    String? parentId,
    required String createdAt,
    String? updatedAt,
    String? heartbeatAt,
    String? status,
    AgentFinishReason? finishReason,
    AgentErrorInfo? error,
    required SessionState state,
  }) {
    _json = {
      'snapshotId': snapshotId,
      'sessionId': ?sessionId,
      'parentId': ?parentId,
      'createdAt': createdAt,
      'updatedAt': ?updatedAt,
      'heartbeatAt': ?heartbeatAt,
      'status': ?status,
      'finishReason': ?finishReason?.value,
      'error': ?error?.toJson(),
      'state': state.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [SessionSnapshot].
  static const SchemanticType<SessionSnapshot> $schema =
      _SessionSnapshotTypeFactory();

  String get snapshotId {
    return _json['snapshotId'] as String;
  }

  set snapshotId(String value) {
    _json['snapshotId'] = value;
  }

  String? get sessionId {
    return _json['sessionId'] as String?;
  }

  set sessionId(String? value) {
    if (value == null) {
      _json.remove('sessionId');
    } else {
      _json['sessionId'] = value;
    }
  }

  String? get parentId {
    return _json['parentId'] as String?;
  }

  set parentId(String? value) {
    if (value == null) {
      _json.remove('parentId');
    } else {
      _json['parentId'] = value;
    }
  }

  String get createdAt {
    return _json['createdAt'] as String;
  }

  set createdAt(String value) {
    _json['createdAt'] = value;
  }

  String? get updatedAt {
    return _json['updatedAt'] as String?;
  }

  set updatedAt(String? value) {
    if (value == null) {
      _json.remove('updatedAt');
    } else {
      _json['updatedAt'] = value;
    }
  }

  String? get heartbeatAt {
    return _json['heartbeatAt'] as String?;
  }

  set heartbeatAt(String? value) {
    if (value == null) {
      _json.remove('heartbeatAt');
    } else {
      _json['heartbeatAt'] = value;
    }
  }

  String? get status {
    return _json['status'] as String?;
  }

  set status(String? value) {
    if (value == null) {
      _json.remove('status');
    } else {
      _json['status'] = value;
    }
  }

  AgentFinishReason? get finishReason {
    return _json['finishReason'] as AgentFinishReason?;
  }

  set finishReason(AgentFinishReason? value) {
    if (value == null) {
      _json.remove('finishReason');
    } else {
      _json['finishReason'] = value;
    }
  }

  AgentErrorInfo? get error {
    return _json['error'] == null
        ? null
        : AgentErrorInfo.fromJson(_json['error'] as Map<String, dynamic>);
  }

  set error(AgentErrorInfo? value) {
    if (value == null) {
      _json.remove('error');
    } else {
      _json['error'] = value;
    }
  }

  SessionState get state {
    return SessionState.fromJson(_json['state'] as Map<String, dynamic>);
  }

  set state(SessionState value) {
    _json['state'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [SessionSnapshot] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _SessionSnapshotTypeFactory extends SchemanticType<SessionSnapshot> {
  const _SessionSnapshotTypeFactory();

  @override
  SessionSnapshot parse(Object? json) {
    return SessionSnapshot._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SessionSnapshot',
    definition: $Schema
        .object(
          properties: {
            'snapshotId': $Schema.string(),
            'sessionId': $Schema.string(),
            'parentId': $Schema.string(),
            'createdAt': $Schema.string(),
            'updatedAt': $Schema.string(),
            'heartbeatAt': $Schema.string(),
            'status': $Schema.string(),
            'finishReason': $Schema.any(),
            'error': $Schema.fromMap({'\$ref': r'#/$defs/AgentErrorInfo'}),
            'state': $Schema.fromMap({'\$ref': r'#/$defs/SessionState'}),
          },
          required: ['snapshotId', 'createdAt', 'state'],
        )
        .value,
    dependencies: [AgentErrorInfo.$schema, SessionState.$schema],
  );
}

base class SessionState {
  /// Creates a [SessionState] from a JSON map.
  factory SessionState.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SessionState._(this._json);

  SessionState({
    String? sessionId,
    List<Message>? messages,
    dynamic custom,
    List<Artifact>? artifacts,
  }) {
    _json = {
      'sessionId': ?sessionId,
      'messages': ?messages?.map((e) => e.toJson()).toList(),
      'custom': ?custom,
      'artifacts': ?artifacts?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [SessionState].
  static const SchemanticType<SessionState> $schema =
      _SessionStateTypeFactory();

  String? get sessionId {
    return _json['sessionId'] as String?;
  }

  set sessionId(String? value) {
    if (value == null) {
      _json.remove('sessionId');
    } else {
      _json['sessionId'] = value;
    }
  }

  List<Message>? get messages {
    return (_json['messages'] as List?)
        ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set messages(List<Message>? value) {
    if (value == null) {
      _json.remove('messages');
    } else {
      _json['messages'] = value.toList();
    }
  }

  dynamic get custom {
    return _json['custom'] as dynamic;
  }

  set custom(dynamic value) {
    _json['custom'] = value;
  }

  List<Artifact>? get artifacts {
    return (_json['artifacts'] as List?)
        ?.map((e) => Artifact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set artifacts(List<Artifact>? value) {
    if (value == null) {
      _json.remove('artifacts');
    } else {
      _json['artifacts'] = value.toList();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [SessionState] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _SessionStateTypeFactory extends SchemanticType<SessionState> {
  const _SessionStateTypeFactory();

  @override
  SessionState parse(Object? json) {
    return SessionState._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SessionState',
    definition: $Schema
        .object(
          properties: {
            'sessionId': $Schema.string(),
            'messages': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Message'}),
            ),
            'custom': $Schema.any(),
            'artifacts': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Artifact'}),
            ),
          },
          required: ['custom'],
        )
        .value,
    dependencies: [Message.$schema, Artifact.$schema],
  );
}
