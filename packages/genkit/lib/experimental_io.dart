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

/// Native (`dart:io`) extensions to the experimental Genkit agent surface.
///
/// These APIs are NOT covered by the package's semantic-versioning stability
/// guarantees. They may change or be removed in any MINOR release without a
/// major version bump. Because they depend on `dart:io` they do not work on the
/// web; import them only from server / CLI / desktop / mobile targets:
///
/// ```dart
/// import 'package:genkit/experimental.dart';
/// import 'package:genkit/experimental_io.dart';
/// ```
library;

export 'src/ai/agents/session_io.dart' show FileSessionStore;
