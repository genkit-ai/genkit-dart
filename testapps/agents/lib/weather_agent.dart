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

/// Weather agent — multi-turn streaming chat with tool calling.
///
/// Ported from the JS `weather-agent.ts`. This agent uses a [FileSessionStore]
/// (server-managed state) so sessions persist to disk across runs. Tool calls
/// and multi-turn session threading work identically.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'weather_agent.g.dart';

@Schema()
abstract class $GetWeatherInput {
  String get location;
}

@Schema()
abstract class $GetWeatherOutput {
  String get weather;
  String get temperature;
}

/// A simple mock weather lookup tool, shared by the weather agents.
final getWeather = ai.defineTool(
  name: 'getWeather',
  description: 'Get the current weather for a given location.',
  inputSchema: GetWeatherInput.$schema,
  outputSchema: GetWeatherOutput.$schema,
  fn: (input, _) async => GetWeatherOutput(
    weather: 'Sunny in ${input.location}',
    temperature: '71F',
  ),
);

/// The weather agent — server-managed state via a file-backed store.
final weatherAgent = ai.defineAgent(
  name: 'weatherAgent',
  system:
      'You are an assistant helping with weather information. Use the '
      'getWeather tool.',
  use: [retry()],
  tools: [getWeather],
  store: FileSessionStore('.sessions'),
);
