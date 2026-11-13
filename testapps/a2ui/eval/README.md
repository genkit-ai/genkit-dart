# A2UI eval

Rerunnable, multi-turn evaluation of the A2UI sample agent
(`../server/lib/agent.dart`). It drives the real agent in-process through
scripted conversations, replays every emitted A2UI message into a headless
renderer, and reports per-check pass rates across repeated runs.

```bash
source ~/init-gemini.sh            # GEMINI_API_KEY
dart run bin/eval.dart --runs 5    # all scenarios, 5 runs each
dart run bin/eval.dart --only form --only delete -n 10 -c 6
dart run bin/eval.dart --list
```

Each run writes `results/<timestamp>.md` (summary plus the full transcript,
Express source and middleware logs of every failing run) and
`results/<timestamp>.json` (everything, for diffing).

## Scenarios

Scenarios live in `lib/scenarios.dart`:

```dart
Scenario('action targets its own surface (2 surfaces)', [
  const Say('Show the weather in Tokyo, with a Refresh button.'),
  const Say('Now show Paris as a separate card, also with a Refresh button.'),
  Expect.liveSurfaces(2),
  const Press('Refresh', on: SurfaceRef.nth(0)),   // sends the renderer's action message
  Expect.touched(SurfaceRef.nth(0)),
  Expect.untouched(SurfaceRef.nth(1)),
  Expect.newSurfaces(0),
]),
```

- `Say(text)`: a user turn.
- `Press(label, on:)`: presses the `Button` whose visible label contains
  `label`, resolving its `Event` context against the surface's data model.
- `Fill(label, value, on:)`: writes the data path bound to an input, like a
  renderer would; it reaches the agent with the next `Press`.
- `Expect.*`: checks on the turn before them. Surfaces are referenced by
  creation order (`SurfaceRef.nth`), content (`SurfaceRef.containing`), the
  turn that created them (`SurfaceRef.fromTurn`), or `SurfaceRef.last`, never
  by the id the model picked.

The harness renders from the stream, like the sample client does, and every
turn gets four implicit checks: rendering the stream produces the same surfaces
as replaying the session history (a client never misses state the next turn
will assume it has), the turn did not fail (with
`validate: 'strict'` a block that does not compile even after repair fails
the turn), the headless renderer accepted every message (no `createSurface`
for a live id, no updates to unknown surfaces, a `root`, no dangling
component references), and no markup leaked into the prose.

Repairs are counted from the middleware's logs, which are attributed to the
turn that produced them through the zone each turn runs in.

## What it does not do (yet)

- No LLM judge: checks are deterministic. "The UI is right" is approximated by
  content checks (`Expect.shows`), not judged.
- No diffing between runs; compare the Markdown summaries.

