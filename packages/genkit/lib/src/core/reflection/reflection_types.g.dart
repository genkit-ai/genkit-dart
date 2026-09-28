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

part of 'reflection_types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

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
    required int pid,
    String? name,
    String? genkitVersion,
    double? reflectionApiSpecVersion,
    List<String>? envs,
  }) {
    _json = {
      'id': id,
      'pid': pid,
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

  int get pid {
    return _json['pid'] as int;
  }

  set pid(int value) {
    _json['pid'] = value;
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
          required: ['id', 'pid'],
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
