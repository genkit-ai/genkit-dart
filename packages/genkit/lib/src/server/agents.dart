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

import '../ai/agents/agent.dart';
import '../experimental_types.dart';
import 'http.dart';
import 'router.dart';

/// Agent support for [GenkitRouter].
///
/// Lives in an extension (exported only from the experimental
/// `package:genkit/experimental_io.dart`) so the stable [GenkitRouter] API
/// never references the experimental [Agent] type.
extension GenkitRouterAgents on GenkitRouter {
  /// Serves [agent] using the layout `remoteAgent(url: '<base><path>')`
  /// expects. Companion routes are mounted only when the agent supports them:
  ///
  /// - `POST <path>`: runs a turn (streams with `?stream=true`). Always.
  /// - `POST <path>/getSnapshot`: reads a snapshot. Server-managed agents
  ///   (defined with a session store), unless [hideGetSnapshot].
  /// - `POST <path>/abort`: aborts a detached turn. Agents whose store can
  ///   signal the running turn (the metadata's `abortable`), unless
  ///   [hideAbort].
  ///
  /// So a client-managed agent gets only its turn route. The `hide*` flags
  /// can only remove supported routes, never force-mount unsupported ones
  /// (those could only answer with an error). Missing or unrecognized
  /// metadata counts as unsupported. To serve a companion route anyway, mount
  /// its action yourself:
  ///
  /// ```dart
  /// router.addAction(agent.abortAgentAction, path: '/myAgent/abort');
  /// ```
  ///
  /// [path] defaults to `'/<agent name>'`. [contextProvider] applies to every
  /// mounted route, so reading or aborting a snapshot is authorized the same
  /// way as running a turn. Future Genkit versions may add more companion
  /// routes here (each with its own `hide*` flag).
  ///
  /// Throws an [ArgumentError] if [path] is invalid (see
  /// [GenkitRouter.addAction]; `/` is rejected too, since the companion routes
  /// are nested under it) or if any of the paths is already registered. Routes
  /// are added all or nothing, so after a failure none of them are served.
  void addAgent(
    Agent<dynamic> agent, {
    String? path,
    ContextProvider? contextProvider,
    bool hideGetSnapshot = false,
    bool hideAbort = false,
  }) {
    final base = path ?? '/${agent.action.name}';
    // addRoutes validates the rest; '/' alone is only invalid here, because
    // the companions would become '//getSnapshot' and '//abort'.
    if (base == '/') {
      throw ArgumentError.value(path, 'path', "must not be '/'");
    }
    final capabilities = _capabilitiesOf(agent);
    addRoutes(this, [
      (action: agent.action, path: base),
      if (capabilities.snapshots && !hideGetSnapshot)
        (action: agent.getSnapshotDataAction, path: '$base/getSnapshot'),
      if (capabilities.abortable && !hideAbort)
        (action: agent.abortAgentAction, path: '$base/abort'),
    ], contextProvider: contextProvider);
  }
}

/// Reads what [agent] supports from the `agent` entry of its turn action's
/// metadata, the same descriptor every Genkit runtime publishes (and the Dev
/// UI reads).
///
/// Fails closed: a companion route is mounted only when the metadata
/// explicitly advertises it. defineAgent/defineCustomAgent always set both
/// fields, so this only matters if the metadata was tampered with or its
/// shape changes, and then a missing route beats an `/abort` without a store
/// that can signal the turn.
({bool snapshots, bool abortable}) _capabilitiesOf(Agent<dynamic> agent) {
  final raw = agent.action.metadata['agent'];
  if (raw is! Map) return (snapshots: false, abortable: false);
  return (
    snapshots: raw['stateManagement'] == AgentStateManagement.server.value,
    abortable: raw['abortable'] == true,
  );
}
