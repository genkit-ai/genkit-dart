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

/// Shared Genkit instance + the A2UI-enabled agent for the sample.
///
/// The whole A2UI integration is the `a2ui()` middleware in the agent's `use`
/// list; `A2uiPlugin()` is registered on the Genkit instance so the reference
/// resolves. The API key is read from the `GEMINI_API_KEY` environment variable
/// by the `googleAI()` plugin.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'agent.g.dart';

@Schema()
abstract class $GetWeatherInput {
  @Field(description: 'The city to get the weather for.')
  String get city;
}

@Schema()
abstract class $GetWeatherOutput {
  String get city;
  double get tempC;
  String get condition;
  int get humidity;
}

/// The shared Genkit instance. `A2uiPlugin()` registers the `a2ui()` middleware.
final Genkit ai = Genkit(plugins: [googleAI(), A2uiPlugin()]);

/// A demo tool the model can call to fetch (fake) weather data.
final getWeather = ai.defineTool(
  name: 'getWeather',
  description: 'Gets the current weather for a given city.',
  inputSchema: GetWeatherInput.$schema,
  outputSchema: GetWeatherOutput.$schema,
  fn: (input, _) async {
    // Deterministic pseudo-values so the demo is stable per-city.
    final seed = input.city.codeUnits.fold<int>(0, (a, c) => a + c);
    const conditions = ['Sunny', 'Partly cloudy', 'Rainy', 'Windy', 'Foggy'];
    return GetWeatherOutput(
      city: input.city,
      tempC: (10 + (seed % 20)).toDouble(),
      condition: conditions[seed % conditions.length],
      humidity: 40 + (seed % 50),
    );
  },
);

/// The A2UI-enabled agent. The whole integration is `a2ui()` in `use`. An
/// [InMemorySessionStore] makes state server-managed, so the client only needs
/// to pass a session id (handled for it by `remoteAgent`).
final uiAgent = ai.defineAgent(
  name: 'uiAgent',
  model: googleAI.gemini('gemini-flash-latest'),
  system:
      'You are a helpful assistant that can render rich UI. Prefer rendering '
      'an A2UI surface whenever a result is clearer shown than told - for '
      'example weather, comparisons, lists, forms, or anything interactive. '
      'Keep any prose brief; put the substance in the UI. When asked about '
      'weather, call the getWeather tool, then render a nice Card/Column '
      'summarizing it (temperature, condition, humidity). Feel free to add a '
      'Button (e.g. "Refresh") when useful.',
  tools: [getWeather],
  use: [a2ui()],
  store: InMemorySessionStore(),
);
