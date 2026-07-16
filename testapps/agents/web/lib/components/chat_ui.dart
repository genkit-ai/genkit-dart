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

/// Shared chat chrome — renders messages, input box, and send button.
///
/// Ported from the JS `web/src/components/ChatUI.tsx`. Contains NO genkit
/// logic; each page owns its own session/streaming code and passes messages in.
library;

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:web/web.dart' as web;

/// A single chat message to render.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    this.reasoning,
    this.detail,
  });

  /// One of `user`, `model`, `system`, `tool`.
  final String role;
  final String text;

  /// Optional reasoning/thinking content — rendered as a collapsible block.
  final String? reasoning;

  /// Optional detail content — rendered as a terminal-style box below the text.
  final String? detail;
}

/// Renders a markdown string as an HTML block.
Component markdownBlock(String source) {
  final html = md.markdownToHtml(
    source,
    extensionSet: md.ExtensionSet.gitHubWeb,
  );
  return div(classes: 'markdown-body', [RawText(html)]);
}

/// A collapsible "🧠 Thinking…" reasoning block.
Component _thinkingBlock(String reasoning, {bool streaming = false}) {
  return details(
    open: streaming,
    classes: streaming ? 'thinking-block thinking-streaming' : 'thinking-block',
    [
      summary(classes: 'thinking-summary', [
        span(
          classes: streaming ? 'thinking-icon thinking-pulse' : 'thinking-icon',
          [.text('🧠')],
        ),
        .text(' Thinking…'),
      ]),
      div(classes: 'thinking-content', [markdownBlock(reasoning)]),
    ],
  );
}

/// Shared chat panel. The page supplies [messages], optional [streamingText],
/// suggestions, and an [onSend] callback.
class ChatUI extends StatefulComponent {
  const ChatUI({
    required this.title,
    required this.onSend,
    this.description,
    this.messages = const [],
    this.streamingText,
    this.streamingReasoning,
    this.loading = false,
    this.inputDisabled = false,
    this.renderMarkdown = false,
    this.suggestions = const [],
    this.headerAction,
    this.extra,
    super.key,
  });

  final String title;
  final String? description;
  final List<ChatMessage> messages;
  final String? streamingText;

  /// Partial reasoning text being streamed (shown as animated "thinking…"
  /// block).
  final String? streamingReasoning;
  final bool loading;
  final bool inputDisabled;
  final bool renderMarkdown;
  final List<String> suggestions;
  final void Function(String text) onSend;
  final Component? headerAction;

  /// Optional content rendered between the messages and the input (e.g. an
  /// interrupt dialog).
  final Component? extra;

  @override
  State<ChatUI> createState() => _ChatUIState();
}

class _ChatUIState extends State<ChatUI> {
  /// Auto-scroll the message list to the bottom after the DOM updates.
  ///
  /// Mirrors the JS double-rAF trick: schedule after the current render so the
  /// container has its final height before we set `scrollTop`.
  void _scrollToBottom() {
    Timer.run(() {
      final el = web.document.querySelector('.chat-messages');
      if (el != null) {
        el.scrollTop = el.scrollHeight.toDouble();
      }
    });
  }

  @override
  Component build(BuildContext context) {
    _scrollToBottom();
    return div(classes: 'chat-panel', [
      _header(),
      _messages(),
      ?component.extra,
      _ChatInput(
        title: component.title,
        disabled: component.loading || component.inputDisabled,
        onSend: component.onSend,
      ),
    ]);
  }

  Component _header() {
    return div(classes: 'chat-header', [
      div(classes: 'chat-header-top', [
        h2([.text(component.title)]),
        if (component.headerAction != null)
          div(classes: 'chat-header-action', [component.headerAction!]),
      ]),
      if (component.description != null)
        span(classes: 'chat-desc', [Component.text(component.description!)]),
    ]);
  }

  Component _messages() {
    final items = <Component>[];
    final messages = component.messages;
    final streamingText = component.streamingText;
    final streamingReasoning = component.streamingReasoning;
    final loading = component.loading;

    if (messages.isEmpty &&
        (streamingText == null || streamingText.isEmpty) &&
        (streamingReasoning == null || streamingReasoning.isEmpty) &&
        !loading) {
      items.add(_emptyState());
    }

    for (final m in messages) {
      if (m.reasoning != null && m.reasoning!.isNotEmpty) {
        items.add(_thinkingBlock(m.reasoning!));
      }
      if (m.text.isEmpty) continue;
      items.add(_messageBubble(m));
    }

    // Live streaming reasoning indicator (before any text is produced).
    if (streamingReasoning != null &&
        streamingReasoning.isNotEmpty &&
        (streamingText == null || streamingText.isEmpty)) {
      items.add(_thinkingBlock(streamingReasoning, streaming: true));
    }

    if (streamingText != null && streamingText.isNotEmpty) {
      items.add(
        div(classes: 'message', [
          div(classes: 'message-role', [.text('model')]),
          div(classes: 'message-text streaming', [
            if (component.renderMarkdown)
              markdownBlock(streamingText)
            else
              .text(streamingText),
            .text('▊'),
          ]),
        ]),
      );
    }

    if (loading &&
        (streamingText == null || streamingText.isEmpty) &&
        (streamingReasoning == null || streamingReasoning.isEmpty)) {
      items.add(
        div(classes: 'message', [
          div(classes: 'message-role', [.text('model')]),
          div(classes: 'message-text loading', [.text('Thinking…')]),
        ]),
      );
    }

    return div(classes: 'chat-messages', items);
  }

  Component _emptyState() {
    final suggestions = component.suggestions;
    final disabled = component.loading || component.inputDisabled;
    return div(classes: 'empty-state', [
      p([
        .text('Send a message to start a conversation with '),
        strong([.text(component.title)]),
      ]),
      if (suggestions.isNotEmpty)
        div(classes: 'suggestions', [
          span(classes: 'suggestions-label', [.text('Try one of these:')]),
          div(classes: 'suggestions-list', [
            for (final s in suggestions)
              button(
                [.text(s)],
                classes: 'suggestion-chip',
                disabled: disabled,
                onClick: () => component.onSend(s),
              ),
          ]),
        ]),
    ]);
  }

  Component _messageBubble(ChatMessage m) {
    final isUser = m.role == 'user';
    final isSystem = m.role == 'system';
    final isTool = m.role == 'tool';
    final cls = [
      'message',
      if (isUser) 'message-user',
      if (isSystem) 'message-system',
      if (isTool) 'message-tool',
    ].join(' ');
    final textCls = ['message-text', if (isTool) 'message-text-mono'].join(' ');
    return div(classes: cls, [
      div(classes: 'message-role', [.text(m.role)]),
      div(classes: textCls, [
        if (component.renderMarkdown && m.role == 'model')
          markdownBlock(m.text)
        else
          .text(m.text),
      ]),
      if (m.detail != null && m.detail!.isNotEmpty)
        pre(classes: 'message-detail', [.text(m.detail!)]),
    ]);
  }
}

/// The text input + send button. Local state holds the draft text; the
/// textarea is reset after each send by bumping a key.
class _ChatInput extends StatefulComponent {
  const _ChatInput({
    required this.title,
    required this.disabled,
    required this.onSend,
  });

  final String title;
  final bool disabled;
  final void Function(String text) onSend;

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  String _draft = '';
  int _resetKey = 0;

  void _send() {
    final value = _draft.trim();
    if (value.isEmpty) return;
    component.onSend(value);
    setState(() {
      _draft = '';
      _resetKey++;
    });
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'chat-input-area', [
      textarea(
        [],
        key: ValueKey('input-$_resetKey'),
        classes: 'chat-input',
        placeholder: 'Message ${component.title}…',
        rows: 2,
        disabled: component.disabled,
        onInput: (value) => _draft = value,
        events: {
          'keydown': (event) {
            final e = event as web.KeyboardEvent;
            if (e.key == 'Enter' && !e.shiftKey) {
              e.preventDefault();
              _send();
            }
          },
        },
      ),
      button(
        [.text('Send')],
        classes: 'btn btn-send',
        disabled: component.disabled,
        onClick: _send,
      ),
    ]);
  }
}
