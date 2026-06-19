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

/// Trip planner — agent wired from a `.prompt` file.
///
/// Ported from the JS `TripPlanner.tsx`.
library;

import 'package:jaspr/jaspr.dart';

import 'streaming_chat_page.dart';

class TripPlannerPage extends StatelessComponent {
  const TripPlannerPage({super.key});

  @override
  Component build(BuildContext context) {
    return const StreamingChatPage(
      endpoint: '/api/tripPlannerAgent',
      title: 'Trip Planner',
      description:
          'A prompt-file (dotprompt) agent. Suggests attractions and looks up '
          'flights using tools.',
      suggestions: [
        'I want to plan a trip to Paris. What should I see there?',
        'Find me flights from London to Tokyo.',
        'What are the top attractions in Tokyo?',
      ],
    );
  }
}
