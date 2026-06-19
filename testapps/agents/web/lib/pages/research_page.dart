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

/// Research agent — multi-step custom agent with live status updates.
///
/// Ported from the JS `ResearchAgent.tsx`. The custom agent streams a `status`
/// field via `customPatch` chunks as it decomposes, researches, and synthesizes;
/// the side panel shows the live progress.
library;

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart';
import 'streaming_chat_page.dart';

class ResearchPage extends StatefulComponent {
  const ResearchPage({super.key});

  @override
  State<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends State<ResearchPage> {
  late final AgentApi _agent = remoteAgent(
    RemoteAgentOptions(url: '$apiBase/api/researchAgent'),
  );
  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _loading = false;
  String _status = '';
  List<String> _subQuestions = const [];

  void _applyCustom(dynamic custom) {
    if (custom is! Map) return;
    setState(() {
      _status = (custom['status'] as String?) ?? _status;
      final sq = custom['subQuestions'];
      if (sq is List) _subQuestions = sq.map((e) => e.toString()).toList();
    });
  }

  Future<void> _handleSend(String text) async {
    if (_loading) return;
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _loading = true;
      _streamingText = '';
      _status = 'Starting…';
      _subQuestions = const [];
    });

    _chat ??= _agent.chat(
      state: SessionState(
        custom: {'subQuestions': <dynamic>[], 'subAnswers': <dynamic>[]},
        messages: [],
        artifacts: [],
      ),
    );
    final chat = _chat!;

    try {
      final turn = chat.sendStream(agentInputFromText(text));
      var accumulated = '';
      await for (final chunk in turn.stream) {
        if (chunk.custom != null) _applyCustom(chunk.custom);
        if (chunk.text.isNotEmpty) {
          accumulated = chunk.accumulatedText;
          setState(() => _streamingText = accumulated);
        }
      }
      final res = await turn.response;
      setState(() {
        _streamingText = '';
        _status = '';
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
        title: 'Research Agent',
        description:
            'A multi-step custom agent: decomposes your question, researches '
            'each part, then synthesizes a final answer. Progress shows live '
            'on the right.',
        suggestions: const [
          'What are the environmental and economic impacts of electric vehicles?',
          'How does quantum computing work and why does it matter?',
        ],
        messages: _messages,
        streamingText: _streamingText,
        loading: _loading,
        renderMarkdown: true,
        onSend: _handleSend,
      ),
      aside(classes: 'state-inspector', [
        h3([.text('🔬 Progress')]),
        if (_status.isNotEmpty)
          p(classes: 'chat-desc', [.text(_status)])
        else
          p(classes: 'artifacts-empty', [.text('Idle.')]),
        if (_subQuestions.isNotEmpty) ...[
          h3([.text('Sub-questions')]),
          ul([
            for (final q in _subQuestions) li([.text(q)]),
          ]),
        ],
      ]),
    ]);
  }
}
