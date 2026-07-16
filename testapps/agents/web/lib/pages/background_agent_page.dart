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

/// Background agent — detached (background) execution with polling.
///
/// Ported from the JS `BackgroundAgent.tsx`. Submits a turn with `detach: true`
/// via `chat.detach(...)`, which returns immediately with a snapshotId. The
/// page then polls the task status (pending → completed/failed/aborted/expired)
/// and renders the final report. An "Abort" button cancels the running task.
library;

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart' show markdownBlock;
import '../components/info_sidebar.dart';
import 'streaming_chat_page.dart';

class BackgroundAgentPage extends StatefulComponent {
  const BackgroundAgentPage({super.key});

  @override
  State<BackgroundAgentPage> createState() => _BackgroundAgentPageState();
}

class _BackgroundAgentPageState extends State<BackgroundAgentPage> {
  late final AgentApi _agent = remoteAgent(url: '$apiBase/api/backgroundAgent');

  String _topic = '';
  bool _running = false;
  String _status = '';
  String? _snapshotId;
  String _report = '';
  String? _error;
  int _polls = 0;
  int _formKey = 0;
  DetachedTask? _task;

  Future<void> _start() async {
    final topic = _topic.trim();
    if (topic.isEmpty || _running) return;
    setState(() {
      _running = true;
      _status = 'pending';
      _report = '';
      _error = null;
      _polls = 0;
      _snapshotId = null;
    });

    try {
      final task = await _agent.chat().detach(text: topic);
      setState(() {
        _task = task;
        _snapshotId = task.snapshotId;
      });

      await for (final snap in task.poll(
        interval: const Duration(milliseconds: 1500),
      )) {
        setState(() {
          _polls++;
          _status = snap.status?.value ?? 'pending';
          final messages = snap.messages;

          if (messages.isNotEmpty) {
            _report = messages.last.content
                .map((part) => part.text ?? '')
                .join();
          }
        });
      }

      // The poll stream completed without producing a report — the worker
      // likely stopped heartbeating.
      if (mounted && _report.isEmpty && _status == 'pending') {
        setState(() {
          _status = 'expired';
          _error =
              'The background worker stopped responding before producing a '
              'report.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'failed';
        _error = '$e';
      });
    } finally {
      setState(() => _running = false);
    }
  }

  Future<void> _abort() async {
    final task = _task;
    if (task == null) return;
    await task.abort();
    setState(() => _status = 'aborted');
  }

  void _reset() {
    setState(() {
      _topic = '';
      _running = false;
      _status = '';
      _snapshotId = null;
      _report = '';
      _error = null;
      _polls = 0;
      _task = null;
      _formKey++;
    });
  }

  bool get _isTerminal =>
      _status == 'completed' ||
      _status == 'failed' ||
      _status == 'aborted' ||
      _status == 'expired';

  @override
  Component build(BuildContext context) {
    final showForm = !_running && _report.isEmpty && !_isTerminal;
    return div(classes: 'page-with-sidebar', [
      div(classes: 'chat-panel', [
        div(classes: 'chat-header', [
          div(classes: 'chat-header-top', [
            h2([.text('Background Agent')]),
            if (_running)
              button(
                [.text('⏹ Abort')],
                classes: 'btn btn-deny',
                onClick: _abort,
              ),
          ]),
          span(classes: 'chat-desc', [
            .text(
              'Submit a research topic; the server processes it in the '
              'background and the page polls until done.',
            ),
          ]),
        ]),
        if (showForm) _form() else _statusView(),
      ]),
      backgroundSidebar(),
    ]);
  }

  Component _form() {
    return div(classes: 'background-form', [
      label(classes: 'background-label', [.text('Research topic')]),
      textarea(
        [],
        key: ValueKey('bg-form-$_formKey'),
        classes: 'background-input',
        rows: 3,
        placeholder: 'e.g. renewable energy trends',
        onInput: (v) => _topic = v,
      ),
      button(
        [.text('🚀 Start background research')],
        classes: 'btn btn-send',
        onClick: _start,
      ),
    ]);
  }

  Component _statusView() {
    final badgeClass = switch (_status) {
      'completed' => 'done',
      'aborted' => 'aborted',
      'failed' || 'expired' => 'failed',
      _ => '',
    };
    return div(classes: 'background-result', [
      div(classes: 'background-result-header', [
        span(classes: 'background-status-badge $badgeClass', [
          .text(_statusLabel()),
        ]),
        if (_snapshotId != null)
          span(classes: 'background-snapshot-id', [
            .text('snapshot: $_snapshotId'),
          ]),
        if (!_isTerminal)
          span(classes: 'background-poll-count', [.text('polls: $_polls')]),
      ]),
      if (!_isTerminal)
        div(classes: 'background-status', [
          span(classes: 'background-status-icon', [.text('⏳')]),
          h3([.text('Working…')]),
          span(classes: 'background-status-detail', [
            .text(
              'The server is generating your report. This page polls for '
              'status updates every couple of seconds.',
            ),
          ]),
        ]),
      if (_error != null) p(classes: 'background-error', [.text(_error!)]),
      if (_report.isNotEmpty)
        div(classes: 'background-report', [markdownBlock(_report)]),
      if (_isTerminal)
        div(classes: 'background-form', [
          button(
            [.text(_status == 'completed' ? '📄 New Report' : '🔄 Try Again')],
            classes: 'btn btn-send',
            onClick: _reset,
          ),
        ]),
    ]);
  }

  String _statusLabel() => switch (_status) {
    'completed' => '✅ Completed',
    'failed' => '❌ Failed',
    'aborted' => '⏹ Aborted',
    'expired' => '⌛ Expired',
    'pending' => '⏳ Pending',
    _ => _status,
  };
}
