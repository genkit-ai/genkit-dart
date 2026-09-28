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

import '../reflection.dart';
import '../registry.dart';
import 'reflection_config.dart';
import 'reflection_v2.dart';

const _v2ServerEnvKey = 'GENKIT_REFLECTION_V2_SERVER';
const _runtimeIdEnvKey = 'GENKIT_RUNTIME_ID';
const _secretEnvKey = 'GENKIT_REFLECTION_SECRET_TOKEN';
const _enabledEnvKey = 'GENKIT_REFLECTION_ENABLED';
const _envKey = 'GENKIT_ENV';

const _v2ServerUrl = String.fromEnvironment(_v2ServerEnvKey, defaultValue: '');
const _secret = String.fromEnvironment(_secretEnvKey, defaultValue: '');
const _enabled = String.fromEnvironment(_enabledEnvKey, defaultValue: '');
const _env = String.fromEnvironment(_envKey, defaultValue: '');

/// The web build has no process environment, so every setting comes from
/// `--dart-define`. Host and port are irrelevant: there are no sockets to
/// listen on, so only v2 is ever available.
ReflectionConfig _resolve({int? port}) => resolveReflectionConfig(
  enabled: _enabled,
  env: _env,
  v2ServerUrl: _v2ServerUrl,
  secret: _secret,
  optionPort: port,
);

/// Whether the environment asks for a reflection server.
///
/// Throws [ReflectionConfigException] when a setting is invalid.
bool reflectionConfigured({int? port}) =>
    _resolve(port: port) is ReflectionV2Config;

/// Whether `GENKIT_REFLECTION_ENABLED=false` switched reflection off. Beats
/// an explicit `Genkit(isDevEnv: true)`.
bool reflectionDisabled() => parseReflectionEnabled(_enabled) == false;

ReflectionServerHandle startReflectionServer(Registry registry, {int? port}) {
  const runtimeId = String.fromEnvironment(_runtimeIdEnvKey, defaultValue: '');
  if (_resolve(port: port) is ReflectionDisabled) {
    return ReflectionServerHandle(() async {});
  }
  if (_v2ServerUrl.isEmpty) {
    throw UnimplementedError(
      '$_v2ServerEnvKey environment variable is not set',
    );
  }
  final server = ReflectionServerV2(
    registry,
    url: _v2ServerUrl,
    runtimeId: runtimeId,
    secret: _secret.isEmpty ? null : _secret,
  );
  server.start();
  return ReflectionServerHandle(server.stop);
}
