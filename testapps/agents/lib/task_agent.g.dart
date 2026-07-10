// Copyright 2026 Google LLC
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

part of 'task_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class TaskItem {
  /// Creates a [TaskItem] from a JSON map.
  factory TaskItem.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TaskItem._(this._json);

  TaskItem({required int id, required String title, required bool done}) {
    _json = {'id': id, 'title': title, 'done': done};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TaskItem].
  static const SchemanticType<TaskItem> $schema = _TaskItemTypeFactory();

  int get id {
    return _json['id'] as int;
  }

  set id(int value) {
    _json['id'] = value;
  }

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  bool get done {
    return _json['done'] as bool;
  }

  set done(bool value) {
    _json['done'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [TaskItem] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TaskItemTypeFactory extends SchemanticType<TaskItem> {
  const _TaskItemTypeFactory();

  @override
  TaskItem parse(Object? json) {
    return TaskItem._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TaskItem',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.integer(),
            'title': $Schema.string(),
            'done': $Schema.boolean(),
          },
          required: ['id', 'title', 'done'],
        )
        .value,
    dependencies: [],
  );
}

base class TaskState {
  /// Creates a [TaskState] from a JSON map.
  factory TaskState.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TaskState._(this._json);

  TaskState({required List<TaskItem> tasks, required int nextId}) {
    _json = {'tasks': tasks.map((e) => e.toJson()).toList(), 'nextId': nextId};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TaskState].
  static const SchemanticType<TaskState> $schema = _TaskStateTypeFactory();

  List<TaskItem> get tasks {
    return (_json['tasks'] as List)
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set tasks(List<TaskItem> value) {
    _json['tasks'] = value.toList();
  }

  int get nextId {
    return _json['nextId'] as int;
  }

  set nextId(int value) {
    _json['nextId'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [TaskState] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TaskStateTypeFactory extends SchemanticType<TaskState> {
  const _TaskStateTypeFactory();

  @override
  TaskState parse(Object? json) {
    return TaskState._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TaskState',
    definition: $Schema
        .object(
          properties: {
            'tasks': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/TaskItem'}),
            ),
            'nextId': $Schema.integer(),
          },
          required: ['tasks', 'nextId'],
        )
        .value,
    dependencies: [TaskItem.$schema],
  );
}

base class AddTaskInput {
  /// Creates a [AddTaskInput] from a JSON map.
  factory AddTaskInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AddTaskInput._(this._json);

  AddTaskInput({required String title}) {
    _json = {'title': title};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AddTaskInput].
  static const SchemanticType<AddTaskInput> $schema =
      _AddTaskInputTypeFactory();

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AddTaskInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AddTaskInputTypeFactory extends SchemanticType<AddTaskInput> {
  const _AddTaskInputTypeFactory();

  @override
  AddTaskInput parse(Object? json) {
    return AddTaskInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AddTaskInput',
    definition: $Schema
        .object(
          properties: {
            'title': $Schema.string(
              description: 'Short description of the task',
            ),
          },
          required: ['title'],
        )
        .value,
    dependencies: [],
  );
}

base class ToggleTaskInput {
  /// Creates a [ToggleTaskInput] from a JSON map.
  factory ToggleTaskInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToggleTaskInput._(this._json);

  ToggleTaskInput({required int id}) {
    _json = {'id': id};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ToggleTaskInput].
  static const SchemanticType<ToggleTaskInput> $schema =
      _ToggleTaskInputTypeFactory();

  int get id {
    return _json['id'] as int;
  }

  set id(int value) {
    _json['id'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ToggleTaskInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ToggleTaskInputTypeFactory extends SchemanticType<ToggleTaskInput> {
  const _ToggleTaskInputTypeFactory();

  @override
  ToggleTaskInput parse(Object? json) {
    return ToggleTaskInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToggleTaskInput',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.integer(description: 'The task ID to toggle'),
          },
          required: ['id'],
        )
        .value,
    dependencies: [],
  );
}

base class RemoveTaskInput {
  /// Creates a [RemoveTaskInput] from a JSON map.
  factory RemoveTaskInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RemoveTaskInput._(this._json);

  RemoveTaskInput({required int id}) {
    _json = {'id': id};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [RemoveTaskInput].
  static const SchemanticType<RemoveTaskInput> $schema =
      _RemoveTaskInputTypeFactory();

  int get id {
    return _json['id'] as int;
  }

  set id(int value) {
    _json['id'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [RemoveTaskInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RemoveTaskInputTypeFactory extends SchemanticType<RemoveTaskInput> {
  const _RemoveTaskInputTypeFactory();

  @override
  RemoveTaskInput parse(Object? json) {
    return RemoveTaskInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RemoveTaskInput',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.integer(description: 'The task ID to remove'),
          },
          required: ['id'],
        )
        .value,
    dependencies: [],
  );
}
