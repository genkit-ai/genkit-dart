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

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'protocol/questions.dart';

/// The options of a [Choice]: an enum whose constants are the options, each
/// with what it means.
///
/// The criteria are what the model chooses among, so they belong to the type
/// rather than to any one call. An option's name on the wire is the
/// constant's `name`. [guidance] adds the structured form of a
/// description the wire format also takes, such as examples per option.
/// Options known only at run time are asked with a [ChoiceQuestion] instead.
///
/// ```dart
/// enum Dept with Option {
///   billing('Payments, invoicing, refunds'),
///   technical('Bugs, outages, integrations'),
///   other('None of the above');
///
///   const Dept(this.criteria);
///
///   @override
///   final String criteria;
/// }
/// ```
///
/// Preview: this API may change in any minor release.
@experimental
mixin Option on Enum {
  /// What the option means.
  String get criteria;

  /// The structured form of [criteria] on the wire: any JSON value, most
  /// often an object with labeled parts, such as `what`, `not_for`, and
  /// `examples`. [criteria] stays what the schema and the answers show;
  /// guidance replaces it on the wire only.
  ///
  /// An object with no `what` key gets [criteria] as its `what`, so guidance
  /// adds to the description rather than replacing it. Any other value is
  /// sent as it is. Null, the default, keeps the string.
  Object? get guidance => null;
}

/// The levels of a [ScoreOf]: an enum whose constants are the levels, lowest
/// first. A level's index is its number on the wire, so a three-level rubric
/// scores 0 to 2.
///
/// ```dart
/// enum Frustration with Rubric {
///   calm('Calm and neutral'),
///   concerned('Concerned but civil'),
///   angry('Very angry or using strong language');
///
///   const Frustration(this.description);
///
///   @override
///   final String description;
/// }
/// ```
///
/// Preview: this API may change in any minor release.
@experimental
mixin Rubric on Enum {
  /// What the level means.
  String get description;

  /// The structured form of [description] on the wire, such as a summary and
  /// signals for the level, as [Option.guidance] is for an option.
  /// [ScoreOf.legend] and [ScoreOf.label] keep [description].
  Object? get guidance => null;
}

/// What yes and no mean for a [NoulOf] question, as the criteria of a
/// [Choice] and the levels of a [ScoreOf] come from their types.
///
/// Both sides are given: the API takes the pair or nothing. The guidance of
/// a side replaces its string on the wire, as [Option.guidance] does; each
/// side needs a string or guidance, or neither does.
///
/// ```dart
/// final class Urgent extends YesNo {
///   const Urgent();
///
///   @override
///   String get yes => 'Names a deadline, or says now or today';
///
///   @override
///   String get no => 'No time pressure is expressed';
/// }
/// ```
///
/// Preview: this API may change in any minor release.
@experimental
abstract class YesNo {
  const YesNo();

  /// What a yes means.
  String get yes;

  /// What a no means.
  String get no;

  /// The structured form of [yes] on the wire.
  Object? get yesGuidance => null;

  /// The structured form of [no] on the wire.
  Object? get noGuidance => null;
}

/// The [YesNo] of a plain [Noul]: the question is its description alone.
///
/// Preview: this API may change in any minor release.
final class NoCriteria extends YesNo {
  const NoCriteria();

  @override
  String get yes => '';

  @override
  String get no => '';
}

/// The answer to a choice question: one option of [T], the probability of
/// every option, and how concentrated that distribution is.
///
/// As a question of a decision it is also the question: [Choice.schema]
/// takes the options, `Dept.values`, and the question's instructions. The
/// options go out sorted by name, as they do in Genkit Go and Java.
///
/// Preview: this API may change in any minor release.
@experimental
final class Choice<T extends Option> {
  Choice({
    required this.choice,
    Map<T, double> probabilities = const {},
    required this.confidence,
  }) : probabilities = Map.unmodifiable(probabilities);

  /// The option with the most of the probability.
  final T choice;

  /// The model's distribution over the options, which sums to 1. Empty when
  /// the answer carries none.
  final Map<T, double> probabilities;

  /// How concentrated the distribution is, from 0 to 1.
  final double confidence;

  /// The question that asks for one of [options], with [description] as its
  /// instructions, and parses its answer.
  static SchemanticType<Choice<T>> schema<T extends Option>(
    List<T> options, {
    String? description,
  }) {
    final sorted = [...options]..sort((a, b) => a.name.compareTo(b.name));
    final byName = {for (final o in options) o.name: o};
    return _QuestionType(
      withInstructions(
        choiceSchema([
          for (final o in sorted)
            ChoiceOption(o.name, criteria: o.criteria, guidance: o.guidance),
        ]),
        description,
      ),
      (json) {
        final map = _object(json, 'choice');
        T option(Object? name) =>
            byName[name] ??
            (throw FormatException('"$name" is not one of the options'));
        // A probability for a name the enum does not have is left out: the
        // map is keyed by the enum, and Go keeps such keys in its map rather
        // than failing the decision.
        return Choice(
          choice: option(map['choice']),
          probabilities: {
            for (final e in _object(
              map['probabilities'] ?? const {},
              'probabilities',
            ).entries)
              ?byName[e.key]: _number(e.value, 'probability'),
          },
          confidence: _optionalNumber(map['confidence']),
        );
      },
    );
  }

  /// The options from most to least likely, ties broken by name. Empty when
  /// the answer carries no distribution.
  List<T> get ranked => probabilities.keys.toList()
    ..sort((a, b) {
      final byProbability = probabilities[b]!.compareTo(probabilities[a]!);
      return byProbability != 0 ? byProbability : a.name.compareTo(b.name);
    });

  /// The probability gap between the two most likely options: how decisive
  /// the choice is, where [confidence] reads the whole distribution. Zero
  /// with fewer than two options in the distribution.
  double get margin {
    final r = ranked;
    if (r.length < 2) return 0;
    return probabilities[r[0]]! - probabilities[r[1]]!;
  }

  Map<String, Object?> toJson() => {
    'choice': choice.name,
    if (probabilities.isNotEmpty)
      'probabilities': {
        for (final e in probabilities.entries) e.key.name: e.value,
      },
    'confidence': confidence,
  };

  @override
  String toString() => 'Choice${toJson()}';
}

/// The answer to a rubric question: the expected level, computed from the
/// probability of each level, so it falls between levels when the model is
/// split.
///
/// [probabilities] is that distribution, keyed by level number; [confidence],
/// from 0 to 1, is how concentrated it is; [legend] maps each level number
/// back to its description, from [L] even when the level was sent with
/// guidance. [ScoreOf.schema] takes the levels, `Frustration.values`, and the
/// question's instructions.
///
/// Genkit Go and Java call this type `Score`. Here that name is the core
/// `genkit` evaluator's, which every app imports.
///
/// Preview: this API may change in any minor release.
@experimental
final class ScoreOf<L extends Rubric> {
  ScoreOf({
    required this.levels,
    required this.score,
    Map<String, double> probabilities = const {},
    this.confidence = 0,
    Map<String, String> legend = const {},
  }) : probabilities = Map.unmodifiable(probabilities),
       legend = Map.unmodifiable(legend);

  /// The rubric, lowest level first.
  final List<L> levels;

  /// The expected level, from 0 to the top level's number.
  final double score;

  /// The probability of each level, keyed by level number.
  final Map<String, double> probabilities;

  /// How concentrated the distribution is, from 0 to 1.
  final double confidence;

  /// Each level number's description.
  final Map<String, String> legend;

  /// The question that rates the state on [levels], lowest first, with
  /// [description] as its instructions, and parses its answer.
  static SchemanticType<ScoreOf<L>> schema<L extends Rubric>(
    List<L> levels, {
    String? description,
  }) {
    final rubric = List<L>.unmodifiable(levels);
    return _QuestionType(
      withInstructions(
        scoreSchema(
          [for (final l in rubric) l.description],
          {
            for (final (i, l) in rubric.indexed)
              if (l.guidance != null) i: l.guidance,
          },
        ),
        description,
      ),
      (json) {
        final map = _object(json, 'score');
        return ScoreOf(
          levels: rubric,
          score: _number(map['score'], 'score'),
          probabilities: {
            for (final e in _object(
              map['probabilities'] ?? const {},
              'probabilities',
            ).entries)
              e.key: _number(e.value, 'probability'),
          },
          confidence: _optionalNumber(map['confidence']),
          legend: {
            for (final e in _object(
              map['legend'] ?? const {},
              'legend',
            ).entries)
              e.key: '${e.value}',
          },
        );
      },
    );
  }

  /// The nearest whole level's number, clamped to the rubric.
  int get level {
    if (levels.isEmpty) return 0;
    return math.min(math.max(score.round(), 0), levels.length - 1);
  }

  /// The rubric's description of [level]. It comes from [L], so it does not
  /// depend on the answer carrying a legend.
  String get label => levels.isEmpty ? '' : levels[level].description;

  Map<String, Object?> toJson() => {
    'score': score,
    if (probabilities.isNotEmpty) 'probabilities': probabilities,
    'confidence': confidence,
    if (legend.isNotEmpty) 'legend': legend,
  };

  @override
  String toString() => 'ScoreOf${toJson()}';
}

/// The answer to a yes/no question whose criteria come from [C]: the
/// probability that the statement is true.
///
/// A value near 0.5 means the model could not tell, not that the answer is
/// "somewhat". There is no separate confidence; the probability is the whole
/// answer. [NoulOf.schema] takes the criteria and the question's
/// instructions; [Noul] is the question with no criteria.
///
/// Preview: this API may change in any minor release.
@experimental
final class NoulOf<C extends YesNo> {
  NoulOf(this.probability);

  /// The probability that the statement is true, from 0 to 1.
  final double probability;

  /// The question that asks whether a statement is true, with [criteria]
  /// saying what yes and no mean and [description] as its instructions, and
  /// parses its answer.
  static SchemanticType<NoulOf<C>> schema<C extends YesNo>(
    C criteria, {
    String? description,
  }) => _QuestionType(
    withInstructions(
      noulSchema(
        criteria.yes,
        criteria.no,
        criteria.yesGuidance,
        criteria.noGuidance,
      ),
      description,
    ),
    (json) => NoulOf<C>(_probability(json)),
  );

  Map<String, Object?> toJson() => {'noul': probability};

  @override
  String toString() => 'Noul{probability: $probability}';
}

/// A [NoulOf] with no criteria: the question is its description alone, which
/// is the usual yes/no question.
///
/// Preview: this API may change in any minor release.
@experimental
final class Noul extends NoulOf<NoCriteria> {
  Noul(super.probability);

  /// The question that asks whether a statement is true, with [description]
  /// as its instructions, and parses its answer.
  static SchemanticType<Noul> schema({String? description}) => _QuestionType(
    withInstructions(noulSchema('', '', null, null), description),
    (json) => Noul(_probability(json)),
  );
}

double _probability(Object? json) =>
    _number(_object(json, 'noul')['noul'], 'noul');

/// A number the answer must carry, or a [FormatException] naming it.
double _number(Object? value, String field) => value is num
    ? value.toDouble()
    : throw FormatException('the answer\'s $field is not a number: $value');

/// A number the answer may leave out, read as 0 when it does, as Go decodes
/// a missing field.
double _optionalNumber(Object? value) => value is num ? value.toDouble() : 0;

Map<String, Object?> _object(Object? json, String what) {
  if (json is! Map) {
    throw FormatException('a $what answer must be a JSON object, got $json');
  }
  return json.cast<String, Object?>();
}

/// A question's schema with the parse of its answer.
final class _QuestionType<T> extends SchemanticType<T> {
  const _QuestionType(this._schema, this._parse);

  final Map<String, Object?> _schema;
  final T Function(Object? json) _parse;

  @override
  T parse(Object? json) => _parse(json);

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      _deepCopy(_schema) as Map<String, Object?>;
}

/// The schema of a decision: one question per property, each answered under
/// its key, with [parse] building the decision from the parsed answers.
///
/// Built by [decisionSchema].
final class _DecisionType<T> extends SchemanticType<T> {
  _DecisionType(this._questions, this._parse, this._description);

  final Map<String, SchemanticType<Object?>> _questions;
  final T Function(Map<String, Object?> answers) _parse;
  final String? _description;

  @override
  T parse(Object? json) {
    final map = _object(json, 'decision');
    final answers = {
      for (final e in _questions.entries)
        e.key: e.value.parse(
          map.containsKey(e.key)
              ? map[e.key]
              : throw FormatException('no answer for question "${e.key}"'),
        ),
    };
    try {
      return _parse(answers);
      // The build function casts each answer to its question's type; a cast
      // that fails means the decision's map and its build disagree.
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      throw FormatException(
        'the decision${_description == null ? '' : ' "$_description"'} '
        'cannot be built from its answers: $e',
      );
    }
  }

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) => {
    'type': 'object',
    'description': ?_description,
    'properties': {
      for (final e in _questions.entries) e.key: e.value.jsonSchema(),
    },
    'required': _questions.keys.toList(),
    'additionalProperties': false,
  };
}

/// The output schema of a decision: one question per entry of [questions],
/// each answered under its key, and [parse] building the decision from the
/// answers, which come keyed the same way and parsed by their questions.
///
/// This is the Dart form of a Go decision struct: the output type is the
/// question set, so a decision is one typed generate call. [description], if
/// given, follows the system message in front of every question's
/// instructions.
///
/// ```dart
/// final class Triage {
///   Triage(this.department, this.isUrgent, this.frustration);
///
///   final Choice<Dept> department;
///   final Noul isUrgent;
///   final ScoreOf<Frustration> frustration;
///
///   static final $schema = decisionSchema(
///     {
///       'department': Choice.schema(Dept.values,
///           description: 'Which team should handle this?'),
///       'is_urgent': Noul.schema(
///           description: 'Does the ticket explicitly communicate time pressure?'),
///       'frustration': ScoreOf.schema(Frustration.values,
///           description: 'How frustrated is the customer?'),
///     },
///     (a) => Triage(
///       a['department'] as Choice<Dept>,
///       a['is_urgent'] as Noul,
///       a['frustration'] as ScoreOf<Frustration>,
///     ),
///   );
/// }
/// ```
///
/// Preview: this API may change in any minor release.
@experimental
SchemanticType<T> decisionSchema<T>(
  Map<String, SchemanticType<Object?>> questions,
  T Function(Map<String, Object?> answers) parse, {
  String? description,
}) => _DecisionType(Map.unmodifiable(questions), parse, description);

/// One question of a set built at run time, for questions whose options,
/// levels, or instructions come from data: the tools or products on hand, the
/// nodes of a taxonomy, a tenant's own categories.
///
/// [ChoiceQuestion], [ScoreQuestion], and [NoulQuestion] are the kinds, and
/// [questionsSchema] turns a set of them into an output schema. A question
/// known when the code is written reads better as a question of a
/// [decisionSchema].
///
/// Preview: this API may change in any minor release.
@experimental
sealed class Question {
  const Question();

  /// The question: a string, or any JSON value, such as an object that names
  /// the field of the state the question is about.
  Object? get instructions;

  Map<String, Object?> _schema();
}

/// Asks for one of its [options], which go out in the order given.
///
/// Preview: this API may change in any minor release.
@experimental
final class ChoiceQuestion extends Question {
  const ChoiceQuestion({required this.instructions, required this.options});

  @override
  final Object? instructions;

  final List<ChoiceOption> options;

  @override
  Map<String, Object?> _schema() =>
      withInstructions(choiceSchema(options), instructions);
}

/// One option of a [ChoiceQuestion]: the [name] that is the answer when it
/// is chosen, what it means, and optionally the structured form of that
/// meaning, as [Option.guidance] gives it for a [Choice]. An option with
/// neither criteria nor guidance is described by its name.
///
/// Preview: this API may change in any minor release.
@experimental
final class ChoiceOption {
  const ChoiceOption(this.name, {this.criteria = '', this.guidance});

  final String name;
  final String criteria;
  final Object? guidance;
}

/// Rates the state on its [levels], lowest first, as a [Rubric] gives them,
/// with [guidance] keyed by level index as [Rubric.guidance] gives it.
///
/// Preview: this API may change in any minor release.
@experimental
final class ScoreQuestion extends Question {
  const ScoreQuestion({
    required this.instructions,
    required this.levels,
    this.guidance = const {},
  });

  @override
  final Object? instructions;

  final List<String> levels;
  final Map<int, Object?> guidance;

  @override
  Map<String, Object?> _schema() =>
      withInstructions(scoreSchema(levels, guidance), instructions);
}

/// Asks whether a statement is true, with what yes and no mean as a [YesNo]
/// gives them for a [NoulOf]: each side needs a string or guidance, or
/// neither does.
///
/// Preview: this API may change in any minor release.
@experimental
final class NoulQuestion extends Question {
  const NoulQuestion({
    required this.instructions,
    this.yes = '',
    this.no = '',
    this.yesGuidance,
    this.noGuidance,
  });

  @override
  final Object? instructions;

  final String yes;
  final String no;
  final Object? yesGuidance;
  final Object? noGuidance;

  @override
  Map<String, Object?> _schema() => withInstructions(
    noulSchema(yes, no, yesGuidance, noGuidance),
    instructions,
  );
}

/// The output schema that asks the given [questions], each answered under
/// its key, read back as a map of [Answer].
///
/// ```dart
/// final result = await ai.generate(
///   model: SystemOne.typeSafe().modelRef('jev-1.13.0'),
///   prompt: request,
///   outputSchema: questionsSchema({
///     'tool': ChoiceQuestion(
///       instructions: 'Which tool serves the request?',
///       options: [for (final t in tools) ChoiceOption(t.name, criteria: t.description)],
///     ),
///   }),
/// );
/// final tool = result.output!['tool']!.choice;
/// ```
///
/// Genkit Go calls this `Schema`, and Java `SystemOne.schema`; here `Schema`
/// is schemantic's annotation.
///
/// Preview: this API may change in any minor release.
@experimental
SchemanticType<Map<String, Answer>> questionsSchema(
  Map<String, Question> questions,
) {
  final ids = questions.keys.toList()..sort();
  final schema = <String, Object?>{
    'type': 'object',
    'properties': {for (final id in ids) id: questions[id]!._schema()},
    'required': ids,
    'additionalProperties': false,
  };
  return SchemanticType.from(
    jsonSchema: schema,
    parse: (json) => {
      for (final e in _object(json, 'decision').entries)
        e.key: Answer.fromJson(_object(e.value, 'question')),
    },
    serialize: (answers) => {
      for (final e in answers.entries) e.key: e.value.toJson(),
    },
  );
}

/// The answer to a question of a [questionsSchema], with the fields of its
/// kind set.
///
/// [type] names the kind: `choice` sets [choice], [probabilities] over the
/// options, and [confidence]; `score` sets [score], [probabilities] keyed by
/// level number, [confidence], and [legend]; `noul` sets [probability] alone.
/// They mean what the same fields of [Choice], [ScoreOf], and [NoulOf] mean.
///
/// Preview: this API may change in any minor release.
@experimental
final class Answer {
  const Answer({
    this.type = '',
    this.choice = '',
    this.score = 0,
    this.probability = 0,
    this.probabilities = const {},
    this.confidence = 0,
    this.legend = const {},
  });

  /// Decodes an answer. A missing type is read from the field every answer of
  /// a kind carries: choice, score, or noul.
  factory Answer.fromJson(Map<String, Object?> json) {
    var type = json['type'] is String ? json['type'] as String : '';
    if (type.isEmpty) {
      type = [
        kindChoice,
        kindScore,
        kindNoul,
      ].firstWhere(json.containsKey, orElse: () => '');
    }
    return Answer(
      type: type,
      choice: json['choice'] is String ? json['choice'] as String : '',
      score: _optionalNumber(json['score']),
      probability: _optionalNumber(json['noul']),
      probabilities: {
        if (json['probabilities'] case final Map p)
          for (final e in p.entries)
            '${e.key}': _number(e.value, 'probability'),
      },
      confidence: _optionalNumber(json['confidence']),
      legend: {
        if (json['legend'] case final Map l)
          for (final e in l.entries) '${e.key}': '${e.value}',
      },
    );
  }

  final String type;
  final String choice;
  final double score;
  final double probability;
  final Map<String, double> probabilities;
  final double confidence;
  final Map<String, String> legend;

  /// Writes the fields of the answer's kind, zeros included, so a score of 0
  /// survives a round trip, and none of another kind's. An answer with no
  /// type writes its non-empty fields.
  Map<String, Object?> toJson() => switch (type) {
    kindChoice => {
      'type': type,
      'choice': choice,
      'probabilities': ?(probabilities.isEmpty ? null : probabilities),
      'confidence': confidence,
    },
    kindScore => {
      'type': type,
      'score': score,
      'probabilities': ?(probabilities.isEmpty ? null : probabilities),
      'confidence': confidence,
      'legend': ?(legend.isEmpty ? null : legend),
    },
    kindNoul => {'type': type, 'noul': probability},
    _ => {
      if (type.isNotEmpty) 'type': type,
      if (choice.isNotEmpty) 'choice': choice,
      if (score != 0) 'score': score,
      if (probability != 0) 'noul': probability,
      if (probabilities.isNotEmpty) 'probabilities': probabilities,
      if (confidence != 0) 'confidence': confidence,
      if (legend.isNotEmpty) 'legend': legend,
    },
  };

  @override
  String toString() => 'Answer${toJson()}';
}

/// Encodes a choice question's options, in order, with the guidance any of
/// them carries.
Map<String, Object?> choiceSchema(List<ChoiceOption> options) {
  final guidance = <String, Object?>{
    for (final o in options)
      if (o.guidance != null) o.name: o.guidance,
  };
  return _answerSchema(
    kindChoice,
    {
      'choice': {
        'type': 'string',
        'oneOf': [
          for (final o in options)
            {
              'const': o.name,
              if (o.criteria.isNotEmpty) 'description': o.criteria,
            },
        ],
      },
      'probabilities': _probabilitiesSchema,
      'confidence': {'type': 'number'},
    },
    'choice',
    guidance: guidance,
  );
}

/// Encodes a score question's ordered levels and the guidance keyed by level
/// index. The level descriptions ride on the x-levels keyword, since a
/// fractional score cannot be a oneOf of levels.
Map<String, Object?> scoreSchema(
  List<String> levels,
  Map<int, Object?> guidance,
) => {
  ..._answerSchema(
    kindScore,
    {
      'score': {
        'type': 'number',
        'minimum': 0,
        'maximum': math.max(levels.length - 1, 0),
      },
      'probabilities': _probabilitiesSchema,
      'confidence': {'type': 'number'},
      'legend': {
        'type': 'object',
        'additionalProperties': {'type': 'string'},
      },
    },
    'score',
    guidance: {
      for (final e in guidance.entries)
        if (e.value != null) '${e.key}': e.value,
    },
  ),
  levelsKeyword: [...levels],
};

/// Encodes a noul question with its optional criteria and guidance for each
/// side.
Map<String, Object?> noulSchema(
  String yes,
  String no,
  Object? yesGuidance,
  Object? noGuidance,
) => {
  ..._answerSchema(
    kindNoul,
    {
      'noul': {'type': 'number', 'minimum': 0, 'maximum': 1},
    },
    'noul',
    guidance: {'true': ?yesGuidance, 'false': ?noGuidance},
  ),
  if (yes.isNotEmpty || no.isNotEmpty) ...{trueKeyword: yes, falseKeyword: no},
};

/// Puts a question's instructions on its schema: text as the description,
/// and any other value on the x-instructions keyword.
Map<String, Object?> withInstructions(
  Map<String, Object?> schema,
  Object? instructions,
) => {
  ...schema,
  if (instructions is String)
    'description': instructions
  else
    instructionsKeyword: ?instructions,
};

const _probabilitiesSchema = {
  'type': 'object',
  'additionalProperties': {'type': 'number'},
};

/// The object schema shared by the answer types. It is closed: the model
/// projects a wire answer onto exactly these fields.
Map<String, Object?> _answerSchema(
  String kind,
  Map<String, Object?> properties,
  String required, {
  Map<String, Object?> guidance = const {},
}) => {
  'type': 'object',
  'properties': properties,
  'required': [required],
  'additionalProperties': false,
  kindKeyword: kind,
  if (guidance.isNotEmpty) guidanceKeyword: guidance,
};

Object? _deepCopy(Object? value) => switch (value) {
  Map() => <String, Object?>{
    for (final e in value.entries) '${e.key}': _deepCopy(e.value),
  },
  List() => [for (final v in value) _deepCopy(v)],
  _ => value,
};
