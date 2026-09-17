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
import 'reflection_v1.dart';
import 'reflection_v2.dart';

const String _v2ServerKey = 'GENKIT_REFLECTION_V2_SERVER';
const String _runtimeIdKey = 'GENKIT_RUNTIME_ID';

const String _v2ServerDefine = String.fromEnvironment(_v2ServerKey);
const String _runtimeIdDefine = String.fromEnvironment(_runtimeIdKey);

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
/// The v1 server serves unauthenticated `runAction` over a loopback socket.
/// Mobile loopback is shared between installed apps, and a host Developer UI
/// cannot reach a device's loopback in any case, so v1 is refused there.
@visibleForTesting
ReflectionTransport reflectionTransportFor({
  required String? v2ServerUrl,
  required bool isMobile,
}) {
  if (v2ServerUrl != null) return ReflectionTransport.v2;
  return isMobile ? ReflectionTransport.none : ReflectionTransport.v1;
}

/// Starts the reflection server the Developer UI talks to.
///
/// Both settings come from the process environment, falling back to the
/// `--dart-define` of the same name for an app whose environment no launcher
/// can set. An empty `GENKIT_REFLECTION_V2_SERVER` selects the v1 server, as an
/// unset one does, except on mobile where no server is started.
ReflectionServerHandle startReflectionServer(Registry registry, {int? port}) {
  final v2ServerUrl = resolveDevConfig(
    io.Platform.environment[_v2ServerKey],
    _v2ServerDefine,
  );
  final runtimeId =
      resolveDevConfig(
        io.Platform.environment[_runtimeIdKey],
        _runtimeIdDefine,
      ) ??
      '';
  switch (reflectionTransportFor(
    v2ServerUrl: v2ServerUrl,
    isMobile: io.Platform.isAndroid || io.Platform.isIOS,
  )) {
    case ReflectionTransport.v2:
      final server = ReflectionServerV2(
        registry,
        url: v2ServerUrl!,
        runtimeId: runtimeId,
      );
      server.start();
      return ReflectionServerHandle(server.stop);
    case ReflectionTransport.v1:
      final server = ReflectionServerV1(registry, port: port);
      server.start();
      return ReflectionServerHandle(server.stop);
    case ReflectionTransport.none:
      _logger.warning(
        'Dev mode is on but $_v2ServerKey is not set. No reflection server '
        'started: the loopback server this would otherwise start is not safe '
        'on a mobile device and the Developer UI could not reach it.',
      );
      return ReflectionServerHandle(() async {});
  }
}
