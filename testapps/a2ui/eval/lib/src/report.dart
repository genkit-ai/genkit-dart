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

/// Summaries of a batch of runs: a console table and a Markdown report with
/// the transcripts of failing runs.
library;

import 'renderer.dart';
import 'runner.dart';
import 'scenario.dart';

/// Per-scenario aggregates.
final class ScenarioSummary {
  ScenarioSummary(this.scenario, this.runs);

  final Scenario scenario;
  final List<RunRecord> runs;

  int get passed => runs.where((r) => r.passed).length;
  int get turns => runs.fold(0, (n, r) => n + r.turns.length);
  int get failedTurns =>
      runs.fold(0, (n, r) => n + r.turns.where((t) => t.error != null).length);
  int get repaired =>
      runs.fold(0, (n, r) => n + r.turns.fold(0, (m, t) => m + t.repaired));
  int get repairFailed =>
      runs.fold(0, (n, r) => n + r.turns.fold(0, (m, t) => m + t.repairFailed));
  int get violations => runs.fold(
    0,
    (n, r) => n + r.turns.fold(0, (m, t) => m + t.violations.length),
  );
  int get aborted => runs.where((r) => r.abortedAt != null).length;

  int _tokens(String key) => runs.fold(
    0,
    (n, r) =>
        n +
        r.turns.fold(
          0,
          (m, t) =>
              m +
              t.usage.fold(0, (k, u) => k + ((u[key] as num?)?.toInt() ?? 0)),
        ),
  );
  int get inputTokens => _tokens('inputTokens');
  int get thoughtsTokens => _tokens('thoughtsTokens');

  /// Billed output tokens, including thinking tokens (`thoughtsTokens`) that
  /// Gemini plugins report separately from `outputTokens`.
  int get outputTokens => _tokens('outputTokens') + thoughtsTokens;

  /// How existing surfaces were changed: partial updates vs full re-renders.
  int _changes(SurfaceChange c) => runs.fold(
    0,
    (n, r) =>
        n +
        r.turns.fold(
          0,
          (m, t) => m + t.changes.values.where((v) => v == c).length,
        ),
  );
  int get updatedInPlace => _changes(SurfaceChange.updated);
  int get replaced => _changes(SurfaceChange.replaced);

  /// `"t<turn> <check>"` to how many runs failed it.
  Map<String, int> get failingChecks {
    final out = <String, int>{};
    for (final r in runs) {
      for (final t in r.turns) {
        for (final c in t.checks.where((c) => !c.passed)) {
          final key = 't${t.index} ${c.name}';
          out[key] = (out[key] ?? 0) + 1;
        }
      }
      if (r.abortedAt case final a?) {
        final key = 'aborted: ${a.split(':').first}';
        out[key] = (out[key] ?? 0) + 1;
      }
    }
    return out;
  }
}

String consoleSummary(List<ScenarioSummary> summaries) {
  final b = StringBuffer();
  final width = summaries.fold(
    8,
    (w, s) => s.scenario.name.length > w ? s.scenario.name.length : w,
  );
  b.writeln(
    '${'scenario'.padRight(width)}  passed  turn errs  repaired  '
    'repair fails  renderer errs  updated/replaced  tokens (in/out)',
  );
  for (final s in summaries) {
    final avgIn = s.runs.isEmpty ? 0 : (s.inputTokens / s.runs.length).round();
    final avgOut = s.runs.isEmpty
        ? 0
        : (s.outputTokens / s.runs.length).round();
    b.writeln(
      '${s.scenario.name.padRight(width)}  '
      '${'${s.passed}/${s.runs.length}'.padLeft(6)}  '
      '${'${s.failedTurns}/${s.turns}'.padLeft(9)}  '
      '${'${s.repaired}'.padLeft(8)}  '
      '${'${s.repairFailed}'.padLeft(12)}  '
      '${'${s.violations}'.padLeft(13)}  '
      '${'${s.updatedInPlace}/${s.replaced}'.padLeft(16)}  '
      '${'$avgIn/$avgOut'.padLeft(15)}',
    );
    for (final MapEntry(:key, :value) in s.failingChecks.entries) {
      b.writeln(
        '${''.padRight(width)}    $key: failed $value/${s.runs.length}',
      );
    }
  }
  final all = summaries.expand((s) => s.runs).toList();
  final ok = all.where((r) => r.passed).length;
  final totalIn = summaries.fold(0, (n, s) => n + s.inputTokens);
  final totalOut = summaries.fold(0, (n, s) => n + s.outputTokens);
  final totalThoughts = summaries.fold(0, (n, s) => n + s.thoughtsTokens);
  final thoughtsNote = totalThoughts > 0
      ? ', incl. $totalThoughts thoughts'
      : '';
  b.writeln(
    '\n$ok/${all.length} runs passed every check '
    '(total tokens: $totalIn in / $totalOut out$thoughtsNote)',
  );
  return b.toString();
}

String markdownReport(
  List<ScenarioSummary> summaries, {
  required Map<String, Object?> meta,
}) {
  final totalIn = summaries.fold(0, (n, s) => n + s.inputTokens);
  final totalOut = summaries.fold(0, (n, s) => n + s.outputTokens);
  final totalThoughts = summaries.fold(0, (n, s) => n + s.thoughtsTokens);
  final b = StringBuffer()
    ..writeln('# A2UI eval')
    ..writeln()
    ..writeln(
      [
        for (final MapEntry(:key, :value) in meta.entries) '`$key`: $value',
        '`totalInputTokens`: $totalIn',
        '`totalOutputTokens`: $totalOut',
        if (totalThoughts > 0) '`totalThoughtsTokens`: $totalThoughts',
      ].join(' | '),
    )
    ..writeln()
    ..writeln(
      '| Scenario | Passed | Turn errors | Repaired | Repair fails | '
      'Renderer errors | Updated / replaced | Avg tokens (in / out) |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|');
  for (final s in summaries) {
    final avgIn = s.runs.isEmpty ? 0 : (s.inputTokens / s.runs.length).round();
    final avgOut = s.runs.isEmpty
        ? 0
        : (s.outputTokens / s.runs.length).round();
    b.writeln(
      '| ${s.scenario.name} | ${s.passed}/${s.runs.length} | '
      '${s.failedTurns}/${s.turns} | ${s.repaired} | ${s.repairFailed} | '
      '${s.violations} | ${s.updatedInPlace} / ${s.replaced} | '
      '$avgIn / $avgOut |',
    );
  }

  for (final s in summaries) {
    final failing = s.failingChecks;
    if (failing.isEmpty) continue;
    b
      ..writeln()
      ..writeln('## ${s.scenario.name}')
      ..writeln();
    if (s.scenario.description case final d?) b.writeln('$d\n');
    for (final MapEntry(:key, :value) in failing.entries) {
      b.writeln('- `$key`: failed $value/${s.runs.length}');
    }
    for (final r in s.runs.where((r) => !r.passed)) {
      b
        ..writeln()
        ..writeln('### Run ${r.run}')
        ..writeln();
      if (r.abortedAt case final a?) b.writeln('**Aborted:** $a\n');
      for (final t in r.turns) {
        _writeTurn(b, t);
      }
    }
  }
  return b.toString();
}

void _writeTurn(StringBuffer b, TurnRecord t) {
  final failed = t.checks.where((c) => !c.passed).toList();
  b.writeln(
    '**t${t.index} ${t.kind}:** ${t.input} '
    '(${(t.duration.inMilliseconds / 1000).toStringAsFixed(1)}s)'
    '${failed.isEmpty ? '' : ' - FAILED'}',
  );
  b.writeln();
  for (final c in failed) {
    b.writeln('- `${c.name}`: ${c.error}');
  }
  if (t.changes.isNotEmpty) {
    b.writeln(
      '- changes: ${t.changes.entries.map((e) => '${e.key}:${e.value.name}').join(', ')}',
    );
  }
  if (t.prose.trim().isNotEmpty) {
    b.writeln('- prose: ${_oneLine(t.prose)}');
  }
  for (final l in t.logs) {
    b.writeln('- log: ${_oneLine(l)}');
  }
  for (final src in t.express) {
    b
      ..writeln()
      ..writeln('```')
      ..writeln(src)
      ..writeln('```');
  }
  b.writeln();
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
