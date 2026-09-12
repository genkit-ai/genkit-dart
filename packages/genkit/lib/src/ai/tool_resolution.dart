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

import '../core/action.dart';
import '../core/dynamic_action_provider.dart';
import '../core/registry.dart';

/// A tool/action reference addressed through a dynamic action provider.
///
/// Captures the provider [host], the resolved (internal) [actionType], and the
/// [matcher] naming a single action or a `*`/`prefix*` wildcard.
class DapToolRef {
  final String host;
  final ActionType actionType;
  final String matcher;

  DapToolRef(this.host, this.actionType, this.matcher);
}

/// Maps a user-facing tool-reference type segment to its internal [ActionType].
///
/// Users write `tool`/`prompt`/`resource`; the internal wire values are
/// `tool.v2`, `executable-prompt`, and `resource`. A value that is already an
/// internal type (e.g. `tool.v2` from a full Dev UI registry key) passes
/// through unchanged.
ActionType dapActionType(String userType) => switch (userType) {
  'tool' => ActionType.tool,
  'prompt' => ActionType.executablePrompt,
  'resource' => ActionType.resource,
  _ => ActionType(userType),
};

/// The user-facing type segments accepted in the shorthand reference form
/// (`<host>:tool/<name>`). Anything else before the first `/` is treated as part
/// of the action name (DAP names are commonly namespaced, e.g.
/// `localServer/weather`).
const _shorthandTypeSegments = {'tool', 'prompt', 'resource'};

/// Parses a DAP tool reference into its parts, or returns null when [ref] is not
/// a DAP reference.
///
/// Handles both forms:
///  - the full registry key sent by the Dev UI,
///    `/dynamic-action-provider/<host>:<type>/<name>` (type is internal, e.g.
///    `tool.v2`); and
///  - the user-facing shorthand: `<host>:*`, `<host>:tool/<name>`,
///    `<host>:prompt/<name>`, `<host>:resource/<name>`, or `<host>:<name>`
///    (defaulting to the `tool` type).
DapToolRef? parseDapToolRef(String ref) {
  if (ref.startsWith('/dynamic-action-provider/')) {
    final parsed = parseRegistryKey(ref);
    final host = parsed?.dynamicActionHost;
    if (parsed == null || host == null) return null;
    return DapToolRef(host, parsed.actionType, parsed.actionName);
  }

  final colonIdx = ref.indexOf(':');
  if (colonIdx == -1) return null;
  final host = ref.substring(0, colonIdx);
  var matcher = ref.substring(colonIdx + 1);
  var actionType = ActionType.tool;

  final slashIdx = matcher.indexOf('/');
  if (slashIdx > 0) {
    final typeSegment = matcher.substring(0, slashIdx);
    if (_shorthandTypeSegments.contains(typeSegment)) {
      actionType = dapActionType(typeSegment);
      matcher = matcher.substring(slashIdx + 1);
    }
  }
  return DapToolRef(host, actionType, matcher);
}

/// Resolves a [ref] to concrete actions via [dap], expanding `*`/`prefix*`
/// wildcards. Returns the resolved actions of any type; the caller decides which
/// to attach (e.g. only tools are passed to the model).
Future<List<Action>> resolveDapActions(
  DynamicActionProvider dap,
  DapToolRef ref,
) async {
  final resolved = <Action>[];
  if (ref.matcher.endsWith('*')) {
    final prefix = ref.matcher.substring(0, ref.matcher.length - 1);
    final metas = await dap.listActionMetadata(ref.actionType, ref.matcher);
    for (final meta in metas) {
      if (prefix.isEmpty || meta.name.startsWith(prefix)) {
        final action = await dap.getAction(ref.actionType, meta.name);
        if (action != null) resolved.add(action);
      }
    }
  } else {
    final action = await dap.getAction(ref.actionType, ref.matcher);
    if (action != null) resolved.add(action);
  }
  return resolved;
}
