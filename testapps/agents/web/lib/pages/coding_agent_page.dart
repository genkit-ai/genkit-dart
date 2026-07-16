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
///
/// A file-explorer sidebar mirrors the JS layout: it lists the sandboxed
/// `workspace/` directory (via the `listWorkspaceFiles` flow), refreshing after
/// each turn, and shows file contents on click (via `readWorkspaceFile`).
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

/// A file or directory node in the workspace tree.
class _FileNode {
  _FileNode({
    required this.name,
    required this.path,
    required this.type,
    this.children,
  });

  factory _FileNode.fromJson(Map<String, dynamic> json) => _FileNode(
    name: json['name'] as String? ?? '',
    path: json['path'] as String? ?? '',
    type: json['type'] as String? ?? 'file',
    children: (json['children'] as List?)
        ?.map((c) => _FileNode.fromJson((c as Map).cast<String, dynamic>()))
        .toList(),
  );

  final String name;
  final String path;
  final String type;
  final List<_FileNode>? children;

  bool get isDirectory => type == 'directory';
}

class CodingAgentPage extends StatefulComponent {
  const CodingAgentPage({super.key});

  @override
  State<CodingAgentPage> createState() => _CodingAgentPageState();
}

class _CodingAgentPageState extends State<CodingAgentPage> {
  late final AgentApi _agent = remoteAgent(url: '$apiBase/api/codingAgent');

  // Flows exposing the sandboxed workspace directory.
  late final RemoteAction<void, List<_FileNode>, dynamic, dynamic> _listFiles =
      defineRemoteAction(
        url: '$apiBase/api/workspace/files',
        fromResponse: (json) {
          final files = (json as Map)['files'] as List? ?? const [];
          return files
              .map(
                (f) => _FileNode.fromJson((f as Map).cast<String, dynamic>()),
              )
              .toList();
        },
      );
  late final RemoteAction<String, String, dynamic, dynamic> _readFile =
      defineRemoteAction(
        url: '$apiBase/api/workspace/file',
        fromResponse: (json) => (json as Map)['content'] as String? ?? '',
      );

  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _loading = false;

  // File explorer state.
  List<_FileNode> _files = const [];
  final Set<String> _expandedDirs = {};
  String? _selectedPath;
  String _fileContent = '';
  bool _fileLoading = false;

  // Pending interrupts awaiting a user decision, resolved one at a time. Each
  // decision is accumulated into [_restarts] / [_responses]; once every pending
  // interrupt is resolved, the chat resumes with the combined payload.
  final List<AgentInterrupt> _pending = [];
  final List<ToolRequestPart> _restarts = [];
  final List<ToolResponsePart> _responses = [];

  @override
  void initState() {
    super.initState();
    unawaited(_refreshFiles());
  }

  Future<void> _refreshFiles() async {
    try {
      final files = await _listFiles.call(input: null);
      if (!mounted) return;
      setState(() => _files = files);
    } catch (_) {
      // Silently ignore — the workspace may not exist until the first write.
    }
  }

  Future<void> _openFile(String path) async {
    setState(() {
      _selectedPath = path;
      _fileLoading = true;
      _fileContent = '';
    });
    try {
      final content = await _readFile.call(input: path);
      if (!mounted) return;
      setState(() => _fileContent = content);
    } catch (e) {
      if (!mounted) return;
      setState(() => _fileContent = 'Failed to read file: $e');
    } finally {
      if (mounted) setState(() => _fileLoading = false);
    }
  }

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

    // The agent may have created/edited files this turn — refresh the tree.
    unawaited(_refreshFiles());
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
      await _runTurn(_chat!.sendStream(text: text));
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
          restart: restarts.isNotEmpty ? restarts : null,
          respond: responses.isNotEmpty ? responses : null,
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
    return div(classes: 'coding-agent-layout', [
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
      _fileExplorer(),
    ]);
  }

  // ── File explorer sidebar ──────────────────────────────────────────────
  Component _fileExplorer() {
    return aside(classes: 'file-explorer', [
      div(classes: 'file-explorer-header', [
        h3([.text('📁 Workspace')]),
        button(
          [.text('⟳ Refresh')],
          classes: 'btn-refresh-files',
          onClick: () => unawaited(_refreshFiles()),
        ),
      ]),
      if (_files.isEmpty)
        div(classes: 'file-explorer-empty', [.text('Workspace is empty.')])
      else
        div(classes: 'file-tree', _fileTree(_files, 0)),
      if (_selectedPath != null) _fileViewer(),
    ]);
  }

  List<Component> _fileTree(List<_FileNode> nodes, int depth) {
    final items = <Component>[];
    for (final node in nodes) {
      final indentPad = 12 + depth * 14;
      if (node.isDirectory) {
        final expanded = _expandedDirs.contains(node.path);
        items.add(
          button(
            classes: 'file-tree-item file-tree-dir',
            styles: Styles(raw: {'padding-left': '${indentPad}px'}),
            onClick: () => setState(() {
              if (!_expandedDirs.add(node.path)) {
                _expandedDirs.remove(node.path);
              }
            }),
            [
              span(classes: 'file-icon', [.text(expanded ? '📂' : '📁')]),
              span(classes: 'file-name', [.text(node.name)]),
            ],
          ),
        );
        if (expanded && node.children != null) {
          items.addAll(_fileTree(node.children!, depth + 1));
        }
      } else {
        final selected = node.path == _selectedPath;
        items.add(
          button(
            classes: selected ? 'file-tree-item selected' : 'file-tree-item',
            styles: Styles(raw: {'padding-left': '${indentPad}px'}),
            onClick: () => unawaited(_openFile(node.path)),
            [
              span(classes: 'file-icon', [.text('📄')]),
              span(classes: 'file-name', [.text(node.name)]),
            ],
          ),
        );
      }
    }
    return items;
  }

  Component _fileViewer() {
    return div(classes: 'file-viewer', [
      div(classes: 'file-viewer-header', [
        span(classes: 'file-viewer-path', [.text(_selectedPath ?? '')]),
        button(
          [.text('✕')],
          classes: 'file-viewer-close',
          onClick: () => setState(() {
            _selectedPath = null;
            _fileContent = '';
          }),
        ),
      ]),
      pre(classes: 'file-viewer-content', [
        .text(_fileLoading ? 'Loading…' : _fileContent),
      ]),
    ]);
  }

  // ── Interrupt dialogs ──────────────────────────────────────────────────
  Component _interruptDialog(AgentInterrupt interrupt) {
    if (interrupt.name == 'ask_user') return _askUserDialog(interrupt);
    return _approvalDialog(interrupt);
  }

  Component _approvalDialog(AgentInterrupt interrupt) {
    final isApproval = _approvalTools.contains(interrupt.name);
    return div(classes: 'approval-dialog', [
      h3([.text('🔒 Approval required')]),
      p(classes: 'approval-tool-name', [
        .text('The agent wants to run '),
        code([.text(interrupt.name)]),
        .text(':'),
      ]),
      pre(classes: 'approval-code', [.text(jsonEncode(interrupt.input))]),
      div(classes: 'approval-buttons', [
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
    return div(classes: 'ask-user-dialog', [
      h3([.text('💬 The agent has a question')]),
      p(classes: 'ask-user-question', [.text(question)]),
      div(classes: 'ask-user-options', [
        for (final option in options)
          button(
            [.text(option)],
            classes: 'ask-user-option',
            onClick: () => _answer(interrupt, option),
          ),
      ]),
    ]);
  }
}
