[![Pub](https://img.shields.io/pub/v/genkit_shelf.svg)](https://pub.dev/packages/genkit_shelf)

Shelf integration for Genkit Dart.

## Usage

### Serving Flows

The easiest way to serve your flows is using `startFlowServer`:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

void main() async {
  final ai = Genkit();

  final flow = ai.defineFlow(
    name: 'myFlow',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (String input, _) async => 'Hello $input',
  );

  await startFlowServer(
    flows: [flow],
    port: 8080,
  );
}
```

### Serving Models

You can also serve AI models (and other actions) using `startFlowServer` or `shelfHandler`:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

void main() async {
  // Just an example, can use Anthropic, OpenAI, etc. models
  final geminiApi = googleAI();
  final geminiFlash = geminiApi.model('gemini-2.5-flash');

  await startFlowServer(
    flows: [geminiFlash],
    port: 8080,
  );
}
```

### Existing Shelf Application

You can also integrate Genkit flows and actions (like models) into an existing Shelf application using `shelfHandler`. This allows you to use your own routing, middleware, and server configuration.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final ai = Genkit();

  final flow = ai.defineFlow(
    name: 'myFlow',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (String input, _) async => 'Hello $input',
  );

  final geminiApi = googleAI();
  final geminiFlash = geminiApi.model('gemini-2.5-flash');

  // Create a Shelf Router
  final router = Router();

  // Mount handlers
  router.post('/myFlow', shelfHandler(flow));
  router.post('/geminiFlash', shelfHandler(geminiFlash));

  // Add other application routes
  router.get('/health', (Request request) => Response.ok('OK'));

  // Start the server
  await io.serve(router.call, 'localhost', 8080);
}
```

## Consuming Remote Models

When you serve a model using `genkit_shelf`, you can consume it from another Genkit application using `defineRemoteModel`:

```dart
final ai = Genkit();

final remoteModel = ai.defineRemoteModel(
  name: 'myRemoteModel',
  url: 'http://localhost:8080/googleai/gemini-2.5-flash',
);

final response = await ai.generate(
  model: remoteModel,
  prompt: 'Hello!',
);

print(response.text);
```
