# Telemetry Refactor: Decoupling Genkit from OpenTelemetry

## Goal

Today, Genkit's telemetry instrumentation is tightly coupled to OpenTelemetry
(`package:opentelemetry`). We want to introduce an abstraction layer so that:

- Genkit core has **no hard dependency** on any specific telemetry SDK.
- OpenTelemetry becomes **one of several pluggable telemetry providers**.
- Different OTel packages (Dart has multiple, with no officially endorsed one
  yet) can be plugged in behind the same interface.
- The abstraction covers **traces, metrics, and logs**.
- Genkit's own **Dev UI telemetry is built in** and uses this exact same
  mechanism (it is not special-cased).

## Current State (what couples us to OTel)

There is essentially one chokepoint plus an exporter:

- **`lib/src/o11y/instrumentation.dart`** - the core. Directly uses
  `package:opentelemetry/api.dart`:
  - A global tracer (`api.globalTracerProvider.getTracer('genkit-dart')`).
  - `api.Attribute`, `api.StatusCode`, span lifecycle (`startSpan`, `setAttribute`,
    `setStatus`, `recordException`, `end`).
  - Stores the active OTel `Context` in a **Dart zone** under `#api.context` for
    parent-span propagation across async boundaries.
  - Public surface used throughout core:
    - `runInNewSpan<Input, Output>(...)` - used by `action.dart`, `generate.dart`,
      `prompt.dart`, `agent.dart`, `genkit_class.dart`.
    - `setCustomMetadataAttributes(...)` - used by `generate.dart`, `agent.dart`,
      `tool.dart`.
    - `TelemetryContext` typedef `({Map<String, String> attributes, String traceId,
      String spanId})` - returned to the wrapped function.

- **`lib/src/o11y/telemetry/exporter_impl.dart`** - uses
  `package:opentelemetry/sdk.dart` to register a global tracer provider and a
  hand-rolled OTLP/HTTP JSON exporter (`CollectorHttpExporter`) used by the Genkit
  Dev UI. Wired via a conditional import in `otlp_http_exporter.dart` and invoked
  by the `Genkit(...)` constructor through `configureCollectorExporter()`.

- **Metrics**: not implemented anywhere today.

- **Logs**: use `package:logging` directly, separate from OTel.

### Call sites for spans

Every flow, tool, prompt, model, embedder, and agent turn ultimately runs through
`Action.run()` → `runInNewSpan(...)`. There are also a few **non-action** spans for
logical sub-operations that are not full Actions:

| Site | Span name | Backed by an Action? |
| --- | --- | --- |
| `core/action.dart` `Action.run()` | action name | **Yes** (full `ActionMetadata`) |
| `ai/generate.dart` | `'generate'` | **Yes** - `generate` is a real Action (`actionType: 'util'`); it should carry `ActionMetadata` and look like a normal action to telemetry |
| `ai/prompt.dart` | `'render'`, `ref.name` | No |
| `ai/agents/agent.dart` | `'runTurn-N'` | No |
| `genkit_class.dart` `Genkit.run()` | user-provided name | No |

So most spans (including `generate`) are action-backed; only `render`, `runTurn`,
and `Genkit.run` are plain logical spans. This distinction drives the core design
decision below.

## Chosen Design: a global "observability hook"

Rather than baking a telemetry-provider abstraction directly into core, we
introduce a **lower-level hook**: a chain of hooks that wrap every "run". This is
the single, general interception point telemetry providers plug into.

> **Terminology:** this is intentionally **not** called "middleware". The
> *middleware* term is reserved for the generate-middleware API
> (`docs/generate-middleware.md`). An observability hook **operates similarly** to
> how middleware composes (a wrapper chain calling `next`), but it is a distinct
> concept with a distinct name.

Mental model: **everything is a "run"; most runs are backed by an Action.**

- The vast majority of spans wrap an `Action` and carry full `ActionMetadata`.
- A few logical spans (`render`, `runTurn`, `Genkit.run`) are plain runs with no
  action.

A hook branches on `invocation.action != null` to enrich action-backed spans
(action type, input/output schemas, registry metadata) while still tracing plain
logical spans uniformly.

We are free to make **breaking changes** to the `runInNewSpan` API.

### Global registration (not registry / not plugin-based)

Observability is a **process-global concern**, installed via a top-level
function - not through `Genkit(...)` or a plugin hook.

Why global: the **lite API** has no `Genkit` instance and exposes no
plugins/registry to the user (there is an internal registry, but it's not a user
surface). Telemetry must work there too, so it can't be tied to constructing a
`Genkit` or registering plugins.

```dart
/// Installs an observability hook. Hooks wrap every Genkit "run" (action or
/// logical span). Multiple hooks compose as a chain (outer-to-inner in
/// registration order). Process-global; works with the full and lite APIs.
///
/// Operates similarly to how middleware composes, but is a distinct concept -
/// the "middleware" term is reserved for the generate-middleware API.
void addObservabilityHook(ObservabilityHook hook);

typedef ObservabilityHook = Future<Object?> Function(
  RunInvocation invocation,
  RunNext next,
);

typedef RunNext = Future<Object?> Function(RunContext ctx);
```

> **Naming:** `addObservabilityHook` (spelled out), not `addO11yHook`. Per
> Effective Dart, public identifiers prefer whole words over insider
> abbreviations/numeronyms. `o11y` stays only as the internal library directory
> name (`lib/src/o11y/`).

### Contract

```dart
/// Describes a unit of work being run. `action` is present only when the run is
/// backed by a Genkit Action.
class RunInvocation {
  final String name;
  final Object? input;
  final Map<String, String>? attributes;

  /// Non-null only when this run is an action. Carries the action's name,
  /// `actionType` (e.g. 'flow', 'model', 'tool', 'util'), input/output schemas,
  /// and registry metadata - everything a provider needs to classify the span.
  final ActionMetadata? action;

  /// Non-null for action runs. Exposes the streaming sink (`sendChunk`),
  /// `context`, `inputStream`, and `init` so a provider can capture streamed
  /// chunks and request metadata for observability (see below).
  final ActionFnArg? arg;

  RunInvocation({
    required this.name,
    this.input,
    this.attributes,
    this.action,
    this.arg,
  });
}

/// Handle exposed to the wrapped function (and read back by core) for the
/// currently active run. Published into the current Dart zone by the hook.
abstract interface class RunContext {
  String get traceId;
  String get spanId;

  /// Replaces `setCustomMetadataAttributes`.
  void setAttributes(Map<String, Object?> attributes);

  void addEvent(String name, {Map<String, Object?>? attributes});
}
```

#### Why no `runType` field

An earlier draft had a `runType` string. It's redundant: for action-backed runs
the type already lives on `action.actionType`, and for the handful of plain
logical spans the `name` (`'render'`, `'runTurn-N'`, or the user-supplied
`Genkit.run` name) is sufficient. Dropping `runType` keeps `RunInvocation`
minimal - a hook that wants a "kind" reads `invocation.action?.actionType`.

#### `ActionFnArg` on the invocation

Hooks want more than static metadata. `ActionFnArg` (the per-call context already
threaded through `Action.run()`) carries fields a hook will want to tap:

```dart
typedef ActionFnArg<Chunk, Input, Init> = ({
  bool streamingRequested,
  StreamingCallback<Chunk> sendChunk,   // <-- hook can wrap/tap this
  Map<String, dynamic>? context,
  Stream<Input>? inputStream,
  Init? init,
});
```

- `sendChunk` lets a hook **tap the streamed chunks** for observability
  (e.g. record streamed output, count chunks, capture first-token latency) by
  wrapping the callback before `next` runs.
- `context`, `inputStream`, `init`, and `streamingRequested` give the hook
  request-level metadata to attach to the span.

Because chunk/input/init types are generic, `arg` is exposed at the seam as the
type-erased `ActionFnArg` (i.e. `ActionFnArg<Object?, Object?, Object?>`); hooks
read the fields they need without needing the concrete generics.

#### Type erasure at the seam

The hook boundary uses `Object?` for input/output to avoid Dart's awkwardness with
generics through a chain. `runInNewSpan<Input, Output>` keeps its generic
signature on the **outside** and casts back, so call sites stay strongly typed;
only the internal hook boundary is untyped.

### New `runInNewSpan` (breaking, minimal call-site churn)

```dart
Future<O> runInNewSpan<I, O>(
  String name,
  Future<O> Function(RunContext) fn, {
  I? input,
  Map<String, String>? attributes,
  ActionMetadata? action, // Action.run passes itself
  ActionFnArg? arg,       // Action.run passes its per-call context
}) async {
  final inv = RunInvocation(
    name: name,
    input: input,
    attributes: attributes,
    action: action,
    arg: arg,
  );
  return await _runHookChain(inv, (ctx) async => await fn(ctx)) as O;
}
```

- **No hook registered (default):** the chain is a passthrough that supplies a
  no-op `RunContext` with empty trace IDs - matching today's `''` fallback.
  Result: **zero OTel dependency in core**.
- `setCustomMetadataAttributes(map)` becomes `currentRunContext?.setAttributes(map)`,
  reading the `RunContext` published into the current zone by the active hook.
- `Action.run()` passes `action: this` and `arg: <per-call ActionFnArg>`. The
  plain logical sites pass neither.

### Zone-based scoping owned by the hook

The hook owns the span lifecycle and the zone. Parent-span discovery (the OTel
`Context` propagation that currently lives in core's zone) becomes a private detail
of the OTel hook's zone - core no longer references the OTel `Context` at all.

```dart
Future<Object?> otelHook(RunInvocation inv, RunNext next) async {
  final span = tracer.startSpan(
    inv.name,
    parent: _currentSpan,          // discovered from the current zone
    attributes: _attrsFor(inv),    // uses inv.action when present
  );
  final ctx = _OtelRunContext(span);
  return runZoned(
    () async {
      try {
        final out = await next(ctx);
        // OTel has no setOutput; capture output as an attribute (with a
        // jsonEncode + fallback, exactly as the current instrumentation does).
        span.setAttribute('genkit:output', _encode(out));
        _maybeRecordMetrics(inv, out);   // e.g. model usage (see Metrics)
        return out;
      } catch (e, s) {
        span.recordException(e, stackTrace: s);
        rethrow;
      } finally {
        span.end();
      }
    },
    zoneValues: {#genkit.runContext: ctx, #genkit.span: span},
  );
}
```

## Resulting Layering

- **Core (`genkit`)**: `ObservabilityHook`, `addObservabilityHook`,
  `RunInvocation`, `RunContext`, the chain runner, `runInNewSpan`,
  `currentRunContext`, `setCustomMetadataAttributes`. No OTel dependency.
- **Built-in Dev UI telemetry**: ships in core and is implemented as an
  `ObservabilityHook` using the **same mechanism** as any other provider. When
  `GENKIT_TELEMETRY_SERVER` is set, Genkit installs this hook automatically via
  `addObservabilityHook(...)`; it exports spans (and metrics) to the Dev UI via
  OTLP/HTTP JSON. It does not require the OTel SDK - it hand-builds OTLP JSON from
  the neutral span data (as the current `CollectorHttpExporter` already does).
- **`genkit_otel` plugin**: an alternative/additional provider that calls
  `addObservabilityHook(...)` with a hook implemented over `package:opentelemetry`.
  A different OTel package = a different package implementing the same hook.

## Metrics

The first concrete metrics use case is **generation usage from model calls**.
Because the hook sees `invocation.action`, a provider can do this without any extra
plumbing:

1. Check `invocation.action?.actionType == 'model'`.
2. After `next` returns, read the model output's `usage` field
   (`$GenerationUsage`: `inputTokens`, `outputTokens`, `totalTokens`, etc.).
3. Tick the corresponding metric instruments (counters/histograms) with those
   values, attributing them with the model name and other span attributes.

```dart
void _maybeRecordMetrics(RunInvocation inv, Object? out) {
  if (inv.action?.actionType == 'model' && out is ModelResponse) {
    final usage = out.usage;
    if (usage != null) {
      _inputTokens.add(usage.inputTokens ?? 0, attributes: {'model': inv.name});
      _outputTokens.add(usage.outputTokens ?? 0, attributes: {'model': inv.name});
      _totalTokens.add(usage.totalTokens ?? 0, attributes: {'model': inv.name});
    }
  }
}
```

The same hook can also emit generic per-run metrics (duration histograms, call
counters) for any action type. **Metrics live entirely inside the hook** - core
does not know about them (see "Logs & metrics ownership" below).

## Logs & metrics ownership (v1)

For v1, **hooks own metrics and logs entirely**; core exposes no `Meter`/`Logger`
facades.

- **Metrics**: emitted from inside the hook (e.g. the model-usage example above),
  using whatever instruments the provider's SDK offers.
- **Logs**: handled by bridging `package:logging` records into the provider inside
  the hook (core already logs via `package:logging`), so logs can be
  trace-correlated using the active `RunContext`.

> Future option (out of scope now): if code outside a run needs to emit
> metrics/logs through the same provider, we could add no-op-by-default
> `Meter`/`GenkitTelemetryLogger` facades to core. Deferred deliberately to keep
> v1 surface minimal.

## Migration Sketch

1. Introduce `ObservabilityHook`, `addObservabilityHook`, `RunInvocation` (with
   `action` + `arg`), `RunContext`, and the hook-chain runner in `lib/src/o11y/`
   (no OTel imports).
2. Rewrite `runInNewSpan` and `setCustomMetadataAttributes` on top of the chain +
   zone-published `RunContext`. Default no-op behavior when no hook is installed.
3. Update `Action.run()` to pass `action: this` and `arg: <per-call ActionFnArg>`;
   update the plain logical sites (`render`, `runTurn`, `Genkit.run`) to pass just
   a name. Ensure the `generate` action flows through the normal action path so it
   carries `ActionMetadata`.
4. Update `action.dart` to read `traceId`/`spanId` from `currentRunContext`.
5. Move the existing OTLP/HTTP exporter into a built-in Dev UI `ObservabilityHook`
   (still in core, no OTel SDK), auto-installed via `addObservabilityHook(...)`
   when `GENKIT_TELEMETRY_SERVER` is set.
6. Create `genkit_otel` package that installs an `ObservabilityHook` over
   `package:opentelemetry`, including model-usage metrics.
7. Remove `package:opentelemetry` from `genkit`'s `pubspec.yaml`; move it to
   `genkit_otel`.
8. Update tests (`test/core/action_test.dart`, `test/o11y/*`) to use the new hook
   seam.
