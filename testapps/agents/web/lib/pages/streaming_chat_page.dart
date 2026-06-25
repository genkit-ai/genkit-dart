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

/// A reusable streaming chat page built on the `remoteAgent` client.
///
/// Mirrors the streaming loop shared by most JS pages (`WeatherChat`,
/// `TripPlanner`, etc.): create a chat, `sendStream` each turn, render tool
/// calls and responses inline, and stream the model text. Specialized pages
/// (banking interrupts, custom state, artifacts) compose this same client
/// surface directly rather than reusing this widget.
library;

import 'dart:convert';

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart';

/// Base URL of the agents server (the Jaspr dev server proxies nothing, so we
/// point straight at the shelf server's origin).
const String apiBase = 'http://localhost:8080';

/// A streaming chat page for a single server-managed agent endpoint.
class StreamingChatPage extends StatefulComponent {
  const StreamingChatPage({
    required this.endpoint,
    required this.title,
    this.description,
    this.suggestions = const [],
    this.renderMarkdown = true,
    super.key,
  });

  /// Endpoint path under [apiBase], e.g. `/api/weatherAgent`.
  final String endpoint;
  final String title;
  final String? description;
  final List<String> suggestions;
  final bool renderMarkdown;

  @override
  State<StreamingChatPage> createState() => _StreamingChatPageState();
}

class _StreamingChatPageState extends State<StreamingChatPage> {
  late final AgentApi _agent = remoteAgent(
    url: '$apiBase${component.endpoint}',
  );

  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _loading = false;

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
        // Render tool calls / responses inline from the raw chunk. The fallback
        // must be typed `const <Part>[]`; an untyped `const []` would widen the
        // element type to `dynamic`, breaking the `Part` extension getters under
        // dart2js (they would compile to failing dynamic invocations).
        for (final part in chunk.raw.modelChunk?.content ?? const <Part>[]) {
          if (part.isToolRequest) {
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
      setState(() {
        _streamingText = '';
        _messages.add(
          ChatMessage(
            role: 'system',
            text:
                '⚠️ Turn failed: $e. The last-good snapshot was preserved — '
                'you can keep chatting.',
          ),
        );
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'page-with-sidebar', [
      ChatUI(
        title: component.title,
        description: component.description,
        suggestions: component.suggestions,
        messages: _messages,
        streamingText: _streamingText,
        loading: _loading,
        renderMarkdown: component.renderMarkdown,
        onSend: _handleSend,
      ),
    ]);
  }
}
