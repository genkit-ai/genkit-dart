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

import 'generated/generativelanguage.dart' as gcl;

/// Aggregates a list of streaming responses into a single response.
gcl.GenerateContentResponse aggregateResponses(
  List<gcl.GenerateContentResponse> responses,
) {
  if (responses.isEmpty) return gcl.GenerateContentResponse();

  gcl.PromptFeedback? promptFeedback;
  gcl.UsageMetadata? usageMetadata;
  final candidateStates = <int, _CandidateState>{};

  for (final response in responses) {
    if (response.promptFeedback != null) {
      promptFeedback = response.promptFeedback;
    }
    if (response.usageMetadata != null) {
      usageMetadata = response.usageMetadata;
    }

    if (response.candidates != null && response.candidates!.isNotEmpty) {
      for (final candidate in response.candidates!) {
        final index = candidate.index ?? 0;
        final state = candidateStates.putIfAbsent(
          index,
          () => _CandidateState(index: index),
        );
        state.merge(candidate);
      }
    }
  }

  return gcl.GenerateContentResponse(
    candidates: candidateStates.values.map((s) => s.toCandidate()).toList(),
    promptFeedback: promptFeedback,
    usageMetadata: usageMetadata,
  );
}

class _CandidateState {
  final int index;
  String? finalFinishReason;
  String? finalFinishMessage;
  List<gcl.SafetyRating> safetyRatings = [];
  gcl.CitationMetadata? citationMetadata;
  gcl.GroundingMetadata? groundingMetadata;
  String role = 'model';
  List<gcl.Part> parts = [];

  _CandidateState({required this.index});

  void merge(gcl.Candidate chunk) {
    if (chunk.finishReason != null) {
      finalFinishReason = chunk.finishReason;
    }
    if (chunk.safetyRatings != null && chunk.safetyRatings!.isNotEmpty) {
      safetyRatings.addAll(chunk.safetyRatings!);
    }
    if (chunk.citationMetadata != null) {
      citationMetadata = chunk.citationMetadata;
    }
    if (chunk.groundingMetadata != null) {
      groundingMetadata = chunk.groundingMetadata;
    }
    if (chunk.content != null) {
      if (chunk.content!.role != null) {
        role = chunk.content!.role!;
      }
      if (chunk.content!.parts != null) {
        _mergeParts(chunk.content!.parts!);
      }
    }
  }

  void _mergeParts(List<gcl.Part> newParts) {
    for (final part in newParts) {
      if (parts.isNotEmpty) {
        final lastPart = parts.last;
        if (lastPart.text != null && part.text != null) {
          // Merge text
          final newText = lastPart.text! + part.text!;
          parts.removeLast();
          parts.add(gcl.Part(text: newText));
          continue;
        }
        // TODO: Merge Tool Call args if necessary.
        // Currently assuming atomic or append-only behavior for other parts.
      }
      parts.add(part);
    }
  }

  gcl.Candidate toCandidate() {
    return gcl.Candidate(
      index: index,
      finishReason: finalFinishReason,
      safetyRatings: safetyRatings,
      citationMetadata: citationMetadata,
      groundingMetadata: groundingMetadata,
      content: gcl.Content(role: role, parts: parts),
    );
  }
}
