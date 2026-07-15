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

/// Task tracker agent — custom session state.
///
/// Ported from the JS `task-agent.ts`. Demonstrates:
///   * `ai.currentSession().updateCustom()` / `getCustom()` — typed custom
///     state held in `session.custom`.
///   * Tools that mutate structured state inside the session. Each mutation
///     auto-emits a `customPatch` chunk so the client's tracked state stays
///     live mid-stream.
///   * Uses `defineAgent` (not `defineCustomAgent`) — custom state works with
///     the standard agent API.
///
/// The custom state is held as plain JSON
/// (`{ tasks: [{id, title, done}], nextId }`).
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'task_agent.g.dart';

@Schema()
abstract class $TaskItem {
  int get id;
  String get title;
  bool get done;
}

@Schema()
abstract class $TaskState {
  List<$TaskItem> get tasks;
  int get nextId;
}

@Schema()
abstract class $AddTaskInput {
  @Field(description: 'Short description of the task')
  String get title;
}

@Schema()
abstract class $ToggleTaskInput {
  @Field(description: 'The task ID to toggle')
  int get id;
}

@Schema()
abstract class $RemoveTaskInput {
  @Field(description: 'The task ID to remove')
  int get id;
}

/// Locates the task with the given [id] in the session's typed task list and
/// applies [onFound] to mutate it, returning the standard success/error result
/// map. Shared by `toggleTask` and `removeTask` to avoid repeating the lookup
/// and not-found boilerplate.
Map<String, dynamic> _mutateTaskById(
  int id,
  Map<String, dynamic> Function(List<TaskItem> tasks, int idx) onFound,
) {
  final session = ai.currentSession<TaskState>()!;
  var result = <String, dynamic>{'success': false};
  session.updateCustom((state) {
    state ??= TaskState(tasks: [], nextId: 1);
    final tasks = state.tasks;
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      result = onFound(tasks, idx);
      // Reassign so the mutated list is written back to the session state.
      state.tasks = tasks;
    } else {
      result = {'success': false, 'error': 'Task $id not found'};
    }
    return state;
  });
  return result;
}

final addTask = ai.defineTool(
  name: 'addTask',
  description:
      'Add a new task to the task list. Returns the newly created task.',
  inputSchema: AddTaskInput.$schema,
  outputSchema: TaskItem.$schema,
  fn: (input, _) async {
    final session = ai.currentSession<TaskState>()!;
    late TaskItem newTask;
    session.updateCustom((state) {
      state ??= TaskState(tasks: [], nextId: 1);
      newTask = TaskItem(id: state.nextId, title: input.title, done: false);
      state.tasks = [...state.tasks, newTask];
      state.nextId += 1;
      return state;
    });
    return newTask;
  },
);

final toggleTask = ai.defineTool(
  name: 'toggleTask',
  description:
      'Toggle a task between done and not-done by its ID. Returns the updated '
      'task or an error message.',
  inputSchema: ToggleTaskInput.$schema,
  fn: (input, _) async => _mutateTaskById(input.id, (tasks, idx) {
    tasks[idx].done = !tasks[idx].done;
    return {'success': true, 'task': tasks[idx].toJson()};
  }),
);

final removeTask = ai.defineTool(
  name: 'removeTask',
  description: 'Remove a task from the list by its ID.',
  inputSchema: RemoveTaskInput.$schema,
  fn: (input, _) async => _mutateTaskById(input.id, (tasks, idx) {
    tasks.removeAt(idx);
    return {'success': true};
  }),
);

final taskAgent = ai.defineAgent(
  name: 'taskAgent',
  stateSchema: TaskState.$schema,
  system: '''
You are a concise task management assistant. Help the user manage their task list.

Rules:
- Use the addTask tool to add new tasks.
- Use the toggleTask tool to mark tasks done or undone.
- Use the removeTask tool to delete tasks.
- Be brief and friendly. After modifying tasks, confirm what you did.''',
  use: [retry()],
  tools: [addTask, toggleTask, removeTask],
);
