# A2UI sample (server + Flutter client)

A complete, runnable sample of [A2UI](https://a2ui.org/) with Genkit Dart, split
into two packages:

- **`server/`**: a plain `dart:io` HTTP server hosting an A2UI-enabled Genkit
  agent. The whole A2UI integration is the `a2ui()` middleware from
  `package:genkit_a2ui/a2ui.dart` in the agent's `use` list. It is a member of
  the root pub workspace.
- **`client/`**: a Flutter app that streams the agent with `remoteAgent` and
  renders each surface with
  [`a2ui_flutter`](https://pub.dev/packages/a2ui_flutter) (an `a2ui_core`
  `MessageProcessor` plus an `A2uiSurface` widget per surface). Button presses
  and form submits are sent back to the agent as the next turn.

The client deliberately does **not** depend on `genkit_a2ui`. A2UI travels as
spec-shaped data parts, so the client needs only `package:genkit`,
`a2ui_flutter`, `a2ui_core`, and the two helpers in
`client/lib/a2ui_helpers.dart` (copied from the `genkit_a2ui` README). That way
the server package's dependencies can never constrain which renderer version
the client uses. It is also why the two halves are separate packages: pub
resolves a whole package at once, so a shared pubspec would pull the server's
dependencies into the client.

It also demonstrates a **custom catalog**: a bespoke `Gauge` component that is
not part of the bundled basic catalog. See ["Custom catalog"](#custom-catalog)
below.

## Prerequisites

- Flutter SDK.
- A Gemini API key in `GEMINI_API_KEY`.

## Run

1. Start the agent server (terminal 1). Run `dart pub get` once at the
   repository root, then:

   ```sh
   cd testapps/a2ui/server
   dart run build_runner build --delete-conflicting-outputs
   GEMINI_API_KEY=your-key dart run bin/server.dart
   ```

   It listens on `http://localhost:8080` and mounts the agent at `/api/uiAgent`.

2. Run the Flutter client (terminal 2):

   ```sh
   cd testapps/a2ui/client
   flutter pub get
   flutter run -d chrome
   ```

   Point it at a different server with
   `--dart-define=AGENT_BASE_URL=http://host:port`.

The client's widget tests (`flutter test` in `client/`) render a surface from
canned messages, so they need neither the server nor an API key.

## Try it

- "What's the weather in Tokyo?" renders a weather card.
- "Show the weather in Tokyo with a gauge." renders the custom `Gauge`
  component (see below).
- "Compare the weather in London, Paris and Rome." renders a comparison.
- "Give me a short signup form (name and email) with a submit button." renders
  a form; submitting sends the entered values back to the agent.

## How it fits together

- The `a2ui()` middleware turns the model's UI blocks into a2ui `data` parts
  (`{"messages": [...]}`, mime `application/a2ui+json`) on both the streamed
  chunks and the final message.
- The client reads those messages with `a2uiMessagesFrom` and feeds each to a
  `MessageProcessor`, which creates and updates the surfaces. The client
  catalog has the same catalog id the agent uses, so surfaces resolve to real
  widgets.
- The renderer reports a button press as a spec-shaped `{version, action}`
  message. `a2uiActionToMessage` forwards it untouched as the next turn, and
  the middleware summarizes it for the model.

## Custom catalog

By default the `a2ui()` middleware uses the bundled **basic catalog** (Text,
Card, Column, Button, ...). This sample instead ships its own catalog that adds
a bespoke `Gauge` component. A catalog has two halves that must agree on a
catalog id (here `com.example.a2ui.weather`, in each package's
`lib/shared.dart`):

- **Server** (`server/lib/agent.dart`): `weatherCatalog` is the model-facing
  half. The middleware injects it into the system prompt so the model knows
  `Gauge` exists, and validates that emitted surfaces only reference components
  in the catalog. `registerCatalogs()` (called from `server/bin/server.dart`)
  registers it with `loadCatalog(...)`, and the agent selects it with
  `a2ui(catalog: weatherCatalogId, validate: 'strict')`.
- **Client** (`client/lib/gauge.dart` + `client/lib/catalog.dart`): `gauge` is
  an a2ui_flutter `ComponentImplementation` (a `name`, a prop `schema`, and a
  `builder` that paints the gauge). `catalog.dart` lists it next to the basic
  components in a `CatalogImplementation` under the same id.

The `name` on both sides (`'Gauge'`) and the catalog id must match, otherwise the
model would emit a `Gauge` the client can't render, or the client would register
widgets under an id no surface references.
