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

const String _telemetryServerKey = 'GENKIT_TELEMETRY_SERVER';
const String _telemetryServerDefine = String.fromEnvironment(
  _telemetryServerKey,
);

/// The Genkit telemetry server base URL from `GENKIT_TELEMETRY_SERVER` in the
/// process environment, falling back to the `--dart-define` of the same name,
/// or `null` when neither is set.
///
/// An empty value is treated as unset (matching the web implementation) so the
/// same configuration produces the same instrumentation decision across
/// platforms.
String? genkitTelemetryServerUrl() => resolveDevConfig(
  io.Platform.environment[_telemetryServerKey],
  _telemetryServerDefine,
);
