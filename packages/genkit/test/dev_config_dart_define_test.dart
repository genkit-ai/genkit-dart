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

/// Covers the dev-mode config that the `dart:io` platform files read.
///
/// A `--dart-define` is resolved when the code is compiled, so no test can set
/// one for itself. Each case therefore runs `test/fixtures/dev_config_probe.dart`
/// in a child process with the defines under test and an environment the test
/// controls, then reads back both the settings the probe resolved and which
/// fake Dev UI endpoints it reaches. A probe run with no `GENKIT_` variable in
/// its environment is the closest a host test gets to an app on an Android
/// device.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Bounds the probe's startup, which includes compiling the package.
const _readyLimit = Duration(seconds: 30);

/// Bounds a loopback round trip from a probe that is already running.
const _waitLimit = Duration(seconds: 10);

/// Fake Dev UI reflection endpoint: accepts the runtime's WebSocket and records
/// the JSON-RPC messages it sends.
class _FakeReflectionServer {
  _FakeReflectionServer._(this._server);

  final HttpServer _server;
  final List<Map<String, dynamic>> messages = [];

  static Future<_FakeReflectionServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeReflectionServer._(server);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) {
        if (data is String) {
          fake.messages.add(jsonDecode(data) as Map<String, dynamic>);
        }
      }, onError: (Object _) {});
    });
    return fake;
  }

  String get url => 'ws://127.0.0.1:${_server.port}';

  Map<String, dynamic>? _messageOf(String method) {
    for (final message in messages) {
      if (message['method'] == method) return message;
    }
    return null;
  }

  Future<Map<String, dynamic>> awaitMessage(String method) async {
    await _waitFor(
      () => _messageOf(method) != null,
      'no "$method" message reached $url',
    );
    return _messageOf(method)!;
  }

  Future<void> close() => _server.close(force: true);
}

/// Fake Dev UI telemetry endpoint: records the OTLP bodies posted to it.
class _FakeTelemetryServer {
  _FakeTelemetryServer._(this._server);

  final HttpServer _server;
  final List<String> otlpBodies = [];

  static Future<_FakeTelemetryServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeTelemetryServer._(server);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      if (request.uri.path == '/api/otlp') fake.otlpBodies.add(body);
      request.response.statusCode = 200;
      await request.response.close();
    });
    return fake;
  }

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> awaitOtlpBodyContaining(String needle) => _waitFor(
    () => otlpBodies.any((body) => body.contains(needle)),
    'no OTLP body containing "$needle" reached $url',
  );

  Future<void> close() => _server.close(force: true);
}

Future<void> _waitFor(bool Function() condition, String describeFailure) async {
  final deadline = DateTime.now().add(_waitLimit);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('$describeFailure within ${_waitLimit.inSeconds}s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// The probe app running in a child process.
class _Probe {
  _Probe._(this._process, this._ready, this._stderr);

  static const _readyPrefix = 'probe-ready ';

  final Process _process;
  final StringBuffer _stderr;
  final Future<Map<String, dynamic>> _ready;

  /// The settings the probe resolved, once it has built its `Genkit` instance
  /// and run a flow.
  Future<Map<String, dynamic>> get resolved => _ready;

  /// Starts the probe with [defines] passed as `--dart-define` and with the
  /// test runner's own environment minus every `GENKIT_*` entry, so a variable
  /// set around the suite cannot leak in and decide the outcome, then with
  /// [environment] applied on top. Everything else the Dart VM reads (PATH,
  /// HOME, PUB_CACHE, CI) is passed through untouched.
  ///
  /// The probe runs in [workingDirectory] so that a dev-mode run cannot write
  /// its runtime file into the repository.
  static Future<_Probe> start({
    required Directory workingDirectory,
    Map<String, String> defines = const {},
    Map<String, String> environment = const {},
  }) async {
    final fixture = File('test/fixtures/dev_config_probe.dart').absolute;
    expect(
      fixture.existsSync(),
      isTrue,
      reason:
          'probe fixture not found at ${fixture.path}; run this test from the '
          'genkit package root',
    );
    final process = await Process.start(
      Platform.resolvedExecutable,
      [
        'run',
        for (final define in defines.entries)
          '--define=${define.key}=${define.value}',
        fixture.path,
      ],
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
    final ready = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line.startsWith(_readyPrefix), orElse: () => '')
        .timeout(_readyLimit, onTimeout: () => '')
        .then((line) {
          if (line.isEmpty) {
            fail(
              'probe did not report ready within ${_readyLimit.inSeconds}s '
              '(it exited or hung):\n$stderrText',
            );
          }
          return jsonDecode(line.substring(_readyPrefix.length))
              as Map<String, dynamic>;
        });
    return _Probe._(process, ready, stderrText);
  }

  String get stderrText => _stderr.toString();

  void kill() => _process.kill();
}

void main() {
  group('dev-mode config from --dart-define on io', () {
    late _FakeReflectionServer reflection;
    late _FakeTelemetryServer telemetry;
    late Directory probeDir;

    setUp(() async {
      reflection = await _FakeReflectionServer.start();
      telemetry = await _FakeTelemetryServer.start();
      probeDir = await Directory.systemTemp.createTemp('genkit_dev_config_');
    });

    tearDown(() async {
      await reflection.close();
      await telemetry.close();
      await probeDir.delete(recursive: true);
    });

    test('an app with no environment registers and exports traces', () async {
      final probe = await _Probe.start(
        workingDirectory: probeDir,
        defines: {
          'GENKIT_ENV': 'dev',
          'GENKIT_REFLECTION_V2_SERVER': reflection.url,
          'GENKIT_RUNTIME_ID': 'probe-runtime',
          'GENKIT_TELEMETRY_SERVER': telemetry.url,
        },
      );
      addTearDown(probe.kill);

      expect(await probe.resolved, {
        'isDevEnv': true,
        'telemetryServer': telemetry.url,
      });
      final register = await reflection.awaitMessage('register');
      expect(
        (register['params'] as Map<String, dynamic>)['id'],
        'probe-runtime',
      );
      await telemetry.awaitOtlpBodyContaining('probeFlow');
    });

    test('an empty environment variable does not shadow the define', () async {
      final probe = await _Probe.start(
        workingDirectory: probeDir,
        defines: {
          'GENKIT_ENV': 'dev',
          'GENKIT_REFLECTION_V2_SERVER': reflection.url,
          'GENKIT_RUNTIME_ID': 'probe-runtime',
          'GENKIT_TELEMETRY_SERVER': telemetry.url,
        },
        environment: {
          'GENKIT_ENV': '',
          'GENKIT_REFLECTION_V2_SERVER': '',
          'GENKIT_RUNTIME_ID': '',
          'GENKIT_TELEMETRY_SERVER': '',
        },
      );
      addTearDown(probe.kill);

      expect(await probe.resolved, {
        'isDevEnv': true,
        'telemetryServer': telemetry.url,
      });
      final register = await reflection.awaitMessage('register');
      expect(
        (register['params'] as Map<String, dynamic>)['id'],
        'probe-runtime',
      );
      await telemetry.awaitOtlpBodyContaining('probeFlow');
    });

    test('an app with neither channel set stays out of dev mode', () async {
      final probe = await _Probe.start(workingDirectory: probeDir);
      addTearDown(probe.kill);

      expect(await probe.resolved, {
        'isDevEnv': false,
        'telemetryServer': null,
      });
    });

    test('the process environment wins over the define', () async {
      final envReflection = await _FakeReflectionServer.start();
      addTearDown(envReflection.close);

      final probe = await _Probe.start(
        workingDirectory: probeDir,
        defines: {
          'GENKIT_ENV': 'dev',
          'GENKIT_REFLECTION_V2_SERVER': reflection.url,
          'GENKIT_RUNTIME_ID': 'define-runtime',
          'GENKIT_TELEMETRY_SERVER': 'http://127.0.0.1:1/define',
        },
        environment: {
          'GENKIT_REFLECTION_V2_SERVER': envReflection.url,
          'GENKIT_RUNTIME_ID': 'env-runtime',
          'GENKIT_TELEMETRY_SERVER': telemetry.url,
        },
      );
      addTearDown(probe.kill);

      expect(await probe.resolved, {
        'isDevEnv': true,
        'telemetryServer': telemetry.url,
      });
      final register = await envReflection.awaitMessage('register');
      expect((register['params'] as Map<String, dynamic>)['id'], 'env-runtime');
      expect(reflection.messages, isEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
