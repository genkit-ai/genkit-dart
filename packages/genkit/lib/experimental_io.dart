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
///
/// To opt out of the analyzer warning on this import (you have accepted the
/// instability), add to your `analysis_options.yaml`:
///
/// ```yaml
/// analyzer:
///   errors:
///     experimental_member_use: ignore
/// ```
// Annotating this entry point is what surfaces `experimental_member_use` to
// consumers: the analyzer flags the import directive of an @experimental
// library. See experimental_client.dart for why we mark the barrel rather than
// the private `src/ai/agents/*` libraries.
@experimental
library;

import 'package:meta/meta.dart';

export 'src/ai/agents/session_io.dart' show FileSessionStore;
