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

> **Building with a coding agent? Install the Genkit Dart skill first.**
>
> ```bash
> npx skills add genkit-ai/skills --skill developing-genkit-dart
> ```
>
> It teaches your agent the current Genkit Dart APIs and common gotchas.
> Source, manual install and skills for other languages:
> [genkit-ai/skills](https://github.com/genkit-ai/skills).

## Installation

Add the plugin to the package that runs your agent (it is server-side only):

```bash
dart pub add genkit_a2ui
```

The client does not depend on `genkit_a2ui`. To render surfaces it needs
`package:genkit` and a renderer. The Dart examples below use
[`genui`](https://pub.dev/packages/genui), the Flutter renderer for A2UI
surfaces, which takes messages typed by `a2ui_core`:

```bash
flutter pub add genkit genui a2ui_core
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

The client does **not** depend on `genkit_a2ui`. A2UI arrives as plain,
spec-shaped data parts (see [Wire format](#wire-format)), so a client needs only
`package:genkit` and a renderer. Keeping this package off the client also means
it can never hold back the renderer version you use.

Copy these two helpers into your app:

```dart
import 'dart:convert';

import 'package:genkit/client.dart';
// genui also exports `Part`/`DataPart`, so take only what is needed.
import 'package:genui/genui.dart' show ChatMessage, UiPartExtension;

const a2uiMimeType = 'application/a2ui+json';

/// The A2UI messages carried by a chunk's or message's parts.
Iterable<Map<String, dynamic>> a2uiMessagesFrom(List<Part>? parts) sync* {
  for (final part in parts ?? const <Part>[]) {
    if (part.metadata?['mimeType'] != a2uiMimeType) continue;
    // `envelopes` is the pre-spec key, still written by older agents. Malformed
    // payloads are skipped rather than throwing mid-stream.
    final data = part.data;
    if ((data?['messages'] ?? data?['envelopes']) case final List messages) {
      yield* messages.whereType<Map>().map((m) => m.cast<String, dynamic>());
    }
  }
}

/// Turns a genui surface submission (e.g. a button press) into the next agent
/// input, or null when it carries no user action: genui also reports renderer
/// errors through `onSubmit`, and those are not turns. genui already emits
/// spec-shaped `{version, action}` messages, so they are forwarded untouched.
Message? a2uiSubmitToMessage(ChatMessage submit) {
  final actions = <Map<String, dynamic>>[
    for (final part in submit.parts)
      if (part.asUiInteractionPart case final ui?)
        if (_decodeJson(ui.interaction) case final Map<String, dynamic> m
            when m.containsKey('action'))
          m,
  ];
  if (actions.isEmpty) return null;
  return Message(
    role: Role.user,
    content: [
      DataPart(
        data: {'messages': actions},
        metadata: {'mimeType': a2uiMimeType},
      ),
    ],
  );
}

Object? _decodeJson(String source) {
  try {
    return jsonDecode(source);
  } on FormatException {
    return null;
  }
}
```

Then consume the agent with `remoteAgent` and feed each message to
[`genui`](https://pub.dev/packages/genui):

```dart
import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genkit/experimental_client.dart';
import 'package:genui/genui.dart' show BasicCatalogItems, SurfaceController;

final agent = remoteAgent(url: '/api/uiAgent');
final chat = agent.chat();

// genui registers an empty stub for a catalog id it does not know, so the id
// must match the catalog the agent uses. This is genui's own basicCatalogId,
// which is the same URL as the plugin's bundled basic catalog.
final surfaceController = SurfaceController(
  catalogs: [BasicCatalogItems.asCatalog()],
);

Future<void> runTurn(AgentTurn turn) async {
  await for (final chunk in turn.stream) {
    for (final m in a2uiMessagesFrom(chunk.raw.modelChunk?.content)) {
      surfaceController.handleMessage(core.A2uiMessage.fromJson(m));
    }
  }
}

// A surface action (e.g. a button press) becomes the next turn. Listen before
// the first turn: onSubmit is a broadcast stream, so a press with no listener
// is lost. A real app should also keep turns from overlapping (the sample
// ignores presses while a turn is running).
surfaceController.onSubmit.listen((submit) {
  if (a2uiSubmitToMessage(submit) case final message?) {
    runTurn(chat.sendStream(message: message));
  }
});

await runTurn(chat.sendStream(text: 'weather in Tokyo'));
```

> See
> [`testapps/a2ui`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/a2ui)
> for a complete, runnable sample: a `dart:io` server hosting the agent, plus a
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
renderer emits an action. Send it back as an a2ui data part carrying an
`action` message (`a2uiSubmitToMessage` above does this for genui). The
middleware turns it into a line the model can read, for example
`[UI action "refresh" on surface tokyo-weather context={"city":"Tokyo"}]`, so
no accompanying text is needed.

### Forms

Input components (`TextField`, `CheckBox`, `Slider`) do **not** send their values
automatically. To capture what the user entered, the model must:

1. Bind each input's `value` to a data-model path (`{ "path": "/email" }`).
2. Echo those same paths in the submit `Button`'s `action.event.context`.

The catalog capabilities injected into the system prompt already instruct the
model to do this. Without both steps, the action arrives with an empty `context`.

### Renderer requirements

genui registers an empty stub for a catalog id it does not recognize, so a
surface whose `catalogId` the client does not hold renders as a blank. The
client's catalog ids must match the server's: genui's basic catalog already uses
the bundled basic catalog's id, and a custom catalog needs the same id on both
sides:

```dart
final catalog = BasicCatalogItems.asCatalog().copyWith(
  newItems: [myCustomItem],
  catalogId: 'https://my-app.org/catalogs/custom.json',
);
```

See
[`testapps/a2ui`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/a2ui)
for the full wiring.

## Wire format

A2UI travels on its own part channel, following the
[A2UI extension spec](https://a2ui.org/specification/v0_9/docs/a2ui_extension_specification/):
a Genkit `data` part tagged `application/a2ui+json`. The spec puts the message
list directly in `data`; a Genkit `data` must be an object, so the list sits
under the spec's `messages` wrapper.

Agent to client (one part per rendered block):

```json
{
  "data": {
    "messages": [
      { "version": "v0.9", "createSurface": { "surfaceId": "tokyo-weather", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json" } },
      { "version": "v0.9", "updateComponents": { "surfaceId": "tokyo-weather", "components": [ { "id": "root", "component": "Text", "text": "Sunny, 18C" } ] } }
    ]
  },
  "metadata": { "mimeType": "application/a2ui+json" }
}
```

Client to agent (a user action):

```json
{
  "data": {
    "messages": [
      { "version": "v0.9", "action": { "name": "refresh", "surfaceId": "tokyo-weather", "sourceComponentId": "refreshBtn", "timestamp": "2026-01-15T12:00:00Z", "context": { "city": "Tokyo" } } }
    ]
  },
  "metadata": { "mimeType": "application/a2ui+json" }
}
```

Earlier versions of this package used `envelopes` instead of `messages`; the
middleware still reads them when replaying history.

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

A2UI rides on its own part channel (see [Wire format](#wire-format)), which maps
1:1 onto the A2A binding of the A2UI spec, so an A2A or MCP binding can drop in
later for free.

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
