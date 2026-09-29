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

import 'dart:convert';

/// Header carrying the reflection secret on v1 requests.
const String reflectionSecretHeader = 'x-genkit-reflection-secret';

/// Interface used when none is configured.
const String defaultReflectionHost = '127.0.0.1';

/// First port tried when none is pinned.
const int defaultReflectionPort = 3100;

/// JSON-RPC code the CLI returns when a v2 `register` fails auth. Terminal:
/// the secret will not change, so a runtime that sees it must stop
/// reconnecting.
const int reflectionAuthErrorCode = -32001;

/// Programmatic port value meaning "let the OS pick". Code cannot use 0 for
/// this because 0 reads as "unset" in other runtimes; the environment spells
/// the same thing `GENKIT_REFLECTION_PORT=0`.
const int reflectionPortAuto = -1;

/// How the reflection API runs, if at all.
///
/// [ReflectionDisabled] and [ReflectionOff] differ by who decided.
/// [ReflectionDisabled] is an explicit kill switch
/// (`GENKIT_REFLECTION_ENABLED=false`) that even an explicit dev start
/// honours. [ReflectionOff] only means nothing asked for a server, so an
/// explicit start still runs one.
sealed class ReflectionConfig {
  const ReflectionConfig();

  /// Whether a server should run at all.
  bool get enabled => this is ReflectionServerConfig;
}

/// Explicitly switched off, honoured everywhere.
final class ReflectionDisabled extends ReflectionConfig {
  const ReflectionDisabled();
}

/// Nothing asked for a server.
final class ReflectionOff extends ReflectionConfig {
  const ReflectionOff();
}

/// How a running reflection API connects: dial out (v2) or listen (v1).
sealed class ReflectionServerConfig extends ReflectionConfig {
  const ReflectionServerConfig();

  String? get secret;
}

/// Dials out to the Developer UI over a WebSocket and listens on nothing.
final class ReflectionV2Config extends ReflectionServerConfig {
  const ReflectionV2Config({required this.url, this.secret});

  final String url;
  @override
  final String? secret;
}

/// Listens for the Developer UI on a socket.
final class ReflectionV1Config extends ReflectionServerConfig {
  const ReflectionV1Config({
    required this.host,
    required this.port,
    required this.pinned,
    this.secret,
  });

  final String host;

  /// Bound exactly when [pinned] (0 lets the OS pick); otherwise the first
  /// port of an upward probe.
  final int port;

  /// False only when nobody chose a port.
  final bool pinned;
  @override
  final String? secret;
}

/// Thrown when a reflection setting is invalid.
class ReflectionConfigException implements Exception {
  ReflectionConfigException(this.message);

  final String message;

  @override
  String toString() => 'ReflectionConfigException: $message';
}

/// Resolves how the reflection API should run, from already-read settings.
///
/// Whether it runs:
/// - [enabled] `'false'` turns it off, even under dev.
/// - [enabled] `'true'` turns it on in any environment.
/// - Unset, it runs only when [env] is `'dev'`, as it always has.
///
/// How it runs is [resolveReflectionServerConfig]. Host and port are settings,
/// not on-switches: a stray value in a production env does not expose the
/// API, and is not even parsed while reflection is off.
///
/// [optionPort] is validated even when unused so a bad value fails early.
///
/// Values are passed in rather than read here because Dart reaches the
/// environment through two channels (the process environment and
/// `--dart-define`), and the web build has only the latter.
ReflectionConfig resolveReflectionConfig({
  String? enabled,
  String? env,
  String? v2ServerUrl,
  String? host,
  String? port,
  String? secret,
  int? optionPort,
}) {
  resolveReflectionPort(null, optionPort);
  final on = parseReflectionEnabled(enabled);
  if (on == false) return const ReflectionDisabled();
  if (on == null && env != 'dev') return const ReflectionOff();
  return resolveReflectionServerConfig(
    v2ServerUrl: v2ServerUrl,
    host: host,
    port: port,
    secret: secret,
    optionPort: optionPort,
  );
}

/// The "how it runs" half of [resolveReflectionConfig], without the on/off
/// decision. For callers that already decided to run a server, such as an
/// explicit `Genkit(isDevEnv: true)`.
///
/// The environment port beats [optionPort] on purpose: whoever set the
/// variable is typically the supervisor that already published that port.
ReflectionServerConfig resolveReflectionServerConfig({
  String? v2ServerUrl,
  String? host,
  String? port,
  String? secret,
  int? optionPort,
}) {
  final codePort = resolveReflectionPort(null, optionPort);
  final resolvedSecret = (secret == null || secret.isEmpty) ? null : secret;
  if (v2ServerUrl != null && v2ServerUrl.isNotEmpty) {
    return ReflectionV2Config(url: v2ServerUrl, secret: resolvedSecret);
  }
  final envPort = _parsePort(port);
  final resolvedPort = envPort != null
      ? (port: envPort, pinned: true)
      : codePort;
  return ReflectionV1Config(
    host: (host == null || host.isEmpty) ? defaultReflectionHost : host,
    port: resolvedPort.port,
    pinned: resolvedPort.pinned,
    secret: resolvedSecret,
  );
}

/// Resolves the v1 port. Whoever chose a port, the environment or the code,
/// gets exactly that port; only an unchosen port is probed.
///
/// Code values: null or 0 is unset, [reflectionPortAuto] (-1) lets the OS
/// pick, 1..65535 is exact. Anything else throws.
({int port, bool pinned}) resolveReflectionPort(int? envPort, int? optionPort) {
  if (envPort != null) return (port: envPort, pinned: true);
  if (optionPort == null || optionPort == 0) {
    return (port: defaultReflectionPort, pinned: false);
  }
  if (optionPort == reflectionPortAuto) return (port: 0, pinned: true);
  if (optionPort < 1 || optionPort > 65535) {
    throw ReflectionConfigException(
      'reflectionPort must be -1 (OS-assigned) or an integer between 1 and '
      '65535, got $optionPort.',
    );
  }
  return (port: optionPort, pinned: true);
}

/// Parses `GENKIT_REFLECTION_ENABLED`: `true`, `false`, or unset (empty counts
/// as unset). Anything else throws.
bool? parseReflectionEnabled(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  throw ReflectionConfigException(
    'GENKIT_REFLECTION_ENABLED must be "true" or "false", got "$raw".',
  );
}

final _digitsOnly = RegExp(r'^[0-9]+$');

/// Parses `GENKIT_REFLECTION_PORT`, throwing on anything invalid.
///
/// A typo in a deployment config should fail loudly rather than quietly fall
/// back to probing some other port.
int? _parsePort(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // ASCII digits only: int.tryParse would also accept '0x10', '+7' and
  // surrounding whitespace, which are more likely typos than intent.
  final port = _digitsOnly.hasMatch(raw) ? int.tryParse(raw) : null;
  if (port == null || port < 0 || port > 65535) {
    throw ReflectionConfigException(
      'GENKIT_REFLECTION_PORT must be an integer between 0 and 65535, '
      'got "$raw".',
    );
  }
  return port;
}

/// Host to advertise in the runtime discovery file for a server bound to
/// [host]. A wildcard bind is reachable on loopback, and `0.0.0.0` is not a
/// valid destination everywhere, so it is advertised as `127.0.0.1`. IPv6
/// literals are bracketed for use in a URL.
String advertisedReflectionHost(String host) {
  if (host == '0.0.0.0' || host == '::' || host == '[::]') return '127.0.0.1';
  return host.contains(':') && !host.startsWith('[') ? '[$host]' : host;
}

/// Whether a host is unreachable from other machines.
bool isLoopbackHost(String host) =>
    host == 'localhost' ||
    host == '::1' ||
    host == '[::1]' ||
    host.startsWith('127.');

/// Compares secrets in constant time.
///
/// Every byte of the longer input is examined regardless of where the first
/// difference is, so timing does not reveal how much of a wrong secret
/// matched. The package has no crypto dependency, hence the manual loop.
bool secretsEqual(String a, String b) {
  final ba = utf8.encode(a);
  final bb = utf8.encode(b);
  var diff = ba.length ^ bb.length;
  final len = ba.length > bb.length ? ba.length : bb.length;
  for (var i = 0; i < len; i++) {
    diff |= (i < ba.length ? ba[i] : 0) ^ (i < bb.length ? bb[i] : 0);
  }
  return diff == 0;
}
