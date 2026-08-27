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

import 'package:genkit/plugin.dart';

// A const map literal rejects duplicate keys, so 'output' cannot be spread in
// from the base tier and then overridden.
const _claudeSupportsCore = <String, dynamic>{
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': true,
  'systemRole': true,
};

/// Capabilities every Claude model has: multiturn chat, vision (media input),
/// tool calling with tool choice, a system role, and text output.
///
/// The tier for a name this plugin cannot vouch for: no curated member sits
/// here today, but it is what `commonModelInfo` hands an uncurated model, and
/// where a curated model that cannot take a forced `tool_choice` would go.
const baseClaudeSupports = <String, dynamic>{
  ..._claudeSupportsCore,
  'output': ['text'],
};

/// [baseClaudeSupports] plus JSON output and constrained generation, served by
/// the forced `return_output` tool.
///
/// The tier for the stable API surface, where Anthropic's own Structured
/// Outputs feature is not available and the schema has to travel as a tool the
/// model is forced to call. Claimed only for curated names: a forced
/// `tool_choice` is not accepted by every Claude model, so `commonModelInfo`
/// keeps the uncurated fallback on [baseClaudeSupports] and lets core
/// simulate.
///
/// `'no-tools'` rather than `true`, because the trick pins `tool_choice` to
/// `return_output`, and a request that also carries the caller's own tools
/// can then never reach them - the tool loop would silently never fire. So
/// the native path is claimed only for a request with no tools of its own;
/// with tools, core simulates and the schema arrives as prompt instructions,
/// leaving `tool_choice` free.
const structuredClaudeSupports = <String, dynamic>{
  ..._claudeSupportsCore,
  'output': ['text', 'json'],
  'constrained': 'no-tools',
};

/// [structuredClaudeSupports] with the constraint claimed unconditionally.
///
/// The tier for the beta surface, where the schema goes over as
/// `output_config.format` - Anthropic's own Structured Outputs feature. That
/// path pins no `tool_choice` and adds no tool, so the caller's own tools stay
/// reachable and the claim needs no `'no-tools'` qualifier: this is the
/// narrowing the forced-tool tier was always standing in for.
const nativeStructuredClaudeSupports = <String, dynamic>{
  ..._claudeSupportsCore,
  'output': ['text', 'json'],
  'constrained': true,
};

/// Claude models the Anthropic plugin curates capability metadata for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label]; [info] picks the capability tier via [structuredOutputs]. Other
/// model names still resolve dynamically via the plugin's `commonModelInfo`
/// fallback, so this enum only enriches the names listed here.
enum KnownClaudeModel {
  fable5('claude-fable-5', 'Claude Fable 5', ClaudeThinkingMode.adaptive),
  opus5('claude-opus-5', 'Claude Opus 5', ClaudeThinkingMode.adaptive),
  opus48('claude-opus-4-8', 'Claude Opus 4.8', ClaudeThinkingMode.adaptive),
  opus47('claude-opus-4-7', 'Claude Opus 4.7', ClaudeThinkingMode.adaptive),
  opus46('claude-opus-4-6', 'Claude Opus 4.6', ClaudeThinkingMode.adaptive),
  opus45('claude-opus-4-5', 'Claude Opus 4.5', ClaudeThinkingMode.enabled),
  sonnet5('claude-sonnet-5', 'Claude Sonnet 5', ClaudeThinkingMode.adaptive),
  sonnet46(
    'claude-sonnet-4-6',
    'Claude Sonnet 4.6',
    ClaudeThinkingMode.adaptive,
  ),
  sonnet45(
    'claude-sonnet-4-5',
    'Claude Sonnet 4.5',
    ClaudeThinkingMode.enabled,
  ),
  haiku45('claude-haiku-4-5', 'Claude Haiku 4.5', ClaudeThinkingMode.enabled);

  // The base tier currently has no curated member.
  const KnownClaudeModel(
    this.id,
    this.label,
    this.defaultThinkingMode, {
    // ignore: unused_element_parameter
    this.structuredOutputs = true,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Thinking mode used when a request supplies a thinking configuration but
  /// does not select a mode explicitly.
  final ClaudeThinkingMode defaultThinkingMode;

  /// Whether the model is on Anthropic's Structured Outputs list and may
  /// claim native constrained generation and JSON output.
  final bool structuredOutputs;

  /// Capability metadata registered for this model on the stable surface.
  ModelInfo get info => infoFor(beta: false);

  /// Capability metadata registered for this model on the given API surface.
  ///
  /// The mechanism decides the claim, and the mechanism depends on the
  /// surface: `output_config.format` exists only on beta, so only there can a
  /// model on Anthropic's Structured Outputs list claim `constrained: true`.
  /// On stable the same model is served by the forced tool, which is
  /// `'no-tools'`.
  ModelInfo infoFor({required bool beta}) => ModelInfo(
    label: label,
    supports: switch ((structuredOutputs, beta)) {
      (false, _) => baseClaudeSupports,
      (true, false) => structuredClaudeSupports,
      (true, true) => nativeStructuredClaudeSupports,
    },
    stage: 'stable',
  );
}

/// Thinking modes that can be safely selected by default for curated models.
enum ClaudeThinkingMode { enabled, adaptive }

final _datedSuffixRegExp = RegExp(r'-\d{8}$');

/// Returns the curated alias for [modelName], removing a dated snapshot suffix.
String claudeModelAlias(String modelName) =>
    modelName.replaceFirst(_datedSuffixRegExp, '');

final _knownClaudeModelsById = <String, KnownClaudeModel>{
  for (final model in KnownClaudeModel.values) model.id: model,
};

/// Returns the curated model matching [modelName], including dated snapshots.
KnownClaudeModel? knownClaudeModelFor(String modelName) =>
    _knownClaudeModelsById[claudeModelAlias(modelName)];

/// Curated capability metadata for known Claude models, keyed by bare model
/// name (no plugin prefix).
///
/// Derived from [KnownClaudeModel]; other model names still resolve dynamically
/// with the shared `commonModelInfo` fallback. This map only enriches known
/// names with a typed label and stable stage, and ensures they appear in
/// listings even when the Anthropic models endpoint omits them.
final knownClaudeModels = <String, ModelInfo>{
  for (final model in KnownClaudeModel.values) model.id: model.info,
};
