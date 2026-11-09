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

/// Capabilities of every Claude model this plugin serves: multiturn chat,
/// vision (media input), tool calling with tool choice, a system role, and
/// text or JSON output with native constrained generation.
///
/// `constrained: true` holds for any model name, curated or not. Structured
/// outputs (`output_config.format`) are GA on the stable surface and cover
/// every active Claude model; models that predate them are retired. The
/// schema pins no `tool_choice` and adds no tool, so it composes with the
/// caller's own tools and with extended thinking.
const claudeSupports = <String, dynamic>{
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': true,
  'systemRole': true,
  'output': ['text', 'json'],
  'constrained': true,
};

/// Claude models the Anthropic plugin curates metadata for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label] and a default thinking mode. Curation adds labels, a stable stage
/// and listing without discovery; capabilities are the same [claudeSupports]
/// for every model. Other names still resolve via the plugin's
/// `commonModelInfo` fallback.
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
  ModelInfo get info =>
      ModelInfo(label: label, supports: claudeSupports, stage: 'stable');
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
