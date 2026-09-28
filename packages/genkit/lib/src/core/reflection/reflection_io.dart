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

import 'dart:io' as io;

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../../dev_config.dart';
import '../reflection.dart';
import '../registry.dart';
import 'reflection_config.dart';
import 'reflection_v1.dart';
import 'reflection_v2.dart';

const String _v2ServerKey = 'GENKIT_REFLECTION_V2_SERVER';
const String _runtimeIdKey = 'GENKIT_RUNTIME_ID';
const String _enabledKey = 'GENKIT_REFLECTION_ENABLED';
const String _hostKey = 'GENKIT_REFLECTION_HOST';
const String _portKey = 'GENKIT_REFLECTION_PORT';
const String _secretKey = 'GENKIT_REFLECTION_SECRET_TOKEN';
const String _envKey = 'GENKIT_ENV';

const String _v2ServerDefine = String.fromEnvironment(_v2ServerKey);
const String _runtimeIdDefine = String.fromEnvironment(_runtimeIdKey);
const String _enabledDefine = String.fromEnvironment(_enabledKey);
const String _hostDefine = String.fromEnvironment(_hostKey);
const String _portDefine = String.fromEnvironment(_portKey);
const String _secretDefine = String.fromEnvironment(_secretKey);
const String _envDefine = String.fromEnvironment(_envKey);

final _logger = Logger('genkit.reflection');

/// How the Developer UI reaches a running app, or [none] when it cannot.
enum ReflectionTransport {
  /// Dials out to the Developer UI over a WebSocket and listens on nothing.
  v2,

  /// Listens for the Developer UI on a loopback socket.
  v1,

  /// No reflection server runs.
  none,
}

/// Selects the reflection transport for the current platform.
///
/// The v1 server serves `runAction` over a socket. Mobile loopback is shared
/// between installed apps, and a host Developer UI cannot reach a device's
/// loopback in any case, so v1 is refused there even when a host or port is
/// configured.
@visibleForTesting
ReflectionTransport reflectionTransportFor({
  required ReflectionConfig config,
  required bool isMobile,
}) {
  return switch (config) {
    ReflectionDisabled() || ReflectionOff() => ReflectionTransport.none,
    ReflectionV2Config() => ReflectionTransport.v2,
    ReflectionV1Config() =>
      isMobile ? ReflectionTransport.none : ReflectionTransport.v1,
  };
}

/// Whether the environment asks for a reflection server.
///
/// Mobile is excluded for the same reason [reflectionTransportFor] refuses v1
/// there, so `GENKIT_REFLECTION_ENABLED=true` on a device does not open a
/// socket. [port] is the programmatic port, validated here so a bad value
/// fails at construction even when reflection is off.
///
/// Throws [ReflectionConfigException] when a setting is invalid.
bool reflectionConfigured({int? port}) {
  final isMobile = io.Platform.isAndroid || io.Platform.isIOS;
  return reflectionTransportFor(
        config: resolveIoReflectionConfig(optionPort: port),
        isMobile: isMobile,
      ) !=
      ReflectionTransport.none;
}

/// Whether `GENKIT_REFLECTION_ENABLED=false` switched reflection off. Beats
/// an explicit `Genkit(isDevEnv: true)`.
bool reflectionDisabled() =>
    parseReflectionEnabled(_read(_enabledKey, _enabledDefine)) == false;

/// Reads the reflection settings from the environment and the `--dart-define`
/// fallback, then resolves them.
///
/// Throws [ReflectionConfigException] when a setting is invalid.
ReflectionConfig resolveIoReflectionConfig({int? optionPort}) {
  return resolveReflectionConfig(
    enabled: _read(_enabledKey, _enabledDefine),
    env: _read(_envKey, _envDefine),
    v2ServerUrl: _read(_v2ServerKey, _v2ServerDefine),
    host: _read(_hostKey, _hostDefine),
    port: _read(_portKey, _portDefine),
    secret: _read(_secretKey, _secretDefine),
    optionPort: optionPort,
  );
}

String? _read(String key, String define) =>
    resolveDevConfig(io.Platform.environment[key], define);

/// Starts the reflection server the Developer UI talks to.
///
/// Settings come from the process environment, falling back to the
/// `--dart-define` of the same name for an app whose environment no launcher
/// can set. On mobile only v2 is started.
ReflectionServerHandle startReflectionServer(Registry registry, {int? port}) {
  final resolved = resolveIoReflectionConfig(optionPort: port);
  // Reaching here is itself a request for a server, so `off` (nothing in the
  // environment asked for one) still starts, with the environment's host, port
  // and v2 settings. That is how an explicit `Genkit(isDevEnv: true)` works
  // without GENKIT_ENV set. `disabled` is a kill switch and is still honoured.
  final config = resolved is ReflectionOff
      ? resolveReflectionServerConfig(
          v2ServerUrl: _read(_v2ServerKey, _v2ServerDefine),
          host: _read(_hostKey, _hostDefine),
          port: _read(_portKey, _portDefine),
          secret: _read(_secretKey, _secretDefine),
          optionPort: port,
        )
      : resolved;
  final runtimeId =
      resolveDevConfig(
        io.Platform.environment[_runtimeIdKey],
        _runtimeIdDefine,
      ) ??
      '';
  final isMobile = io.Platform.isAndroid || io.Platform.isIOS;
  switch (reflectionTransportFor(config: config, isMobile: isMobile)) {
    case ReflectionTransport.v2:
      final v2 = config as ReflectionV2Config;
      final server = ReflectionServerV2(
        registry,
        url: v2.url,
        runtimeId: runtimeId,
        secret: v2.secret,
      );
      server.start();
      return ReflectionServerHandle(server.stop);
    case ReflectionTransport.v1:
      final v1 = config as ReflectionV1Config;
      if (v1.secret == null && !isLoopbackHost(v1.host)) {
        _logger.warning(
          'Reflection API is listening on ${v1.host} without authentication. '
          'Anyone who can reach this port can run any registered action. Set '
          '$_secretKey, or front it with your own auth.',
        );
      }
      final server = ReflectionServerV1(
        registry,
        host: v1.host,
        port: v1.pinned ? v1.port : null,
        probeFrom: v1.port,
        secret: v1.secret,
      );
      server.start();
      return ReflectionServerHandle(server.stop);
    case ReflectionTransport.none:
      if (isMobile && config is ReflectionV1Config) {
        _logger.warning(
          'No reflection server started: the socket server this would '
          'otherwise start is not safe on a mobile device and the Developer '
          'UI could not reach it. Set $_v2ServerKey instead.',
        );
      }
      return ReflectionServerHandle(() async {});
  }
}
