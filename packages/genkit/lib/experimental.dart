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

/// Experimental Genkit APIs (agents, sessions, snapshots).
///
/// These APIs are NOT covered by the package's semantic-versioning stability
/// guarantees. They may change or be removed in any MINOR release without a
/// major version bump. Import them only if you accept that churn:
///
/// ```dart
/// import 'package:genkit/genkit.dart';
/// import 'package:genkit/experimental.dart';
///
/// final ai = Genkit(plugins: [googleAI()]);
/// final agent = ai.defineAgent(name: 'weather', prompt: '...');
/// ```
///
/// The browser-safe subset lives in `package:genkit/experimental_client.dart`
/// and the `dart:io` extras in `package:genkit/experimental_io.dart`.
///
/// To opt out of the analyzer warning on this import (you have accepted the
/// instability), add to your `analysis_options.yaml`:
///
/// ```yaml
/// analyzer:
///   errors:
///     experimental_member_use: ignore
/// ```
// Annotating this entry point (rather than the private `src/ai/agents/*`
// libraries) is what surfaces `experimental_member_use` to consumers: the
// analyzer flags the import directive of an @experimental library, but a
// library-level annotation does NOT propagate through this non-annotated
// re-export barrel to individual symbols. See experimental_client.dart.
@experimental
library;

import 'package:meta/meta.dart';

// Re-export the browser-safe client surface wholesale rather than duplicating
// its exports here. Keeping `experimental_client.dart` the single direct
// exporter of the shared agent-client / json-patch / remote-agent symbols
// avoids dartdoc ambiguous-reexport warnings, while this fuller server-side
// entry point still surfaces them transitively.
export 'experimental_client.dart';
export 'src/ai/agents/agent.dart'
    show
        Agent,
        AgentFn,
        AgentFnOptions,
        ClientTransform,
        SessionRunner,
        TurnContext,
        TurnResult,
        validateResumeAgainstHistory;
export 'src/ai/agents/session.dart'
    show
        InMemorySessionStore,
        Session,
        SessionError,
        SessionStore,
        SnapshotChangeNotifier,
        SnapshotMetadataReader,
        SnapshotMutator,
        generateUuidV4,
        getCurrentSession,
        reserveSnapshotId,
        runWithSession;
export 'src/experimental/agent_veneer.dart' show GenkitAgents;
