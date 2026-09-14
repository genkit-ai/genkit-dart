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

import 'dev_config.dart';

String? getConfigVar(String name) => io.Platform.environment[name];

int getPid() => io.pid;

String getPlatformLanguageVersion() => io.Platform.version;

const String _devEnvDefine = String.fromEnvironment('GENKIT_ENV');

/// Whether Genkit runs in dev mode, from `GENKIT_ENV` in the process
/// environment, falling back to the `--dart-define` of the same name for an app
/// whose environment no launcher can set.
final bool isDevEnv =
    resolveDevConfig(io.Platform.environment['GENKIT_ENV'], _devEnvDefine) ==
    'dev';
