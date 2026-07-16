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

/// Claude models the Anthropic plugin curates capability metadata for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label]; [info] builds the shared Claude capability preset. Other model
/// names still resolve dynamically via the plugin's `commonModelInfo`
/// fallback, so this enum only enriches the names listed here.
enum KnownClaudeModel {
  fable5('claude-fable-5', 'Claude Fable 5'),
  opus48('claude-opus-4-8', 'Claude Opus 4.8'),
  opus47('claude-opus-4-7', 'Claude Opus 4.7'),
  sonnet5('claude-sonnet-5', 'Claude Sonnet 5'),
  sonnet46('claude-sonnet-4-6', 'Claude Sonnet 4.6'),
  sonnet45('claude-sonnet-4-5', 'Claude Sonnet 4.5'),
  haiku45('claude-haiku-4-5', 'Claude Haiku 4.5');

  const KnownClaudeModel(this.id, this.label);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The capability profile shared by every current Claude model: multiturn
  /// chat, vision (media input), tool calling with tool choice, a system role,
  /// and native constrained generation. Mirrors the single `defaultClaudeOpts`
  /// profile the Go plugin applies to every Claude model.
  ModelInfo get info => ModelInfo(
    label: label,
    // Unmodifiable: curated entries are shared across every resolution of the
    // model, so accidental mutation through action metadata must fail loudly.
    supports: Map.unmodifiable({
      'multiturn': true,
      'media': true,
      'tools': true,
      'toolChoice': true,
      'systemRole': true,
      'constrained': true,
    }),
    stage: 'stable',
  );
}

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
