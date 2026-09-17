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

/// Browser-safe experimental Genkit client APIs (agent client, snapshots).
///
/// These APIs are NOT covered by the package's semantic-versioning stability
/// guarantees. They may change or be removed in any MINOR release without a
/// major version bump. This is the client counterpart to
/// `package:genkit/client.dart`:
///
/// ```dart
/// import 'package:genkit/client.dart';
/// import 'package:genkit/experimental_client.dart';
/// ```
///
/// This is the canonical home for the browser-safe agent-client symbols. They
/// are also re-exported from `package:genkit/experimental.dart`; naming this
/// library (below) is what breaks the dartdoc canonicalization tie so the docs
/// land here rather than emitting ambiguous-reexport warnings.
///
/// To opt out of the analyzer warning on this import (you have accepted the
/// instability), add to your `analysis_options.yaml`:
///
/// ```yaml
/// analyzer:
///   errors:
///     experimental_member_use: ignore
/// ```
// `@experimental` here is what surfaces `experimental_member_use` to consumers:
// the analyzer flags the import directive of an @experimental library. We mark
// this entry point rather than the private `src/ai/agents/*` libraries because a
// library-level annotation does NOT propagate through a re-export barrel to the
// individual symbols (the verifier reads each element's own metadata, which does
// not include its library's annotation).
//
// Named (rather than unnamed) so the library name embeds the package name.
// Dartdoc canonicalization gives a decisive score boost to that, making this
// the canonical home for the agent_core / json_patch / remote_agent libraries
// re-exported by `experimental.dart`. This library-level tie is what produces
// the ambiguous-reexport warnings; `{@canonicalFor}` only disambiguates
// individual symbols, not the private-library reexport, so it does not help.
@experimental
// ignore: unnecessary_library_name
library genkit.experimental.client;

import 'package:meta/meta.dart';

// Note: the core CancellationController / CancellationToken types are
// deliberately not re-exported here. They are stable core types available from
// `package:genkit/genkit.dart`; surfacing them through this experimental agent
// client would make it compete with the `genkit` library for their canonical
// docs location.
export 'src/ai/agents/agent_core.dart'
    show
        AgentApi,
        AgentChat,
        AgentChunk,
        AgentError,
        AgentInterrupt,
        AgentResponse,
        AgentSnapshot,
        AgentTransport,
        AgentTurn,
        DetachedTask,
        TurnStream;
export 'src/ai/agents/json_patch.dart'
    show JsonPatch, JsonPatchOperationMap, applyPatch, diff;
export 'src/ai/agents/remote_agent.dart' show HeadersResolver, remoteAgent;
