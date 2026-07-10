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

/// Workspace builder — artifact production, streamed via `artifact` chunks.
///
/// Ported from the JS `WorkspaceBuilder.tsx`. The agent writes named artifacts;
/// each one streams as an `artifact` chunk. The side panel shows the current
/// artifacts (deduplicated by name).
library;

import 'dart:convert';

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart';
import 'streaming_chat_page.dart';

class WorkspacePage extends StatefulComponent {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final AgentApi _agent = remoteAgent(url: '$apiBase/api/workspaceAgent');

  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  final Map<String, String> _artifacts = {};
  String _streamingText = '';
  bool _loading = false;

  void _captureArtifact(Artifact a) {
    final name = a.name ?? 'artifact';
    final content = a.parts.map((part) => part.text ?? '').join();
    setState(() => _artifacts[name] = content);
  }

  Future<void> _handleSend(String text) async {
    if (_loading) return;
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _loading = true;
      _streamingText = '';
    });

    _chat ??= _agent.chat();
    final chat = _chat!;

    try {
      final turn = chat.sendStream(agentInputFromText(text));
      var accumulated = '';
      await for (final chunk in turn.stream) {
        final artifact = chunk.artifact;
        if (artifact != null) _captureArtifact(artifact);

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
        if (chunk.text.isNotEmpty) {
          accumulated = chunk.accumulatedText;
          setState(() => _streamingText = accumulated);
        }
      }
      final res = await turn.response;
      for (final a in res.artifacts) {
        _captureArtifact(a);
      }
      setState(() {
        _streamingText = '';
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

  @override
  Component build(BuildContext context) {
    return div(classes: 'page-with-sidebar', [
      ChatUI(
        title: 'Workspace Builder',
        description:
            'Ask the agent to create files. Each artifact streams to the panel '
            'on the right (deduplicated by name).',
        suggestions: const [
          'Write poem.txt with a poem about Genkit.',
          'Create a JSON config file called settings.json.',
          'Make a README.md describing this project.',
        ],
        messages: _messages,
        streamingText: _streamingText,
        loading: _loading,
        renderMarkdown: true,
        onSend: _handleSend,
      ),
      aside(classes: 'artifacts-sidebar', [
        h3([.text('📄 Artifacts')]),
        if (_artifacts.isEmpty)
          p(classes: 'artifacts-empty', [.text('No artifacts yet.')])
        else
          for (final entry in _artifacts.entries)
            div(classes: 'artifact', [
              div(classes: 'artifact-name', [.text(entry.key)]),
              pre(classes: 'artifact-content', [.text(entry.value)]),
            ]),
      ]),
    ]);
  }
}
