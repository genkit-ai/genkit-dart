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

// Docker-free local telemetry stack for the OTel sample.
//
// Downloads the Jaeger and otelcol-contrib release binaries into a local cache
// (skipping the download if they already exist), writes a collector config,
// then spawns both processes:
//
//   app --OTLP:4317--> otelcol-contrib --OTLP:14317--> jaeger (UI :16686)
//                             \--debug--> collector.log (metrics + logs)
//
// Jaeger v2's binary is itself an OTel collector, so it ingests OTLP directly;
// the separate otelcol-contrib lets us also debug-log metrics/logs.
//
// Ported from gemini-cli's scripts/local_telemetry.js. Env overrides for
// locked-down networks:
//   JAEGER_BIN / OTEL_COLLECTOR_BIN         use an existing binary, skip download
//   JAEGER_VERSION / OTEL_COLLECTOR_VERSION pin a release tag instead of latest

import 'dart:convert';
import 'dart:io';

const jaegerUiPort = 16686;

// The collector owns the app-facing OTLP ports.
const collectorOtlpGrpcPort = 4317;
const collectorOtlpHttpPort = 4318;

// Jaeger v2 is itself an OTel collector whose OTLP receiver binds both gRPC and
// HTTP by default, so both must be moved off 4317/4318 to avoid colliding with
// the collector above.
const jaegerOtlpGrpcPort = 14317;
const jaegerOtlpHttpPort = 14318;

late final Directory otelDir;
late final Directory binDir;

Future<void> main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final projectRoot = scriptDir.parent; // testapps/otel_jaeger
  otelDir = Directory('${projectRoot.path}/.otel');
  binDir = Directory('${otelDir.path}/bin');
  binDir.createSync(recursive: true);

  final (:platform, :arch) = _platformArch();
  stdout.writeln('Platform: $platform/$arch');

  final otelcolPath = await _ensureBinary(
    executableName: 'otelcol-contrib',
    repo: 'open-telemetry/opentelemetry-collector-releases',
    binaryNameInArchive: 'otelcol-contrib',
    binEnvVar: 'OTEL_COLLECTOR_BIN',
    versionEnvVar: 'OTEL_COLLECTOR_VERSION',
    isJaeger: false,
    platform: platform,
    arch: arch,
  );

  final jaegerPath = await _ensureBinary(
    executableName: 'jaeger',
    repo: 'jaegertracing/jaeger',
    binaryNameInArchive: 'jaeger',
    binEnvVar: 'JAEGER_BIN',
    versionEnvVar: 'JAEGER_VERSION',
    isJaeger: true,
    platform: platform,
    arch: arch,
  );

  // Clean up any stale processes from a previous run. Match on the cached
  // binary paths so we only touch instances this script started.
  _pkill(otelcolPath);
  _pkill(jaegerPath);

  final configFile = File('${otelDir.path}/collector.yaml')
    ..writeAsStringSync(_collectorConfig());
  stdout.writeln('Wrote collector config: ${configFile.path}');

  final jaegerLog = File('${otelDir.path}/jaeger.log');
  final collectorLog = File('${otelDir.path}/collector.log');

  final processes = <Process>[];
  var shuttingDown = false;
  Future<void> shutdown([int code = 0]) async {
    if (shuttingDown) return;
    shuttingDown = true;
    stdout.writeln('\nShutting down...');
    for (final p in processes) {
      p.kill(ProcessSignal.sigterm);
    }
    exit(code);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  ProcessSignal.sigterm.watch().listen((_) => shutdown());

  // Start Jaeger. Its OTLP receiver is moved to 14317/14318 so it does not
  // squat on the app-facing 4317/4318 that the collector needs. UI on 16686.
  stdout.writeln('Starting Jaeger... logs: ${jaegerLog.path}');
  final jaeger = await _spawnLogged(jaegerPath, [
    '--set=receivers.otlp.protocols.grpc.endpoint=127.0.0.1:$jaegerOtlpGrpcPort',
    '--set=receivers.otlp.protocols.http.endpoint=127.0.0.1:$jaegerOtlpHttpPort',
  ], jaegerLog);
  processes.add(jaeger);
  if (!await _waitUntilReady(jaeger, jaegerUiPort, 'Jaeger', jaegerLog)) {
    await shutdown(1);
  }
  stdout.writeln('Jaeger is up.');

  // Start the collector (receives from the app on 4317/4318).
  stdout.writeln('Starting otelcol-contrib... logs: ${collectorLog.path}');
  final collector = await _spawnLogged(otelcolPath, [
    '--config',
    configFile.path,
  ], collectorLog);
  processes.add(collector);
  final collectorReady = await _waitUntilReady(
    collector,
    collectorOtlpHttpPort,
    'Collector',
    collectorLog,
  );
  if (!collectorReady) {
    await shutdown(1);
  }
  stdout.writeln('Collector is up.');

  stdout.writeln('''

Local telemetry environment is running.

  Jaeger UI:  http://localhost:$jaegerUiPort
  OTLP in:    http://localhost:$collectorOtlpHttpPort (http)  |  localhost:$collectorOtlpGrpcPort (grpc)
  Metrics:    tail -f ${collectorLog.path}

Run the sample in another terminal:
  export GEMINI_API_KEY=...
  dart run

Press Ctrl+C to stop.''');

  // Keep the process alive until a child exits or the user interrupts.
  await Future.any(processes.map((p) => p.exitCode));
  await shutdown();
}

({String platform, String arch}) _platformArch() {
  final platform = switch (Platform.operatingSystem) {
    'macos' => 'darwin',
    'windows' => 'windows',
    final other => other, // 'linux'
  };
  final raw = _archString();
  final arch = switch (raw) {
    'x86_64' || 'x64' || 'amd64' => 'amd64',
    'arm64' || 'aarch64' => 'arm64',
    final other => other,
  };
  return (platform: platform, arch: arch);
}

String _archString() {
  try {
    final r = Process.runSync('uname', ['-m']);
    if (r.exitCode == 0) return (r.stdout as String).trim();
  } catch (_) {
    // Fall through to the version banner.
  }
  final banner = Platform.version; // e.g. "... on \"macos_arm64\""
  if (banner.contains('arm64') || banner.contains('aarch64')) return 'arm64';
  return 'x64';
}

String _collectorConfig() =>
    '''
receivers:
  otlp:
    protocols:
      grpc:
        # 0.0.0.0 so both IPv4 and IPv6 loopback resolve (the app may dial
        # localhost as either).
        endpoint: "0.0.0.0:$collectorOtlpGrpcPort"
      http:
        endpoint: "0.0.0.0:$collectorOtlpHttpPort"
processors:
  batch:
    timeout: 1s
exporters:
  otlp:
    endpoint: "127.0.0.1:$jaegerOtlpGrpcPort"
    tls:
      insecure: true
  debug:
    verbosity: detailed
service:
  telemetry:
    logs:
      level: "info"
    metrics:
      level: "none"
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
''';

/// Ensures a binary exists in [binDir], downloading + extracting from the
/// latest (or [versionEnvVar]-pinned) GitHub release when missing.
Future<String> _ensureBinary({
  required String executableName,
  required String repo,
  required String binaryNameInArchive,
  required String binEnvVar,
  required String versionEnvVar,
  required bool isJaeger,
  required String platform,
  required String arch,
}) async {
  final override = Platform.environment[binEnvVar];
  if (override != null && override.isNotEmpty) {
    stdout.writeln('Using $executableName from $binEnvVar=$override');
    return override;
  }

  final target = File('${binDir.path}/$executableName');
  if (target.existsSync()) {
    stdout.writeln('$executableName already cached: ${target.path}');
    return target.path;
  }

  stdout.writeln('$executableName not found; resolving release from $repo...');
  final ext = platform == 'windows' ? 'zip' : 'tar.gz';
  final pinned = Platform.environment[versionEnvVar];

  final (:downloadUrl, :assetName) = isJaeger
      ? _resolveJaegerAsset(repo, platform, arch, pinned)
      : _resolveOtelcolAsset(repo, platform, arch, ext, pinned);

  final tmp = Directory.systemTemp.createTempSync('genkit-otel-');
  try {
    final archivePath = '${tmp.path}/$assetName';
    stdout.writeln('Downloading $assetName...');
    _curlDownload(downloadUrl, archivePath);

    stdout.writeln('Extracting...');
    _extract(archivePath, tmp.path);

    final binName = platform == 'windows'
        ? '$binaryNameInArchive.exe'
        : binaryNameInArchive;
    final found = _findFile(tmp, binName);
    if (found == null) {
      throw StateError('Binary "$binName" not found in $assetName');
    }
    found.copySync(target.path);
    if (platform != 'windows') {
      Process.runSync('chmod', ['755', target.path]);
    }
    stdout.writeln('Installed $executableName: ${target.path}');
    return target.path;
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// otelcol assets are exact-named: `otelcol-contrib_<ver>_<plat>_<arch>.<ext>`.
({String downloadUrl, String assetName}) _resolveOtelcolAsset(
  String repo,
  String platform,
  String arch,
  String ext,
  String? pinned,
) {
  final release = pinned != null
      ? _getJson('https://api.github.com/repos/$repo/releases/tags/$pinned')
      : _getJson('https://api.github.com/repos/$repo/releases/latest');
  final tag = release['tag_name'] as String;
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  final assetName = 'otelcol-contrib_${version}_${platform}_$arch.$ext';
  final asset = (release['assets'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere(
        (a) => a['name'] == assetName,
        orElse: () => throw StateError('Asset not found in $tag: $assetName'),
      );
  return (
    downloadUrl: asset['browser_download_url'] as String,
    assetName: assetName,
  );
}

/// Jaeger v2 assets are named `jaeger-2.x.y-<plat>-<arch>.tar.gz`; pick the
/// newest non-prerelease release that has a matching asset.
({String downloadUrl, String assetName}) _resolveJaegerAsset(
  String repo,
  String platform,
  String arch,
  String? pinned,
) {
  final suffix = platform == 'windows'
      ? '-$platform-$arch.zip'
      : '-$platform-$arch.tar.gz';

  final releases = pinned != null
      ? [_getJson('https://api.github.com/repos/$repo/releases/tags/$pinned')]
      : (_getJsonList('https://api.github.com/repos/$repo/releases')
            .where((r) => r['prerelease'] != true)
            .where((r) => (r['tag_name'] as String).startsWith('v'))
            .toList()
          ..sort(
            (a, b) => _compareSemverTag(
              b['tag_name'] as String,
              a['tag_name'] as String,
            ),
          ));

  for (final r in releases) {
    final assets = (r['assets'] as List).cast<Map<String, dynamic>>();
    for (final a in assets) {
      final name = a['name'] as String;
      if (name.startsWith('jaeger-2.') && name.endsWith(suffix)) {
        return (
          downloadUrl: a['browser_download_url'] as String,
          assetName: name,
        );
      }
    }
  }
  throw StateError('No Jaeger v2 asset for $platform/$arch');
}

int _compareSemverTag(String a, String b) {
  List<int> parts(String t) => t
      .replaceFirst('v', '')
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parts(a), pb = parts(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

Map<String, dynamic> _getJson(String url) =>
    jsonDecode(_curlText(url)) as Map<String, dynamic>;

List<Map<String, dynamic>> _getJsonList(String url) =>
    (jsonDecode(_curlText(url)) as List).cast<Map<String, dynamic>>();

String _curlText(String url) {
  final r = Process.runSync('curl', [
    '-sL',
    '-H',
    'User-Agent: genkit-dart-telemetry',
    url,
  ]);
  if (r.exitCode != 0) {
    throw StateError('curl failed for $url: ${r.stderr}');
  }
  return r.stdout as String;
}

void _curlDownload(String url, String dest) {
  final r = Process.runSync('curl', ['-fL', '-sS', '-o', dest, url]);
  if (r.exitCode != 0) {
    throw StateError('Download failed for $url: ${r.stderr}');
  }
}

void _extract(String archivePath, String destDir) {
  final ProcessResult r;
  if (archivePath.endsWith('.zip')) {
    r = Process.runSync('unzip', ['-o', archivePath, '-d', destDir]);
  } else {
    r = Process.runSync('tar', ['-xzf', archivePath, '-C', destDir]);
  }
  if (r.exitCode != 0) {
    throw StateError('Extraction failed: ${r.stderr}');
  }
}

File? _findFile(Directory dir, String name) {
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.uri.pathSegments.last == name) return entity;
  }
  return null;
}

void _pkill(String pattern) {
  try {
    Process.runSync('pkill', ['-f', pattern]);
  } catch (_) {
    // pkill may be missing or match nothing; ignore.
  }
}

Future<Process> _spawnLogged(
  String executable,
  List<String> args,
  File logFile,
) async {
  final sink = logFile.openWrite(mode: FileMode.append);
  final process = await Process.start(executable, args);
  process.stdout.listen(sink.add);
  process.stderr.listen(sink.add);
  return process;
}

/// Waits until [process] is serving on [port], or fails fast if the process
/// exits first (e.g. a port-bind error). On failure, dumps the log tail.
Future<bool> _waitUntilReady(
  Process process,
  int port,
  String name,
  File logFile,
) async {
  // Race the port coming up against the process dying. A false-positive port
  // check (another process already holding the port) is avoided because a dead
  // child resolves exitCode first here.
  final exited = process.exitCode.then((code) => code);
  final ready = _waitForPort(port).then((ok) => ok ? null : -1);
  final result = await Future.any([exited, ready]);

  if (result == null) return true; // port became available, process alive

  stderr.writeln('$name failed to start (port $port).');
  final log = logFile.existsSync() ? logFile.readAsStringSync() : '';
  final tail = log.length > 2000 ? log.substring(log.length - 2000) : log;
  stderr.writeln(tail);
  return false;
}

Future<bool> _waitForPort(int port, {int timeoutSeconds = 30}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(
        'localhost',
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  return false;
}
