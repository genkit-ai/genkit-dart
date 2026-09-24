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
/// The tier for a name this plugin cannot vouch for, which is what
/// `commonModelInfo` hands an uncurated model. Curation is the claim: a name
/// in [KnownClaudeModel] is one this plugin has checked can take the schema,
/// one way or the other, so no curated model sits here.
const baseClaudeSupports = <String, dynamic>{
  ..._claudeSupportsCore,
  'output': ['text'],
};

/// [baseClaudeSupports] plus JSON output and constrained generation.
///
/// The schema travels as `output_config.format` - Anthropic's own Structured
/// Outputs feature, served on the stable surface as well as beta. It pins no
/// `tool_choice` and adds no tool, so it composes with extended thinking and
/// leaves the caller's own tools reachable; hence `true` rather than the
/// `'no-tools'` a forced `return_output` tool would have needed.
///
/// Claimed for curated names only: whether a model is on Anthropic's
/// Structured Outputs list is per-model, and `commonModelInfo` keeps an
/// uncurated name on [baseClaudeSupports] so core simulates instead of
/// guessing.
const structuredClaudeSupports = <String, dynamic>{
  ..._claudeSupportsCore,
  'output': ['text', 'json'],
  'constrained': true,
};

/// Claude models the Anthropic plugin curates capability metadata for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label]. Membership is itself the capability claim: a curated name is one
/// this plugin has checked is on Anthropic's Structured Outputs list. Other
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

  const KnownClaudeModel(this.id, this.label, this.defaultThinkingMode);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// Thinking mode used when a request supplies a thinking configuration but
  /// does not select a mode explicitly.
  final ClaudeThinkingMode defaultThinkingMode;

  /// Capability metadata registered for this model.
  ///
  /// One tier, not one per surface: `output_config.format` is served on both,
  /// so the claim does not depend on which one a request names.
  ModelInfo get info => ModelInfo(
    label: label,
    supports: structuredClaudeSupports,
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
