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
  Future<GenerateResponseHelper> generate(
    GenerateActionOptions options,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateActionOptions options,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    ) next,
  ) async {
    print('Generate action started for model: ${options.model}');
    final response = await next(options, ctx);
    print('Generate action finished');
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

## Registered Middleware Architecture (Best Practice)

While you can pass raw middleware instances directly to `generate` (e.g. `use: [PrintMiddleware()]`), Genkit encourages using the **Registered Middleware Architecture**. **Crucially, only registered middleware can be configured and utilized via the Genkit Developer UI.** Unregistered, raw middleware instances cannot be represented or configured in the Dev UI.

This pattern, used by official plugins like `RetryMiddleware`, also provides the best Developer Experience (DX) in code by supporting:

1. **Dev UI Integration:** Allowing full visibility and configurability from the Developer UI.
2. **Type-Safe Configurations:** Using Schemantic to define validated configuration schemas.
3. **Dynamic Resolution:** Allowing configurations to be resolved at runtime via the Genkit Registry.
4. **Ergonomic Usage:** Providing simple, named-parameter helper functions for consumers.

Here is how you build a production-ready middleware following these DX focused principles.

### 1. Define the Configuration Schema

Use `schemantic` to define the configuration options for your middleware. This ensures that the configuration can be safely serialized and validated.

```dart
import 'package:schemantic/schemantic.dart';

part 'logger.g.dart';

@Schematic()
abstract class $LoggerOptions {
  bool? get enableColor;
  int? get maxLogLength;
}
```

### 2. Implement the Middleware Logic

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

### 3. Define the Middleware and Plugin

Use `defineMiddleware` to link your schema and implementation. Then, expose it via a `GenkitPlugin` so it can be registered when Genkit initializes. By convention, name the plugin class with a `Plugin` suffix (e.g., `LoggerPlugin`).

```dart
// The plugin that registers the middleware definition
class LoggerPlugin extends GenkitPlugin {
  @override
  String get name => 'logger';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<LoggerOptions>(
      // name should be reasonably unique to avoid conflicts with other plugins.
      name: 'logger',
      configSchema: LoggerOptions.$schema,
      create: ([LoggerOptions? config]) => LoggerMiddleware(
        enableColor: config?.enableColor ?? false,
        maxLogLength: config?.maxLogLength ?? 1000,
      ),
    ),
  ];
}
```

### 4. Create the DX Helper Function

To provide the best developer experience, create a factory function that returns a `GenerateMiddlewareRef`. Instead of forcing the user to instantiate the configuration object directly, use named parameters. This makes the middleware incredibly easy to use inline.

```dart
/// Convenient helper to use the middleware in `generate(use: [...])`
GenerateMiddlewareRef<LoggerOptions> logger({
  bool? enableColor,
  int? maxLogLength,
}) {
  return middlewareRef(
    name: 'logger',
    config: LoggerOptions(
      enableColor: enableColor,
      maxLogLength: maxLogLength,
    ),
  );
}
```

## Usage

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

## Lifecycle and Stateful Middleware

When you register a middleware using the `GenerateMiddlewareRef` pattern, **a new instance of the middleware is instantiated for every single `generate` call.** 

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
