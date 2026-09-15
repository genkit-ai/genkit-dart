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
library;

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
        CancellationController,
        CancellationToken,
        DetachedTask,
        TurnStream;
export 'src/ai/agents/json_patch.dart'
    show JsonPatch, JsonPatchOperationMap, applyPatch, diff;
export 'src/ai/agents/remote_agent.dart' show HeadersResolver, remoteAgent;
