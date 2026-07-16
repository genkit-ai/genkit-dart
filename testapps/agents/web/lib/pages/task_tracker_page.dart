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

/// Task tracker — live custom state via streamed `customPatch` chunks.
///
/// Ported from the JS `TaskTracker.tsx`. The agent mutates a task list in its
/// custom session state; each mutation streams a `customPatch` chunk, so
/// `chunk.custom` (and `chat.state`) stay live mid-stream. The side panel shows
/// the current task list.
library;

import 'dart:convert';

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart';
import 'streaming_chat_page.dart';

class TaskTrackerPage extends StatefulComponent {
  const TaskTrackerPage({super.key});

  @override
  State<TaskTrackerPage> createState() => _TaskTrackerPageState();
}

class _TaskTrackerPageState extends State<TaskTrackerPage> {
  late final AgentApi _agent = remoteAgent(url: '$apiBase/api/taskAgent');

  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _loading = false;
  dynamic _custom;

  Future<void> _handleSend(String text) async {
    if (_loading) return;
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _loading = true;
      _streamingText = '';
    });

    // Seed the chat with an initial empty task state on the first turn.
    _chat ??= _agent.chat(
      state: SessionState(
        custom: {'tasks': <dynamic>[], 'nextId': 1},
        messages: [],
        artifacts: [],
      ),
    );
    final chat = _chat!;

    try {
      final turn = chat.sendStream(text: text);
      var accumulated = '';
      await for (final chunk in turn.stream) {
        for (final part in chunk.raw.modelChunk?.content ?? const <Part>[]) {
          if (part.isToolRequest) {
            final tr = part.toolRequest!;
            setState(
              () => _messages.add(
                ChatMessage(
                  role: 'tool',
                  text: '🔧 ${tr.name}(${jsonEncode(tr.input)})',
                ),
              ),
            );
          } else if (part.isToolResponse) {
            final tr = part.toolResponse!;
            setState(
              () => _messages.add(
                ChatMessage(
                  role: 'tool',
                  text: '✅ ${tr.name} → ${jsonEncode(tr.output)}',
                ),
              ),
            );
          }
        }
        // Live custom state arrives via customPatch chunks.
        if (chunk.custom != null) {
          setState(() => _custom = chunk.custom);
        }
        if (chunk.text.isNotEmpty) {
          accumulated = chunk.accumulatedText;
          setState(() => _streamingText = accumulated);
        }
      }
      final res = await turn.response;
      setState(() {
        _streamingText = '';
        _custom = res.state ?? _custom;
        _messages.add(
          ChatMessage(
            role: 'model',
            text: res.text.isNotEmpty ? res.text : accumulated,
          ),
        );
      });
    } catch (e) {
      setState(() => _messages.add(ChatMessage(role: 'system', text: '⚠️ $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map> get _tasks {
    final custom = _custom;
    if (custom is! Map) return const [];
    return ((custom['tasks'] as List?) ?? const []).cast<Map>();
  }

  Component _progress() {
    final tasks = _tasks;
    if (tasks.isEmpty) return const _Empty();
    final done = tasks.where((t) => t['done'] == true).length;
    final pct = tasks.isEmpty ? 0 : (done / tasks.length * 100).round();
    return div(classes: 'task-progress', [
      .text('$done of ${tasks.length} done'),
      div(classes: 'task-progress-bar', [
        div(
          classes: 'task-progress-fill',
          styles: Styles(raw: {'width': '$pct%'}),
          [],
        ),
      ]),
    ]);
  }

  Component _taskList() {
    final tasks = _tasks;
    if (tasks.isEmpty) {
      return p(classes: 'task-empty', [.text('No tasks yet.')]);
    }
    return ul(classes: 'task-list', [
      for (final t in tasks)
        li(classes: t['done'] == true ? 'task-item task-done' : 'task-item', [
          span(classes: 'task-checkbox', [
            .text(t['done'] == true ? '✅' : '⬜'),
          ]),
          span(classes: 'task-title', [.text('#${t['id']} ${t['title']}')]),
        ]),
    ]);
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'task-tracker-layout', [
      ChatUI(
        title: 'Task Tracker',
        description:
            'Custom session state. Add, toggle, and remove tasks — the live '
            'task list (right) updates mid-stream via customPatch chunks.',
        suggestions: const [
          'Add a task: buy groceries',
          'Add buy milk and walk the dog',
          'Mark task 1 done',
          "What's left?",
        ],
        messages: _messages,
        streamingText: _streamingText,
        loading: _loading,
        renderMarkdown: true,
        onSend: _handleSend,
      ),
      aside(classes: 'task-sidebar', [
        h3([.text('✅ Task List')]),
        p(classes: 'task-sidebar-hint', [
          .text('Lives in the agent\'s custom '),
          code([.text('state')]),
          .text('. Updated live via '),
          code([.text('customPatch')]),
          .text(' stream chunks.'),
        ]),
        _progress(),
        _taskList(),
        hr(classes: 'task-divider'),
        h4([.text('📋 How It Works')]),
        ol(classes: 'task-howto', [
          li([
            .text('Tools mutate '),
            code([.text('ctx.state.custom')]),
            .text(' on the server.'),
          ]),
          li([
            .text('Each mutation streams a '),
            code([.text('customPatch')]),
            .text(' chunk to the client.'),
          ]),
          li([
            code([.text('chunk.custom')]),
            .text(' updates this panel mid-stream.'),
          ]),
        ]),
        h4([.text('Key APIs')]),
        pre(classes: 'task-code', [
          .text('''
// Seed initial custom state
final chat = agent.chat(
  state: SessionState(
    custom: {'tasks': [], 'nextId': 1},
  ),
);

// Live updates during a turn
await for (final chunk in turn.stream) {
  if (chunk.custom != null) {
    setState(() => custom = chunk.custom);
  }
}'''),
        ]),
      ]),
    ]);
  }
}

/// A blank placeholder used when there is no progress bar to show.
class _Empty extends StatelessComponent {
  const _Empty();

  @override
  Component build(BuildContext context) => span([]);
}
