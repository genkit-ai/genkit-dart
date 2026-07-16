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
///
/// When [sessionPath] is provided the page also supports URL-based session
/// persistence (matching the JS demos): it restores history from a
/// `:snapshotId` route param via `agent.loadChat`, pushes `chat.snapshotId`
/// into the URL after each turn, and shows a "✨ New Session" header action.
library;

import 'dart:convert';

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

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
    this.sidebar,
    this.sessionPath,
    this.snapshotId,
    super.key,
  });

  /// Endpoint path under [apiBase], e.g. `/api/weatherAgent`.
  final String endpoint;
  final String title;
  final String? description;
  final List<String> suggestions;
  final bool renderMarkdown;

  /// Optional educational side panel rendered next to the chat (e.g. a
  /// "How It Works" `info-sidebar`).
  final Component? sidebar;

  /// The base route for URL-based session persistence, e.g. `/weather`. When
  /// set, the page restores from [snapshotId] on load and pushes the current
  /// snapshot into the URL (`$sessionPath/:snapshotId`) after each turn.
  final String? sessionPath;

  /// Snapshot id read from the URL (`$sessionPath/:snapshotId`), if any.
  final String? snapshotId;

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

  /// True while restoring history from a URL snapshotId on first load.
  late bool _restoring = component.snapshotId != null;

  @override
  void initState() {
    super.initState();
    if (component.snapshotId != null) {
      _restore(component.snapshotId!);
    }
  }

  @override
  void didUpdateComponent(StreamingChatPage oldComponent) {
    super.didUpdateComponent(oldComponent);
    // The route's snapshotId can change without remounting (back/forward
    // navigation, an edited URL, or our own post-turn `context.replace`), so
    // re-sync here rather than keying the whole page (which would remount and
    // drop the transient tool-call cards that are not re-rendered mid-session).
    final next = component.snapshotId;
    if (next == oldComponent.snapshotId) return;
    // Our own post-turn URL push sets the route to the snapshot we just
    // produced — the UI is already correct, so don't reload (which would drop
    // the inline tool cards until the next reload).
    if (next == _chat?.snapshotId) return;

    if (next != null) {
      setState(() => _restoring = true);
      _restore(next);
    } else {
      // Navigated to "New Session": start fresh.
      setState(() {
        _chat = null;
        _messages.clear();
        _streamingText = '';
        _restoring = false;
      });
    }
  }

  bool get _persists => component.sessionPath != null;

  // ── Restore session history from a snapshotId ──────────────────────────
  //
  // Reconstructs the full transcript — including inline tool request/response
  // cards — from the snapshot's message history so a reload looks the same as
  // the live session.
  Future<void> _restore(String snapshotId) async {
    try {
      final chat = await _agent.loadChat(snapshotId: snapshotId);
      final restored = <ChatMessage>[];
      for (final msg in chat.messages) {
        final role = msg.role.value;
        // Emit inline tool cards for any tool request/response parts, matching
        // the live streaming loop in `_handleSend`.
        for (final part in msg.content) {
          if (part.isToolRequest) {
            final tr = part.toolRequest!;
            restored.add(
              ChatMessage(
                role: 'tool',
                text: '🔧 Calling ${tr.name}(${jsonEncode(tr.input)})',
              ),
            );
          } else if (part.isToolResponse) {
            final tr = part.toolResponse!;
            restored.add(
              ChatMessage(
                role: 'tool',
                text: '✅ ${tr.name} → ${jsonEncode(tr.output)}',
              ),
            );
          }
        }
        if (role != 'user' && role != 'model') continue;
        final text = msg.content.map((part) => part.text ?? '').join();
        if (text.isNotEmpty) restored.add(ChatMessage(role: role, text: text));
      }
      if (!mounted) return;
      setState(() {
        _chat = chat;
        _messages
          ..clear()
          ..addAll(restored);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(role: 'system', text: '⚠️ Failed to restore session: $e'),
        );
      });
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
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
        if (!mounted) break;
        // Render tool calls / responses inline from the raw chunk. The fallback
        // must be typed `const <Part>[]`; an untyped `const []` would widen the
        // element type to `dynamic`, breaking the `Part` extension getters under
        // dart2js (they would compile to failing dynamic invocations).
        for (final part in chunk.raw.modelChunk?.content ?? const <Part>[]) {
          if (part.isToolRequest) {
            // Skip interrupted tool requests: the agent re-emits them as an
            // extra chunk carrying `metadata.interrupt`, but they were already
            // streamed once during generation. Rendering both produces a
            // duplicate "Calling" card.
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
        _messages.add(
          ChatMessage(
            role: 'model',
            text: res.text.isNotEmpty ? res.text : accumulated,
          ),
        );
      });

      // Push the snapshot id into the URL so the session is bookmarkable.
      final id = chat.snapshotId;
      if (_persists && id != null && mounted) {
        context.replace('${component.sessionPath}/$id');
      }
    } catch (e) {
      if (!mounted) return;
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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Component build(BuildContext context) {
    if (_restoring) {
      return div(classes: 'page-with-sidebar', [
        div(classes: 'chat-panel', [
          div(classes: 'chat-header', [
            h2([.text(component.title)]),
            span(classes: 'chat-desc', [.text('Restoring session…')]),
          ]),
          div(classes: 'chat-messages', [
            div(classes: 'message', [
              div(classes: 'message-role', [.text('system')]),
              div(classes: 'message-text loading', [
                .text(
                  'Restoring session from snapshot ${component.snapshotId}…',
                ),
              ]),
            ]),
          ]),
        ]),
        ?component.sidebar,
      ]);
    }

    final showNewSession = _persists && _chat?.snapshotId != null;
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
        headerAction: showNewSession
            ? Link(
                to: component.sessionPath!,
                classes: 'btn btn-new-session',
                children: [.text('✨ New Session')],
              )
            : null,
      ),
      ?component.sidebar,
    ]);
  }
}
