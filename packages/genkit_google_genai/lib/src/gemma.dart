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

import 'package:genkit/plugin.dart';

import 'model.dart';

final commonGemmaModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': 'no-tools',
  },
);

final gemma3ModelInfo = ModelInfo(
  supports: {...?commonGemmaModelInfo.supports, 'systemRole': false},
);

bool isGemmaModelName(String name) => name.startsWith('gemma-');

bool isGemma3ModelName(String name) =>
    name.startsWith('gemma-3-') || name.startsWith('gemma-3n-');

/// Strips parts that the Gemma API rejects in history: reasoning parts
/// and any text/tool parts whose metadata carries a `thoughtSignature`.
/// Messages that become empty after filtering are dropped.
List<Message> stripReasoningParts(List<Message> messages) {
  return messages
      .map(
        (m) => Message(
          role: m.role,
          content: m.content
              .where(
                (p) =>
                    !p.isReasoning && p.metadata?['thoughtSignature'] == null,
              )
              .toList(),
          metadata: m.metadata,
        ),
      )
      .where((m) => m.content.isNotEmpty)
      .toList();
}

/// Maps a [GemmaOptions] config to its [GeminiOptions] equivalent so the
/// shared `toGeminiSettings`/`toGeminiTools`/etc. helpers can be reused.
/// Every Gemma field has an identical Gemini twin; the only schema-level
/// difference is the tighter `temperature` cap on Gemma.
GeminiOptions gemmaToGeminiOptions(GemmaOptions o) {
  return GeminiOptions(
    apiKey: o.apiKey,
    safetySettings: o.safetySettings,
    codeExecution: o.codeExecution,
    functionCallingConfig: o.functionCallingConfig,
    thinkingConfig: o.thinkingConfig,
    responseModalities: o.responseModalities,
    googleSearch: o.googleSearch,
    fileSearch: o.fileSearch,
    temperature: o.temperature,
    topP: o.topP,
    topK: o.topK,
    candidateCount: o.candidateCount,
    stopSequences: o.stopSequences,
    maxOutputTokens: o.maxOutputTokens,
    responseMimeType: o.responseMimeType,
    responseLogprobs: o.responseLogprobs,
    logprobs: o.logprobs,
    presencePenalty: o.presencePenalty,
    frequencyPenalty: o.frequencyPenalty,
    seed: o.seed,
    speechConfig: o.speechConfig,
  );
}
