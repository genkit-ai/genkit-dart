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

part of 'experimental_types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

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
      _json['state'] = value.toJson();
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
      _json['message'] = value.toJson();
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
      _json['resume'] = value.toJson();
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
      _json['respond'] = value.map((e) => e.toJson()).toList();
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
      _json['restart'] = value.map((e) => e.toJson()).toList();
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
      _json['state'] = value.toJson();
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
      _json['message'] = value.toJson();
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
      _json['artifacts'] = value.map((e) => e.toJson()).toList();
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
      _json['error'] = value.toJson();
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

  AgentErrorInfo({String? status, required String message, Object? details}) {
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

  Object? get details {
    return _json['details'] as Object?;
  }

  set details(Object? value) {
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
          required: ['message'],
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
      _json['message'] = value.toJson();
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
      _json['artifacts'] = value.map((e) => e.toJson()).toList();
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
      _json['modelChunk'] = value.toJson();
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
      _json['customPatch'] = value.map((e) => e.toJson()).toList();
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
      _json['artifact'] = value.toJson();
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
      _json['turnEnd'] = value.toJson();
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

base class AgentAbortRequest {
  /// Creates a [AgentAbortRequest] from a JSON map.
  factory AgentAbortRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentAbortRequest._(this._json);

  AgentAbortRequest({required String snapshotId}) {
    _json = {'snapshotId': snapshotId};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentAbortRequest].
  static const SchemanticType<AgentAbortRequest> $schema =
      _AgentAbortRequestTypeFactory();

  String get snapshotId {
    return _json['snapshotId'] as String;
  }

  set snapshotId(String value) {
    _json['snapshotId'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentAbortRequest] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentAbortRequestTypeFactory
    extends SchemanticType<AgentAbortRequest> {
  const _AgentAbortRequestTypeFactory();

  @override
  AgentAbortRequest parse(Object? json) {
    return AgentAbortRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentAbortRequest',
    definition: $Schema
        .object(
          properties: {'snapshotId': $Schema.string()},
          required: ['snapshotId'],
        )
        .value,
    dependencies: [],
  );
}

base class AgentAbortResponse {
  /// Creates a [AgentAbortResponse] from a JSON map.
  factory AgentAbortResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentAbortResponse._(this._json);

  AgentAbortResponse({required String snapshotId, SnapshotStatus? status}) {
    _json = {'snapshotId': snapshotId, 'status': ?status?.value};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentAbortResponse].
  static const SchemanticType<AgentAbortResponse> $schema =
      _AgentAbortResponseTypeFactory();

  String get snapshotId {
    return _json['snapshotId'] as String;
  }

  set snapshotId(String value) {
    _json['snapshotId'] = value;
  }

  SnapshotStatus? get status {
    return _json['status'] as SnapshotStatus?;
  }

  set status(SnapshotStatus? value) {
    if (value == null) {
      _json.remove('status');
    } else {
      _json['status'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentAbortResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentAbortResponseTypeFactory
    extends SchemanticType<AgentAbortResponse> {
  const _AgentAbortResponseTypeFactory();

  @override
  AgentAbortResponse parse(Object? json) {
    return AgentAbortResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentAbortResponse',
    definition: $Schema
        .object(
          properties: {'snapshotId': $Schema.string(), 'status': $Schema.any()},
          required: ['snapshotId'],
        )
        .value,
    dependencies: [],
  );
}

base class AgentMetadata {
  /// Creates a [AgentMetadata] from a JSON map.
  factory AgentMetadata.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentMetadata._(this._json);

  AgentMetadata({
    required AgentStateManagement stateManagement,
    required bool abortable,
    Map<String, dynamic>? stateSchema,
  }) {
    _json = {
      'stateManagement': stateManagement.value,
      'abortable': abortable,
      'stateSchema': ?stateSchema,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentMetadata].
  static const SchemanticType<AgentMetadata> $schema =
      _AgentMetadataTypeFactory();

  AgentStateManagement get stateManagement {
    final value = _json['stateManagement'] as String;
    return AgentStateManagement(value);
  }

  set stateManagement(AgentStateManagement value) {
    _json['stateManagement'] = value.value;
  }

  bool get abortable {
    return _json['abortable'] as bool;
  }

  set abortable(bool value) {
    _json['abortable'] = value;
  }

  Map<String, dynamic>? get stateSchema {
    return (_json['stateSchema'] as Map?)?.cast<String, dynamic>();
  }

  set stateSchema(Map<String, dynamic>? value) {
    if (value == null) {
      _json.remove('stateSchema');
    } else {
      _json['stateSchema'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentMetadata] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentMetadataTypeFactory extends SchemanticType<AgentMetadata> {
  const _AgentMetadataTypeFactory();

  @override
  AgentMetadata parse(Object? json) {
    return AgentMetadata._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentMetadata',
    definition: $Schema
        .object(
          properties: {
            'stateManagement': $Schema.any(),
            'abortable': $Schema.boolean(),
            'stateSchema': $Schema.object(additionalProperties: $Schema.any()),
          },
          required: ['stateManagement', 'abortable'],
        )
        .value,
    dependencies: [],
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
    _json['parts'] = value.map((e) => e.toJson()).toList();
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

  GetSnapshotDataInput({
    String? snapshotId,
    String? sessionId,
    bool? metadataOnly,
  }) {
    _json = {
      'snapshotId': ?snapshotId,
      'sessionId': ?sessionId,
      'metadataOnly': ?metadataOnly,
    };
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

  bool? get metadataOnly {
    return _json['metadataOnly'] as bool?;
  }

  set metadataOnly(bool? value) {
    if (value == null) {
      _json.remove('metadataOnly');
    } else {
      _json['metadataOnly'] = value;
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
            'metadataOnly': $Schema.boolean(),
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
    required JsonPatchOp op,
    required String path,
    String? from,
    Object? value,
  }) {
    _json = {'op': op.value, 'path': path, 'from': ?from, 'value': ?value};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [JsonPatchOperation].
  static const SchemanticType<JsonPatchOperation> $schema =
      _JsonPatchOperationTypeFactory();

  JsonPatchOp get op {
    final value = _json['op'] as String;
    return JsonPatchOp(value);
  }

  set op(JsonPatchOp value) {
    _json['op'] = value.value;
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

  Object? get value {
    return _json['value'] as Object?;
  }

  set value(Object? value) {
    if (value == null) {
      _json.remove('value');
    } else {
      _json['value'] = value;
    }
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
            'op': $Schema.any(),
            'path': $Schema.string(),
            'from': $Schema.string(),
            'value': $Schema.any(),
          },
          required: ['op', 'path'],
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
    SnapshotStatus? status,
    AgentFinishReason? finishReason,
    AgentErrorInfo? error,
    SessionState? state,
  }) {
    _json = {
      'snapshotId': snapshotId,
      'sessionId': ?sessionId,
      'parentId': ?parentId,
      'createdAt': createdAt,
      'updatedAt': ?updatedAt,
      'heartbeatAt': ?heartbeatAt,
      'status': ?status?.value,
      'finishReason': ?finishReason?.value,
      'error': ?error?.toJson(),
      'state': ?state?.toJson(),
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

  SnapshotStatus? get status {
    return _json['status'] as SnapshotStatus?;
  }

  set status(SnapshotStatus? value) {
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
      _json['error'] = value.toJson();
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
      _json['state'] = value.toJson();
    }
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
            'status': $Schema.any(),
            'finishReason': $Schema.any(),
            'error': $Schema.fromMap({'\$ref': r'#/$defs/AgentErrorInfo'}),
            'state': $Schema.fromMap({'\$ref': r'#/$defs/SessionState'}),
          },
          required: ['snapshotId', 'createdAt'],
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
    Object? custom,
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
      _json['messages'] = value.map((e) => e.toJson()).toList();
    }
  }

  Object? get custom {
    return _json['custom'] as Object?;
  }

  set custom(Object? value) {
    if (value == null) {
      _json.remove('custom');
    } else {
      _json['custom'] = value;
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
      _json['artifacts'] = value.map((e) => e.toJson()).toList();
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
        )
        .value,
    dependencies: [Message.$schema, Artifact.$schema],
  );
}
