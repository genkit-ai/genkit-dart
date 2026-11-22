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

/// The model action a decision model is served as.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:genkit/plugin.dart';
import 'package:logging/logging.dart';

import '../info.dart';
import '../options.dart';
import 'client.dart';
import 'questions.dart';
import 'state.dart';

final _logger = Logger('genkit_systemone');

/// What a decision model claims: constrained output, so the loop hands it the
/// output schema untouched, and the system role and context, so nothing
/// rewrites either into instruction text that would land in the state.
Map<String, dynamic> decisionSupports({required bool media}) => {
  'multiturn': true,
  'media': media,
  'tools': false,
  'systemRole': true,
  'context': true,
  'constrained': 'all',
  'output': ['json', 'enum'],
  'contentType': ['application/json', 'text/enum'],
};

/// Builds the model action for one model [id] under its registered [name].
Model<SystemOneOptions> newDecisionModel(
  DecideClient client,
  String name,
  String id, {
  required String label,
  required Reads reads,
}) => Model(
  name: name,
  customOptions: SystemOneOptions.$schema,
  metadata: {
    'model': ModelInfo(
      label: label,
      supports: decisionSupports(media: reads.any),
    ).toJson(),
  },
  fn: (req, ctx) => _generate(client, id, reads, req, ctx.cancel),
);

/// Answers the questions the request's output schema encodes.
Future<ModelResponse> _generate(
  DecideClient client,
  String id,
  Reads reads,
  ModelRequest req,
  CancellationToken? cancel,
) async {
  final output = req.output;
  final enumFormat = output?.format == 'enum';
  if (output == null || (output.schema == null && !enumFormat)) {
    throw GenkitException(
      'systemone: the model answers questions encoded in an output type; '
      'pass outputSchema with a decisionSchema, or a questionsSchema for '
      'questions built at run time',
      status: StatusCode.invalidArgument,
    );
  }
  if (req.tools?.isNotEmpty ?? false) {
    throw GenkitException(
      'systemone: a decision model calls no tools; leave tools out of the '
      'request',
      status: StatusCode.invalidArgument,
    );
  }
  final opts = req.config == null
      ? SystemOneOptions()
      : SystemOneOptions.$schema.parse(req.config!);
  final extra = opts.extra;
  for (final field in reservedFields) {
    if (extra?.containsKey(field) ?? false) {
      throw GenkitException(
        'systemone: extra field "$field" is one the request builds itself',
        status: StatusCode.invalidArgument,
      );
    }
  }
  final preamble = systemPreamble(req.messages);
  final questions = enumFormat
      ? enumQuestion(output.schema, preamble)
      : compileQuestions(output.schema!, preamble);
  final (:state, :media) = buildState(
    req,
    stateJson: opts.stateJSON ?? false,
    reads: reads,
  );

  final resp = await client.decide(
    id,
    DecideRequest(
      state: state,
      media: media,
      questions: questions,
      extra: extra,
    ),
    cancel: cancel,
  );
  _logger.fine(
    'systemone: answered (endpoint ${client.endpoint.name}, model '
    '${resp.model}, ${questions.length} questions, ${resp.inputTokens} input '
    'tokens, ${resp.outputTokens} output tokens)',
  );

  final text = answersText(resp, questions, enumFormat: enumFormat);
  return ModelResponse(
    message: Message(
      role: Role.model,
      content: [TextPart(text: text)],
    ),
    finishReason: FinishReason.stop,
    usage: GenerationUsage(
      inputTokens: resp.inputTokens,
      outputTokens: resp.outputTokens,
      totalTokens: resp.inputTokens + resp.outputTokens,
      custom: resp.cost == null ? null : {'cost': resp.cost},
    ),
    raw: SystemOneInfo(
      model: resp.model,
      provider: resp.provider ?? '',
      id: resp.id ?? '',
      answers: resp.answers,
    ).toJson(),
  );
}

/// The fields of a wire answer per question type, which are the fields the
/// answer types declare. The answer schemas are closed, so a field the API
/// or a gateway adds later is dropped here rather than failing to parse; the
/// untouched answer is still on [SystemOneInfo.answers].
const _answerFields = {
  kindChoice: ['choice', 'probabilities', 'confidence'],
  kindScore: ['score', 'probabilities', 'confidence', 'legend'],
  kindNoul: ['noul'],
};

/// Checks one wire answer against its compiled question, as Genkit Go and
/// JS do when their generate loop validates the output against its schema.
/// Genkit Dart's loop only parses the output, so the check is made here: the
/// kind's own field is present and of its type, a choice is one of the
/// question's options, a noul is a probability, and the optional
/// distribution and confidence are numbers. A score outside the rubric is
/// clamped below, as Go clamps it, rather than refused.
void _checkAnswer(String id, WireQuestion q, Map<String, Object?> answer) {
  Never fail(String what) => throw GenkitException(
    'systemone: answer for question "$id" $what',
    status: StatusCode.internal,
  );
  bool isNumber(Object? v) => v is num && v.isFinite;
  switch (q.type) {
    case kindChoice:
      final choice = answer['choice'];
      if (choice is! String) fail('has no choice');
      final options = q.criteria;
      if (options is Map && !options.containsKey(choice)) {
        fail('chose "$choice", which is not one of its options');
      }
    case kindScore:
      if (!isNumber(answer['score'])) fail('has no numeric score');
    case kindNoul:
      final noul = answer['noul'];
      if (!isNumber(noul)) fail('has no numeric noul');
      if ((noul as num) < 0 || noul > 1) {
        fail('has noul $noul, which is not a probability');
      }
  }
  if (answer.containsKey('confidence') &&
      answer['confidence'] != null &&
      !isNumber(answer['confidence'])) {
    fail('has a confidence that is not a number');
  }
  if (q.type != kindNoul && answer['probabilities'] != null) {
    final p = answer['probabilities'];
    if (p is! Map || p.values.any((v) => !isNumber(v))) {
      fail('has probabilities that are not numbers by option');
    }
  }
}

/// Renders the answers as the message text: for the enum format the chosen
/// option itself, otherwise a JSON object keyed by question ID whose values
/// are the answers projected onto the fields the output type declares.
///
/// A score's legend is rebuilt from the rubric's strings: for a level sent
/// with guidance the API echoes the guidance, which the legend's strings
/// cannot hold. A score is clamped to the rubric, since float rounding in the
/// expected level can land a hair past the top level.
String answersText(
  DecideResponse resp,
  Map<String, WireQuestion> questions, {
  required bool enumFormat,
}) {
  final answers = <String, Map<String, Object?>>{};
  for (final MapEntry(key: id, value: q) in questions.entries) {
    final answer = resp.answers[id];
    if (answer == null) {
      throw GenkitException(
        'systemone: no answer for question "$id"',
        status: StatusCode.internal,
      );
    }
    _checkAnswer(id, q, answer);
    final projected = <String, Object?>{
      for (final field in _answerFields[q.type] ?? const <String>[])
        if (answer.containsKey(field)) field: answer[field],
    };
    if (q.labels case final labels?) {
      projected['legend'] = q.legend();
      if (projected['score'] case final num score) {
        projected['score'] = math.min(
          math.max(score.toDouble(), 0.0),
          (labels.length - 1).toDouble(),
        );
      }
    }
    answers[id] = projected;
  }
  if (enumFormat) {
    final choice = answers[enumQuestionId]?['choice'];
    if (choice is! String || choice.isEmpty) {
      throw GenkitException(
        'systemone: the enum answer names no option',
        status: StatusCode.internal,
      );
    }
    return choice;
  }
  return jsonEncode(answers);
}
