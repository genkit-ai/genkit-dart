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

/// Banking (interrupt) — human-in-the-loop approval.
///
/// Ported from the JS `BankingInterrupt.tsx`. When the agent pauses on the
/// `userApproval` interrupt, an approve/deny dialog appears. Approving resumes
/// the chat with `chat.resume(...)` using the interrupt's `respond` builder.
library;

import 'dart:convert';

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart';
import 'streaming_chat_page.dart';

class BankingPage extends StatefulComponent {
  const BankingPage({super.key});

  @override
  State<BankingPage> createState() => _BankingPageState();
}

class _BankingPageState extends State<BankingPage> {
  late final AgentApi _agent = remoteAgent(url: '$apiBase/api/bankingAgent');

  AgentChat? _chat;

  final List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _loading = false;
  AgentInterrupt? _pendingApproval;

  Future<void> _runTurn(AgentTurn turn) async {
    var accumulated = '';
    await for (final chunk in turn.stream) {
      for (final part in chunk.raw.modelChunk?.content ?? const <Part>[]) {
        if (part.isToolRequest) {
          final tr = part.toolRequest!;
          setState(() {
            _messages.add(
              ChatMessage(
                role: 'tool',
                text: '🔧 ${tr.name}(${jsonEncode(tr.input)})',
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
      if (res.text.isNotEmpty || accumulated.isNotEmpty) {
        _messages.add(
          ChatMessage(
            role: 'model',
            text: res.text.isNotEmpty ? res.text : accumulated,
          ),
        );
      }
      // Surface a pending approval interrupt, if any.
      final approval = res.interrupts
          .where((interrupt) => interrupt.name == 'userApproval')
          .toList();
      _pendingApproval = approval.isNotEmpty ? approval.first : null;
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
    try {
      await _runTurn(_chat!.sendTextStream(text));
    } catch (e) {
      setState(() => _messages.add(ChatMessage(role: 'system', text: '⚠️ $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resolveApproval(bool approved) async {
    final approval = _pendingApproval;
    final chat = _chat;
    if (approval == null || chat == null) return;
    setState(() {
      _pendingApproval = null;
      _loading = true;
      _messages.add(
        ChatMessage(
          role: 'system',
          text: approved ? 'Approved transfer.' : 'Denied transfer.',
        ),
      );
    });

    try {
      final turn = chat.resumeStream(
        AgentResume(
          respond: [
            approval.respond({
              'approved': approved,
              'feedback': approved ? 'Looks good' : 'User denied',
            }),
          ],
        ),
      );
      await _runTurn(turn);
    } catch (e) {
      setState(() => _messages.add(ChatMessage(role: 'system', text: '⚠️ $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Component build(BuildContext context) {
    final approval = _pendingApproval;
    return div(classes: 'page-with-sidebar', [
      ChatUI(
        title: 'Banking Agent',
        description:
            'Ask to transfer money — the agent pauses for your approval before '
            'executing the transfer (human-in-the-loop interrupt).',
        suggestions: const [
          'Transfer \$500 to my savings account.',
          'Move \$1200 to account 4471.',
        ],
        messages: _messages,
        streamingText: _streamingText,
        loading: _loading,
        inputDisabled: approval != null,
        renderMarkdown: true,
        onSend: _handleSend,
        extra: approval == null
            ? null
            : div(classes: 'interrupt-dialog', [
                h3([.text('Approval required')]),
                p([
                  .text('The agent wants to: '),
                  strong([.text(jsonEncode(approval.input))]),
                ]),
                div(classes: 'interrupt-buttons', [
                  button(
                    [.text('Approve')],
                    classes: 'btn btn-approve',
                    onClick: () => _resolveApproval(true),
                  ),
                  button(
                    [.text('Deny')],
                    classes: 'btn btn-deny',
                    onClick: () => _resolveApproval(false),
                  ),
                ]),
              ]),
      ),
    ]);
  }
}
