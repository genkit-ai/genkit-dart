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

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:markdown/markdown.dart' as md;

/// A single chat message to render.
class ChatMessage {
  ChatMessage({required this.role, required this.text});

  /// One of `user`, `model`, `system`, `tool`.
  final String role;
  final String text;
}

/// Renders a markdown string as an HTML block.
Component markdownBlock(String source) {
  final html = md.markdownToHtml(
    source,
    extensionSet: md.ExtensionSet.gitHubWeb,
  );
  return div(classes: 'markdown-body', [RawText(html)]);
}

/// Shared chat panel. The page supplies [messages], optional [streamingText],
/// suggestions, and an [onSend] callback.
class ChatUI extends StatelessComponent {
  const ChatUI({
    required this.title,
    required this.onSend,
    this.description,
    this.messages = const [],
    this.streamingText,
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
  Component build(BuildContext context) {
    return div(classes: 'chat-panel', [
      _header(),
      _messages(),
      ?extra,
      _ChatInput(
        title: title,
        disabled: loading || inputDisabled,
        onSend: onSend,
      ),
    ]);
  }

  Component _header() {
    return div(classes: 'chat-header', [
      div(classes: 'chat-header-top', [
        h2([.text(title)]),
        if (headerAction != null)
          div(classes: 'chat-header-action', [headerAction!]),
      ]),
      if (description != null)
        span(classes: 'chat-desc', [Component.text(description!)]),
    ]);
  }

  Component _messages() {
    final items = <Component>[];

    if (messages.isEmpty &&
        (streamingText == null || streamingText!.isEmpty) &&
        !loading) {
      items.add(_emptyState());
    }

    for (final m in messages) {
      if (m.text.isEmpty) continue;
      items.add(_messageBubble(m));
    }

    final streaming = streamingText;
    if (streaming != null && streaming.isNotEmpty) {
      items.add(
        div(classes: 'message', [
          div(classes: 'message-role', [.text('model')]),
          div(classes: 'message-text streaming', [
            if (renderMarkdown) markdownBlock(streaming) else .text(streaming),
            .text('▊'),
          ]),
        ]),
      );
    }

    if (loading && (streaming == null || streaming.isEmpty)) {
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
    return div(classes: 'empty-state', [
      p([
        .text('Send a message to start a conversation with '),
        strong([.text(title)]),
      ]),
      if (suggestions.isNotEmpty)
        div(classes: 'suggestions', [
          span(classes: 'suggestions-label', [.text('Try one of these:')]),
          div(classes: 'suggestions-list', [
            for (final s in suggestions)
              button(
                [.text(s)],
                classes: 'suggestion-chip',
                disabled: loading || inputDisabled,
                onClick: () => onSend(s),
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
        if (renderMarkdown && m.role == 'model')
          markdownBlock(m.text)
        else
          .text(m.text),
      ]),
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
