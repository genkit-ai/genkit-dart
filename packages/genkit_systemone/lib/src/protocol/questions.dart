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

/// The System One protocol's questions: the schema keywords a question set
/// rides on, and the compiler that reads them back into wire questions.
///
/// Internal to the package; the question types callers declare decisions
/// with are in `questions.dart`.
library;

import 'package:genkit/plugin.dart';

// The schema keywords a question is encoded with. The output schema is the
// one channel the generate loop hands a model besides the messages, so the
// question set rides on it: each property is one question, its description is
// the instructions, and these keywords carry what plain JSON Schema has no
// keyword for. [compileQuestions] reads them back.

/// Marks a property as a question and names its type.
const kindKeyword = 'x-systemone';

/// Carries a score question's ordered level descriptions.
const levelsKeyword = 'x-levels';

/// Carries a noul question's optional yes criteria.
const trueKeyword = 'x-true';

/// Carries a noul question's optional no criteria.
const falseKeyword = 'x-false';

/// Carries a question's structured guidance, keyed as on the wire: by option,
/// by level index, or by "true" and "false".
const guidanceKeyword = 'x-guidance';

/// Carries a runtime question's instructions when they are structured rather
/// than text, which a description cannot hold.
const instructionsKeyword = 'x-instructions';

/// The question types, as the API names them.
const kindChoice = 'choice';
const kindScore = 'score';
const kindNoul = 'noul';

/// Names the one question an enum-format request asks.
const enumQuestionId = 'choice';

/// One question on the wire.
final class WireQuestion {
  WireQuestion({
    required this.type,
    required this.instructions,
    this.criteria,
    this.labels,
  });

  /// `choice`, `score`, or `noul`.
  final String type;

  /// The question's text, or the structured value a runtime question gives,
  /// after the preamble.
  final Object? instructions;

  /// The options and their descriptions for a choice question, in order; a
  /// map of side to description for a noul question; and an ordered list of
  /// level descriptions for a score question. A description is a string, or
  /// the guidance that replaces it on the wire.
  final Object? criteria;

  /// A score question's level strings, which the legend is built from
  /// whatever form the levels take on the wire. Not sent.
  final List<String>? labels;

  /// The legend of a score: each level number to its label.
  Map<String, String> legend() => {
    for (final (i, label) in (labels ?? const <String>[]).indexed) '$i': label,
  };

  Map<String, Object?> toJson() => {
    'type': type,
    'instructions': instructions,
    'criteria': ?criteria,
  };
}

GenkitException _invalidSchema(String message) =>
    GenkitException('systemone: $message', status: StatusCode.invalidArgument);

/// Reads the questions an output schema encodes: one per property, each
/// marked with the `x-systemone` keyword the answer types emit.
///
/// A property without the marker is rejected, since the model has no way to
/// answer a shape it does not know. The [preamble], the request's system
/// text, goes in front of every question's own instructions, followed by the
/// schema's own description when it has one, as it is for the enum format.
///
/// The questions come back keyed by ID in sorted order, which is the order
/// they go on the wire.
Map<String, WireQuestion> compileQuestions(
  Map<String, dynamic> schema,
  String preamble,
) {
  final root = resolveRef(schema, schema);
  final props = _map(root['properties']);
  if (props == null || props.isEmpty) {
    throw _invalidSchema(
      'the output schema has no properties; each question is a field of the '
      'output type',
    );
  }
  final description = root['description'];
  preamble = joinInstructions(
    preamble,
    description is String ? description : '',
  );
  final questions = <String, WireQuestion>{};
  for (final id in props.keys.toList()..sort()) {
    final prop = resolveRef(_map(props[id]) ?? const {}, schema);
    final kind = prop[kindKeyword];
    if (kind is! String || kind.isEmpty) {
      throw _invalidSchema(
        'field "$id" is not a question; use a Choice, ScoreOf, or Noul field',
      );
    }
    final instructions = _questionInstructions(id, prop, preamble);
    questions[id] = switch (kind) {
      kindChoice => WireQuestion(
        type: kind,
        instructions: instructions,
        criteria: _choiceCriteria(id, prop),
      ),
      kindScore => _scoreQuestion(id, prop, instructions),
      kindNoul => WireQuestion(
        type: kind,
        instructions: instructions,
        criteria: _noulCriteria(id, prop),
      ),
      _ => throw _invalidSchema('question "$id" has unknown type "$kind"'),
    };
  }
  return questions;
}

/// Follows a `$ref` into the root's `$defs`, and unwraps an `allOf` of one
/// schema, which is how a registered type reaches a model: schemantic emits
/// its root as a reference, and a described nested type as `allOf`.
Map<String, dynamic> resolveRef(
  Map<String, dynamic> schema,
  Map<String, dynamic> root,
) {
  var current = schema;
  for (var depth = 0; depth < 16; depth++) {
    final ref = current[r'$ref'];
    if (ref is String && ref.startsWith(r'#/$defs/')) {
      final defs = _map(root[r'$defs']);
      final target = _map(defs?[ref.substring(r'#/$defs/'.length)]);
      if (target == null) {
        throw _invalidSchema(
          'the output schema references "$ref", which it does not define',
        );
      }
      current = {
        ...target,
        // Siblings of the reference, such as a description, win.
        for (final e in current.entries)
          if (e.key != r'$ref') e.key: e.value,
      };
      continue;
    }
    final allOf = current['allOf'];
    if (allOf is List && allOf.length == 1 && _map(allOf.first) != null) {
      current = {
        ..._map(allOf.first)!,
        for (final e in current.entries)
          if (e.key != 'allOf') e.key: e.value,
      };
      continue;
    }
    return current;
  }
  throw _invalidSchema('the output schema references itself');
}

/// Reads a question's instructions: the structured value a runtime question
/// carries on the x-instructions keyword, or the property's description. The
/// preamble goes in front: as a paragraph of the text, as the first element
/// of a list, or as the first element beside any other structured value.
Object? _questionInstructions(
  String id,
  Map<String, dynamic> prop,
  String preamble,
) {
  final structured = prop[instructionsKeyword];
  if (structured != null) {
    if (preamble.isEmpty) return structured;
    if (structured is List) return [preamble, ...structured];
    return [preamble, structured];
  }
  final text = prop['description'];
  if (text is! String || text.isEmpty) {
    throw _invalidSchema(
      'question "$id" has no instructions; give the field a description, or '
      'instructions to a runtime question',
    );
  }
  return joinInstructions(preamble, text);
}

/// Reads the options back out of the oneOf a Choice emits, in order, with
/// the guidance of an option in place of its string. An option with neither
/// is described by its own name, since the wire format takes a description
/// per option and some gateways reject a null one.
Map<String, Object?> _choiceCriteria(String id, Map<String, dynamic> prop) {
  final choice = _map(_map(prop['properties'])?['choice']);
  final oneOf = choice?['oneOf'];
  if (oneOf is! List || oneOf.isEmpty) {
    throw _invalidSchema('choice question "$id" lists no options');
  }
  final guidance = _map(prop[guidanceKeyword]) ?? const {};
  final options = <String, Object?>{};
  for (final raw in oneOf) {
    final key = _map(raw)?['const'];
    if (key is! String || key.isEmpty) {
      throw _invalidSchema(
        'choice question "$id" has an option without a const',
      );
    }
    if (options.containsKey(key)) {
      throw _invalidSchema('choice question "$id" lists option "$key" twice');
    }
    final description = _map(raw)?['description'];
    final value = withWhat(
      guidance[key],
      description is String ? description : '',
    );
    options[key] = value == '' ? key : value;
  }
  for (final key in guidance.keys.toList()..sort()) {
    if (!options.containsKey(key)) {
      throw _invalidSchema(
        'choice question "$id" has guidance for "$key", which is not one of '
        'its options',
      );
    }
  }
  return options;
}

/// Reads the ordered levels off the x-levels keyword, with the guidance of a
/// level in place of its string, and keeps the strings for the legend. The
/// API takes two to ten levels; the lower bound is checked here because one
/// level is not a scale, the upper bound is the API's to enforce.
WireQuestion _scoreQuestion(
  String id,
  Map<String, dynamic> prop,
  Object? instructions,
) {
  final raw = prop[levelsKeyword];
  final levels = raw is List ? raw : const <Object?>[];
  if (levels.any((l) => l is! String)) {
    throw _invalidSchema(
      'score question "$id" has a level that is not a string',
    );
  }
  final labels = levels.cast<String>().toList();
  if (labels.length < 2) {
    throw _invalidSchema('score question "$id" needs at least two levels');
  }
  final criteria = <Object?>[...labels];
  final guidance = _map(prop[guidanceKeyword]) ?? const {};
  for (final key in guidance.keys.toList()..sort()) {
    final i = int.tryParse(key);
    if (i == null || i < 0 || i >= labels.length) {
      throw _invalidSchema(
        'score question "$id" has guidance for level $key, which its rubric '
        'does not have',
      );
    }
    criteria[i] = withWhat(guidance[key], labels[i]);
  }
  return WireQuestion(
    type: kindScore,
    instructions: instructions,
    criteria: criteria,
    labels: labels,
  );
}

/// Reads the optional true and false criteria a NoulOf emits, with the
/// guidance of a side in place of its string. They are sent as a pair or not
/// at all: the API describes the pair, and one side alone would leave the
/// other implied. No criteria is null, so the field stays absent rather than
/// null, which the gateways reject.
Map<String, Object?>? _noulCriteria(String id, Map<String, dynamic> prop) {
  final guidance = _map(prop[guidanceKeyword]) ?? const {};
  final criteria = <String, Object?>{};
  for (final (side, keyword) in [
    ('true', trueKeyword),
    ('false', falseKeyword),
  ]) {
    final text = prop[keyword];
    final value = withWhat(guidance[side], text is String ? text : '');
    if (value != '') criteria[side] = value;
  }
  return switch (criteria.length) {
    0 => null,
    1 => throw _invalidSchema(
      'noul question "$id" says what only one side means; give both yes and '
      'no, as criteria or guidance',
    ),
    _ => criteria,
  };
}

/// A description as it goes on the wire: the guidance when there is some,
/// the string otherwise. An object with no "what" gets the string as its
/// what, so guidance adds to the description rather than replacing it; any
/// other guidance is sent as it is.
Object? withWhat(Object? guidance, String description) {
  if (guidance == null) return description;
  if (guidance is Map) {
    if (guidance.containsKey('what') || description.isEmpty) return guidance;
    return {...guidance, 'what': description};
  }
  return guidance;
}

/// Turns an enum output schema into a single choice question, so the enum
/// output format works on the model with no decision type.
///
/// The instructions are the preamble, the request's system text, followed by
/// the schema's description when it has one; the options keep the order the
/// values were given in, and an option's description is its own name, since
/// an enum carries none.
Map<String, WireQuestion> enumQuestion(
  Map<String, dynamic>? schema,
  String preamble,
) {
  final root = schema == null ? null : resolveRef(schema, schema);
  final values = root?['enum'];
  if (values is! List || values.any((v) => v is! String || v.isEmpty)) {
    throw _invalidSchema('enum output values must be non-empty strings');
  }
  if (values.isEmpty) {
    throw _invalidSchema('the enum output schema lists no values');
  }
  final options = <String, Object?>{};
  for (final v in values.cast<String>()) {
    if (options.containsKey(v)) {
      throw _invalidSchema('the enum output schema lists "$v" twice');
    }
    options[v] = v;
  }
  final description = root?['description'];
  var instructions = joinInstructions(
    preamble,
    description is String ? description : '',
  );
  if (instructions.isEmpty) {
    instructions = 'Choose the option that best describes the state.';
  }
  return {
    enumQuestionId: WireQuestion(
      type: kindChoice,
      instructions: instructions,
      criteria: options,
    ),
  };
}

/// Puts the preamble in front of a question's own text as two paragraphs, or
/// returns whichever of the two is present.
String joinInstructions(String preamble, String text) {
  if (preamble.isEmpty) return text;
  if (text.isEmpty) return preamble;
  return '$preamble\n\n$text';
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;
