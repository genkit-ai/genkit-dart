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

// In its own file (no imports) so `o11y/` can use it without importing
// `action.dart`, which imports `o11y/`.

/// Well-known action type identifiers used as the `actionType` of an `Action`
/// and as the first segment of its registry key (`/$actionType/$name`).
///
/// This is a string-backed, open "enum" (following the same pattern as `Role`).
/// The known constants below give type-safe names and autocomplete, while
/// custom types remain expressible via the unnamed constructor, e.g.
/// `ActionType('my-custom-type')`.
extension type const ActionType(String value) {
  /// A model action.
  static const ActionType model = ActionType('model');

  /// A bidirectional (streaming) model action.
  static const ActionType bidiModel = ActionType('bidi-model');

  /// A flow action.
  static const ActionType flow = ActionType('flow');

  /// An embedder action.
  static const ActionType embedder = ActionType('embedder');

  /// An evaluator action.
  static const ActionType evaluator = ActionType('evaluator');

  /// A resource action.
  static const ActionType resource = ActionType('resource');

  /// An executable prompt action.
  static const ActionType executablePrompt = ActionType('executable-prompt');

  /// A prompt template action.
  static const ActionType promptTemplate = ActionType('promptTemplate');

  /// A dotprompt action.
  static const ActionType dotprompt = ActionType('dotprompt');

  /// An agent action.
  static const ActionType agent = ActionType('agent');

  /// An agent snapshot data action.
  static const ActionType agentSnapshot = ActionType('agent-snapshot');

  /// An agent abort action.
  static const ActionType agentAbort = ActionType('agent-abort');

  /// A dynamic action provider.
  static const ActionType dynamicActionProvider = ActionType(
    'dynamic-action-provider',
  );

  /// A utility action (e.g. the built-in `generate` action).
  static const ActionType util = ActionType('util');

  /// An ad-hoc step inside a flow (e.g. `ai.run(name, fn)`).
  static const ActionType flowStep = ActionType('flowStep');

  /// The default action type for actions that don't specify one.
  static const ActionType custom = ActionType('custom');

  /// The action type for tools.
  ///
  /// Its wire value is `tool.v2`: every Genkit Dart tool implements the
  /// multipart ("v2") tool contract (its function returns a `ToolResult` that
  /// serializes to `{output, content?, metadata?}`), so tools are registered
  /// and resolved under `tool.v2`. External consumers such as the Dev UI use
  /// this to render/run tools as multipart.
  static const ActionType tool = ActionType('tool.v2');
}
