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

import 'package:a2ui_core/a2ui_core.dart' show A2uiDataError;
import 'package:a2ui_server/agent.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:logging/logging.dart';

import 'renderer.dart';
import 'scenario.dart';

/// Zone key carrying the current turn's log sink, so concurrent runs keep
/// their middleware logs apart.
const _turnLogKey = #a2uiEvalTurnLog;
const _turnUsageKey = #a2uiEvalUsage;

/// Wraps the sample agent's model in `ai.registry` so each raw model call
/// (tool-loop steps, repairs, retries) records its token usage and system
/// prompt size into the current turn's zone.
Future<void> installModelUsageTap() async {
  const name = 'googleai/gemini-flash-latest';
  final inner = await ai.registry.lookupAction(ActionType.model, name);
  if (inner is! Model) return;
  ai.registry.register(
    Model(
      name: name,
      metadata: inner.metadata,
      customOptions: inner.customOptions,
      fn: (request, ctx) async {
        final response = await inner(
          request,
          onChunk: ctx.streamingRequested ? ctx.sendChunk : null,
          context: ctx.context,
          cancel: ctx.cancel,
        );
        if (Zone.current[_turnUsageKey]
            case final List<Map<String, Object?>> sink) {
          sink.add({
            'inputTokens': response.usage?.inputTokens,
            'outputTokens': response.usage?.outputTokens,
            'thoughtsTokens': response.usage?.thoughtsTokens,
            'cachedContentTokens': response.usage?.cachedContentTokens,
            'systemChars': [
              for (final m in request.messages)
                if (m.role == Role.system)
                  for (final p in m.content) p.text?.length ?? 0,
            ].fold<int>(0, (a, b) => a + b),
          });
        }
        return response;
      },
    ),
  );
}

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
        (l) =>
            l.contains('repair failed') ||
            l.contains('returned nothing') ||
            l.contains('discarding it') ||
            l.contains('ran out of time') ||
            l.contains('repair limit reached'),
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
  final historyRenderer = HeadlessRenderer();
  final chat = uiAgent.chat();
  var before = <SurfaceSnapshot>[];
  var seen = 0;
  TurnRecord? last;

  List<SurfaceSnapshot> snapshot() => [
    for (final s in renderer.surfaces) SurfaceSnapshot(s),
  ];

  Future<void> turn(String kind, String input, Message message) async {
    final t = TurnRecord(record.turns.length, kind, input);
    record.turns.add(t);
    before = snapshot();
    final sw = Stopwatch()..start();
    void Function()? abortTurn;
    try {
      final res = await runZoned(
        () async {
          final activeTurn = chat.sendStream(message: message);
          abortTurn = activeTurn.abort;
          await for (final chunk in activeTurn.stream) {
            t.streamed.addAll(
              a2uiEnvelopesFromParts(chunk.raw.modelChunk?.content),
            );
          }
          return activeTurn.response;
        },
        zoneValues: {_turnLogKey: t.logs, _turnUsageKey: t.usage},
      ).timeout(turnTimeout);
      if (res.error case final e?) t.error = '${e.status}: ${e.message}';
      // Read from the persisted session so model messages written alongside
      // intermediate tool calls are captured too (`chat.messages` holds only
      // the final message when the agent uses a session store).
      final session = chat.snapshotId == null
          ? null
          : await uiAgent.getSnapshot(snapshotId: chat.snapshotId!);
      final all = session?.messages ?? chat.messages;
      final produced = all.length > seen
          ? all.skip(seen).where((m) => m.role == Role.model)
          : [?res.message];
      seen = all.length;
      final prose = StringBuffer();
      for (final m in produced) {
        for (final p in m.content) {
          if (p.isText) prose.write(p.text);
          if (isA2uiPart(p)) {
            t.messages.addAll(a2uiEnvelopesFromParts([p]));
            if (p.metadata?[a2uiExpressMetadataKey] case final String src) {
              t.express.add(src);
            }
          }
        }
      }
      t.prose = prose.toString();
    } on TimeoutException {
      abortTurn?.call();
      t.error = 'timed out after ${turnTimeout.inSeconds}s';
      record.abortedAt = 't${t.index} timed out';
    } catch (e) {
      t.error = '$e';
    }
    t.duration = sw.elapsed;

    // Render what the client received, and compare the resulting surfaces
    // against what replaying the session history produces (catch-up chunks
    // deliberately resend or reorder parts while leaving the same rendered
    // state).
    final applied = renderer.applyTurn(t.index, t.streamed);
    historyRenderer.applyTurn(t.index, t.messages);
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
          _renderedState(renderer) == _renderedState(historyRenderer)
              ? null
              : 'streamed surfaces differ from session history '
                    '(streamed ${t.streamed.length} messages, '
                    'history has ${t.messages.length})',
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
        if (record.abortedAt != null) return record;
      case Press(:final button, :final or, :final on):
        final action = findAction(renderer, on, [button, ...or]);
        if (action.error case final e?) {
          record.abortedAt = 'press "$button" on $on: $e';
          return record;
        }
        await turn('press', '"$button" on $on', action.message!);
        if (record.abortedAt != null) return record;
      case Fill(:final field, :final value, :final on):
        if (fillInput(renderer, on, field, value) case final e?) {
          record.abortedAt = 'fill "$field" on $on: $e';
          return record;
        }
        fillInput(historyRenderer, on, field, value);
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
              streamed: t.streamed,
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

String _renderedState(HeadlessRenderer r) => jsonEncode({
  for (final s in r.surfaces.toList()..sort((a, b) => a.id.compareTo(b.id)))
    s.id: {'components': s.reachableComponents, 'data': s.data},
});

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

/// Builds the `action` message a renderer sends when a button matching
/// [labels] on [ref] is pressed.
({Message? message, String? error}) findAction(
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
    for (final MapEntry(key: id, value: c)
        in surface.reachableComponents.entries)
      if (c['component'] == 'Button') id: c,
  };
  final match = buttons.entries.where((e) {
    final label = surface.labelOf(e.key).toLowerCase();
    return needles.any(label.contains);
  }).firstOrNull;
  if (match == null) {
    final found = buttons.keys.map((id) => '"${surface.labelOf(id)}"');
    return (
      message: null,
      error: 'no matching button; buttons: ${found.join(', ')}',
    );
  }
  final event = switch (match.value['action']) {
    {'event': final Map e} => e,
    _ => null,
  };
  if (event == null) {
    return (message: null, error: 'button "${match.key}" has no event action');
  }
  final Map<String, Object?> context;
  final String? userMessage;
  try {
    context = <String, Object?>{
      if (event['context'] case final Map ctx)
        for (final MapEntry(:key, :value) in ctx.entries)
          '$key': surface.resolve(value, rejectRelative: true),
    };
    userMessage = switch (surface.resolve(
      event['userMessage'],
      rejectRelative: true,
    )) {
      final String m when m.isNotEmpty => m,
      _ => null,
    };
  } on FormatException catch (e) {
    return (message: null, error: e.message);
  }
  return (
    message: Message(
      role: Role.user,
      content: [
        DataPart(
          data: {
            'messages': [
              {
                'version': surface.version,
                'action': {
                  'name': event['name'],
                  'surfaceId': surface.id,
                  'sourceComponentId': match.key,
                  'timestamp': DateTime.now().toUtc().toIso8601String(),
                  'context': context,
                  'userMessage': ?userMessage,
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
String? fillInput(
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
    for (final MapEntry(key: id, value: c)
        in surface.reachableComponents.entries)
      if (_inputTypes.contains(c['component'])) id: c,
  };
  final match = inputs.entries
      .where((e) => surface.labelOf(e.key).toLowerCase().contains(needle))
      .firstOrNull;
  if (match == null) {
    final found = inputs.keys.map((id) => '"${surface.labelOf(id)}"');
    return 'no matching input; inputs: ${found.join(', ')}';
  }
  final bound = match.value['value'] ?? match.value['checked'];
  if (bindingPath(bound, version: surface.version) case final path?) {
    if (!path.startsWith('/')) {
      return 'input "${match.key}" uses relative binding "$path"';
    }
    try {
      surface.setData(path, value);
      return null;
    } on A2uiDataError catch (e) {
      return e.message;
    }
  }
  return 'input "${match.key}" is not bound to the data model';
}
