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

import 'package:firebase_ai/firebase_ai.dart' as m;

m.GenerateContentResponse aggregateResponses(
  List<m.GenerateContentResponse> responses,
) {
  if (responses.isEmpty) return m.GenerateContentResponse([], null);

  m.PromptFeedback? promptFeedback;
  m.UsageMetadata? usageMetadata;
  final candidateStates = <int, _CandidateState>{};

  for (final response in responses) {
    if (response.promptFeedback != null) {
      promptFeedback = response.promptFeedback;
    }
    if (response.usageMetadata != null) {
      usageMetadata = response.usageMetadata;
    }

    if (response.candidates.isNotEmpty) {
      final index = 0;
      final state = candidateStates.putIfAbsent(index, _CandidateState.new);
      state.merge(response.candidates.first);
    }
  }

  return m.GenerateContentResponse(
    candidateStates.values.map((s) => s.toCandidate()).toList(),
    promptFeedback,
    usageMetadata: usageMetadata,
  );
}

class _CandidateState {
  m.FinishReason? finalFinishReason;
  String? finalFinishMessage;
  List<m.SafetyRating> safetyRatings = [];
  m.CitationMetadata? citationMetadata;
  String role = 'model';
  List<m.Part> parts = [];

  _CandidateState();

  void merge(m.Candidate chunk) {
    if (chunk.finishReason != null &&
        chunk.finishReason != m.FinishReason.unknown) {
      finalFinishReason = chunk.finishReason;
    }
    if (chunk.finishMessage != null) {
      finalFinishMessage = chunk.finishMessage;
    }
    if (chunk.safetyRatings != null && chunk.safetyRatings!.isNotEmpty) {
      safetyRatings.addAll(chunk.safetyRatings!);
    }
    if (chunk.citationMetadata != null) {
      citationMetadata = chunk.citationMetadata;
    }
    if (chunk.content.role != null) {
      role = chunk.content.role!;
    }
    _mergeParts(chunk.content.parts);
  }

  void _mergeParts(List<m.Part> newParts) {
  for (final part in newParts) {
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      if (lastPart is m.TextPart && part is m.TextPart) {
        final newText = lastPart.text + part.text;
        parts.removeLast();
        
        Map<String, dynamic>? mergedMetadata;
        if (lastPart.metadata != null || part.metadata != null) {
          mergedMetadata = {};
          if (lastPart.metadata != null) {
            mergedMetadata!.addAll(lastPart.metadata!);
          }
          if (part.metadata != null) {
            mergedMetadata!.addAll(part.metadata!);
          }
        }
        
        Map<String, dynamic>? mergedCustom;
        if (lastPart.custom != null || part.custom != null) {
          mergedCustom = {};
          if (lastPart.custom != null) {
            mergedCustom!.addAll(lastPart.custom!);
          }
          if (part.custom != null) {
            mergedCustom!.addAll(part.custom!);
          }
        }
        
        parts.add(m.TextPart(
          newText,
          metadata: mergedMetadata,
          custom: mergedCustom,
        ));
        continue;
      } else if (lastPart is m.FunctionCall && part is m.FunctionCall) {
        if (part.id == lastPart.id || part.name == lastPart.name) {
          parts.removeLast();
        }
      }
    }
    parts.add(part);
  }
}

  m.Candidate toCandidate() {
    return m.Candidate(
      m.Content(role, parts),
      safetyRatings.isEmpty ? null : safetyRatings,
      citationMetadata,
      finalFinishReason,
      finalFinishMessage,
    );
  }
}