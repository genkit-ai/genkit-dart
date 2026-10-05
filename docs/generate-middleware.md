# Generate Middleware

Middleware in Genkit Dart allows you to intercept, inspect, and modify the execution of models and tools during a `generate` call. This is incredibly powerful for implementing cross-cutting concerns like logging, telemetry, caching, and retry logic.

## The `GenerateMiddleware` Base Class

At its core, a basic middleware is a class extending `GenerateMiddleware`. You can override the `generate`, `model` and `tool` methods to wrap the underlying execution at different stages.

- `generate`: Wraps the entire generation process, including the tool loop. Called once per tool loop iteration.
- `model`: Wraps the raw call to the model. Called once per model call.
- `tool`: Wraps independent tool calls. Called once per tool call.

```dart
import 'package:genkit/genkit.dart';

class PrintMiddleware extends GenerateMiddleware {
  @override
  Future<GenerateResult> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    ) next,
  ) async {
    print('Turn ${envelope.currentTurn} started for model: '
        '${envelope.request.model}');
    final response = await next(envelope, ctx);
    print('Turn ${envelope.currentTurn} finished');
    return response;
  }

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    ) next,
  ) async {
    print('Model request started: ${request.messages.length} messages');
    final response = await next(request, ctx);
    print('Model request finished');
    return response;
  }
}
```

## Configurable Middleware

The rest of this page builds a configurable `logger` middleware, first registered in app code and then packaged in a plugin. Both use the same options schema and middleware class.

### Configuration Schema

Use `schemantic` to define the configuration options for your middleware. This ensures that the configuration can be safely serialized and validated.

```dart
import 'package:schemantic/schemantic.dart';

part 'logger.g.dart';

@Schema()
abstract class $LoggerOptions {
  bool? get enableColor;
  int? get maxLogLength;
}
```

### Middleware Logic

Create the actual middleware implementation. By convention, name the concrete class with an `Middleware` suffix (e.g., `LoggerMiddleware`).

```dart
class LoggerMiddleware extends GenerateMiddleware {
  final bool enableColor;
  final int maxLogLength;

  LoggerMiddleware({
    this.enableColor = false,
    this.maxLogLength = 1000,
  });

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    ) next,
  ) async {
    // Custom interception logic here...
    return next(request, ctx);
  }
}
```

## Defining Middleware in Your App

While you can pass raw middleware instances directly to `generate` (e.g. `use: [PrintMiddleware()]`), prefer registering it. **Only registered middleware shows up in the Genkit Developer UI**, where it can be configured and used.

In app code, `ai.defineGenerateMiddleware` registers a middleware and returns its definition. Call the definition to build the ref for `use:`:

```dart
final logger = ai.defineGenerateMiddleware<LoggerOptions>(
  name: 'logger',
  configSchema: LoggerOptions.$schema,
  create: (config, ctx) => LoggerMiddleware(
    enableColor: config?.enableColor ?? false,
    maxLogLength: config?.maxLogLength ?? 1000,
  ),
);

await ai.generate(
  model: googleAI.gemini('gemini-flash-latest'),
  prompt: 'Hello world',
  use: [logger(LoggerOptions(enableColor: true)), retry(maxRetries: 2)],
);

await ai.generate(prompt: 'Hi again', use: [logger()]); // config is optional
```

A middleware defined this way replaces a built-in or plugin middleware with the same name.

`configSchema` is optional, but without it the middleware can't take a JSON config, for example from the Developer UI or a `.prompt` file. Such a config fails with an `INVALID_ARGUMENT` error.

## Packaging Middleware in a Plugin

To ship middleware in a reusable package, build the definition with `generateMiddleware` and register it from a plugin. This pattern, used by built-in middleware like `retry` and by the `genkit_middleware` plugins, supports:

1. **Dev UI Integration:** Allowing full visibility and configurability from the Developer UI.
2. **Type-Safe Configurations:** Using Schemantic to define validated configuration schemas.
3. **Dynamic Resolution:** Allowing configurations to be resolved at runtime via the Genkit Registry.
4. **Ergonomic Usage:** Providing simple, named-parameter helper functions for consumers.

Here is how you package the `LoggerOptions` schema and `LoggerMiddleware` class from [Configurable Middleware](#configurable-middleware).

### 1. Define the Middleware and Plugin

Use `generateMiddleware` to link your schema and implementation. Unlike `ai.defineGenerateMiddleware`, it only builds the definition; expose it via a `GenkitPlugin` so it is registered when Genkit initializes. By convention, name the plugin class with a `Plugin` suffix (e.g., `LoggerPlugin`).

```dart
final loggerDef = generateMiddleware<LoggerOptions>(
  // name should be reasonably unique to avoid conflicts with other plugins.
  name: 'logger',
  configSchema: LoggerOptions.$schema,
  create: (config, ctx) => LoggerMiddleware(
    enableColor: config?.enableColor ?? false,
    maxLogLength: config?.maxLogLength ?? 1000,
  ),
);

// The plugin that registers the middleware definition
class LoggerPlugin extends GenkitPlugin {
  @override
  String get name => 'logger';

  @override
  List<GenerateMiddlewareDef> middleware() => [loggerDef];
}
```

Like the one returned by `ai.defineGenerateMiddleware`, the definition is callable: `loggerDef(LoggerOptions(enableColor: true))` builds a ref for `use:`.

### 2. Create the DX Helper Function

For the best developer experience, wrap the definition in a factory function with named parameters, so users don't have to build the options object themselves.

```dart
/// Convenient helper to use the middleware in `generate(use: [...])`
GenerateMiddlewareRef<LoggerOptions> logger({
  bool? enableColor,
  int? maxLogLength,
}) => loggerDef(
  LoggerOptions(enableColor: enableColor, maxLogLength: maxLogLength),
);
```

### 3. Usage

Consumers first register the plugin when initializing Genkit, and then use your DX helper function directly in their `generate` calls!

```dart
void main() {
  final genkit = Genkit(
    plugins: [LoggerPlugin()],
  );

  final response = await genkit.generate(
    model: customModel,
    prompt: 'Hello world',
    use: [
      logger(
        enableColor: true,
        maxLogLength: 500,
      ),
    ],
  );
}
```

## Accessing AI from Middleware (Middleware Context)

The `create` callback you pass to `ai.defineGenerateMiddleware` or `generateMiddleware`
receives two positional arguments: the resolved `config`, and a
`GenerateMiddlewareContext` (`ctx`).

```dart
create: (config, ctx) => LoggerMiddleware(...),
```

If you don't need the context, name the second parameter `_` and ignore it.

The context carries an ephemeral `GenkitAI` instance via `ctx.ai`. This lets a
middleware run its own AI operations (`generate`, `generateStream`, `embed`,
etc.) at request time. This is useful for middleware that needs to call a model
itself, for example an AI risk/safety classifier that scores or filters a
request, a summarization or guardrail middleware, or a routing middleware that
asks a model to pick a downstream model.

```dart
class RiskClassifierPlugin extends GenkitPlugin {
  @override
  String get name => 'risk_classifier';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    generateMiddleware<RiskClassifierOptions>(
      name: 'risk_classifier',
      configSchema: RiskClassifierOptions.$schema,
      // Pass the ephemeral GenkitAI to the middleware via the context.
      create: (config, ctx) =>
          RiskClassifierMiddleware(config, ai: ctx.ai),
    ),
  ];
}

class RiskClassifierMiddleware extends GenerateMiddleware {
  RiskClassifierMiddleware(this.config, {required this.ai});

  final RiskClassifierOptions? config;
  final GenkitAI ai;

  @override
  Future<GenerateResult> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    ) next,
  ) async {
    // Run a nested generate to classify the request before continuing.
    final lastMessage = envelope.request.messages.last.text;
    final verdict = await ai.generate(
      prompt: 'Classify the risk of this request: $lastMessage',
    );
    if (verdict.text.contains('BLOCK')) {
      throw GenkitException('Request blocked by risk classifier');
    }
    return next(envelope, ctx);
  }
}
```

The same `ctx.ai` also exposes the active registry, so a middleware can resolve
other registered actions (models, tools, agents, etc.) by name:

```dart
final agent = await ctx.ai.registry.lookupAction('agent', 'researcher');
```

## Lifecycle and Stateful Middleware

When you use a registered middleware (via `ai.defineGenerateMiddleware` or a plugin), **a new instance of the middleware is instantiated for every single `generate` call.**

Because of this per-request lifecycle, the middleware instance is isolated safely to that specific generation execution. This makes it the perfect place to maintain state across the different interceptors (`generate`, `model`, and `tool`) and across multi-turn tool calling loops.

For example, you could write a stateful middleware to count and strictly enforce the number of model iterations (a custom "max turns" property):

```dart
class TurnLimitingMiddleware extends GenerateMiddleware {
  final int maxTurns;
  
  // Isolated state for this specific `generate` call
  int _turnCount = 0;

  TurnLimitingMiddleware({this.maxTurns = 3});

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    ) next,
  ) async {
    _turnCount++;
    if (_turnCount > maxTurns) {
      throw Exception('Exceeded custom turn limit of $maxTurns.');
    }
    
    print('Starting turn: $_turnCount');
    return next(request, ctx);
  }
}
```

Another powerful pattern using stateful middleware is communicating between `tool` invocations and the subsequent `model` calls. For example, if a tool call needs to inject extra systemic messages or context before the loop continues, the `tool` interceptor can safely save that message to an instance field, which the `model` or `generate` interceptor can then read and inject into the history before yielding back to the model!
