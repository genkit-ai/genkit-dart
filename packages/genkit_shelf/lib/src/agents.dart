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

import 'package:genkit/experimental.dart';

import 'handler.dart';
import 'router.dart';

/// Agent support for [GenkitRouter].
///
/// Lives in an extension (exported only from the experimental
/// `package:genkit_shelf/agents.dart`) so the stable [GenkitRouter] API never
/// references the experimental [Agent] type.
extension GenkitRouterAgents on GenkitRouter {
  /// Serves [agent] using the layout `remoteAgent(url: '<base><path>')`
  /// expects:
  ///
  /// - `POST <path>`: runs a turn (streams with `?stream=true`)
  /// - `POST <path>/getSnapshot`: reads a snapshot, unless [hideGetSnapshot]
  /// - `POST <path>/abort`: aborts a detached turn, unless [hideAbort]
  ///
  /// [path] defaults to `'/<agent name>'`. [contextProvider] applies to every
  /// route, so reading or aborting a snapshot is authorized the same way as
  /// running a turn.
  ///
  /// The snapshot and abort routes need a session store; on a client-managed
  /// agent they answer `400 FAILED_PRECONDITION`. Hide them if you don't want
  /// them mounted at all. Future Genkit versions may add more companion
  /// routes here (each with its own `hide*` flag).
  ///
  /// Throws an [ArgumentError] if [path] is invalid (see
  /// [GenkitRouter.addAction]; `/` is rejected too, since the companion routes
  /// are nested under it) or if any of the paths is already registered.
  void addAgent(
    Agent<dynamic> agent, {
    String? path,
    ContextProvider? contextProvider,
    bool hideGetSnapshot = false,
    bool hideAbort = false,
  }) {
    final base = path ?? '/${agent.action.name}';
    // addAction validates the rest; '/' alone is only invalid here, because
    // the companions would become '//getSnapshot' and '//abort'.
    if (base == '/') {
      throw ArgumentError.value(path, 'path', "must not be '/'");
    }
    addAction(agent.action, path: base, contextProvider: contextProvider);
    if (!hideGetSnapshot) {
      addAction(
        agent.getSnapshotDataAction,
        path: '$base/getSnapshot',
        contextProvider: contextProvider,
      );
    }
    if (!hideAbort) {
      addAction(
        agent.abortAgentAction,
        path: '$base/abort',
        contextProvider: contextProvider,
      );
    }
  }
}
