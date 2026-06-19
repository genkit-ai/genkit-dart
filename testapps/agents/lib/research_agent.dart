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

/// Multi-step research agent — demonstrates `defineCustomAgent`.
///
/// Ported from the JS `research-agent.ts`. Showcases capabilities that REQUIRE
/// `defineCustomAgent`:
///   * Multi-step orchestration — multiple sequential model calls with custom
///     logic between them.
///   * Custom status streaming — mutating a typed `status` field via
///     `session.updateCustom` auto-emits a `customPatch` chunk so the client's
///     tracked state stays live mid-stream.
///   * Direct session control — manually managing messages and custom state.
///   * Multiple models — a fast model for decomposition, the capable model for
///     research and synthesis.
///
/// Flow:
///   1. Decompose the question into 2–3 sub-questions (fast model).
///   2. Research each sub-question (main model, with status updates).
///   3. Synthesize a final response (main model, streamed to the client).
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

Map<String, dynamic> _state(dynamic custom) {
  if (custom is Map) return Map<String, dynamic>.from(custom);
  return {'subQuestions': <dynamic>[], 'subAnswers': <dynamic>[]};
}

final researchAgent = ai.defineCustomAgent(
  name: 'researchAgent',
  fn: (sess, options) async {
    Message? lastMessage;
    final session = ai.currentSession()!;

    await sess.run((input, ctx) async {
      final userText = input.message?.content.first.text ?? '';

      // Build conversation history context (available for ALL steps).
      final priorMessages = sess.getMessages();
      final historyContext = priorMessages.length > 1
          ? '\nConversation history:\n${priorMessages.sublist(0, priorMessages.length - 1).map((m) => '${m.role.value}: ${m.content.map((c) => c.text ?? '').join()}').join('\n')}\n'
          : '';

      // Step 1: Decompose the question. Mutating custom state auto-emits a
      // `customPatch` chunk to the client.
      session.updateCustom((s) {
        final state = _state(s);
        state['status'] = 'Decomposing question into sub-topics…';
        return state;
      });

      final decompose = await ai.generate(
        model: liteModel,
        prompt:
            'You are a research planner. Given a user question, break it into '
            'exactly 2-3 focused sub-questions that together would provide a '
            'comprehensive answer. Return ONLY the sub-questions as a JSON '
            'array of strings, no other text.\n'
            '$historyContext\nUser question: "$userText"',
        use: [retry()],
        outputFormat: 'json',
        outputSchema: SchemanticType.list(SchemanticType.string()),
      );

      final subQuestions = (decompose.output ?? [userText])
          .map((e) => e.toString())
          .toList();

      session.updateCustom((s) {
        final state = _state(s);
        state['subQuestions'] = subQuestions;
        state['subAnswers'] = <dynamic>[];
        return state;
      });

      // Step 2: Research each sub-question.
      final subAnswers = <Map<String, dynamic>>[];
      for (var i = 0; i < subQuestions.length; i++) {
        final q = subQuestions[i];
        session.updateCustom((s) {
          final state = _state(s);
          state['status'] = 'Researching (${i + 1}/${subQuestions.length}): $q';
          return state;
        });

        final research = await ai.generate(
          use: [retry()],
          prompt:
              'Answer this question concisely but thoroughly in 2-3 '
              'paragraphs. Be specific and factual.\n\nQuestion: $q',
        );
        subAnswers.add({'question': q, 'answer': research.text});
      }

      session.updateCustom((s) {
        final state = _state(s);
        state['subAnswers'] = subAnswers;
        return state;
      });

      // Step 3: Synthesize the final response.
      session.updateCustom((s) {
        final state = _state(s);
        state['status'] = 'Synthesizing final response…';
        return state;
      });

      final researchContext = subAnswers
          .asMap()
          .entries
          .map(
            (e) =>
                '### Sub-question ${e.key + 1}: ${e.value['question']}\n${e.value['answer']}',
          )
          .join('\n\n');

      final synthesisStream = ai.generateStream(
        use: [retry()],
        prompt:
            'You are a research synthesizer. Based on the research below, '
            'write a comprehensive, well-structured answer to the original '
            'question. Use markdown formatting.\n'
            '$historyContext\nCurrent question: "$userText"\n\n'
            'Research findings:\n$researchContext\n\n'
            'Write a clear, cohesive response that integrates all the research '
            "findings. Don't just list the sub-answers — synthesize them into "
            'a unified narrative. If there is conversation history, take it '
            'into account for context.',
      );

      await for (final chunk in synthesisStream) {
        options.sendChunk(AgentStreamChunk(modelChunk: chunk.rawChunk));
      }

      final synthesisResponse = await synthesisStream.onResult;
      lastMessage = synthesisResponse.message;
      if (lastMessage != null) {
        sess.addMessages([lastMessage!]);
      }

      session.updateCustom((s) {
        final state = _state(s);
        state['status'] = 'Done';
        return state;
      });

      return null;
    });

    return AgentResult(
      message:
          lastMessage ??
          Message(
            role: Role.model,
            content: [TextPart(text: 'Research complete.')],
          ),
    );
  },
);
