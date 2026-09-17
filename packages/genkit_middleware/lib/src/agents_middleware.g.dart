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

part of 'agents_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Configuration options for the [agents] middleware.
base class AgentsOptions {
  /// Creates a [AgentsOptions] from a JSON map.
  factory AgentsOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentsOptions._(this._json);

  AgentsOptions({
    required List<String> agents,
    String? toolPrefix,
    int? maxDelegations,
    int? historyLength,
    String? artifactStrategy,
    bool? async,
  }) {
    _json = {
      'agents': agents,
      'toolPrefix': ?toolPrefix,
      'maxDelegations': ?maxDelegations,
      'historyLength': ?historyLength,
      'artifactStrategy': ?artifactStrategy,
      'async': ?async,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentsOptions].
  static const SchemanticType<AgentsOptions> $schema =
      _AgentsOptionsTypeFactory();

  List<String> get agents {
    return (_json['agents'] as List).cast<String>();
  }

  set agents(List<String> value) {
    _json['agents'] = value;
  }

  String? get toolPrefix {
    return _json['toolPrefix'] as String?;
  }

  set toolPrefix(String? value) {
    if (value == null) {
      _json.remove('toolPrefix');
    } else {
      _json['toolPrefix'] = value;
    }
  }

  int? get maxDelegations {
    return _json['maxDelegations'] as int?;
  }

  set maxDelegations(int? value) {
    if (value == null) {
      _json.remove('maxDelegations');
    } else {
      _json['maxDelegations'] = value;
    }
  }

  int? get historyLength {
    return _json['historyLength'] as int?;
  }

  set historyLength(int? value) {
    if (value == null) {
      _json.remove('historyLength');
    } else {
      _json['historyLength'] = value;
    }
  }

  String? get artifactStrategy {
    return _json['artifactStrategy'] as String?;
  }

  set artifactStrategy(String? value) {
    if (value == null) {
      _json.remove('artifactStrategy');
    } else {
      _json['artifactStrategy'] = value;
    }
  }

  bool? get async {
    return _json['async'] as bool?;
  }

  set async(bool? value) {
    if (value == null) {
      _json.remove('async');
    } else {
      _json['async'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentsOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentsOptionsTypeFactory extends SchemanticType<AgentsOptions> {
  const _AgentsOptionsTypeFactory();

  @override
  AgentsOptions parse(Object? json) {
    return AgentsOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentsOptions',
    definition: $Schema
        .object(
          properties: {
            'agents': $Schema.list(
              description:
                  'Names of registered agents available for delegation. Each name gets a dedicated delegation tool.',
              items: $Schema.string(),
            ),
            'toolPrefix': $Schema.string(
              description:
                  'Prefix for generated delegation tool names. Defaults to "delegate_to" (tools become delegate_to_<agent>). Set to an empty string to use bare agent names.',
            ),
            'maxDelegations': $Schema.integer(
              description:
                  'Maximum sub-agent delegations allowed per generate call. Prevents runaway delegation loops.',
            ),
            'historyLength': $Schema.integer(
              description:
                  'Number of recent conversation messages (user/model only) to forward to sub-agents as additional context. 0 or omitted means only the task description is sent.',
            ),
            'artifactStrategy': $Schema.string(
              description:
                  'How sub-agent artifacts are handled: "inline" (default) includes artifact content in the delegation tool result AND merges artifacts into the parent session; "session" merges artifacts into the parent session only (the tool result mentions names but not content).',
            ),
            'async': $Schema.boolean(
              description:
                  'Enables background delegation. Delegation tools accept a "background" flag that starts the sub-agent and returns a taskId immediately, and the check_background_tasks / wait_for_background_tasks / abort_background_tasks tools are added. Background delegation requires server-managed sub-agents (those with a session store that supports detach).',
            ),
          },
          required: ['agents'],
        )
        .value,
    dependencies: [],
  );
}

/// Input schema for a generated delegation tool.
base class DelegateInput {
  /// Creates a [DelegateInput] from a JSON map.
  factory DelegateInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  DelegateInput._(this._json);

  DelegateInput({required String task, String? name}) {
    _json = {'task': task, 'name': ?name};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [DelegateInput].
  static const SchemanticType<DelegateInput> $schema =
      _DelegateInputTypeFactory();

  String get task {
    return _json['task'] as String;
  }

  set task(String value) {
    _json['task'] = value;
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

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [DelegateInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _DelegateInputTypeFactory extends SchemanticType<DelegateInput> {
  const _DelegateInputTypeFactory();

  @override
  DelegateInput parse(Object? json) {
    return DelegateInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'DelegateInput',
    definition: $Schema
        .object(
          properties: {
            'task': $Schema.string(
              description:
                  'A clear, self-contained description of the task to delegate.',
            ),
            'name': $Schema.string(
              description:
                  'Optional short label for this delegation (e.g. "sources-sweep"). Echoed on the result and on background-task reports next to the taskId, to keep several tasks readable. Not an identifier.',
            ),
          },
          required: ['task'],
        )
        .value,
    dependencies: [],
  );
}

/// Input schema for a delegation tool when [$AgentsOptions.async] is set: the
/// plain input plus the background flag.
base class AsyncDelegateInput {
  /// Creates a [AsyncDelegateInput] from a JSON map.
  factory AsyncDelegateInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AsyncDelegateInput._(this._json);

  AsyncDelegateInput({required String task, String? name, bool? background}) {
    _json = {'task': task, 'name': ?name, 'background': ?background};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AsyncDelegateInput].
  static const SchemanticType<AsyncDelegateInput> $schema =
      _AsyncDelegateInputTypeFactory();

  String get task {
    return _json['task'] as String;
  }

  set task(String value) {
    _json['task'] = value;
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

  bool? get background {
    return _json['background'] as bool?;
  }

  set background(bool? value) {
    if (value == null) {
      _json.remove('background');
    } else {
      _json['background'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AsyncDelegateInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AsyncDelegateInputTypeFactory
    extends SchemanticType<AsyncDelegateInput> {
  const _AsyncDelegateInputTypeFactory();

  @override
  AsyncDelegateInput parse(Object? json) {
    return AsyncDelegateInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AsyncDelegateInput',
    definition: $Schema
        .object(
          properties: {
            'task': $Schema.string(
              description:
                  'A clear, self-contained description of the task to delegate.',
            ),
            'name': $Schema.string(
              description:
                  'Optional short label for this delegation. Echoed on the result and on background-task reports next to the taskId. Not an identifier.',
            ),
            'background': $Schema.boolean(
              description:
                  'Run the delegation in the background. The tool returns immediately with a taskId; collect the result later with check_background_tasks or wait_for_background_tasks.',
            ),
          },
          required: ['task'],
        )
        .value,
    dependencies: [],
  );
}

/// An artifact reported back by a delegation tool.
base class AgentDelegationArtifact {
  /// Creates a [AgentDelegationArtifact] from a JSON map.
  factory AgentDelegationArtifact.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentDelegationArtifact._(this._json);

  AgentDelegationArtifact({String? name, String? content}) {
    _json = {'name': ?name, 'content': ?content};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentDelegationArtifact].
  static const SchemanticType<AgentDelegationArtifact> $schema =
      _AgentDelegationArtifactTypeFactory();

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

  String? get content {
    return _json['content'] as String?;
  }

  set content(String? value) {
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

  /// Serializes this [AgentDelegationArtifact] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentDelegationArtifactTypeFactory
    extends SchemanticType<AgentDelegationArtifact> {
  const _AgentDelegationArtifactTypeFactory();

  @override
  AgentDelegationArtifact parse(Object? json) {
    return AgentDelegationArtifact._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentDelegationArtifact',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(description: 'Name of the artifact.'),
            'content': $Schema.string(
              description:
                  'Text content of the artifact (inline strategy only).',
            ),
          },
        )
        .value,
    dependencies: [],
  );
}

/// Output schema for a generated delegation tool.
base class AgentDelegationResult {
  /// Creates a [AgentDelegationResult] from a JSON map.
  factory AgentDelegationResult.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AgentDelegationResult._(this._json);

  AgentDelegationResult({
    required String response,
    List<AgentDelegationArtifact>? artifacts,
    String? taskId,
    String? status,
    String? name,
  }) {
    _json = {
      'response': response,
      'artifacts': ?artifacts?.map((e) => e.toJson()).toList(),
      'taskId': ?taskId,
      'status': ?status,
      'name': ?name,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AgentDelegationResult].
  static const SchemanticType<AgentDelegationResult> $schema =
      _AgentDelegationResultTypeFactory();

  String get response {
    return _json['response'] as String;
  }

  set response(String value) {
    _json['response'] = value;
  }

  List<AgentDelegationArtifact>? get artifacts {
    return (_json['artifacts'] as List?)
        ?.map(
          (e) => AgentDelegationArtifact.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  set artifacts(List<AgentDelegationArtifact>? value) {
    if (value == null) {
      _json.remove('artifacts');
    } else {
      _json['artifacts'] = value.map((e) => e.toJson()).toList();
    }
  }

  String? get taskId {
    return _json['taskId'] as String?;
  }

  set taskId(String? value) {
    if (value == null) {
      _json.remove('taskId');
    } else {
      _json['taskId'] = value;
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

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AgentDelegationResult] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AgentDelegationResultTypeFactory
    extends SchemanticType<AgentDelegationResult> {
  const _AgentDelegationResultTypeFactory();

  @override
  AgentDelegationResult parse(Object? json) {
    return AgentDelegationResult._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AgentDelegationResult',
    definition: $Schema
        .object(
          properties: {
            'response': $Schema.string(
              description: 'The sub-agent\'s text response.',
            ),
            'artifacts': $Schema.list(
              description: 'Artifacts produced by the sub-agent, if any.',
              items: $Schema.fromMap({
                '\$ref': r'#/$defs/AgentDelegationArtifact',
              }),
            ),
            'taskId': $Schema.string(
              description:
                  'Handle for this delegation ("<agent>:<snapshotId>"), when the sub-agent keeps a session. Pass it to check_background_tasks, wait_for_background_tasks, abort_background_tasks, or continue_task.',
            ),
            'status': $Schema.string(
              description:
                  'Outcome behind taskId: "pending" for a background launch, or the settled status ("completed", "failed", "aborted") for a synchronous delegation that carries a handle.',
            ),
            'name': $Schema.string(
              description:
                  'The caller-chosen label for this delegation, if given.',
            ),
          },
          required: ['response'],
        )
        .value,
    dependencies: [AgentDelegationArtifact.$schema],
  );
}

/// Input for the check and abort background-task tools: a list of task handles.
base class BackgroundTasksInput {
  /// Creates a [BackgroundTasksInput] from a JSON map.
  factory BackgroundTasksInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  BackgroundTasksInput._(this._json);

  BackgroundTasksInput({List<String>? taskIds}) {
    _json = {'taskIds': ?taskIds};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [BackgroundTasksInput].
  static const SchemanticType<BackgroundTasksInput> $schema =
      _BackgroundTasksInputTypeFactory();

  List<String>? get taskIds {
    return (_json['taskIds'] as List?)?.cast<String>();
  }

  set taskIds(List<String>? value) {
    if (value == null) {
      _json.remove('taskIds');
    } else {
      _json['taskIds'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [BackgroundTasksInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _BackgroundTasksInputTypeFactory
    extends SchemanticType<BackgroundTasksInput> {
  const _BackgroundTasksInputTypeFactory();

  @override
  BackgroundTasksInput parse(Object? json) {
    return BackgroundTasksInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'BackgroundTasksInput',
    definition: $Schema
        .object(
          properties: {
            'taskIds': $Schema.list(
              description:
                  'Task IDs returned by background delegations (form "<agent>:<snapshotId>").',
              items: $Schema.string(),
            ),
          },
        )
        .value,
    dependencies: [],
  );
}

/// Input for the wait background-task tool: the handle list plus a bound on how
/// long to block and the join semantics.
base class WaitBackgroundTasksInput {
  /// Creates a [WaitBackgroundTasksInput] from a JSON map.
  factory WaitBackgroundTasksInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WaitBackgroundTasksInput._(this._json);

  WaitBackgroundTasksInput({
    List<String>? taskIds,
    int? timeoutSeconds,
    String? waitFor,
  }) {
    _json = {
      'taskIds': ?taskIds,
      'timeoutSeconds': ?timeoutSeconds,
      'waitFor': ?waitFor,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [WaitBackgroundTasksInput].
  static const SchemanticType<WaitBackgroundTasksInput> $schema =
      _WaitBackgroundTasksInputTypeFactory();

  List<String>? get taskIds {
    return (_json['taskIds'] as List?)?.cast<String>();
  }

  set taskIds(List<String>? value) {
    if (value == null) {
      _json.remove('taskIds');
    } else {
      _json['taskIds'] = value;
    }
  }

  int? get timeoutSeconds {
    return _json['timeoutSeconds'] as int?;
  }

  set timeoutSeconds(int? value) {
    if (value == null) {
      _json.remove('timeoutSeconds');
    } else {
      _json['timeoutSeconds'] = value;
    }
  }

  String? get waitFor {
    return _json['waitFor'] as String?;
  }

  set waitFor(String? value) {
    if (value == null) {
      _json.remove('waitFor');
    } else {
      _json['waitFor'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [WaitBackgroundTasksInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _WaitBackgroundTasksInputTypeFactory
    extends SchemanticType<WaitBackgroundTasksInput> {
  const _WaitBackgroundTasksInputTypeFactory();

  @override
  WaitBackgroundTasksInput parse(Object? json) {
    return WaitBackgroundTasksInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WaitBackgroundTasksInput',
    definition: $Schema
        .object(
          properties: {
            'taskIds': $Schema.list(
              description:
                  'Task IDs returned by background delegations (form "<agent>:<snapshotId>").',
              items: $Schema.string(),
            ),
            'timeoutSeconds': $Schema.integer(
              description:
                  'Maximum seconds to wait before returning the current statuses. 0 or omitted waits until every task settles; a negative value returns the current statuses immediately.',
            ),
            'waitFor': $Schema.string(
              description:
                  '"all" (default) waits until every listed task settles. "first" returns as soon as any one settles; the remaining tasks report their current status and keep running.',
            ),
          },
        )
        .value,
    dependencies: [],
  );
}

/// A per-task entry returned by the check and wait background-task tools.
base class BackgroundTaskReport {
  /// Creates a [BackgroundTaskReport] from a JSON map.
  factory BackgroundTaskReport.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  BackgroundTaskReport._(this._json);

  BackgroundTaskReport({
    required String taskId,
    String? agent,
    String? name,
    required String status,
    String? response,
    List<AgentDelegationArtifact>? artifacts,
    String? error,
  }) {
    _json = {
      'taskId': taskId,
      'agent': ?agent,
      'name': ?name,
      'status': status,
      'response': ?response,
      'artifacts': ?artifacts?.map((e) => e.toJson()).toList(),
      'error': ?error,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [BackgroundTaskReport].
  static const SchemanticType<BackgroundTaskReport> $schema =
      _BackgroundTaskReportTypeFactory();

  String get taskId {
    return _json['taskId'] as String;
  }

  set taskId(String value) {
    _json['taskId'] = value;
  }

  String? get agent {
    return _json['agent'] as String?;
  }

  set agent(String? value) {
    if (value == null) {
      _json.remove('agent');
    } else {
      _json['agent'] = value;
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

  String get status {
    return _json['status'] as String;
  }

  set status(String value) {
    _json['status'] = value;
  }

  String? get response {
    return _json['response'] as String?;
  }

  set response(String? value) {
    if (value == null) {
      _json.remove('response');
    } else {
      _json['response'] = value;
    }
  }

  List<AgentDelegationArtifact>? get artifacts {
    return (_json['artifacts'] as List?)
        ?.map(
          (e) => AgentDelegationArtifact.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  set artifacts(List<AgentDelegationArtifact>? value) {
    if (value == null) {
      _json.remove('artifacts');
    } else {
      _json['artifacts'] = value.map((e) => e.toJson()).toList();
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

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [BackgroundTaskReport] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _BackgroundTaskReportTypeFactory
    extends SchemanticType<BackgroundTaskReport> {
  const _BackgroundTaskReportTypeFactory();

  @override
  BackgroundTaskReport parse(Object? json) {
    return BackgroundTaskReport._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'BackgroundTaskReport',
    definition: $Schema
        .object(
          properties: {
            'taskId': $Schema.string(
              description: 'The task handle this report describes.',
            ),
            'agent': $Schema.string(
              description: 'The sub-agent running the task.',
            ),
            'name': $Schema.string(
              description:
                  'The caller-chosen label of the delegation, if given.',
            ),
            'status': $Schema.string(
              description:
                  'Lifecycle state: "pending", "completed", "failed", "aborted", "expired", "aborting", or "unknown".',
            ),
            'response': $Schema.string(
              description:
                  'The sub-agent\'s final text response, for completed tasks.',
            ),
            'artifacts': $Schema.list(
              description: 'The completed task\'s artifacts, if any.',
              items: $Schema.fromMap({
                '\$ref': r'#/$defs/AgentDelegationArtifact',
              }),
            ),
            'error': $Schema.string(
              description:
                  'Describes why no response is available (failure, abort, expiry, or an unresolvable task ID).',
            ),
          },
          required: ['taskId', 'status'],
        )
        .value,
    dependencies: [AgentDelegationArtifact.$schema],
  );
}

/// Output for the check and wait background-task tools.
base class BackgroundTasksResult {
  /// Creates a [BackgroundTasksResult] from a JSON map.
  factory BackgroundTasksResult.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  BackgroundTasksResult._(this._json);

  BackgroundTasksResult({
    List<BackgroundTaskReport>? tasks,
    bool? timedOut,
    String? note,
  }) {
    _json = {
      'tasks': ?tasks?.map((e) => e.toJson()).toList(),
      'timedOut': ?timedOut,
      'note': ?note,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [BackgroundTasksResult].
  static const SchemanticType<BackgroundTasksResult> $schema =
      _BackgroundTasksResultTypeFactory();

  List<BackgroundTaskReport>? get tasks {
    return (_json['tasks'] as List?)
        ?.map((e) => BackgroundTaskReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set tasks(List<BackgroundTaskReport>? value) {
    if (value == null) {
      _json.remove('tasks');
    } else {
      _json['tasks'] = value.map((e) => e.toJson()).toList();
    }
  }

  bool? get timedOut {
    return _json['timedOut'] as bool?;
  }

  set timedOut(bool? value) {
    if (value == null) {
      _json.remove('timedOut');
    } else {
      _json['timedOut'] = value;
    }
  }

  String? get note {
    return _json['note'] as String?;
  }

  set note(String? value) {
    if (value == null) {
      _json.remove('note');
    } else {
      _json['note'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [BackgroundTasksResult] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _BackgroundTasksResultTypeFactory
    extends SchemanticType<BackgroundTasksResult> {
  const _BackgroundTasksResultTypeFactory();

  @override
  BackgroundTasksResult parse(Object? json) {
    return BackgroundTasksResult._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'BackgroundTasksResult',
    definition: $Schema
        .object(
          properties: {
            'tasks': $Schema.list(
              description: 'One report per requested task ID.',
              items: $Schema.fromMap({
                '\$ref': r'#/$defs/BackgroundTaskReport',
              }),
            ),
            'timedOut': $Schema.boolean(
              description:
                  'Set when the wait returned because timeoutSeconds elapsed while some tasks were still pending.',
            ),
            'note': $Schema.string(
              description: 'Usage guidance when the call itself was unusable.',
            ),
          },
        )
        .value,
    dependencies: [BackgroundTaskReport.$schema],
  );
}

/// Input for the continue_task tool.
base class ContinueInput {
  /// Creates a [ContinueInput] from a JSON map.
  factory ContinueInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ContinueInput._(this._json);

  ContinueInput({required String taskId, String? instructions}) {
    _json = {'taskId': taskId, 'instructions': ?instructions};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ContinueInput].
  static const SchemanticType<ContinueInput> $schema =
      _ContinueInputTypeFactory();

  String get taskId {
    return _json['taskId'] as String;
  }

  set taskId(String value) {
    _json['taskId'] = value;
  }

  String? get instructions {
    return _json['instructions'] as String?;
  }

  set instructions(String? value) {
    if (value == null) {
      _json.remove('instructions');
    } else {
      _json['instructions'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ContinueInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ContinueInputTypeFactory extends SchemanticType<ContinueInput> {
  const _ContinueInputTypeFactory();

  @override
  ContinueInput parse(Object? json) {
    return ContinueInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ContinueInput',
    definition: $Schema
        .object(
          properties: {
            'taskId': $Schema.string(
              description:
                  'The task handle to continue ("<agent>:<snapshotId>"), from a delegation result or a background-task report.',
            ),
            'instructions': $Schema.string(
              description:
                  'Optional guidance delivered to the sub-agent as it continues. Omit it to retry a failed or aborted task exactly as it stood; required when following up on a completed task.',
            ),
          },
          required: ['taskId'],
        )
        .value,
    dependencies: [],
  );
}

/// Input for the continue_task tool when [$AgentsOptions.async] is set.
base class AsyncContinueInput {
  /// Creates a [AsyncContinueInput] from a JSON map.
  factory AsyncContinueInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AsyncContinueInput._(this._json);

  AsyncContinueInput({
    required String taskId,
    String? instructions,
    bool? background,
  }) {
    _json = {
      'taskId': taskId,
      'instructions': ?instructions,
      'background': ?background,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AsyncContinueInput].
  static const SchemanticType<AsyncContinueInput> $schema =
      _AsyncContinueInputTypeFactory();

  String get taskId {
    return _json['taskId'] as String;
  }

  set taskId(String value) {
    _json['taskId'] = value;
  }

  String? get instructions {
    return _json['instructions'] as String?;
  }

  set instructions(String? value) {
    if (value == null) {
      _json.remove('instructions');
    } else {
      _json['instructions'] = value;
    }
  }

  bool? get background {
    return _json['background'] as bool?;
  }

  set background(bool? value) {
    if (value == null) {
      _json.remove('background');
    } else {
      _json['background'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AsyncContinueInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AsyncContinueInputTypeFactory
    extends SchemanticType<AsyncContinueInput> {
  const _AsyncContinueInputTypeFactory();

  @override
  AsyncContinueInput parse(Object? json) {
    return AsyncContinueInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AsyncContinueInput',
    definition: $Schema
        .object(
          properties: {
            'taskId': $Schema.string(
              description:
                  'The task handle to continue ("<agent>:<snapshotId>"), from a delegation result or a background-task report.',
            ),
            'instructions': $Schema.string(
              description:
                  'Optional guidance delivered to the sub-agent as it continues. Omit it to retry a failed or aborted task exactly as it stood; required when following up on a completed task.',
            ),
            'background': $Schema.boolean(
              description:
                  'Continue the task in the background. The tool returns immediately with a new taskId; collect the result later with the background-task tools.',
            ),
          },
          required: ['taskId'],
        )
        .value,
    dependencies: [],
  );
}
