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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

part 'structured_output.g.dart';

@Schematic()
abstract class $MovieReviewInput {
  /// Title of the movie to review
  String get title;

  /// Optional release year to disambiguate
  int? get year;
}

@Schematic()
abstract class $MovieReview {
  /// Official movie title
  String get title;

  /// Rating from 1.0 to 10.0
  double get rating;

  /// One-paragraph summary of the film
  String get summary;

  /// List of standout positives
  List<String> get pros;

  /// List of notable negatives
  List<String> get cons;

  /// Recommended audience, e.g. "sci-fi fans", "families"
  String get recommendedFor;
}

/// Defines a flow that demonstrates structured output with an OpenAI model.
///
/// Passes a MovieReview schema to Genkit.generate using outputSchema,
/// which instructs the model to respond with valid JSON matching that shape.
/// The typed result is accessed via output rather than text.
Flow<MovieReviewInput, MovieReview, void, void> defineStructuredOutputFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'structuredOutput',
    inputSchema: MovieReviewInput.$schema,
    outputSchema: MovieReview.$schema,
    fn: (input, _) async {
      final yearClause = input.year != null ? ' (${input.year})' : '';

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Write a detailed review  of the movie "${input.title}$yearClause".',
        outputFormat: 'json',
        outputSchema: MovieReview.$schema,
      );

      final output = response.output;
      if (output == null) throw StateError('Model returned no structured output.');
      return output;
    },
  );
}

/// Defines a flow that demonstrates streaming structured output with an OpenAI model.
///
/// Emits summary paragraphs as streaming chunks, then returns structured [MovieReview]
/// in the final output.
Flow<MovieReviewInput, MovieReview, String, void> defineStreamedStructuredOutputFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'streamedStructuredOutput',
    inputSchema: MovieReviewInput.$schema,
    outputSchema: MovieReview.$schema,
    streamSchema: stringSchema(),
    fn: (input, ctx) async {
      final yearClause = input.year != null ? ' (${input.year})' : '';
      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
        prompt: 'Write a detailed review of the movie "${input.title}$yearClause".',
        outputFormat: 'json',
        outputSchema: MovieReview.$schema,
      );

      await for (final chunk in stream) {
        // Only send summary or text-like chunks to streaming.
        // This assumes chunk.text is a portion of the overall review being generated.
        if (ctx.streamingRequested && chunk.text.isNotEmpty) {
          ctx.sendChunk(chunk.text);
        }
      }

      final response = await stream.onResult;
      final output = response.output;
      if (output == null) throw StateError('Model returned no structured output.');
      return output;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [openAI(apiKey: Platform.environment['OPENAI_API_KEY'])],
  );

  defineStructuredOutputFlow(ai);
  defineStreamedStructuredOutputFlow(ai);
}
