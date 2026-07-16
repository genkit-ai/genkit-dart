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

/// Weather chat (stateless) — client-managed session state.
///
/// Ported from the JS `ClientState.tsx`. The agent has no server store; the
/// client round-trips the session `state` blob automatically (the `AgentChat`
/// tracks it). A side panel shows the live client-held state.
library;

import 'dart:convert';

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart';
import 'streaming_chat_page.dart';

class ClientStatePage extends StatefulComponent {
  const ClientStatePage({super.key});

  @override
  State<ClientStatePage> createState() => _ClientStatePageState();
}

class _ClientStatePageState extends State<ClientStatePage> {
  late final AgentApi _agent = remoteAgent(
    url: '$apiBase/api/weatherAgentStateless',
  );

  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _loading = false;

  String get _stateJson {
    final chat = _chat;
    if (chat == null) return '(no session yet)';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'snapshotId': chat.snapshotId,
      'messages': chat.messages.length,
      'custom': chat.state,
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
        if (chunk.text.isNotEmpty) {
          accumulated = chunk.accumulatedText;
          setState(() => _streamingText = accumulated);
        }
      }
      final res = await turn.response;
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
        title: 'Weather Agent (Stateless)',
        description:
            'No server store — the client round-trips the session state blob '
            'on every turn. The panel on the right shows the live state.',
        suggestions: const ['What is the weather in Tokyo?', 'And in Paris?'],
        messages: _messages,
        streamingText: _streamingText,
        loading: _loading,
        renderMarkdown: true,
        onSend: _handleSend,
      ),
      aside(classes: 'state-inspector', [
        h3([.text('🧠 Client-held state')]),
        pre(classes: 'state-inspector-json', [.text(_stateJson)]),
      ]),
    ]);
  }
}
