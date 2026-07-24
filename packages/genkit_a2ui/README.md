# genkit_a2ui

A Genkit Dart plugin that adds [A2UI](https://a2ui.org/) ("Agent to UI") - a
transport-agnostic, JSON-based **streaming UI protocol** - to Genkit agents.

An A2UI-enabled agent can stream not just prose, but rich, interactive UI
**surfaces** that a client renders incrementally.

> Status: experimental.

## Design principle: one representation

A2UI rides on its own part channel - a Genkit `data` part carrying the mime type
`application/a2ui+json` whose `data` is `{ "envelopes": [...] }`, an **array of
A2UI envelope messages**. This maps onto the A2A binding of the A2UI spec.

- A **mixed** turn is a message whose content is `[textPart, a2uiPart, ...]`.
- A **pure-surface** turn is the special case with no text parts.
- Downstream consumers (the client transport, `genui`) only ever see a2ui parts.

## Server: the `a2ui()` middleware

The whole server-side integration is the `a2ui()` model middleware. Register
`A2uiPlugin` in `Genkit(plugins: [...])`, then add `a2ui()` to an agent's (or a
one-shot `generate`'s) `use` list. Nothing else changes.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

final ai = Genkit(
  plugins: [GoogleGenerativeAI(), A2uiPlugin()],
);

final uiAgent = ai.defineAgent(
  name: 'uiAgent',
  model: googleAI.model('gemini-flash-latest'),
  system: 'You help users. Render UI when it is clearer than prose.',
  use: [a2ui()], // <- A2UI support (defaults to the bundled 'basic' catalog)
);
```

Works the same on a one-shot generate:

```dart
final res = await ai.generate(
  model: googleAI.model('gemini-flash-latest'),
  prompt: 'Show me the weather in Tokyo',
  use: [a2ui()],
);
```

> Unlike the JS plugin, Dart middleware is resolved by name from the registry, so
> you must register `A2uiPlugin()` in `Genkit(plugins: [...])` before referencing
> it via `a2ui()` in `use`.

### Options

| Option         | Default    | Description                                                                                                   |
| -------------- | ---------- | ------------------------------------------------------------------------------------------------------------ |
| `catalog`      | `'basic'`  | The id of the catalog describing what the agent may render.                                                   |
| `instructions` | `'system'` | Where to inject catalog capabilities. `'none'` injects nothing.                                               |
| `validate`     | `'warn'`   | Validate emitted envelopes against the catalog. `'warn'` logs and drops bad blocks; `'strict'` throws; `'off'` skips checking. |
| `surfaceId`    | UUID       | A fixed surface id to reuse for every surface (defaults to a fresh UUID per surface).                         |
| `version`      | `'v0.9'`   | Protocol version stamped on envelopes.                                                                        |

The middleware injects the catalog's capabilities into the system prompt, then
intercepts model output (streamed chunks **and** the final message), extracts
`a2ui` fenced blocks, validates them, and rewrites them into a2ui data parts.

### Catalogs

`catalog` is a **catalog id** resolved from the Genkit registry. The bundled `'basic'` catalog is the default and needs no registration.

To define and use a custom catalog (e.g., matching your own layout elements and design system), you can register it with `loadCatalog` and reference it by id.

#### Catalog Format & Structure

An A2UI catalog describes the list of visual or interactive components that the model is allowed to emit. It consists of:
- `id`: A globally unique URI identifying the catalog (used as `catalogId` on `createSurface`).
- `components`: An array of components, where each component contains:
  - `name`: The component type name, matching the renderer type (e.g. `CustomCard`, `Text`).
  - `description`: A clear, one-line summary of what the component is and when to use it.
  - `props`: A compact, model-facing text description of its properties (kept as a simple, human-readable string to minimize system prompt token usage).

#### Option A: Load from a JSON File
Create a JSON file (e.g., `./my-catalog.json`) following this format:

```json
{
  "id": "https://my-app.org/catalogs/custom.json",
  "components": [
    {
      "name": "Banner",
      "description": "Displays a prominent alert banner at the top of a section.",
      "props": "title: string (required); severity?: info|warning|error."
    },
    {
      "name": "Text",
      "description": "Displays a plain or inline-markdown text run.",
      "props": "text: string (required); variant?: body|caption."
    }
  ]
}
```

Then register it under a lookup identifier (e.g. `'my-catalog'`) on the server:

```dart
import 'package:genkit_a2ui/a2ui.dart';

await loadCatalog(
  ai.registry,
  id: 'my-catalog',
  file: './my-catalog.json',
);
```

#### Option B: In-Memory Definition
You can construct and register an `A2uiCatalog` directly in-memory using pure Dart:

```dart
import 'package:genkit_a2ui/a2ui.dart';

final myCatalog = A2uiCatalog(
  id: 'https://my-app.org/catalogs/custom.json',
  components: [
    const A2uiCatalogComponent(
      name: 'Banner',
      description: 'Displays a prominent alert banner at the top of a section.',
      props: 'title: string (required); severity?: info|warning|error.',
    ),
    const A2uiCatalogComponent(
      name: 'Text',
      description: 'Displays a plain or inline-markdown text run.',
      props: 'text: string (required); variant?: body|caption.',
    ),
  ],
);

await loadCatalog(
  ai.registry,
  id: 'my-catalog',
  catalog: myCatalog,
);
```

#### Utilizing the Registered Catalog in Agents

Once registered, reference your catalog lookup id in your `a2ui()` options:

```dart
final uiAgent = ai.defineAgent(
  name: 'uiAgent',
  model: googleAI.model('gemini-flash-latest'),
  use: [a2ui(catalog: 'my-catalog')],
);
```

Catalogs are stored in the Genkit registry (under the `a2ui-catalog` value type) so the middleware can dynamically resolve them.

## Client

`package:genkit_a2ui/client.dart` is browser/Flutter-safe (no `dart:io`). Consume
the agent with `remoteAgent` from `package:genkit/client.dart`, pull A2UI
envelopes off each chunk's content with `a2uiEnvelopesFromParts`, and feed them
to a renderer such as [`genui`](https://pub.dev/packages/genui):

```dart
import 'package:genkit/client.dart';
import 'package:genkit_a2ui/client.dart';

final agent = remoteAgent(url: '/api/uiAgent');
final chat = agent.chat();
final turn = chat.sendStream(text: 'weather in Tokyo');
await for (final chunk in turn.stream) {
  final envelopes = a2uiEnvelopesFromParts(chunk.raw.modelChunk?.content);
  if (envelopes.isNotEmpty) {
    // Convert each envelope map to a genui A2uiMessage and hand it to a
    // SurfaceController (see testapps/a2ui for a complete example).
  }
}
```

### Sending user actions back to the agent

When the user interacts with a surface (e.g. presses a `Button`), the renderer
emits an action. Turn it into an agent input with `actionToMessage` and send it
as the next turn:

```dart
import 'package:genkit_a2ui/client.dart';

final message = actionToMessage(
  A2uiClientAction(
    name: 'refresh',
    surfaceId: surfaceId,
    sourceComponentId: 'refreshBtn',
    timestamp: DateTime.now().toIso8601String(),
    context: {'city': 'Tokyo'},
  ),
);
final turn = chat.sendStream(message: message);
```

The action's `name` is sent as the user message; the full action (including its
`context`) is attached as an a2ui data part so the agent can react to it.

**Forms:** input components (`TextField`, `CheckBox`, `Slider`) do **not** send
their values automatically. To capture what the user entered, the model must
(1) bind each input's `value` to a data-model path (`{ "path": "/email" }`) and
(2) echo those same paths in the submit `Button`'s `action.event.context`. The
catalog capabilities injected into the system prompt already instruct the model
to do this.

See `testapps/a2ui` for a complete runnable sample (a shelf server hosting an
agent, plus a Flutter client that renders surfaces with `genui`).

## License

Apache-2.0
