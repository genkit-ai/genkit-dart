# A2UI sample (server + Flutter genui client)

A complete, runnable sample of [A2UI](https://a2ui.org/) with Genkit Dart:

- **Server** (`bin/server.dart`): a shelf HTTP server hosting an A2UI-enabled
  Genkit agent. The whole A2UI integration is the `a2ui()` middleware from
  `package:genkit_a2ui/a2ui.dart` in the agent's `use` list.
- **Client** (`lib/main.dart`): a Flutter app that streams the agent with
  `remoteAgent`, pulls A2UI envelopes off each chunk with `a2uiEnvelopes`, and
  renders each surface with the [`genui`](https://pub.dev/packages/genui)
  renderer (`SurfaceController` + `Surface`). Button presses and form submits are
  sent back to the agent as the next turn.

It also demonstrates a **custom catalog**: a bespoke `Gauge` component that is
not part of the bundled basic catalog. See ["Custom catalog"](#custom-catalog)
below.


This is a Flutter package, so it lives outside the root pub workspace (like
`testapps/flutter_genai`) and uses `path:` dependencies on the local packages.

## Prerequisites

- Flutter SDK.
- A Gemini API key in `GEMINI_API_KEY`.

## Run

1. Install dependencies and generate the tool schema:

   ```sh
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

2. Start the agent server (terminal 1):

   ```sh
   GEMINI_API_KEY=your-key dart run bin/server.dart
   ```

   It listens on `http://localhost:8080` and mounts the agent at `/api/uiAgent`.

3. Run the Flutter client (terminal 2):

   ```sh
   flutter run -d chrome
   ```

   Point it at a different server with
   `--dart-define=AGENT_BASE_URL=http://host:port`.

## Try it

- "What's the weather in Tokyo?" — renders a weather card.
- "Show the weather in Tokyo with a gauge." — renders the custom `Gauge`
  component (see below).
- "Compare the weather in London, Paris and Rome." — renders a comparison.
- "Give me a short signup form (name and email) with a submit button." — renders
  a form; submitting sends the entered values back to the agent.

## How it fits together

- The agent emits ` ```a2ui ` fenced JSON blocks. The `a2ui()` middleware
  extracts, validates, and rewrites them into a2ui `data` parts
  (`{ "envelopes": [...] }`, mime `application/a2ui+json`) on both the streamed
  chunks and the final message.
- The client converts each envelope map to a genui `A2uiMessage`
  (`A2uiMessage.fromJson`) and feeds it to a `SurfaceController`. The client
  catalog is tagged with the same catalog id the agent uses, so surfaces resolve
  to real widgets.

## Custom catalog

By default the `a2ui()` middleware uses the bundled **basic catalog** (Text,
Card, Column, Button, ...). This sample instead ships its own catalog that adds
a bespoke `Gauge` component. A catalog has two halves that must agree on a
catalog id (here `com.example.a2ui.weather`, defined once in `lib/shared.dart`):

- **Server** (`lib/agent.dart`): `weatherCatalog` is an `A2uiCatalog` built from
  `basicCatalog.components` plus one `A2uiCatalogComponent` describing `Gauge`
  (its name, a one-line description, and a plain-text `props` line). This is the
  model-facing half: the middleware injects it into the system prompt so the
  model knows `Gauge` exists, and validates that emitted surfaces only reference
  components in the catalog. `registerCatalogs()` (called from
  `bin/server.dart`) registers it with `loadCatalog(...)`, and the agent selects
  it with `a2ui(catalog: weatherCatalogId, validate: 'strict')`.
- **Client** (`lib/gauge.dart` + `lib/main.dart`): `gaugeCatalogItem` is a genui
  `CatalogItem` (a `name`, a prop `dataSchema`, and a `widgetBuilder` that paints
  the gauge). `main.dart` adds it to genui's basic widgets and re-tags the whole
  catalog with the same id
  (`BasicCatalogItems.asCatalog().copyWith(newItems: [gaugeCatalogItem],
  catalogId: weatherCatalogId)`).

The `name` on both sides (`'Gauge'`) and the catalog id must match, otherwise the
model would emit a `Gauge` the client can't render, or the client would register
widgets under an id no surface references.

