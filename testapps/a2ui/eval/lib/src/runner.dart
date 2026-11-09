// Copyright 2025 Google LLC
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

/// Runs scenarios against the sample agent and records what happened.
library;

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_server/agent.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:logging/logging.dart';

import 'impl.dart';
import 'renderer.dart';
import 'scenario.dart';

/// Zone key carrying the current turn's log sink, so concurrent runs keep
/// their middleware logs apart.
const _turnLogKey = #a2uiEvalTurnLog;

/// Routes `genkit_a2ui` log records to the turn that produced them.
///
/// `LogRecord.zone` is the zone the record was logged in, which async work
/// inherits from the `runZoned` around each turn.
void installLogCapture() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) {
    if (!r.loggerName.startsWith('genkit_a2ui')) return;
    if (r.zone?[_turnLogKey] case final List<String> sink) {
      sink.add('${r.level.name} ${r.loggerName}: ${r.message}');
    }
  });
}

final class CheckResult {
  CheckResult(this.name, this.error);
  final String name;

  /// Null when the check passed.
  final String? error;
  bool get passed => error == null;

  Map<String, Object?> toJson() => {'name': name, 'error': error};
}

/// One agent turn plus the checks that ran on it.
final class TurnRecord {
  TurnRecord(this.index, this.kind, this.input);

  final int index;
  final String kind;
  final String input;
  String prose = '';
  final List<String> express = [];

  /// The A2UI messages in the session history (the model messages the turn
  /// added). What the next turn's middleware will assume the client holds.
  final List<Map<String, dynamic>> messages = [];

  /// The A2UI messages that arrived on the stream: what a client rendering
  /// from chunks (like the sample) actually received. The renderer applies
  /// these.
  final List<Map<String, dynamic>> streamed = [];
  Map<String, SurfaceChange> changes = {};
  List<String> violations = [];
  final List<String> logs = [];

  /// Every raw model call the turn made (tool loop steps, repairs, retries),
  /// as recorded by the agent's eval usage tap.
  final List<Map<String, Object?>> usage = [];
  String? error;
  Duration duration = Duration.zero;
  final List<CheckResult> checks = [];

  int get repaired => logs.where((l) => l.contains('repaired an A2UI')).length;
  int get repairFailed => logs
      .where(
        (l) => l.contains('repair failed') || l.contains('returned nothing'),
      )
      .length;

  Map<String, Object?> toJson() => {
    'index': index,
    'kind': kind,
    'input': input,
    'prose': prose,
    'express': express,
    'messages': messages,
    'streamed': streamed,
    'changes': {for (final e in changes.entries) e.key: e.value.name},
    'violations': violations,
    'logs': logs,
    'usage': usage,
    'error': error,
    'durationMs': duration.inMilliseconds,
    'checks': [for (final c in checks) c.toJson()],
  };
}

final class RunRecord {
  RunRecord(this.scenario, this.run);

  final String scenario;
  final int run;
  final List<TurnRecord> turns = [];

  /// Set when a step could not run (e.g. the button to press does not exist);
  /// the remaining steps are skipped.
  String? abortedAt;

  Iterable<CheckResult> get checks => turns.expand((t) => t.checks);
  bool get passed => abortedAt == null && checks.every((c) => c.passed);

  Map<String, Object?> toJson() => {
    'scenario': scenario,
    'run': run,
    'passed': passed,
    'abortedAt': abortedAt,
    'turns': [for (final t in turns) t.toJson()],
  };
}

/// Runs one scenario end to end in a fresh session.
Future<RunRecord> runScenario(
  Scenario scenario,
  int run, {
  Duration turnTimeout = const Duration(seconds: 120),
}) async {
  final record = RunRecord(scenario.name, run);
  final renderer = HeadlessRenderer();
  final chat = uiAgent.chat();
  var before = <SurfaceSnapshot>[];
  TurnRecord? last;

  List<SurfaceSnapshot> snapshot() => [
    for (final s in renderer.surfaces) SurfaceSnapshot(s),
  ];

  Future<void> turn(String kind, String input, Message message) async {
    final t = TurnRecord(record.turns.length, kind, input);
    record.turns.add(t);
    before = snapshot();
    final sw = Stopwatch()..start();
    final sent = chat.messages.length;
    try {
      final res = await runZoned(
        () async {
          final turn = chat.sendStream(message: message);
          await for (final chunk in turn.stream) {
            t.streamed.addAll(
              a2uiEnvelopesFromParts(chunk.raw.modelChunk?.content),
            );
          }
          return turn.response;
        },
        zoneValues: {_turnLogKey: t.logs, #a2uiEvalUsage: t.usage},
      ).timeout(turnTimeout);
      if (res.error case final e?) t.error = '${e.status}: ${e.message}';
      // Everything the model produced this turn, including any blocks written
      // alongside a tool call before the final answer.
      final produced = chat.messages.length > sent
          ? chat.messages.skip(sent).where((m) => m.role == Role.model)
          : [?res.message];
      final prose = StringBuffer();
      for (final m in produced) {
        for (final p in m.content) {
          if (p.isText) prose.write(p.text);
          if (isA2uiPart(p)) {
            t.messages.addAll(a2uiEnvelopesFromParts([p]));
            if (expressSourceOf(p) case final src?) t.express.add(src);
          }
        }
      }
      t.prose = prose.toString();
    } catch (e) {
      t.error = '$e';
    }
    t.duration = sw.elapsed;

    // Render what the client received, like a real client would.
    final applied = renderer.applyTurn(t.index, t.streamed);
    t
      ..changes = applied.changes
      ..violations = applied.violations;

    // Implicit checks on every turn.
    t.checks
      ..add(CheckResult('turn ok', t.error))
      ..add(
        CheckResult(
          'renderer valid',
          t.violations.isEmpty ? null : t.violations.join('; '),
        ),
      )
      ..add(CheckResult('prose clean', _proseLeak(t.prose)))
      ..add(
        CheckResult(
          'stream matches history',
          jsonEncode(t.streamed) == jsonEncode(t.messages)
              ? null
              : 'streamed ${t.streamed.length} messages, history has '
                    '${t.messages.length}',
        ),
      );
    last = t;
  }

  for (final step in scenario.steps) {
    switch (step) {
      case Say(:final text):
        await turn(
          'say',
          text,
          Message(
            role: Role.user,
            content: [TextPart(text: text)],
          ),
        );
      case Press(:final button, :final or, :final on):
        final action = _findAction(renderer, on, [button, ...or]);
        if (action.error case final e?) {
          record.abortedAt = 'press "$button" on $on: $e';
          return record;
        }
        await turn('press', '"$button" on $on', action.message!);
      case Fill(:final field, :final value, :final on):
        if (_fill(renderer, on, field, value) case final e?) {
          record.abortedAt = 'fill "$field" on $on: $e';
          return record;
        }
      case Check(:final name, :final fn):
        final t = last;
        if (t == null) {
          record.abortedAt = 'check "$name" before any turn';
          return record;
        }
        String? error;
        try {
          error = fn(
            CheckContext(
              before: before,
              after: snapshot(),
              changes: t.changes,
              prose: t.prose,
              renderer: renderer,
            ),
          );
        } catch (e) {
          error = 'check threw: $e';
        }
        t.checks.add(CheckResult(name, error));
    }
  }
  return record;
}

/// Markup that should have been turned into a2ui parts but leaked into prose.
String? _proseLeak(String prose) {
  final lower = prose.toLowerCase();
  for (final marker in const [
    '<a2ui',
    '</a2ui',
    '```a2ui',
    '"createsurface"',
  ]) {
    if (lower.contains(marker)) return 'contains $marker';
  }
  return null;
}

/// Builds the `action` message genui sends when the button labelled [label]
/// on [ref] is pressed.
({Message? message, String? error}) _findAction(
  HeadlessRenderer renderer,
  SurfaceRef ref,
  List<String> labels,
) {
  final snap = ref.resolve([
    for (final s in renderer.surfaces) SurfaceSnapshot(s),
  ]);
  if (snap == null) return (message: null, error: 'no such surface');
  final surface = renderer[snap.id]!;
  final needles = [for (final l in labels) l.toLowerCase()];
  final buttons = {
    for (final MapEntry(key: id, value: c) in surface.components.entries)
      if (c['component'] == 'Button') id: c,
  };
  final match = buttons.entries.where((e) {
    final label = surface.labelOf(e.key).toLowerCase();
    return needles.any(label.contains);
  }).firstOrNull;
  if (match == null) {
    final labels = buttons.keys.map((id) => '"${surface.labelOf(id)}"');
    return (
      message: null,
      error: 'no matching button; buttons: ${labels.join(', ')}',
    );
  }
  final event = switch (match.value['action']) {
    {'event': final Map e} => e,
    _ => null,
  };
  if (event == null) {
    return (message: null, error: 'button "${match.key}" has no event action');
  }
  final context = {
    for (final MapEntry(:key, :value)
        in ((event['context'] as Map?) ?? const {}).entries)
      '$key': surface.resolve(value),
  };
  return (
    message: Message(
      role: Role.user,
      content: [
        DataPart(
          data: {
            actionDataKey: [
              {
                'version': 'v0.9',
                'action': {
                  'name': event['name'],
                  'surfaceId': surface.id,
                  'sourceComponentId': match.key,
                  'timestamp': DateTime.now().toUtc().toIso8601String(),
                  'context': context,
                },
              },
            ],
          },
          metadata: {'mimeType': a2uiMimeType},
        ),
      ],
    ),
    error: null,
  );
}

const _inputTypes = {
  'TextField',
  'CheckBox',
  'Slider',
  'DateTimeInput',
  'ChoicePicker',
};

/// Writes [value] to the data path bound to the input labelled [field].
String? _fill(
  HeadlessRenderer renderer,
  SurfaceRef ref,
  String field,
  Object value,
) {
  final snap = ref.resolve([
    for (final s in renderer.surfaces) SurfaceSnapshot(s),
  ]);
  if (snap == null) return 'no such surface';
  final surface = renderer[snap.id]!;
  final needle = field.toLowerCase();
  final inputs = {
    for (final MapEntry(key: id, value: c) in surface.components.entries)
      if (_inputTypes.contains(c['component'])) id: c,
  };
  final match = inputs.entries
      .where((e) => surface.labelOf(e.key).toLowerCase().contains(needle))
      .firstOrNull;
  if (match == null) {
    final labels = inputs.keys.map((id) => '"${surface.labelOf(id)}"');
    return 'no matching input; inputs: ${labels.join(', ')}';
  }
  final bound = match.value['value'] ?? match.value['checked'];
  if (bound case {'path': final String path}) {
    writePointer(surface.data, path, value);
    return null;
  }
  return 'input "${match.key}" is not bound to the data model';
}
