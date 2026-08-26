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

final gemmaModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': 'no-tools',
  },
);

bool isGemma4ModelName(String name) => name.startsWith('gemma-4-');

/// Strips what the Gemma API rejects in history: reasoning parts are
/// dropped, and `thoughtSignature` metadata is removed from other parts.
/// Messages that become empty after filtering are dropped.
List<Message> stripReasoningParts(List<Message> messages) {
  return messages
      .map(
        (m) => Message(
          role: m.role,
          content: m.content
              .where((p) => !p.isReasoning)
              .map(_withoutThoughtSignature)
              .toList(),
          metadata: m.metadata,
        ),
      )
      .where((m) => m.content.isNotEmpty)
      .toList();
}

Part _withoutThoughtSignature(Part p) {
  final metadata = p.metadata;
  if (metadata == null || !metadata.containsKey('thoughtSignature')) {
    return p;
  }
  final stripped = {...metadata}..remove('thoughtSignature');
  final json = {...p.toJson()};
  if (stripped.isEmpty) {
    json.remove('metadata');
  } else {
    json['metadata'] = stripped;
  }
  return Part.fromJson(json);
}

/// Maps a [GemmaOptions] config to its [GeminiOptions] equivalent.
///
/// Throws a [GenkitException] with `INVALID_ARGUMENT` when `temperature` is
/// outside the 0.0-1.0 range the Gemma API accepts.
GeminiOptions gemmaToGeminiOptions(GemmaOptions o) {
  final temperature = o.temperature;
  if (temperature != null && (temperature < 0.0 || temperature > 1.0)) {
    throw GenkitException(
      'Gemma models accept temperature between 0.0 and 1.0, got $temperature.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
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
