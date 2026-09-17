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
///
/// The agent researches the report one section at a time (each a
/// `research_section` tool round), so an abort lands mid-loop. The aborted
/// snapshot preserves the sections researched so far (its intermediate
/// last-good state), and "Continue" resumes from that snapshot via
/// `chat(snapshotId: ...).detach(...)` instead of restarting from scratch.
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
  List<String> _sections = const [];
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
      _sections = const [];
      _error = null;
      _polls = 0;
      _snapshotId = null;
    });

    try {
      final task = await _agent.chat().detach(text: topic);
      await _pollTask(task);
    } catch (e) {
      setState(() {
        _status = 'failed';
        _error = '$e';
      });
    } finally {
      setState(() => _running = false);
    }
  }

  /// Resumes a previously aborted run from its snapshot. The aborted snapshot
  /// carries the sections researched before the abort, so the agent continues
  /// from there rather than starting over.
  Future<void> _continue() async {
    final id = _snapshotId;
    if (id == null || _running) return;
    setState(() {
      _running = true;
      _status = 'pending';
      _error = null;
      _polls = 0;
    });

    try {
      final task = await _agent
          .chat(snapshotId: id)
          .detach(
            text:
                'Continue the research from where you left off: research any '
                'remaining sections, then write the final report.',
          );
      await _pollTask(task);
    } catch (e) {
      setState(() {
        _status = 'failed';
        _error = '$e';
      });
    } finally {
      setState(() => _running = false);
    }
  }

  /// Polls [task] to a terminal state, projecting each snapshot's message
  /// history into a live section checklist plus the final report text.
  Future<void> _pollTask(DetachedTask task) async {
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
        _sections = _researchedSections(snap.messages);
        _report = _finalReport(snap.messages);
        // A continue turn reserves a fresh snapshot id; track it so a
        // subsequent abort/continue targets the latest one.
        _snapshotId = snap.snapshotId;
      });
    }

    // The poll stream completed without producing a report — the worker likely
    // stopped heartbeating.
    if (mounted && _report.isEmpty && _status == 'pending') {
      setState(() {
        _status = 'expired';
        _error =
            'The background worker stopped responding before producing a '
            'report.';
      });
    }
  }

  /// Names of the sections researched so far, in order, from `research_section`
  /// tool requests in the model turns.
  List<String> _researchedSections(List<Message> messages) {
    final sections = <String>[];
    for (final message in messages) {
      if (message.role != Role.model) continue;
      for (final part in message.content) {
        final req = part.toolRequest;
        if (req?.name != 'research_section') continue;
        final input = req!.input;
        final section = input is Map ? input['section']?.toString() : null;
        if (section != null && section.isNotEmpty) sections.add(section);
      }
    }
    return sections;
  }

  /// The final markdown report: the last model message that is plain text (no
  /// tool requests). Empty until the agent finishes researching and writes it.
  String _finalReport(List<Message> messages) {
    for (final message in messages.reversed) {
      if (message.role != Role.model) continue;
      final hasToolRequest = message.content.any((p) => p.toolRequest != null);
      if (hasToolRequest) continue;
      final text = message.content.map((p) => p.text ?? '').join();
      if (text.trim().isNotEmpty) return text;
    }
    return '';
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
      _sections = const [];
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
              'Submit a research topic; the server researches it section by '
              'section in the background and the page polls until done. Abort '
              'mid-run, then continue from where it stopped.',
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
              'The server is researching your report section by section. This '
              'page polls for status updates every couple of seconds.',
            ),
          ]),
        ]),
      if (_sections.isNotEmpty) _sectionChecklist(),
      if (_error != null) p(classes: 'background-error', [.text(_error!)]),
      if (_report.isNotEmpty)
        div(classes: 'background-report', [markdownBlock(_report)]),
      if (_isTerminal) _terminalActions(),
    ]);
  }

  /// A live checklist of researched sections, so the intermediate progress an
  /// aborted snapshot preserves is visible.
  Component _sectionChecklist() {
    final aborted = _status == 'aborted';
    return div(classes: 'background-sections', [
      h4([
        .text(
          aborted
              ? 'Sections researched before abort (${_sections.length})'
              : 'Sections researched (${_sections.length})',
        ),
      ]),
      ul(classes: 'background-section-list', [
        for (final section in _sections) li([.text('✅ $section')]),
      ]),
    ]);
  }

  Component _terminalActions() {
    final canContinue = _status == 'aborted' && _snapshotId != null;
    return div(classes: 'background-form', [
      if (canContinue)
        button(
          [.text('▶️ Continue from where it stopped')],
          classes: 'btn btn-send',
          onClick: _continue,
        ),
      button(
        [.text(_status == 'completed' ? '📄 New Report' : '🔄 Start Over')],
        classes: canContinue ? 'btn btn-secondary' : 'btn btn-send',
        onClick: _reset,
      ),
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
