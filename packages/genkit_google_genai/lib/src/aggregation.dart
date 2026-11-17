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

/// Aggregates the chunks of a streamed generateContent response into one
/// response (JS `aggregateResponses`, common/utils.ts).
///
/// Differs from JS in one way: text pieces in a row are joined when they're
/// of the same kind (text with text, thought with thought), so the final
/// message has the shape of a non-streamed response, as the Interactions
/// stream assembly does in both languages. JS keeps one part per piece. A
/// thought signature stays on the joined part; two signed pieces in a row
/// are kept apart so neither signature is lost.
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
  double? avgLogprobs;
  gcl.LogprobsResult? logprobsResult;
  List<gcl.SafetyRating> safetyRatings = [];
  Map<String, dynamic>? citationMetadata;
  Map<String, dynamic>? groundingMetadata;
  String role = 'model';

  /// The parts so far, as JSON (copies: the chunks are left as received).
  final List<Map<String, dynamic>> parts = [];

  _CandidateState({required this.index});

  void merge(gcl.Candidate chunk) {
    if (chunk.finishReason != null) {
      finalFinishReason = chunk.finishReason;
    }
    if (chunk.finishMessage != null) {
      finalFinishMessage = chunk.finishMessage;
    }
    if (chunk.avgLogprobs != null) avgLogprobs = chunk.avgLogprobs;
    if (chunk.logprobsResult != null) logprobsResult = chunk.logprobsResult;
    if (chunk.safetyRatings != null && chunk.safetyRatings!.isNotEmpty) {
      safetyRatings.addAll(chunk.safetyRatings!);
    }
    citationMetadata = _mergeMetadata(
      citationMetadata,
      chunk.citationMetadata?.toJson(),
    );
    groundingMetadata = _mergeMetadata(
      groundingMetadata,
      chunk.groundingMetadata?.toJson(),
    );
    if (chunk.content != null) {
      if (chunk.content!.role != null) {
        role = chunk.content!.role!;
      }
      for (final part in chunk.content!.parts ?? const <gcl.Part>[]) {
        _addPart(part);
      }
    }
  }

  void _addPart(gcl.Part part) {
    final data = Map<String, dynamic>.of(part.toJson());
    // An empty part becomes an empty text part (as in JS).
    if (data.isEmpty) data['text'] = '';
    final last = parts.isEmpty ? null : parts.last;
    if (last != null && _canJoin(last, data)) {
      last['text'] = '${last['text']}${data['text']}';
      if (data['thoughtSignature'] case final signature?) {
        last['thoughtSignature'] = signature;
      }
      return;
    }
    parts.add(data);
  }

  gcl.Candidate toCandidate() {
    final citation = citationMetadata;
    final grounding = groundingMetadata;
    return gcl.Candidate(
      index: index,
      finishReason: finalFinishReason,
      finishMessage: finalFinishMessage,
      avgLogprobs: avgLogprobs,
      logprobsResult: logprobsResult,
      safetyRatings: safetyRatings,
      citationMetadata: citation == null
          ? null
          : gcl.CitationMetadata.fromJson(citation),
      groundingMetadata: grounding == null
          ? null
          : gcl.GroundingMetadata.fromJson(grounding),
      content: gcl.Content(
        role: role,
        parts: parts.map(gcl.Part.fromJson).toList(),
      ),
    );
  }
}

/// The keys a text piece may have and still be joined with its neighbour.
const _textPieceKeys = {'text', 'thought', 'thoughtSignature'};

bool _isTextPiece(Map<String, dynamic> part) =>
    part['text'] is String && part.keys.every(_textPieceKeys.contains);

/// Whether [next] can be appended to [last]: both plain text pieces of the
/// same kind (thought or not), and not both signed.
bool _canJoin(Map<String, dynamic> last, Map<String, dynamic> next) =>
    _isTextPiece(last) &&
    _isTextPiece(next) &&
    (last['thought'] == true) == (next['thought'] == true) &&
    (last['thoughtSignature'] == null || next['thoughtSignature'] == null);

/// Merges a chunk's [chunk] metadata into [current] (JS aggregateMetadata):
/// lists are concatenated, other fields take the chunk's value when it has
/// one.
Map<String, dynamic>? _mergeMetadata(
  Map<String, dynamic>? current,
  Map<String, dynamic>? chunk,
) {
  if (chunk == null) return current;
  if (current == null) return Map.of(chunk);
  final merged = Map<String, dynamic>.of(current);
  chunk.forEach((key, value) {
    final existing = merged[key];
    merged[key] = existing is List && value is List
        ? [...existing, ...value]
        : value ?? existing;
  });
  return merged;
}
