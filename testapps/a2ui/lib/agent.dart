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
///
/// This sample also demonstrates a **custom catalog**: [weatherCatalog] extends
/// the bundled basic catalog with a bespoke `Gauge` component. The catalog
/// tells the model what it may render; the Flutter client registers a matching
/// `Gauge` widget under the same id (see `lib/main.dart`) so the surface renders
/// to a real widget.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

import 'shared.dart';

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
final Genkit ai = Genkit(plugins: [googleAI(), A2uiPlugin(), RetryPlugin()]);

/// The app's custom A2UI catalog.
///
/// A catalog is just the list of components the model is allowed to render,
/// each with a short, model-facing description of its props. Here we start from
/// the bundled [basicCatalog] (Text, Card, Column, Button, ...) and add one
/// bespoke component, `Gauge`, that has no basic-catalog equivalent. The
/// matching `Gauge` *widget* is registered on the client under the same
/// [weatherCatalogId] (see `lib/main.dart`).
///
/// Because the middleware validates emitted surfaces against this catalog (see
/// `a2ui(validate: 'strict')` below), the model can only reference components
/// listed here - so `Gauge` is both advertised to the model and enforced.
final A2uiCatalog weatherCatalog = A2uiCatalog(
  id: weatherCatalogId,
  components: [
    // Reuse everything the bundled basic catalog offers...
    ...basicCatalog.components,
    // ...plus one component of our own. The description and `props` line are
    // what the model sees; keep them concise and concrete.
    const A2uiCatalogComponent(
      name: 'Gauge',
      description:
          'A circular gauge that visualizes a single numeric value within a '
          'range (e.g. temperature or humidity). Prefer this over plain text '
          'for a headline metric.',
      props:
          'value: number or { path } binding (required); min?: number '
          '(default 0); max?: number (default 100); label?: string; unit?: '
          'string (e.g. "°C" or "%").',
    ),
  ],
);

/// Registers [weatherCatalog] on the Genkit registry so `a2ui(catalog: ...)`
/// can resolve it by id. Call this once at startup (see `bin/server.dart`)
/// before the agent handles a turn.
///
/// [loadCatalog] is the documented way to register a catalog; you can also load
/// one from a JSON file with `loadCatalog(ai.registry, id: ..., file: ...)`.
Future<void> registerCatalogs() =>
    loadCatalog(ai, id: weatherCatalogId, catalog: weatherCatalog);

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
    return .response(
      GetWeatherOutput(
        city: input.city,
        tempC: (10 + (seed % 20)).toDouble(),
        condition: conditions[seed % conditions.length],
        humidity: 40 + (seed % 50),
      ),
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
      'summarizing it (temperature, condition, humidity). Use the custom '
      'Gauge component for the headline temperature (e.g. min -10, max 40, '
      'unit "°C") and consider a second Gauge for humidity (min 0, max 100, '
      'unit "%"). Feel free to add a Button (e.g. "Refresh") when useful.',
  tools: [getWeather],
  // Point the middleware at our custom catalog by id, and use strict
  // validation so any surface referencing a component outside the catalog
  // fails fast during development.
  use: [
    a2ui(catalog: weatherCatalogId, validate: 'strict'),
    retry(),
  ],
  store: InMemorySessionStore(),
);
