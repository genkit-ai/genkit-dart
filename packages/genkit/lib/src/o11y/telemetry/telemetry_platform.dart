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

/// Platform-specific resolution of the Genkit telemetry server URL.
///
/// Reads `GENKIT_TELEMETRY_SERVER` from the process environment on IO targets
/// and from the compile-time environment on web; returns `null` elsewhere.
library;

export 'telemetry_stub.dart'
    if (dart.library.io) 'telemetry_io.dart'
    if (dart.library.js_interop) 'telemetry_web.dart';
