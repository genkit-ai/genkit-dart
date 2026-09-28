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

/// Covers the `GENKIT_RUNTIME_ID` override of the v1 reflection server's id.
///
/// The override is read from the process environment, which a test cannot set
/// for itself, so each case runs `test/fixtures/reflection_health_probe.dart`
/// in a child process with the environment under test. The probe runs in a
/// temp dir holding a stub `pubspec.yaml`, so its runtime file lands there and
/// not in the repository. The suite is unverified on Windows because there is
/// no Windows CI.
@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Bounds the probe's startup, which includes compiling the package.
const _readyLimit = Duration(seconds: 30);

/// Bounds the probe's shutdown after it is signalled.
const _exitLimit = Duration(seconds: 10);

/// The probe app running in a child process.
class _Probe {
  _Probe._(this._process, this._ready, this._stderr);

  static const _readyPrefix = 'probe-ready ';

  final Process _process;
  final StringBuffer _stderr;
  final Future<Map<String, dynamic>> _ready;

  /// The pid, port and runtime file path the probe reported once its server
  /// was listening.
  Future<Map<String, dynamic>> get ready => _ready;

  /// Starts the probe with the test runner's own environment minus every
  /// `GENKIT_*` entry, so a variable set around the suite cannot leak in and
  /// decide the outcome, then with [environment] applied on top.
  static Future<_Probe> start({
    required Directory workingDirectory,
    Map<String, String> environment = const {},
  }) async {
    final fixture = File('test/fixtures/reflection_health_probe.dart').absolute;
    expect(
      fixture.existsSync(),
      isTrue,
      reason:
          'probe fixture not found at ${fixture.path}; run this test from the '
          'genkit package root',
    );
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', fixture.path],
      environment: {
        for (final entry in Platform.environment.entries)
          if (!entry.key.startsWith('GENKIT_')) entry.key: entry.value,
        ...environment,
      },
      includeParentEnvironment: false,
      workingDirectory: workingDirectory.path,
    );

    final stderrText = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(stderrText.write);
    // Drained past the ready line so the probe cannot block on a full pipe.
    final readyLine = Completer<String>();
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!readyLine.isCompleted && line.startsWith(_readyPrefix)) {
              readyLine.complete(line);
            }
          },
          onDone: () async {
            if (readyLine.isCompleted) return;
            final exitCode = await process.exitCode;
            readyLine.completeError(
              TestFailure(
                'probe exited with code $exitCode before reporting ready:\n'
                '$stderrText',
              ),
            );
          },
        );
    final ready = readyLine.future
        .timeout(
          _readyLimit,
          onTimeout: () => fail(
            'probe did not report ready within ${_readyLimit.inSeconds}s:\n'
            '$stderrText',
          ),
        )
        .then(
          (line) =>
              jsonDecode(line.substring(_readyPrefix.length))
                  as Map<String, dynamic>,
        );
    return _Probe._(process, ready, stderrText);
  }

  String get stderrText => _stderr.toString();

  /// Closes the probe's stdin, which tells it to stop, and waits for it to
  /// exit so its runtime file cleanup has finished before the working
  /// directory is deleted.
  Future<void> stop() async {
    await _process.stdin.close();
    await _process.exitCode.timeout(
      _exitLimit,
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}

void main() {
  group('GENKIT_RUNTIME_ID on the v1 reflection server', () {
    late Directory probeDir;

    setUp(() async {
      probeDir = await Directory.systemTemp.createTemp('genkit_runtime_id_');
      await File(
        p.join(probeDir.path, 'pubspec.yaml'),
      ).writeAsString('name: probe_root\n');
    });

    tearDown(() async {
      await probeDir.delete(recursive: true);
    });

    test('the health check accepts the overridden id, not pid-port', () async {
      final probe = await _Probe.start(
        workingDirectory: probeDir,
        environment: {'GENKIT_RUNTIME_ID': 'probe-runtime'},
      );
      addTearDown(probe.stop);

      final ready = await probe.ready;
      final url = 'http://localhost:${ready['port']}';
      final runtimeFile = File(ready['runtimeFile'] as String);
      expect(
        p.isWithin(
          await probeDir.resolveSymbolicLinks(),
          await runtimeFile.resolveSymbolicLinks(),
        ),
        isTrue,
      );
      final runtime =
          jsonDecode(await runtimeFile.readAsString()) as Map<String, dynamic>;
      expect(runtime['id'], 'probe-runtime');

      final overridden = await http.get(
        Uri.parse('$url/api/__health?id=probe-runtime'),
      );
      expect(overridden.statusCode, 200);
      expect(overridden.body, 'OK');

      final pidPort = await http.get(
        Uri.parse('$url/api/__health?id=${ready['pid']}-${ready['port']}'),
      );
      expect(pidPort.statusCode, 503);
      expect(pidPort.body, 'Invalid runtime ID');

      await probe.stop();
      expect(await runtimeFile.exists(), isFalse, reason: probe.stderrText);
    });

    test('an empty override falls back to pid-port', () async {
      final probe = await _Probe.start(
        workingDirectory: probeDir,
        environment: {'GENKIT_RUNTIME_ID': ''},
      );
      addTearDown(probe.stop);

      final ready = await probe.ready;
      final url = 'http://localhost:${ready['port']}';
      final pidPort = '${ready['pid']}-${ready['port']}';
      final runtime =
          jsonDecode(await File(ready['runtimeFile'] as String).readAsString())
              as Map<String, dynamic>;
      expect(runtime['id'], pidPort);

      final response = await http.get(
        Uri.parse('$url/api/__health?id=$pidPort'),
      );
      expect(response.statusCode, 200);
      expect(response.body, 'OK');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
