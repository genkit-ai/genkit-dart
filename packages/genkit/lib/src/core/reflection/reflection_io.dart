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

import '../../dev_config.dart';
import '../reflection.dart';
import '../registry.dart';
import 'reflection_v1.dart';
import 'reflection_v2.dart';

const String _v2ServerDefine = String.fromEnvironment(
  'GENKIT_REFLECTION_V2_SERVER',
);
const String _runtimeIdDefine = String.fromEnvironment('GENKIT_RUNTIME_ID');

/// Starts the reflection server the Developer UI talks to.
///
/// Both settings come from the process environment, falling back to the
/// `--dart-define` of the same name for an app whose environment no launcher
/// can set. An empty `GENKIT_REFLECTION_V2_SERVER` selects the v1 server, as an
/// unset one does.
ReflectionServerHandle startReflectionServer(Registry registry, {int? port}) {
  final v2ServerUrl = resolveDevConfig(
    io.Platform.environment['GENKIT_REFLECTION_V2_SERVER'],
    _v2ServerDefine,
  );
  final runtimeId =
      resolveDevConfig(
        io.Platform.environment['GENKIT_RUNTIME_ID'],
        _runtimeIdDefine,
      ) ??
      '';
  if (v2ServerUrl != null) {
    final server = ReflectionServerV2(
      registry,
      url: v2ServerUrl,
      runtimeId: runtimeId,
    );
    server.start();
    return ReflectionServerHandle(server.stop);
  } else {
    final server = ReflectionServerV1(registry, port: port);
    server.start();
    return ReflectionServerHandle(server.stop);
  }
}
