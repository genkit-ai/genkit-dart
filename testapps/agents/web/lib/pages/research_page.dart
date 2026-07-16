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
  late final AgentApi _agent = remoteAgent(url: '$apiBase/api/researchAgent');

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
      final turn = chat.sendStream(text: text);
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
    return div(classes: 'research-layout', [
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
      _sidebar(),
    ]);
  }

  Component _sidebar() {
    final hasProgress = _status.isNotEmpty || _subQuestions.isNotEmpty;
    return aside(classes: 'research-sidebar', [
      h3([.text('🔬 Research Process')]),
      p(classes: 'research-sidebar-hint', [
        .text('A custom agent that orchestrates '),
        code([.text('decompose → research → synthesize')]),
        .text(' and streams progress via '),
        code([.text('customPatch')]),
        .text(' chunks.'),
      ]),
      if (_loading && _status.isNotEmpty)
        div(classes: 'research-status-bar', [
          div(classes: 'research-status-dot', []),
          .text(_status),
        ]),
      if (!hasProgress)
        div(classes: 'research-empty', [
          .text('Ask a question to watch the research process unfold.'),
        ]),
      if (_subQuestions.isNotEmpty)
        div(classes: 'research-section', [
          h4([.text('Sub-questions')]),
          p(classes: 'research-section-hint', [
            .text('The agent decomposed your question into these parts:'),
          ]),
          ol(classes: 'research-questions', [
            for (final q in _subQuestions)
              li(classes: 'research-question', [.text(q)]),
          ]),
        ]),
      hr(classes: 'research-divider'),
      h4([.text('📋 How It Works')]),
      ol(classes: 'research-howto', [
        li([
          .text('Decompose: the agent breaks your question into '),
          code([.text('subQuestions')]),
          .text('.'),
        ]),
        li([.text('Research: each sub-question is answered in turn.')]),
        li([.text('Synthesize: answers are combined into a final response.')]),
        li([
          .text('Each step streams a '),
          code([.text('customPatch')]),
          .text(' with the live '),
          code([.text('status')]),
          .text('.'),
        ]),
      ]),
    ]);
  }
}
