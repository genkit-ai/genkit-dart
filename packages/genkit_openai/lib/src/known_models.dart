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

/// Chat models the plugin curates so they stay listable without network access.
///
/// The plugin normally discovers models from `GET /models`, but that needs both
/// connectivity and a valid key. This list is what gets listed when discovery
/// is unavailable, and it is merged with the discovered set when it is.
///
/// It is a convenience, never a gate: the plugin resolves any model id, so a
/// model absent from this list still works when named explicitly. That is
/// deliberate - it keeps just-released models usable without a plugin release.
/// Capability metadata is not duplicated here either; it comes from the
/// heuristics behind `modelInfoFor`.
///
/// Curation rules, to keep this list from sprawling as OpenAI ships:
///
/// - Aliases only. Dated snapshots (`gpt-4o-2024-08-06`) and `-chat-latest`
///   aliases are omitted; discovery surfaces them when online, and pinning a
///   snapshot is an explicit act the plugin's resolver already supports.
/// - Chat models only. Embeddings, image, audio and moderation models are not
///   served by this plugin's chat path.
/// - Recent generations plus what apps still pin in practice, not every
///   generation ever shipped.
const List<String> knownChatModels = <String>[
  // GPT-5 family, newest first. `-pro` is the higher-reasoning tier;
  // `-mini`/`-nano` trade capability for latency and cost.
  'gpt-5.5',
  'gpt-5.5-pro',
  'gpt-5.4',
  'gpt-5.4-mini',
  'gpt-5.4-nano',
  'gpt-5.4-pro',
  'gpt-5',
  'gpt-5-mini',
  'gpt-5-nano',

  // GPT-4.1 and 4o remain widely pinned by existing apps.
  'gpt-4.1',
  'gpt-4.1-mini',
  'gpt-4.1-nano',
  'gpt-4o',
  'gpt-4o-mini',

  // o-series reasoning models.
  'o3',
  'o3-mini',
  'o4-mini',
];
