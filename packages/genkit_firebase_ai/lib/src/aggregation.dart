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

    // firebase_ai drops the wire `index`, so a candidate's position stands in.
    for (final (index, candidate) in response.candidates.indexed) {
      candidateStates.putIfAbsent(index, _CandidateState.new).merge(candidate);
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
  final Map<m.HarmCategory, m.SafetyRating> safetyRatings = {};
  m.CitationMetadata? citationMetadata;
  // firebase_ai does not export the metadata types, so the latest chunk that
  // carried each one is kept instead.
  m.Candidate? groundingSource;
  m.Candidate? urlContextSource;
  String role = 'model';
  List<m.Part> parts = [];

  _CandidateState();

  void merge(m.Candidate chunk) {
    // An unknown reason is kept until a known one arrives.
    if (chunk.finishReason case final reason?
        when reason != m.FinishReason.unknown || finalFinishReason == null) {
      finalFinishReason = reason;
    }
    if (chunk.finishMessage != null) {
      finalFinishMessage = chunk.finishMessage;
    }
    for (final rating in chunk.safetyRatings ?? const <m.SafetyRating>[]) {
      safetyRatings[rating.category] = rating;
    }
    if (chunk.citationMetadata != null) {
      citationMetadata = chunk.citationMetadata;
    }
    // Gemini sends grounding metadata whole, usually on the last chunk.
    if (chunk.groundingMetadata != null) groundingSource = chunk;
    if (chunk.urlContextMetadata != null) urlContextSource = chunk;
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
      safetyRatings.isEmpty ? null : safetyRatings.values.toList(),
      citationMetadata,
      finalFinishReason,
      finalFinishMessage,
      groundingMetadata: groundingSource?.groundingMetadata,
      urlContextMetadata: urlContextSource?.urlContextMetadata,
    );
  }
}
