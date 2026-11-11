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

/// Runs the A2UI eval scenarios against the sample agent.
///
///     source ~/init-gemini.sh
///     dart run bin/eval.dart --runs 5 --concurrency 4 [--only form]
library;

import 'dart:convert';
import 'dart:io';

import 'package:a2ui_eval/scenarios.dart';
import 'package:a2ui_eval/src/report.dart';
import 'package:a2ui_eval/src/runner.dart';
import 'package:a2ui_eval/src/scenario.dart';
import 'package:a2ui_server/agent.dart';
import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('runs', abbr: 'n', defaultsTo: '3', help: 'Runs per scenario.')
    ..addOption('concurrency', abbr: 'c', defaultsTo: '4')
    ..addMultiOption(
      'only',
      help: 'Run scenarios whose name contains this (repeatable).',
    )
    ..addOption('timeout', defaultsTo: '120', help: 'Per-turn timeout (s).')
    ..addOption('out', defaultsTo: 'results', help: 'Report directory.')
    ..addFlag('list', negatable: false, help: 'List scenarios and exit.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final opts = parser.parse(args);
  if (opts.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }
  if (opts.flag('list')) {
    for (final s in scenarios) {
      stdout.writeln(
        '${s.name}${s.description == null ? '' : ': ${s.description}'}',
      );
    }
    return;
  }
  if ((Platform.environment['GEMINI_API_KEY'] ?? '').isEmpty) {
    stderr.writeln('GEMINI_API_KEY is not set (try: source ~/init-gemini.sh)');
    exitCode = 64;
    return;
  }

  int? positiveInt(String name) {
    final v = int.tryParse(opts.option(name)!);
    if (v == null || v < 1) {
      stderr.writeln(
        '--$name must be an integer >= 1 (got "${opts.option(name)}").',
      );
      exitCode = 64;
      return null;
    }
    return v;
  }

  final runs = positiveInt('runs');
  final concurrency = positiveInt('concurrency');
  final timeoutSec = positiveInt('timeout');
  if (runs == null || concurrency == null || timeoutSec == null) return;
  final timeout = Duration(seconds: timeoutSec);
  final only = opts.multiOption('only');
  final selected = [
    for (final s in scenarios)
      if (only.isEmpty || only.any(s.name.contains)) s,
  ];
  if (selected.isEmpty) {
    stderr.writeln('No scenario matches $only. Use --list.');
    exitCode = 64;
    return;
  }

  installLogCapture();
  await registerCatalogs();
  await installModelUsageTap();

  final jobs = [
    for (final s in selected)
      for (var i = 0; i < runs; i++) (scenario: s, run: i),
  ];
  final results = <Scenario, List<RunRecord>>{for (final s in selected) s: []};
  var next = 0;
  var done = 0;
  final started = DateTime.now();

  Future<void> worker() async {
    while (next < jobs.length) {
      final job = jobs[next++];
      final r = await runScenario(job.scenario, job.run, turnTimeout: timeout);
      results[job.scenario]!.add(r);
      done++;
      stdout.writeln(
        '[$done/${jobs.length}] ${r.passed ? 'PASS' : 'FAIL'} '
        '${job.scenario.name} #${job.run}',
      );
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  final elapsed = DateTime.now().difference(started);

  final summaries = [
    for (final s in selected)
      ScenarioSummary(s, results[s]!..sort((a, b) => a.run.compareTo(b.run))),
  ];
  stdout
    ..writeln()
    ..writeln(consoleSummary(summaries));

  final stamp = started.toIso8601String().replaceAll(':', '-').split('.').first;
  final dir = Directory(opts.option('out')!)..createSync(recursive: true);
  final meta = <String, Object?>{
    'started': started.toIso8601String(),
    'elapsed': '${elapsed.inSeconds}s',
    'runs': runs,
  };
  final json = File('${dir.path}/$stamp.json')
    ..writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'meta': meta,
        'runs': [
          for (final s in summaries)
            for (final r in s.runs) r.toJson(),
        ],
      }),
    );
  final md = File('${dir.path}/$stamp.md')
    ..writeAsStringSync(markdownReport(summaries, meta: meta));
  stdout.writeln('Report: ${md.path}\nRaw:    ${json.path}');

  // Genkit keeps the process alive (telemetry, HTTP clients).
  exit(summaries.every((s) => s.passed == s.runs.length) ? 0 : 1);
}
