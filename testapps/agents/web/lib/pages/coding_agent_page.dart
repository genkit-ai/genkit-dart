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

/// Coding agent — filesystem + shell + skills, with tool-approval interrupts.
///
/// Ported from the JS `CodingAgent.tsx`. Streams tool calls (list_files,
/// write_file, run_shell, ...) inline, and handles the agent's interrupts:
///   * File writes/edits and risky shell commands are gated by the
///     `toolApproval` / shell safety middleware — they pause and surface an
///     approve/deny dialog. Approving *restarts* the tool with a
///     `tool-approved: true` flag in its `resumed` payload (matching what the
///     middleware reads); denying *responds* with a "not approved" result.
///   * `ask_user` pauses to ask a question — the dialog shows the options and
///     resumes by *responding* with the chosen answer.
library;

import 'dart:async';
import 'dart:convert';

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';

import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart';
import 'streaming_chat_page.dart';

/// Tools that pause for an approve/deny confirmation before running.
const _approvalTools = {'write_file', 'search_and_replace', 'run_shell'};

class CodingAgentPage extends StatefulComponent {
  const CodingAgentPage({super.key});

  @override
  State<CodingAgentPage> createState() => _CodingAgentPageState();
}

class _CodingAgentPageState extends State<CodingAgentPage> {
  late final AgentApi _agent = remoteAgent(url: '$apiBase/api/codingAgent');

  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _loading = false;

  // Pending interrupts awaiting a user decision, resolved one at a time. Each
  // decision is accumulated into [_restarts] / [_responses]; once every pending
  // interrupt is resolved, the chat resumes with the combined payload.
  final List<AgentInterrupt> _pending = [];
  final List<ToolRequestPart> _restarts = [];
  final List<ToolResponsePart> _responses = [];

  Future<void> _runTurn(AgentTurn turn) async {
    var accumulated = '';
    await for (final chunk in turn.stream) {
      if (!mounted) break;
      for (final part in chunk.raw.modelChunk?.content ?? const <Part>[]) {
        if (part.isToolRequest) {
          // Skip interrupted tool requests: the agent re-emits them as an extra
          // chunk carrying `metadata.interrupt` (surfaced via the dialog
          // below), but they were already streamed once during generation.
          if (part.metadata?['interrupt'] != null) continue;
          final tr = part.toolRequest!;
          setState(() {
            _messages.add(
              ChatMessage(
                role: 'tool',
                text: '🔧 Calling ${tr.name}(${jsonEncode(tr.input)})',
              ),
            );
          });
        } else if (part.isToolResponse) {
          final tr = part.toolResponse!;
          setState(() {
            _messages.add(
              ChatMessage(
                role: 'tool',
                text: '✅ ${tr.name} → ${jsonEncode(tr.output)}',
              ),
            );
          });
        }
      }
      if (chunk.text.isNotEmpty) {
        accumulated = chunk.accumulatedText;
        setState(() => _streamingText = accumulated);
      }
    }

    if (!mounted) return;
    final res = await turn.response;
    setState(() {
      _streamingText = '';
      if (res.text.isNotEmpty || accumulated.isNotEmpty) {
        _messages.add(
          ChatMessage(
            role: 'model',
            text: res.text.isNotEmpty ? res.text : accumulated,
          ),
        );
      }
      _pending
        ..clear()
        ..addAll(res.interrupts);
    });
  }

  Future<void> _handleSend(String text) async {
    if (_loading) return;
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _loading = true;
      _streamingText = '';
    });

    _chat ??= _agent.chat();
    try {
      await _runTurn(_chat!.sendTextStream(text));
    } catch (e) {
      setState(() => _messages.add(ChatMessage(role: 'system', text: '⚠️ $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Records an approval (restart with the `tool-approved` flag) and advances.
  void _approve(AgentInterrupt interrupt) {
    _restarts.add(interrupt.restart({'tool-approved': true}));
    _messages.add(
      ChatMessage(role: 'system', text: 'Approved ${interrupt.name}.'),
    );
    _advance();
  }

  /// Records a denial (respond with a "not approved" result) and advances.
  void _deny(AgentInterrupt interrupt) {
    _responses.add(interrupt.respond(_denyOutput(interrupt.name)));
    _messages.add(
      ChatMessage(role: 'system', text: 'Denied ${interrupt.name}.'),
    );
    _advance();
  }

  /// Records an `ask_user` answer (respond with the chosen text) and advances.
  void _answer(AgentInterrupt interrupt, String answer) {
    _responses.add(interrupt.respond({'answer': answer}));
    _messages.add(ChatMessage(role: 'user', text: answer));
    _advance();
  }

  /// The result sent back when the user denies an interrupted tool. Shaped so
  /// the model can read it and adjust.
  Object _denyOutput(String toolName) {
    if (toolName == 'run_shell') {
      return {
        'stdout': '',
        'stderr': 'Command denied by the user.',
        'exitCode': 1,
      };
    }
    return {'error': 'The user denied this operation.'};
  }

  /// Pops the resolved interrupt; resumes the chat once none remain.
  void _advance() {
    setState(() {
      if (_pending.isNotEmpty) _pending.removeAt(0);
    });
    if (_pending.isEmpty) unawaited(_resume());
  }

  Future<void> _resume() async {
    final chat = _chat;
    final restarts = List<ToolRequestPart>.from(_restarts);
    final responses = List<ToolResponsePart>.from(_responses);
    _restarts.clear();
    _responses.clear();
    if (chat == null || (restarts.isEmpty && responses.isEmpty)) return;

    setState(() => _loading = true);
    try {
      await _runTurn(
        chat.resumeStream(
          AgentResume(
            restart: restarts.isNotEmpty ? restarts : null,
            respond: responses.isNotEmpty ? responses : null,
          ),
        ),
      );
    } catch (e) {
      setState(() => _messages.add(ChatMessage(role: 'system', text: '⚠️ $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Component build(BuildContext context) {
    final interrupt = _pending.isNotEmpty ? _pending.first : null;
    return div(classes: 'page-with-sidebar', [
      ChatUI(
        title: 'Coding Agent',
        description:
            'An AI coding assistant working in a sandboxed workspace. It can '
            'list, read, write, and edit files and run shell commands. File '
            'writes and risky shell commands pause for your approval.',
        suggestions: const [
          'Create a Dart hello world file called hello.dart.',
          'List the files in the workspace.',
          'Write a function that calculates the fibonacci sequence.',
        ],
        messages: _messages,
        streamingText: _streamingText,
        loading: _loading,
        inputDisabled: interrupt != null,
        renderMarkdown: true,
        onSend: _handleSend,
        extra: interrupt == null ? null : _interruptDialog(interrupt),
      ),
    ]);
  }

  Component _interruptDialog(AgentInterrupt interrupt) {
    if (interrupt.name == 'ask_user') return _askUserDialog(interrupt);
    return _approvalDialog(interrupt);
  }

  Component _approvalDialog(AgentInterrupt interrupt) {
    final isApproval = _approvalTools.contains(interrupt.name);
    return div(classes: 'interrupt-dialog', [
      h3([.text('Approval required')]),
      p([
        .text('The agent wants to run '),
        strong([.text(interrupt.name)]),
        .text(':'),
      ]),
      pre([.text(jsonEncode(interrupt.input))]),
      div(classes: 'interrupt-buttons', [
        button(
          [.text(isApproval ? 'Approve' : 'Allow')],
          classes: 'btn btn-approve',
          onClick: () => _approve(interrupt),
        ),
        button(
          [.text('Deny')],
          classes: 'btn btn-deny',
          onClick: () => _deny(interrupt),
        ),
      ]),
    ]);
  }

  Component _askUserDialog(AgentInterrupt interrupt) {
    final input = interrupt.input;
    final question = input is Map ? input['question']?.toString() ?? '' : '';
    final options = input is Map && input['options'] is List
        ? (input['options'] as List).map((o) => o.toString()).toList()
        : <String>[];
    return div(classes: 'interrupt-dialog', [
      h3([.text('The agent has a question')]),
      p([
        strong([.text(question)]),
      ]),
      div(classes: 'interrupt-buttons', [
        for (final option in options)
          button(
            [.text(option)],
            classes: 'btn btn-approve',
            onClick: () => _answer(interrupt, option),
          ),
      ]),
    ]);
  }
}
