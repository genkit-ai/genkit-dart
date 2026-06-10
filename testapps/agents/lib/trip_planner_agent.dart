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

/// Prompt-file agent — demonstrates `definePromptAgent`.
///
/// Ported from the JS `trip-planner-agent.ts`. The prompt template lives in
/// `prompts/tripPlanner.prompt` (dotprompt) and references tools declared here.
/// `definePromptAgent` wires the prompt file into a multi-turn agent without an
/// inline prompt configuration.
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'trip_planner_agent.g.dart';

@Schema()
abstract class $GetAttractionsInput {
  String get city;
}

@Schema()
abstract class $Attraction {
  String get name;
  String get description;
}

@Schema()
abstract class $GetAttractionsOutput {
  List<$Attraction> get attractions;
}

@Schema()
abstract class $GetFlightInfoInput {
  String get from;
  String get to;
  String? get date;
}

@Schema()
abstract class $Flight {
  String get airline;
  String get departure;
  String get arrival;
  String get price;
}

@Schema()
abstract class $GetFlightInfoOutput {
  List<$Flight> get flights;
}

const _attractionData = <String, List<List<String>>>{
  'paris': [
    ['Eiffel Tower', 'Iconic iron lattice tower'],
    ['Louvre Museum', 'World-renowned art museum'],
    ['Notre-Dame Cathedral', 'Medieval Catholic cathedral'],
  ],
  'tokyo': [
    ['Senso-ji Temple', 'Ancient Buddhist temple'],
    ['Shibuya Crossing', 'Famous busy intersection'],
    ['Meiji Shrine', 'Shinto shrine in a forest'],
  ],
};

final getAttractions = ai.defineTool(
  name: 'getAttractions',
  description: 'Get popular tourist attractions for a given city.',
  inputSchema: GetAttractionsInput.$schema,
  outputSchema: GetAttractionsOutput.$schema,
  fn: (input, _) async {
    final key = input.city.toLowerCase();
    final data = _attractionData[key];
    final attractions = data != null
        ? data.map((a) => Attraction(name: a[0], description: a[1])).toList()
        : [
            Attraction(
              name: '${input.city} Central Park',
              description: 'A lovely park in the city center',
            ),
            Attraction(
              name: '${input.city} History Museum',
              description: 'Learn about the local history',
            ),
          ];
    return GetAttractionsOutput(attractions: attractions);
  },
);

final getFlightInfo = ai.defineTool(
  name: 'getFlightInfo',
  description:
      'Get mock flight information between two cities on a given date.',
  inputSchema: GetFlightInfoInput.$schema,
  outputSchema: GetFlightInfoOutput.$schema,
  fn: (input, _) async => GetFlightInfoOutput(
    flights: [
      Flight(
        airline: 'SkyAir',
        departure: '08:00',
        arrival: '11:30',
        price: r'$350',
      ),
      Flight(
        airline: 'GlobalJet',
        departure: '14:15',
        arrival: '17:45',
        price: r'$420',
      ),
    ],
  ),
);

/// Wired from the `prompts/tripPlanner.prompt` file via `definePromptAgent`.
final tripPlannerAgent = ai.definePromptAgent(
  promptName: 'tripPlanner',
  store: InMemorySessionStore(),
);
