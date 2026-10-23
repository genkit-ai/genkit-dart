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

/// Aggregates a list of streaming responses from Firebase AI into a single response.
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
      // Firebase AI Candidates don't expose index, assume single candidate.
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
    for (var part in newParts) {
      if (parts.isNotEmpty) {
        final lastPart = parts.last;
        if (lastPart is m.TextPart &&
            part is m.TextPart &&
            _canAppendText(lastPart, part)) {
          final merged = m.TextPart(
            lastPart.text + part.text,
            isThought: part.isThought,
          );
          parts
            ..removeLast()
            ..add(merged);
          continue;
        } else if (lastPart is m.FunctionCall && part is m.FunctionCall) {
          // Firebase AI returns completed function calls, so only a resend of
          // the same call replaces the previous one. Parallel calls, including
          // several to the same function, are all kept: the first one carries
          // the thought signature.
          if (part.id != null && part.id == lastPart.id) {
            parts.removeLast();
            final signature = _thoughtSignature(lastPart);
            if (signature != null && _thoughtSignature(part) == null) {
              // ignore: invalid_use_of_visible_for_testing_member
              part = m.FunctionCall.forTest(
                part.name,
                part.args,
                id: part.id,
                isThought: part.isThought,
                thoughtSignature: signature,
              );
            }
          }
        }
      }
      parts.add(part);
    }
  }

  /// Whether [next] continues the text of [last].
  ///
  /// Thoughts and answer text stay separate parts, and a part that carries a
  /// thought signature is never merged with another part: Gemini needs each
  /// signature back in its original part.
  static bool _canAppendText(m.TextPart last, m.TextPart next) =>
      (last.isThought ?? false) == (next.isThought ?? false) &&
      _thoughtSignature(last) == null &&
      _thoughtSignature(next) == null;

  /// The signature is only readable through `toJson`.
  static String? _thoughtSignature(m.Part part) =>
      (part.toJson() as Map<String, dynamic>)['thoughtSignature'] as String?;

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
