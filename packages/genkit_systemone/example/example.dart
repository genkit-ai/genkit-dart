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

// Decisions: asking a System One model typed questions about a state and
// getting calibrated answers back, instead of asking a chat model for prose
// and parsing it. The model is TypeSafe's jev, through OpenRouter's Decisions
// API.
//
//   - triageFlow asks three questions of one ticket in a single call and
//     routes it in code, behind a confidence gate.
//   - teamFlow is the enum output format on the same model: the system
//     message is the question, the enum values are the options.
//   - toolFlow picks the tool an agent should call from a list built at run
//     time, and asks the user instead when the pick is not clear.
//
// Thresholds live in code next to the questions. The model returns
// probabilities; what to do at 0.6 is the application's decision.
//
// Run it with an OpenRouter key:
//
//   export OPENROUTER_API_KEY=...
//   dart run example/example.dart
//
// Or with the Dev UI, to call the flows from a browser and read a trace of
// every run, with the question set on the model request and the full
// distributions on the response:
//
//   genkit start -- dart run example/example.dart

// genkit exports an evaluator `Score`; System One's rubric answer is
// `ScoreOf`, so hiding it is only needed when an app names both.
import 'package:genkit/genkit.dart';
import 'package:genkit_systemone/genkit_systemone.dart';

/// The option set of a choice. The criteria belong to the type: they are
/// what the model chooses among on every call that asks for a Dept, and a
/// catch-all option keeps the model from forcing a fit.
enum Dept with Option {
  billing('Payments, invoicing, refunds, duplicate charges'),
  technical('Bugs, outages, integrations, login problems'),
  sales('Pricing, upgrades, new accounts'),
  other('None of the above');

  const Dept(this.criteria);

  @override
  final String criteria;

  /// Guidance adds structure where a string is not enough. The wire format
  /// takes an object per option; this one says what billing does not cover,
  /// since a question about a delivery mentions an order and reads as billing
  /// otherwise. The criteria string becomes its "what".
  @override
  Object? get guidance => switch (this) {
    billing => {
      'not_for': 'Where an order is, or when it arrives',
      'examples': [
        'I was charged twice for one order.',
        'My invoice shows a plan I never picked.',
      ],
    },
    _ => null,
  };
}

/// The rubric of a score, lowest level first. The answer is the expected
/// level, so it falls between two when the model is split.
enum Frustration with Rubric {
  calm('Calm and neutral'),
  concerned('Concerned but civil'),
  angry('Very angry or using strong language');

  const Frustration(this.description);

  @override
  final String description;
}

/// What yes and no mean for a yes/no question. Like a rubric, the pair is a
/// type, so every decision that asks the question shares it.
final class Urgent extends YesNo {
  const Urgent();

  @override
  String get yes => 'Names a deadline, or says now or today';

  @override
  String get no => 'No time pressure is expressed';
}

/// The decision: one question per field, answered in one call.
final class Triage {
  Triage(this.department, this.isUrgent, this.frustration);

  final Choice<Dept> department;
  final NoulOf<Urgent> isUrgent;
  final ScoreOf<Frustration> frustration;

  static final $schema = decisionSchema(
    {
      'department': Choice.schema(
        Dept.values,
        description: 'Which team should handle this?',
      ),
      'is_urgent': NoulOf.schema(
        const Urgent(),
        description: 'Does the ticket explicitly communicate time pressure?',
      ),
      'frustration': ScoreOf.schema(
        Frustration.values,
        description: 'How frustrated is the customer?',
      ),
    },
    (a) => Triage(
      a['department'] as Choice<Dept>,
      a['is_urgent'] as NoulOf<Urgent>,
      a['frustration'] as ScoreOf<Frustration>,
    ),
  );
}

void main() {
  final decisions = SystemOne.openRouter(); // OPENROUTER_API_KEY
  final ai = Genkit(plugins: [decisions]);

  // Pin a version: thresholds tuned against one release do not carry over to
  // the next, and SystemOneInfo.of(response).model says which one answered.
  final jev = decisions.modelRef('typesafe/jev-1.13');

  ai.defineFlow(
    name: 'triageFlow',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (ticket, _) async {
      final result = await ai.generate(
        model: jev,
        system: 'The state is a customer support ticket.',
        prompt: ticket,
        outputSchema: Triage.$schema,
      );
      final triage = result.output!;
      // The caller owns thresholds.
      if (triage.department.confidence < 0.6) return 'route to a human';
      final queue = triage.isUrgent.probability > 0.8 ? 'priority' : 'normal';
      return '${triage.department.choice.name} ($queue), customer is '
          '${triage.frustration.label.toLowerCase()}, answered by '
          '${SystemOneInfo.of(result.modelResponse).model}';
    },
  );

  ai.defineFlow(
    name: 'teamFlow',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (ticket, _) async {
      final result = await ai.generate(
        model: jev,
        system: 'Which team should handle this ticket?',
        prompt: ticket,
        outputFormat: 'enum',
        outputSchema: .string(enumValues: ['billing', 'technical', 'sales']),
      );
      return result.text;
    },
  );

  ai.defineFlow(
    name: 'toolFlow',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (request, _) async {
      // Known only at run time, as the tools on hand are.
      final tools = {
        'calendar': 'Create, move, or cancel meetings and events',
        'mail': 'Read, search, or send email',
        'weather': 'Forecasts and current conditions',
      };
      final result = await ai.generate(
        model: jev,
        prompt: request,
        outputSchema: questionsSchema({
          'tool': ChoiceQuestion(
            instructions: 'Which tool serves the request?',
            options: [
              for (final MapEntry(:key, :value) in tools.entries)
                ChoiceOption(key, criteria: value),
            ],
          ),
        }),
      );
      final pick = result.output!['tool']!;
      return pick.confidence >= 0.8
          ? 'call ${pick.choice}'
          : 'ask the user: did you mean ${pick.choice}?';
    },
  );
}
