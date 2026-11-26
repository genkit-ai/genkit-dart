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

import 'package:genkit_systemone/genkit_systemone.dart';
import 'package:schemantic/schemantic.dart';

enum Dept with Option {
  technical('Bugs, outages, integrations'),
  billing('Payments, invoicing, refunds'),
  other('None of the above');

  const Dept(this.criteria);

  @override
  final String criteria;

  @override
  Object? get guidance => switch (this) {
    billing => {
      'not_for': 'Where an order is, or when it arrives',
      'examples': ['I was charged twice for one order.'],
    },
    _ => null,
  };
}

enum Anger with Rubric {
  calm('Calm'),
  concerned('Concerned but civil'),
  angry('Very angry');

  const Anger(this.description);

  @override
  final String description;

  @override
  Object? get guidance => switch (this) {
    angry => {
      'signals': ['all caps', 'threats to leave'],
    },
    _ => null,
  };
}

final class Urgent extends YesNo {
  const Urgent();

  @override
  String get yes => 'Names a deadline, or says now or today';

  @override
  String get no => 'No time pressure is expressed';
}

final class Triage {
  Triage(this.department, this.isUrgent, this.frustration, this.deadline);

  final Choice<Dept> department;
  final Noul isUrgent;
  final ScoreOf<Anger> frustration;
  final NoulOf<Urgent> deadline;

  static final SchemanticType<Triage> $schema = decisionSchema(
    {
      'department': Choice.schema(
        Dept.values,
        description: 'Which team should handle this?',
      ),
      'is_urgent': Noul.schema(
        description: 'Does the ticket explicitly communicate time pressure?',
      ),
      'frustration': ScoreOf.schema(
        Anger.values,
        description: 'How frustrated is the customer?',
      ),
      'deadline': NoulOf.schema(
        const Urgent(),
        description: 'Is there a deadline?',
      ),
    },
    (a) {
      return Triage(
        a['department'] as Choice<Dept>,
        a['is_urgent'] as Noul,
        a['frustration'] as ScoreOf<Anger>,
        a['deadline'] as NoulOf<Urgent>,
      );
    },
  );
}
