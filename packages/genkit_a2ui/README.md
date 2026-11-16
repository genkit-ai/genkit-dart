[![Pub](https://img.shields.io/pub/v/genkit_a2ui.svg)](https://pub.dev/packages/genkit_a2ui)

# genkit_a2ui

A Genkit Dart plugin that brings [A2UI](https://a2ui.org/) ("Agent to UI"), a
transport-agnostic, JSON-based streaming UI protocol, to Genkit agents.

An A2UI-enabled agent can stream more than prose. It streams rich, interactive UI
**surfaces** (cards, lists, forms, buttons) that a client renders incrementally
as the model responds. The whole server-side integration is a single model
middleware: add `a2ui()` to an agent's `use` list and nothing else changes.

[Documentation](https://genkit.dev) • [API Reference](https://pub.dev/packages/genkit_a2ui) • [A2UI Specification](https://a2ui.org/)

![An A2UI weather card rendered by a Flutter client.](https://raw.githubusercontent.com/genkit-ai/genkit-dart/main/packages/genkit_a2ui/doc/a2ui.png)

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
[`a2ui_flutter`](https://pub.dev/packages/a2ui_flutter), the Flutter renderer
for A2UI surfaces, with [`a2ui_core`](https://pub.dev/packages/a2ui_core),
which processes the messages and holds each surface's state:

```bash
flutter pub add genkit a2ui_flutter a2ui_core url_launcher
```

An app that hosts the agent in-process can depend on both `genkit_a2ui` and
`a2ui_flutter`: both build on `a2ui_core` 0.7. `a2ui_core` is pre-1.0 and
still makes breaking releases, so a server package of its own (as in the
sample) keeps the agent from holding back the renderer version.

## Quickstart

### 1. Add the middleware on the server

Add `a2ui()` to your agent's `use` list. That is the entire server-side setup.

Unlike the JS plugin, Dart middleware is resolved by name from the registry, so
you must register `A2uiPlugin()` in `Genkit(plugins: [...])` before referencing
it via `a2ui()`.

```dart
import 'package:genkit/experimental.dart'; // defineAgent
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
import 'package:a2ui_core/a2ui_core.dart'
    show ActionMessage, RendererToAgentMessagePayload;
import 'package:genkit/client.dart';

const a2uiMimeType = 'application/a2ui+json';

const _envelopeKeys = {'checks', 'accessibility', 'catalogId', 'metadata'};

/// The A2UI messages carried by a chunk's or message's parts.
Iterable<Map<String, dynamic>> a2uiMessagesFrom(List<Part>? parts) sync* {
  for (final part in parts ?? const <Part>[]) {
    if (part.metadata?['mimeType'] != a2uiMimeType) continue;
    // `envelopes` is the pre-spec key, still written by older agents. Malformed
    // payloads are skipped rather than throwing mid-stream.
    final data = part.data;
    if ((data?['messages'] ?? data?['envelopes']) case final List messages) {
      yield* messages.whereType<Map>().map(
        (m) => _normalizeEnvelopeKeys(
          m is Map<String, dynamic> ? m : m.cast<String, dynamic>(),
        ),
      );
    }
  }
}

bool _hasAtEnvelopeKey(Object? c) =>
    c is Map &&
    c.keys.any(
      (k) =>
          k is String &&
          k.startsWith('@') &&
          _envelopeKeys.contains(k.substring(1)) &&
          !c.containsKey(k.substring(1)),
    );

/// Rewrites `@checks`, `@accessibility`, `@catalogId` and `@metadata` on v1.0
/// components to the bare names that `a2ui_core` 0.7 expects, so this client
/// keeps rendering if the agent moves to a newer SDK first. Delete it once your
/// `a2ui_core` reads the `@` keys itself (a2ui-project/a2ui#4037): after the
/// bare-key fallback is removed (a2ui-project/a2ui#4082), the rewritten keys
/// are read as ordinary component properties and `checks` stop applying.
Map<String, dynamic> _normalizeEnvelopeKeys(Map<String, dynamic> message) {
  if (message['version'] != '1.0') return message;
  for (final kind in const ['createSurface', 'updateComponents']) {
    if (message[kind] case final Map body) {
      if (body['components'] case final List components
          when components.any(_hasAtEnvelopeKey)) {
        return <String, dynamic>{
          ...message,
          kind: <String, dynamic>{
            ...body.cast<String, dynamic>(),
            'components': <Object?>[
              for (final c in components)
                if (c is Map)
                  <String, dynamic>{
                    for (final MapEntry(:key, :value) in c.entries)
                      if (key is String &&
                          key.startsWith('@') &&
                          _envelopeKeys.contains(key.substring(1)) &&
                          !c.containsKey(key.substring(1)))
                        key.substring(1): value
                      else
                        '$key': value,
                  }
                else
                  c,
            ],
          },
        };
      }
    }
  }
  return message;
}

/// Wraps a surface action (e.g. a button press) as the next agent input.
///
/// `a2ui_core` writes the `{messages: [...]}` wrapper the agent reads, with
/// the action in a spec-shaped `{version, action}` message, so it is forwarded
/// as is.
Message a2uiActionToMessage(ActionMessage action) => Message(
  role: .user,
  content: [
    DataPart(
      data: RendererToAgentMessagePayload.of(action).toJson(),
      metadata: {'mimeType': a2uiMimeType},
    ),
  ],
);
```

Then consume the agent with `remoteAgent` and feed each message to an
`a2ui_core` `MessageProcessor`, which creates a surface for each
`createSurface`. [`a2ui_flutter`](https://pub.dev/packages/a2ui_flutter)
renders one with an `A2uiSurface` widget:

```dart
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:genkit/experimental_client.dart';
import 'package:url_launcher/url_launcher.dart';

final agent = remoteAgent(url: '/api/uiAgent');
final chat = agent.chat();

// The renderer rejects a surface whose catalog id it does not hold, so the id
// must match the catalog the agent uses. `basicCatalog()` has the same id as
// the plugin's bundled basic catalog.
final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [basicCatalog(openUrl: (uri) => launchUrl(uri))],
  // Deliver actions to `outboundListener` as typed, versioned messages.
  unifiedOutbound: true,
  // A surface action (e.g. a button press) becomes the next turn. A real app
  // should also keep turns from overlapping (the sample ignores presses while
  // a turn is running).
  outboundListener: (message) {
    if (message is ActionMessage) {
      runTurn(chat.sendStream(message: a2uiActionToMessage(message)));
    }
  },
  onError: (error) => print('A2UI renderer error: ${error.message}'),
);

Future<void> runTurn(AgentTurn turn) async {
  await for (final chunk in turn.stream) {
    for (final m in a2uiMessagesFrom(chunk.raw.modelChunk?.content)) {
      // One message the renderer cannot take (a newer protocol version, say)
      // must not stop the rest of the turn.
      try {
        processor.processMessages([m]);
      } on Object catch (e) {
        print('skipping an A2UI message: $e');
      }
    }
  }
}

await runTurn(chat.sendStream(text: 'weather in Tokyo'));

// In build, for each surface the processor holds (listen to
// `processor.model.onSurfaceCreated` and `onSurfaceDeleted` to rebuild):
A2uiSurface(key: ObjectKey(surface), surface: surface);
```

> See
> [`testapps/a2ui`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/a2ui)
> for a complete, runnable sample: a `dart:io` server hosting the agent, plus a
> Flutter client that renders surfaces with `a2ui_flutter`.

## Options

Pass options to `a2ui()` to control the catalog, prompt injection, and
validation:

| Option         | Default    | Description                                                                                                                                                      |
| -------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `catalog`      | `'basic'`  | The id of the catalog describing what the agent may render (`'basic'` is v1.0; `'basic-v0.9'` keeps v0.9).                                                      |
| `instructions` | `'system'` | Where to inject catalog capabilities. `'none'` injects nothing.                                                                                                 |
| `validate`     | `'warn'`   | What to do with a block that fails to compile or validate. `'warn'` logs and drops it; `'strict'` throws; `'off'` checks only that the block compiles, not the component tree (references, `root`). |
| `version`      | *from catalog* | Optional assertion (`'1.0'` or `'v0.9'`): throws if the resolved catalog targets another version.                                                          |
| `repair`       | `true`     | Ask the model once to fix a block that failed to compile. Costs an extra call on the failure path only; see [Self-repair](#self-repair).                        |

### When the model renders

The injected instructions ask for a surface when the answer is data the user
will look at or act on (structured tool results, comparisons, choices, forms),
and for plain prose otherwise: greetings, advice, explanations, simple facts.
They yield to your system prompt, so steer it from there:

```dart
ai.defineAgent(
  name: 'dashboard',
  // More surfaces:
  system: 'Answer with an A2UI surface whenever you can, explanations included.',
  // Or fewer: 'Only render a surface when the user asks for one.'
  use: [a2ui()],
);
```

### Surfaces

The model names each surface (`surface("tokyo-weather")`) and the id reaches the
client unchanged. Rendering an id again **replaces** that surface: the
middleware puts a `deleteSurface` in front of every `createSurface`, since
renderers reject a second `createSurface` for a live id. For a new surface the
delete is a no-op, so this holds even when the server's history misses a surface
the client has (a turn that failed after streaming one, say). Custom renderers
should treat a `deleteSurface` for an unknown id as a no-op too.
A block that omits `surface()` targets `default_surface`, so such blocks replace
each other.

A block without `root` **updates** a live surface instead: it carries only what
changed, as `updateComponents` / `updateDataModel` messages for that surface.
Like any block, it must define every variable it uses, so redefining a parent
component means redefining its children too.

```text
surface("tokyo-weather")
$/temp = "21°C"
```

(That updates whatever the surface bound to `$/temp`, such as a
`Text($/temp)`; a surface that rendered the temperature as a literal needs the
component redefined instead.)

**A part can be partial.** Since an a2ui part may carry only updates for a
surface an earlier part or turn created, clients must feed every message from
every part, in order, into one renderer (one `a2ui_core` `MessageProcessor`)
per conversation, and render each surface once, keyed by its id. Rendering each
part as its own surface drops the updates.

Unless `validate` is `'off'`, every block is checked against the surfaces the
conversation's history left on the client, so an update must target a live
surface and leave its component tree valid. Send a2ui parts back with the
history (as `remoteAgent` and session stores do) for this to work. The check trusts the history: a client that
dropped messages the server sent can still reject an update the server
accepted.

In a chat UI, key each rendered surface by its id. A replaced surface then
re-renders where it first appeared, and an updated one changes in place.

### Self-repair

Models occasionally emit a block that does not compile, most often by putting a
label where a component id belongs:

```text
refresh = Button("Refresh", "primary", Event("refresh"))
```

`Button.child` is a component id, so that would render nothing useful. When a
block fails to compile the middleware sends a follow-up call containing the
error, the Express contract with the catalog's signatures (a few thousand input
tokens with the basic catalog), and the failed block, then compiles the reply.
If it works the surface renders (and the repaired block is what gets replayed
as history); if not, the block is dropped as before. That is one call per
distinct broken block, at most 3 per model call and 30 seconds in total.

This costs extra model calls **on the failure path only**. It also changes what
`validate: 'strict'` reports: it throws only if the repair fails too. To see
the model's own mistakes while developing, turn repair off:

```dart
use: [a2ui(validate: 'strict', repair: false)]
```

Repair runs once the model's response is complete, since the streaming callback
cannot wait for a second model call. The repaired surface is then sent as the
last chunk of the stream (and is in the final message), so it arrives at the
end of the turn rather than where the model wrote it. The repair call uses the
same model config as the turn (so a per-request API key still applies; an
option that forces JSON output or a function call can make the repair fail, in
which case the block is dropped as before; provider-side tools enabled in the
config, such as code execution, stay on too). Its token usage is added to the
turn's `usage`; `latencyMs` stays that of the turn's own call. Cancelling the
turn cancels a repair in flight.

## Handling user actions

When a user interacts with a surface (for example, presses a `Button`), the
renderer emits an action. Send it back as an a2ui data part carrying an
`action` message (`a2uiActionToMessage` above does this). The
middleware turns it into a line the model can read, for example
`[UI action "refresh" from refreshBtn on surface tokyo-weather context={"city":"Tokyo"}]`, so
no accompanying text is needed.

### Forms

Input components (`TextField`, `CheckBox`, `Slider`, `ChoicePicker`,
`DateTimeInput`) do **not** send their values
automatically. To capture what the user entered, the model must:

1. Bind each input's value to a data-model path:
   `email = TextField("Email", $/email)`.
2. Echo those same paths in the submit button's event context:
   `Event("submit", {email: $/email})`.

The catalog capabilities injected into the system prompt already instruct the
model to do this. Without both steps, the action arrives with an empty `context`.

### Renderer requirements

The renderer rejects a `createSurface` whose `catalogId` it does not hold (an
`A2uiCatalogError` from `processMessages`), so that surface never appears. The
client's catalog ids must match the server's: a2ui_flutter's `basicCatalog()`
already uses the bundled basic catalog's id, and a custom catalog extended with
`basicCatalog.extend(...)` needs the same id on both sides:

```dart
import 'package:a2ui_core/a2ui_core.dart'
    show A2uiProtocolVersion, BasicCatalog;
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:url_launcher/url_launcher.dart';

final catalog = CatalogImplementation(
  id: 'https://my-app.org/catalogs/custom.json',
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [...BasicComponents.all, myCustomComponent],
  functions: BasicCatalog.v1_0(
    openUrl: (uri) => launchUrl(uri),
  ).functions.values.toList(),
  definitions: BasicComponents.api.definitions,
);
```

See
[`testapps/a2ui`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/a2ui)
for the full wiring.

## Wire format

A2UI travels on its own part channel, following the
[A2UI extension spec](https://a2ui.org/specification/v1.0-a2ui-extension-specification/):
a Genkit `data` part tagged `application/a2ui+json`. The spec puts the message
list directly in `data`; a Genkit `data` must be an object, so the list sits
under the spec's `messages` wrapper.

Agent to client (one part per rendered block; v1.0 carries initial components
and data on `createSurface`):

```json
{
  "data": {
    "messages": [
      { "version": "1.0", "deleteSurface": { "surfaceId": "tokyo-weather" } },
      {
        "version": "1.0",
        "createSurface": {
          "surfaceId": "tokyo-weather",
          "catalogId": "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json",
          "components": [ { "id": "root", "component": "Text", "text": "Sunny, 18C" } ]
        }
      }
    ]
  },
  "metadata": {
    "mimeType": "application/a2ui+json",
    "a2uiExpress": "surface(\"tokyo-weather\")\nroot = Text(\"Sunny, 18C\")"
  }
}
```

Client to agent (a user action):

```json
{
  "data": {
    "messages": [
      { "version": "1.0", "action": { "name": "refresh", "surfaceId": "tokyo-weather", "sourceComponentId": "refreshBtn", "timestamp": "2026-01-15T12:00:00Z", "context": { "city": "Tokyo" } } }
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

Catalogs use the A2UI specification's
[`catalog.json`](https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json)
format, so a published catalog loads unmodified:

- `catalogId`: A globally unique URI identifying the catalog (used as
  `catalogId` on `createSurface`).
- `protocolVersion`: `'1.0'` for A2UI v1.0 catalogs (omitted on v0.9
  catalogs). The catalog's protocol version decides what the middleware emits.
- `components`: An object keyed by component name, where each value is the
  component's JSON Schema. The schema's `description` and property
  descriptions are what the model sees.
- `functions` (optional): Client functions (validation checks, formatters),
  keyed by name.

Property order matters: A2UI Express is positional, so the model writes
`Banner("Disk almost full", "warning")` and the order of a component's
properties decides which argument is which.

### Option A: load from a JSON file

Create a JSON file (for example `./my-catalog.json`):

```json
{
  "catalogId": "https://my-app.org/catalogs/custom.json",
  "protocolVersion": "1.0",
  "components": {
    "Banner": {
      "type": "object",
      "description": "Displays a prominent alert banner at the top of a section.",
      "properties": {
        "component": { "const": "Banner" },
        "title": {
          "$ref": "common_types.json#/$defs/DynamicString"
        },
        "severity": { "type": "string", "enum": ["info", "warning", "error"] }
      },
      "required": ["component", "title"]
    }
  }
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

`A2uiCatalogComponent.simple` builds the same schema from a parameter list, so
you do not have to write JSON Schema by hand. Extend the bundled basic catalog
to keep its standard components:

```dart
import 'package:genkit_a2ui/a2ui.dart';

final myCatalog = basicCatalog.extend(
  id: 'https://my-app.org/catalogs/custom.json',
  components: [
    A2uiCatalogComponent.simple(
      name: 'Banner',
      description: 'Displays a prominent alert banner at the top of a section.',
      params: [
        // A literal or a data binding (`$/path`).
        const A2uiParam.dynamicValue('title', required: true),
        // A literal only, restricted to these values.
        const A2uiParam.string(
          'severity',
          enumValues: ['info', 'warning', 'error'],
        ),
      ],
    ),
  ],
);

await loadCatalog(
  ai,
  id: 'my-catalog',
  catalog: myCatalog,
);
```

`A2uiParam.dynamicValue` takes a string unless you set its `type`
(`A2uiDynamicType.number`, `.boolean`, `.stringList` or `.value`). The other
parameter kinds are `A2uiParam.number`, `A2uiParam.boolean`, `A2uiParam.child`
(one child component id), `A2uiParam.children` (a list of child ids) and
`A2uiParam.action` (an event fired on interaction), and `A2uiParam.schema` for a
property with a hand-written JSON Schema. Pass `checkable: true` for inputs that
accept validation checks. Catalog-wide guidance for the model goes
in `instructions`, as in a `catalog.json`.

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
emits as **untrusted input**. Every block is compiled and checked against the
catalog's schemas (component names, property types, enum values, component
references), but that only says the surface is *well-formed*. Model-controlled
values such as `Image.url` and `Text` (inline Markdown, which a renderer may turn
into rich content) pass through as written. Validation is a well-formedness
check, not a security boundary.

A prompt-injected or simply mistaken model can therefore emit an arbitrary remote
image URL, or Markdown that a renderer turns into formatted content. To keep that
safe:

- **The renderer/catalog owns prop sanitization.** Whatever renders a surface
  (for example `a2ui_flutter` plus your Markdown renderer) is responsible for escaping
  and sanitizing prop values before they reach the UI. If you ship a custom
  catalog, its renderer must sanitize its own components' props.
- **Restrict remote sources at the host.** On the web, serve the app with a
  Content Security Policy that limits `img-src` (and other fetch directives) to
  origins you trust, so a model-supplied image or link URL cannot exfiltrate data
  or load unexpected content.
- **Do not put secrets in the data model.** Anything bound into a surface's data
  model can be echoed back through an action's `context`.

If you need server-side control over props (for example, allow-listing image
hosts), add your own model middleware **before** `a2ui()` in `use` (middleware
listed first wraps the ones after it, so it sees the parts `a2ui()` emits) to
inspect and rewrite them. If you change a part's `data.messages`, also update or
remove its `metadata.a2uiExpress`: that source is what the model is shown on
later turns.

## How it works

### One representation

A2UI rides on its own part channel (see [Wire format](#wire-format)), which maps
1:1 onto the A2A binding of the A2UI spec, so an A2A or MCP binding can drop in
later for free.

- A **mixed** turn is a message whose content is `[textPart, a2uiPart, ...]`.
- A **pure-surface** turn is the special case with no text parts.
- Downstream consumers (the client helpers, the renderer) only ever see a2ui
  parts.
  "Pure vs mixed" is a prompting choice, not a separate code path.

### The middleware pipeline

On each model call inside the agent's tool loop, `a2ui()`:

1. Injects the catalog and the
   [A2UI Express](https://a2ui.org/specification/proposals/express/a2ui_express/) contract into the system prompt so the
   model knows what UI it may render (unless `instructions: 'none'`).
2. Intercepts the model's output, both the streamed chunks and the final
   aggregated message.
3. Extracts the `<a2ui>` Express blocks from the model's text.
4. Compiles each block into A2UI messages (v1.0 by default) with
   [`a2ui_agent`](https://pub.dev/packages/a2ui_agent), checking it against the
   catalog (per the `validate` option).
5. Rewrites each block into a canonical a2ui data part, with the Express source
   in the part's metadata.

A2UI Express is a compact, positional notation for UI. The model writes:

```text
surface("tokyo-weather")
root = Card(Column([title, refresh]))
title = Text("## Weather in Tokyo")
refresh = Button(Text("Refresh"), "primary", Event("refresh", {city: "Tokyo"}))
```

which costs far fewer tokens than the equivalent JSON messages and is easier for
a model to get right.

Inbound a2ui parts are turned back into text before the underlying model sees
them, so a model that does not understand the a2ui mime type can still reason
about prior surfaces and user actions:

- A surface the model rendered is replayed as its original Express block
  (read from the part's `a2uiExpress` metadata), so the model sees exactly what
  it wrote. If you manage conversation history on the client, send parts back
  with their metadata intact.
- A user action becomes a line such as
  `[UI action "refresh" from refreshBtn on surface tokyo-weather context={"city":"Tokyo"}]`.

## Migrating from 0.5

### Clients: genui to a2ui_flutter

[genui](https://pub.dev/packages/genui) is discontinued. Its replacement is
[`a2ui_flutter`](https://pub.dev/packages/a2ui_flutter) (the widgets) with
[`a2ui_core`](https://pub.dev/packages/a2ui_core) (message processing and
surface state), and the client examples here now use them. `a2ui_flutter` ships
both a v1.0 basic catalog (`package:a2ui_flutter/basic_catalog.dart`) and a
v0.9 basic catalog (`package:a2ui_flutter/v0_9/basic_catalog.dart`). Their ids
differ, so a client that registers both renders either server version. A client
holds only one protocol version per catalog id, though, so for a custom catalog
either give the v1.0 edition a new id (and keep the v0.9 one registered) or
upgrade the server and its clients together.

Replace `genui` with `a2ui_flutter` in the pubspec, raise `a2ui_core` to 0.7,
and copy the helpers from
[Render surfaces on the client](#2-render-surfaces-on-the-client) again
(`a2uiSubmitToMessage` became `a2uiActionToMessage`). Then:

```dart
// genui (v0.9)
final controller = SurfaceController(catalogs: [BasicCatalogItems.asCatalog()]);
controller.handleMessage(core.A2uiMessage.fromJson(m));
controller.onSubmit.listen((submit) {
  if (a2uiSubmitToMessage(submit) case final message?) {
    runTurn(chat.sendStream(message: message));
  }
});
Surface(surfaceContext: controller.contextFor(surfaceId));

// a2ui_flutter: import 'package:a2ui_flutter/basic_catalog.dart' for a v1.0
// agent (the 0.6 default), or 'package:a2ui_flutter/v0_9/basic_catalog.dart'
// while talking to a 0.5 server or `a2ui(catalog: 'basic-v0.9')`.
final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [basicCatalog(openUrl: (uri) => launchUrl(uri))],
  unifiedOutbound: true,
  outboundListener: (message) {
    if (message is ActionMessage) {
      runTurn(chat.sendStream(message: a2uiActionToMessage(message)));
    }
  },
  onError: (error) => print('A2UI renderer error: ${error.message}'),
);
processor.processMessages([m]);
A2uiSurface(surface: processor.model.getSurface(surfaceId)!);
```

- A custom component is a `ComponentImplementation` (`name`, `schema`,
  `builder`) instead of a `CatalogItem`, and the catalog a
  `CatalogImplementation`; see [Renderer requirements](#renderer-requirements).
- Pass an `openUrl` callback (such as `url_launcher`'s `launchUrl`) to
  `basicCatalog(...)` / `BasicCatalog`; unlike genui, `a2ui_core` does not
  bundle `url_launcher`, and `openUrl(...)` actions fail without one.
- A surface whose catalog id the client does not hold is rejected with an
  `A2uiCatalogError`, where genui rendered a blank.
- `genkit_a2ui` and `a2ui_flutter` can share a pubspec.

### Agents: A2UI v1.0 by default

`basicCatalog` and `A2uiCatalog(...)` now target A2UI **1.0** by default:
messages carry `"version": "1.0"`, new surfaces inline their `components` and
`dataModel` on `createSurface`, data bindings use `{"@path": ...}` and function
calls use `{"@call": ...}`, and `Text.variant` drops `h1`..`h5` in favor of
Markdown heading lines (`"## Heading"`). `basicCatalog` now exposes all 18
components of the v1.0 basic catalog, adding `AudioPlayer`, `Video`, `Tabs`,
`Modal`, `ChoicePicker`, and `DateTimeInput` to the 12 in `basicCatalogV09`.

- **Staying on v0.9** (for example while clients still run `genui`): pass
  `a2ui(catalog: 'basic-v0.9')` (`basicCatalogV09LookupId`), extend
  `basicCatalogV09`, or pass `protocolVersion: 'v0.9'` to `A2uiCatalog(...)`.
- **v1.0 catalog validation**: Dart-built `A2uiCatalog(...)` instances now run
  `a2ui_core`'s v1.0 catalog checks (UAX #31 property identifiers, such as
  rejecting `'aria-label'`, and `$ref`s restricted to `#/...` or
  `common_types.json`). Pass `protocolVersion: 'v0.9'` if a catalog still needs
  v0.9 schema rules.
- **`version:` option**: `a2ui(version:)` no longer picks the version (the
  catalog does), and now throws if the resolved catalog targets another version.
  `a2uiVersion` is removed in favor of `catalog.protocolVersion`.
- **`a2ui_core` 0.7 compatibility**: the published `a2ui_agent` 0.3 /
  `a2ui_core` 0.7 SDKs still write bare `checks` rather than `@checks` on
  components. `a2uiMessagesFrom` above normalizes `@checks`, `@accessibility`,
  `@catalogId` and `@metadata` back to bare keys on v1.0 surfaces, so clients
  that copy it tolerate the later SDK rename too. Delete `_normalizeEnvelopeKeys`
  once your client's `a2ui_core` reads the `@` keys directly
  (a2ui-project/a2ui#4037 / #4082), otherwise the rewritten bare keys will be
  treated as ordinary component properties and `checks` will stop applying.
- **Persisted v0.9 sessions**: a v1.0 agent cannot update a v0.9 surface in
  place. Stored v0.9 surface parts are replayed to the model as a summary asking
  it to re-render the surface in full (rather than replaying the v0.9 Express
  source), and `repair` skips rootless deltas targeting a v0.9-only surface
  instead of fabricating a stub replacement.

## Migrating from 0.4

0.5 is a breaking release: the wire format, the model's output format, the
catalog API and the client story all change.

### Upgrade order

The a2ui part's payload key changed from `data.envelopes` to `data.messages`
(the A2UI extension spec's message list). 0.5 reads both keys but writes only
`messages`, so:

- A 0.5 agent's surfaces don't render on 0.4 clients
  (`package:genkit_a2ui/client.dart`). Prose still streams; the surfaces just
  never appear.
- A client on the 0.5 helpers sends actions as `{messages: [...]}` with no text
  part, which a 0.4 agent fails on.

Upgrade the agent and its clients together. If you can't (a store-distributed
app, say), stage it: ship clients with the helpers below, but have
`a2uiActionToMessage` write both keys
(`{'messages': messages, 'envelopes': messages}`); upgrade the agent once no 0.4
clients remain; then drop `envelopes`. A 0.5 agent logs a warning once when a
client still sends only `envelopes`.

Persisted 0.4 sessions still replay, but their parts carry no Express source,
so the model sees each old surface only as a one-line summary ("UI surface X
was rendered here") and will usually re-render it rather than update it.

Other runtimes: the JS, Go and Python plugins make the same key change in
genkit-ai/genkit#7091, #7092 and #7118 (not yet released). Until those ship,
mix them with a 0.5 Dart agent or client only through the staged rollout
above.

### Clients

- `package:genkit_a2ui/client.dart` (`actionToMessage`, `A2uiClientAction`)
  and `A2uiComponent` are removed. Clients no longer depend on `genkit_a2ui`:
  add `genkit`, `a2ui_flutter` and `a2ui_core`, and copy `a2uiMessagesFrom`
  and `a2uiActionToMessage` from
  [Render surfaces on the client](#2-render-surfaces-on-the-client).
- [A part can be partial](#surfaces): feed every part's messages, in order, into
  one `MessageProcessor` per conversation.
- Every render starts with a `deleteSurface` for its id, which is a no-op when
  the surface is new. `a2ui_core` handles that; a custom renderer must treat a
  delete of an unknown id as a no-op too, and key surfaces by id rather than
  append one per `createSurface`.
- If you manage history yourself, send model messages back verbatim, including
  `metadata.a2uiExpress`: it is what the model sees of its earlier surfaces, and
  updates are checked against the surfaces the history contains.

### Agents

- The model writes [A2UI Express](#one-representation) between `<a2ui>` tags
  instead of fenced `a2ui` JSON. The wire messages are still A2UI v0.9. With
  `instructions: 'none'`, rewrite your prompt starting from
  `renderCatalogInstructions(catalog)`; a fenced JSON block now passes through
  as prose (with a one-time warning).
- Surface ids belong to the model. The `surfaceId` option is removed (in a JSON
  middleware config the key is ignored). Rendering an id again replaces that
  surface, and a block without `root` updates it.
- Every block is checked against the catalog's schemas and against the
  conversation's live surfaces, so `validate: 'strict'` throws in more cases.
  [Self-repair](#self-repair) is on by default; `repair: false` restores the
  drop-or-throw behavior.
- The injected instructions favor prose for conversation; see
  [When the model renders](#when-the-model-renders).

```dart
// 0.4
use: [a2ui(surfaceId: 'main')]
// 0.5
use: [a2ui()]
```

### Catalogs

Catalogs use the spec's catalog.json shape: `components` is an object keyed by
name, each a JSON Schema whose property order is the model's argument order.
The published basic `catalog.json` loads as is, and `loadCatalog(file:)` rejects
the 0.4 array shape. In Dart, `components` is a `Map`, components are
`{name, schema}`, and you extend the basic catalog rather than spread it:

```dart
// 0.4
const gauge = A2uiCatalogComponent(
  name: 'Gauge',
  description: 'A circular gauge.',
  props: 'value: number (required); max?: number.',
);
final myCatalog = A2uiCatalog(
  id: myId,
  components: [...basicCatalog.components, gauge],
);

// 0.5
final myCatalog = basicCatalog.extend(
  id: myId,
  components: [
    A2uiCatalogComponent.simple(
      name: 'Gauge',
      description: 'A circular gauge.',
      params: [
        A2uiParam.dynamicValue(
          'value',
          required: true,
          type: A2uiDynamicType.number,
        ),
        A2uiParam.number('max'),
      ],
    ),
  ],
);
```

The bundled `basicCatalog` follows the published catalog: arguments come in
spec order, `List.listStyle` and `Slider.step` are gone, and `Icon` accepts only
the listed names.

### `A2uiStreamParser`

If you use it directly: `surfaceId` and `version` are removed, `catalog` is
required, and `history` takes every A2UI message the client already holds.
`EnvelopeSegment` gained the block's Express `source`.

## License

Apache-2.0
