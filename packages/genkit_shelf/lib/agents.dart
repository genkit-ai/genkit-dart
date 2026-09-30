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

/// Serves Genkit agents over HTTP with [GenkitRouter].
///
/// ```dart
/// import 'package:genkit_shelf/agents.dart';
/// import 'package:genkit_shelf/genkit_shelf.dart';
///
/// final genkit = GenkitRouter()
///   ..addAgent(weatherAgent)
///   ..addAgent(bankingAgent, contextProvider: bearerAuth);
///
/// await genkit.serve();
/// ```
///
/// This builds on Genkit's experimental agent surface. Like
/// `package:genkit/experimental.dart`, these APIs are NOT covered by
/// semantic-versioning stability guarantees and may change or be removed in any
/// MINOR release without a major version bump.
///
/// It is deliberately not re-exported from
/// `package:genkit_shelf/genkit_shelf.dart`; import it directly.
///
/// To opt out of the analyzer warning on this import (you have accepted the
/// instability), add to your `analysis_options.yaml`:
///
/// ```yaml
/// analyzer:
///   errors:
///     experimental_member_use: ignore
/// ```
// `@experimental` on the library is what surfaces `experimental_member_use` on
// the import directive; the annotation does not propagate to re-exported
// symbols, which is why this library must not be re-exported from a stable
// barrel.
@experimental
library;

import 'package:meta/meta.dart';

import 'genkit_shelf.dart';

export 'src/agents.dart' show GenkitRouterAgents;
