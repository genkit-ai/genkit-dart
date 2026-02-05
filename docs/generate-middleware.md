# Generate Middleware

Middleware in Genkit Dart allows you to intercept, inspect, and modify the execution of models and tools during a `generate` call. This is incredibly powerful for implementing cross-cutting concerns like logging, telemetry, caching, and retry logic.

## The `GenerateMiddleware` Base Class

At its core, a basic middleware is a class extending `GenerateMiddleware`. You can override the `model` and `tool` methods to wrap the underlying execution.

```dart
import 'package:genkit/genkit.dart';

class LoggingMiddleware extends GenerateMiddleware {
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

While you can pass raw middleware instances directly to `generate` (e.g. `use: [LoggingMiddleware()]`), Genkit encourages using the **Registered Middleware Architecture**. **Crucially, only registered middleware can be configured and utilized via the Genkit Developer UI.** Unregistered, raw middleware instances cannot be represented or configured in the Dev UI.

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

part 'my_middleware.g.dart';

@Schematic()
abstract class $MyMiddlewareOptions {
  bool? get enableFeatureX;
  int? get maxRetries;
}
```

### 2. Implement the Middleware Logic

Create the actual middleware implementation. By convention, name the concrete class with an `Impl` suffix (e.g., `MyMiddlewareImpl`) to keep the primary name available for the plugin wrapper.

```dart
class MyMiddlewareImpl extends GenerateMiddleware {
  final bool enableFeatureX;
  final int maxRetries;

  MyMiddlewareImpl({
    this.enableFeatureX = false,
    this.maxRetries = 3,
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

Use `defineMiddleware` to link your schema and implementation. Then, expose it via a `GenkitPlugin` so it can be registered when Genkit initializes.

```dart
final _myMiddlewareDef = defineMiddleware<MyMiddlewareOptions>(
  name: 'my-middleware',
  configSchema: MyMiddlewareOptions.$schema,
  create: ([MyMiddlewareOptions? config]) => MyMiddlewareImpl(
    enableFeatureX: config?.enableFeatureX ?? false,
    maxRetries: config?.maxRetries ?? 3,
  ),
);

// The plugin that registers the middleware definition
class MyMiddleware extends GenkitPlugin {
  @override
  String get name => 'my-middleware';

  @override
  List<GenerateMiddlewareDef> middleware() => [_myMiddlewareDef];
}
```

### 4. Create the DX Helper Function

To provide the best developer experience, create a factory function that returns a `GenerateMiddlewareRef`. Instead of forcing the user to instantiate the configuration object directly, use named parameters. This makes the middleware incredibly easy to use inline.

```dart
/// Convenient helper to use the middleware in `generate(use: [...])`
GenerateMiddlewareRef<MyMiddlewareOptions> myMiddleware({
  bool? enableFeatureX,
  int? maxRetries,
}) {
  return middlewareRef(
    name: 'my-middleware',
    config: MyMiddlewareOptions(
      enableFeatureX: enableFeatureX,
      maxRetries: maxRetries,
    ),
  );
}
```

## Usage

Consumers first register the plugin when initializing Genkit, and then use your DX helper function directly in their `generate` calls!

```dart
void main() {
  final genkit = Genkit(
    plugins: [MyMiddleware()],
  );

  final response = await genkit.generate(
    model: customModel,
    prompt: 'Hello world',
    // The `use` array accepts dynamic parameters, allowing our DX helper
    // to map the configuration to the registered middleware transparently!
    use: [
      myMiddleware(
        enableFeatureX: true,
        maxRetries: 5,
      ),
    ],
  );
}
```
