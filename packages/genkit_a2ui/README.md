[![Pub](https://img.shields.io/pub/v/genkit_a2ui.svg)](https://pub.dev/packages/genkit_a2ui)

# genkit_a2ui

A Genkit Dart plugin that brings [A2UI](https://a2ui.org/) ("Agent to UI"), a
transport-agnostic, JSON-based streaming UI protocol, to Genkit agents.

An A2UI-enabled agent can stream more than prose. It streams rich, interactive UI
**surfaces** (cards, lists, forms, buttons) that a client renders incrementally
as the model responds. The whole server-side integration is a single model
middleware: add `a2ui()` to an agent's `use` list and nothing else changes.

[Documentation](https://genkit.dev) • [API Reference](https://pub.dev/packages/genkit_a2ui) • [A2UI Specification](https://a2ui.org/)

![An A2UI weather card rendered by a Flutter genui client.](https://raw.githubusercontent.com/genkit-ai/genkit-dart/main/packages/genkit_a2ui/doc/a2ui.png)

> Status: experimental.

## Installation

Add the plugin to your project:

```bash
dart pub add genkit_a2ui
```

To render surfaces you also need a renderer. The Dart examples below use
[`genui`](https://pub.dev/packages/genui), the Flutter renderer for A2UI
surfaces. Add it to your client (Flutter) app:

```bash
flutter pub add genui
```

## Quickstart

### 1. Add the middleware on the server

Add `a2ui()` to your agent's `use` list. That is the entire server-side setup.

Unlike the JS plugin, Dart middleware is resolved by name from the registry, so
you must register `A2uiPlugin()` in `Genkit(plugins: [...])` before referencing
it via `a2ui()`.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

final ai = Genkit(
  plugins: [googleAI(), A2uiPlugin()],
);

final uiAgent = ai.defineAgent(
  name: 'uiAgent',
  model: googleAI.gemini('gemini-flash-latest'),
  system: 'You help users. Render UI when it is clearer than prose.',
  use: [a2ui()], // <- A2UI support (defaults to the bundled 'basic' catalog)
);
```

It works the same on a one-shot `generate`:

```dart
final res = await ai.generate(
  model: googleAI.gemini('gemini-flash-latest'),
  prompt: 'Show me the weather in Tokyo',
  use: [a2ui()],
);
```

### 2. Render surfaces on the client

`package:genkit_a2ui/client.dart` is browser/Flutter-safe (no `dart:io`). Consume
the agent with `remoteAgent` from `package:genkit/client.dart`, pull A2UI
envelopes off each chunk's content with `a2uiEnvelopesFromParts`, and feed them
to a renderer such as [`genui`](https://pub.dev/packages/genui):

```dart
import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genkit/client.dart';
import 'package:genkit_a2ui/client.dart';
import 'package:genui/genui.dart' hide basicCatalogId;

final agent = remoteAgent(url: '/api/uiAgent');
final chat = agent.chat();

// genui otherwise registers an empty stub for an unknown catalog id, so re-tag
// its basic catalog with the id the plugin's bundled basic catalog advertises.
final catalog = BasicCatalogItems.asCatalog().copyWith(
  catalogId: basicCatalogId,
);
final surfaceController = SurfaceController(catalogs: [catalog]);

final turn = chat.sendStream(text: 'weather in Tokyo');
await for (final chunk in turn.stream) {
  for (final envelope in a2uiEnvelopesFromParts(chunk.raw.modelChunk?.content)) {
    surfaceController.handleMessage(core.A2uiMessage.fromJson(envelope));
  }
}
```

> See
> [`testapps/a2ui`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/a2ui)
> for a complete, runnable sample: a shelf server hosting the agent, plus a
> Flutter client that renders surfaces with `genui`.

## Options

Pass options to `a2ui()` to control the catalog, prompt injection, and
validation:

| Option         | Default    | Description                                                                                                                     |
| -------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `catalog`      | `'basic'`  | The id of the catalog describing what the agent may render.                                                                    |
| `instructions` | `'system'` | Where to inject catalog capabilities. `'none'` injects nothing.                                                                |
| `validate`     | `'warn'`   | Validate emitted envelopes against the catalog. `'warn'` logs and drops bad blocks; `'strict'` throws; `'off'` skips checking. |
| `surfaceId`    | fresh UUID | Surface id policy. Defaults to a new UUID per surface; pass a fixed string to reuse one id for every surface.                  |
| `version`      | `'v0.9'`   | Protocol version stamped on envelopes.                                                                                         |

## Handling user actions

When a user interacts with a surface (for example, presses a `Button`), the
renderer emits an action. Turn it into an agent input with `actionToMessage` and
send it as the next turn:

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

### Forms

Input components (`TextField`, `CheckBox`, `Slider`) do **not** send their values
automatically. To capture what the user entered, the model must:

1. Bind each input's `value` to a data-model path (`{ "path": "/email" }`).
2. Echo those same paths in the submit `Button`'s `action.event.context`.

The catalog capabilities injected into the system prompt already instruct the
model to do this. Without both steps, the action arrives with an empty `context`.

### Renderer requirements

genui registers an empty stub for a catalog id it does not recognize, so surfaces
created by the agent would render as blanks. Re-tag genui's basic catalog with the
plugin's `basicCatalogId` so surfaces resolve to real widgets:

```dart
final catalog = BasicCatalogItems.asCatalog().copyWith(catalogId: basicCatalogId);
```

Note that both `genkit_a2ui` and `genui` export a `basicCatalogId` symbol with
different values. You want the plugin's, so hide genui's with
`import 'package:genui/genui.dart' hide basicCatalogId;`. See
[`testapps/a2ui`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/a2ui)
for the full wiring.

## Custom catalogs

The `catalog` option is a **catalog id** resolved from the Genkit registry. The
bundled `'basic'` catalog is the default and needs no registration.

To match your own layout elements and design system, define a custom catalog,
register it with `loadCatalog`, and reference it by id.

### Catalog format

An A2UI catalog describes the components the model is allowed to emit:

- `id`: A globally unique URI identifying the catalog (used as `catalogId` on
  `createSurface`).
- `components`: An array of components, where each has:
  - `name`: The component type name, matching the renderer type (for example
    `CustomCard`, `Text`).
  - `description`: A clear, one-line summary of what the component is and when to
    use it.
  - `props`: A compact, model-facing text description of its properties (kept as
    a simple, human-readable string to minimize system prompt token usage).

### Option A: load from a JSON file

Create a JSON file (for example `./my-catalog.json`) following this format:

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

Then register it under a lookup identifier (for example `'my-catalog'`) on the
server:

```dart
import 'package:genkit_a2ui/a2ui.dart';

await loadCatalog(
  ai,
  id: 'my-catalog',
  file: './my-catalog.json',
);
```

### Option B: in-memory definition

You can construct and register an `A2uiCatalog` directly in pure Dart:

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
  ai,
  id: 'my-catalog',
  catalog: myCatalog,
);
```

### Using a registered catalog

Once registered, reference the lookup id in your `a2ui()` options:

```dart
final uiAgent = ai.defineAgent(
  name: 'uiAgent',
  model: googleAI.gemini('gemini-flash-latest'),
  use: [a2ui(catalog: 'my-catalog')],
);
```

Catalogs live in the registry (value type `a2ui-catalog`) so the middleware can
resolve them by id.

## Security and the trust boundary

Generative UI moves model output into the UI, so treat every surface an agent
emits as **untrusted input**. The `a2ui()` middleware's `validate` option
(including `'strict'`) checks envelope structure and component *type names*
against the catalog only. It does **not** validate component props or data-model
values: model-controlled values such as `Image.url` and `Text` (inline Markdown,
which a renderer may turn into rich content) pass through untouched. `'strict'` is
a well-formedness check, not a security boundary.

A prompt-injected or simply mistaken model can therefore emit an arbitrary remote
image URL, or Markdown that a renderer turns into formatted content. To keep that
safe:

- **The renderer/catalog owns prop sanitization.** Whatever renders a surface
  (for example `genui` plus your Markdown renderer) is responsible for escaping
  and sanitizing prop values before they reach the UI. If you ship a custom
  catalog, its renderer must sanitize its own components' props.
- **Restrict remote sources at the host.** On the web, serve the app with a
  Content Security Policy that limits `img-src` (and other fetch directives) to
  origins you trust, so a model-supplied image or link URL cannot exfiltrate data
  or load unexpected content.
- **Do not put secrets in the data model.** Anything bound into a surface's data
  model can be echoed back through an action's `context`.

If you need server-side control over props (for example, allow-listing image
hosts), add your own model middleware after `a2ui()` to inspect and rewrite the
emitted a2ui parts.

## How it works

### One representation

A2UI rides on its own part channel: a Genkit `data` part carrying the mime type
`application/a2ui+json` whose `data` is an object `{ "envelopes": [...] }`
wrapping an array of A2UI envelope messages. This maps 1:1 onto the A2A binding of
the A2UI spec, so an A2A or MCP binding can drop in later for free.

- A **mixed** turn is a message whose content is `[textPart, a2uiPart, ...]`.
- A **pure-surface** turn is the special case with no text parts.
- Downstream consumers (the client transport, `genui`) only ever see a2ui parts.
  "Pure vs mixed" is a prompting choice, not a separate code path.

### The middleware pipeline

On each model call inside the agent's tool loop, `a2ui()`:

1. Injects the catalog's capabilities into the system prompt so the model knows
   what UI it may render (unless `instructions: 'none'`).
2. Intercepts the model's output, both the streamed chunks and the final
   aggregated message.
3. Extracts `a2ui` fenced code blocks from the model's text.
4. Validates them against the catalog (per the `validate` option).
5. Rewrites them into canonical a2ui data parts.

Inbound a2ui parts (for example, a surface action sent back as the next turn, or
replayed history) are summarized into plain text before the underlying model sees
them, so a model that does not understand the a2ui mime type can still reason
about prior surfaces and user actions.

## License

Apache-2.0
