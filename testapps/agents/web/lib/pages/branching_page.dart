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

/// Branching chat — "pick your variant".
///
/// Faithful port of the JS `BranchingChat.tsx`. Every turn fires TWO parallel
/// `chat.send()` calls from the SAME `snapshotId` (an immutable checkpoint),
/// producing two independent branches. The user picks one; the chosen
/// variant's `snapshotId` becomes the next branch point and is pushed into the
/// URL (`/branching/:snapshotId`) for persistence. On reload the session is
/// restored from that snapshot via `getSnapshot`.
library;

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'streaming_chat_page.dart';

/// A settled chat message (user turn or the chosen model response).
class _ChatMessage {
  _ChatMessage(this.role, this.text);
  final String role; // 'user' | 'model'
  final String text;
}

/// A pair of variant responses awaiting user selection.
class _Variant {
  _Variant(this.text, this.snapshotId);
  final String text;
  final String snapshotId;
}

class BranchingPage extends StatefulComponent {
  const BranchingPage({this.snapshotId, super.key});

  /// Branch point read from the URL (`/branching/:snapshotId`), if any.
  final String? snapshotId;

  @override
  State<BranchingPage> createState() => _BranchingPageState();
}

class _BranchingPageState extends State<BranchingPage> {
  late final AgentApi _agent = remoteAgent(
    RemoteAgentOptions(url: '$apiBase/api/branchingAgent'),
  );

  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  _Variant? _variantA;
  _Variant? _variantB;
  String? _error;

  /// The snapshotId of the current branch point.
  String? _snapshotId;

  /// True while restoring history from a URL snapshotId on first load.
  late bool _restoring = component.snapshotId != null;

  @override
  void initState() {
    super.initState();
    _snapshotId = component.snapshotId;
    if (component.snapshotId != null) {
      _restore(component.snapshotId!);
    }
  }

  // ── Restore session history from a snapshotId ──────────────────────────
  Future<void> _restore(String snapshotId) async {
    try {
      final snapshot = await _agent.getSnapshot(snapshotId: snapshotId);
      final messages = snapshot?.state.messages;
      if (messages != null) {
        final restored = <_ChatMessage>[];
        for (final msg in messages) {
          final role = msg.role.value;
          if (role != 'user' && role != 'model') continue;
          final t = msg.content.map((part) => part.text ?? '').join();
          if (t.isNotEmpty) restored.add(_ChatMessage(role, t));
        }
        setState(() {
          _messages
            ..clear()
            ..addAll(restored);
          _snapshotId = snapshot?.snapshotId ?? snapshotId;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to restore session: $e');
    } finally {
      setState(() => _restoring = false);
    }
  }

  // ── Send a message and generate two variants ───────────────────────────
  Future<void> _handleSend(String text) async {
    if (_loading || _variantA != null) return;
    setState(() {
      _messages.add(_ChatMessage('user', text));
      _loading = true;
      _error = null;
      _variantA = null;
      _variantB = null;
    });

    // Each variant gets its own chat that branches from the same snapshot
    // (or a fresh session when there is no branch point yet).
    AgentChat makeChat() => _snapshotId != null
        ? _agent.chat(snapshotId: _snapshotId)
        : _agent.chat();

    try {
      final results = await Future.wait([
        makeChat().send(agentInputFromText(text)),
        makeChat().send(agentInputFromText(text)),
      ]);
      setState(() {
        _variantA = _Variant(results[0].text, results[0].snapshotId ?? '');
        _variantB = _Variant(results[1].text, results[1].snapshotId ?? '');
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── User picks a variant ───────────────────────────────────────────────
  void _handlePick(_Variant chosen) {
    setState(() {
      _snapshotId = chosen.snapshotId;
      _messages.add(_ChatMessage('model', chosen.text));
      _variantA = null;
      _variantB = null;
    });
    // Push the chosen snapshotId into the URL for persistence.
    context.replace('/branching/${chosen.snapshotId}');
  }

  @override
  Component build(BuildContext context) {
    if (_restoring) {
      return div(classes: 'page-with-sidebar', [
        div(classes: 'chat-panel', [
          div(classes: 'chat-header', [
            h2([.text('🔀 Branching Chat')]),
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
        aside(classes: 'info-sidebar', []),
      ]);
    }

    return div(classes: 'page-with-sidebar', [
      div(classes: 'chat-panel', [_header(), _messageList(), _inputArea()]),
      _infoSidebar(),
    ]);
  }

  Component _header() {
    return div(classes: 'chat-header', [
      div(classes: 'chat-header-top', [
        h2([.text('🔀 Branching Chat')]),
        if (_snapshotId != null)
          Link(
            to: '/branching',
            classes: 'btn btn-new-session',
            children: [.text('✨ New Session')],
          ),
      ]),
      span(classes: 'chat-desc', [
        .text(
          'Every response generates two variants from the same snapshot. '
          'Pick the one you prefer to continue the conversation.',
        ),
      ]),
    ]);
  }

  Component _messageList() {
    final items = <Component>[];

    if (_messages.isEmpty && !_loading && _variantA == null) {
      items.add(
        div(classes: 'chat-empty', [
          .text(
            'Send a message to start. Each response will show two variants — '
            'pick your favorite to choose which branch to follow.',
          ),
        ]),
      );
    }

    for (final m in _messages) {
      items.add(
        div(classes: m.role == 'user' ? 'message message-user' : 'message', [
          div(classes: 'message-role', [
            .text(m.role == 'user' ? 'You' : 'Model'),
          ]),
          div(classes: 'message-text', [.text(m.text)]),
        ]),
      );
    }

    if (_loading) {
      items.add(
        div(classes: 'variant-loading', [
          div(classes: 'variant-loading-icon', [.text('🔀')]),
          .text('Generating two variants…'),
        ]),
      );
    }

    final a = _variantA;
    final b = _variantB;
    if (a != null && b != null) {
      items.add(
        div(classes: 'variant-picker', [
          div(classes: 'variant-picker-label', [
            .text('Pick a variant to continue:'),
          ]),
          div(classes: 'variant-cards', [
            _variantCard('A', a),
            _variantCard('B', b),
          ]),
        ]),
      );
    }

    if (_error != null) {
      items.add(
        div(classes: 'message message-system', [
          div(classes: 'message-role', [.text('system')]),
          div(classes: 'message-text', [.text('Error: $_error')]),
        ]),
      );
    }

    return div(classes: 'chat-messages', items);
  }

  Component _variantCard(String badge, _Variant variant) {
    return button(
      classes: 'variant-card',
      onClick: () => _handlePick(variant),
      [
        div(classes: 'variant-card-badge', [.text(badge)]),
        div(classes: 'variant-card-text', [.text(variant.text)]),
        div(classes: 'variant-card-action', [.text('Use this ✓')]),
      ],
    );
  }

  Component _inputArea() {
    final disabled = _loading || _variantA != null;
    return _BranchingInput(
      disabled: disabled,
      placeholder: _variantA != null
          ? 'Pick a variant above first…'
          : 'Type a message…',
      onSend: _handleSend,
    );
  }

  Component _infoSidebar() {
    return aside(classes: 'info-sidebar', [
      h3([.text('📋 How It Works')]),
      ol([
        li([
          .text('User sends a message. The client fires '),
          strong([.text('two parallel')]),
          .text(' '),
          code([.text('chat.send()')]),
          .text(' turns, both branching from the same '),
          code([.text('snapshotId')]),
          .text('.'),
        ]),
        li([
          .text('Each call creates an '),
          strong([.text('independent branch')]),
          .text(
            " from the same conversation checkpoint. The LLM's "
            'non-determinism produces different responses.',
          ),
        ]),
        li([
          .text(
            'Both variants are displayed side-by-side. The user picks one.',
          ),
        ]),
        li([
          .text("The chosen variant's "),
          code([.text('snapshotId')]),
          .text(
            ' becomes the new branch point for the next turn and is pushed '
            'into the URL for persistence.',
          ),
        ]),
        li([
          .text(
            'On reload, the client reads the snapshot for the URL ',
          ),
          code([.text('snapshotId')]),
          .text(' to restore the conversation history.'),
        ]),
      ]),
      h4([.text('Key Concept')]),
      p([
        .text('A '),
        code([.text('snapshotId')]),
        .text(' is an '),
        strong([.text('immutable checkpoint')]),
        .text(
          '. You can branch from it as many times as you want — each branch '
          'creates a new, independent snapshot. This is like Git: the '
          "original commit doesn't change when you create branches from it.",
        ),
      ]),
    ]);
  }
}

/// A single-line input for the branching page (it has its own input chrome
/// rather than the shared `ChatUI`, to match the JS layout).
class _BranchingInput extends StatefulComponent {
  const _BranchingInput({
    required this.disabled,
    required this.placeholder,
    required this.onSend,
  });

  final bool disabled;
  final String placeholder;
  final void Function(String text) onSend;

  @override
  State<_BranchingInput> createState() => _BranchingInputState();
}

class _BranchingInputState extends State<_BranchingInput> {
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
        key: ValueKey('branch-input-$_resetKey'),
        classes: 'chat-input',
        rows: 2,
        placeholder: component.placeholder,
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
