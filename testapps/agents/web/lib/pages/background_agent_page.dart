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
/// page then polls the task status (pending → done/failed/aborted) and renders
/// the final report. An "Abort" button cancels the running task.
library;

import 'package:genkit/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/chat_ui.dart' show markdownBlock;
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
  int _polls = 0;
  DetachedTask? _task;

  Future<void> _start() async {
    final topic = _topic.trim();
    if (topic.isEmpty || _running) return;
    setState(() {
      _running = true;
      _status = 'pending';
      _report = '';
      _polls = 0;
      _snapshotId = null;
    });

    try {
      final task = await _agent.chat().detachText(topic);
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
    } catch (e) {
      setState(() => _status = 'failed: $e');
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

  @override
  Component build(BuildContext context) {
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
        if (!_running && _report.isEmpty) _form() else _statusView(),
      ]),
    ]);
  }

  Component _form() {
    return div(classes: 'background-form', [
      label(classes: 'background-label', [.text('Research topic')]),
      textarea(
        [],
        classes: 'chat-input',
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
    final terminal =
        _status == 'completed' ||
        _status.startsWith('failed') ||
        _status == 'aborted';
    return div(classes: 'background-result', [
      div(classes: 'background-result-header', [
        span(
          classes:
              'background-status-badge '
              '${_status == 'completed'
                  ? 'done'
                  : _status == 'aborted'
                  ? 'aborted'
                  : _status.startsWith('failed')
                  ? 'failed'
                  : ''}',
          [.text(_status)],
        ),

        if (_snapshotId != null)
          span(classes: 'chat-desc', [.text('snapshot: $_snapshotId')]),
        if (!terminal) span(classes: 'chat-desc', [.text('polls: $_polls')]),
      ]),
      if (!terminal)
        div(classes: 'background-status', [
          span(classes: 'background-status-icon', [.text('⏳')]),
          h3([.text('Working…')]),
        ]),
      if (_report.isNotEmpty)
        div(classes: 'background-report', [markdownBlock(_report)]),
    ]);
  }
}
