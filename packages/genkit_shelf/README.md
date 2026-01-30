[![Pub](https://img.shields.io/pub/v/genkit_shelf.svg)](https://pub.dev/packages/genkit_shelf)

Shelf integration for Genkit Dart.

## Usage

### Standalone Server

The easiest way to serve your flows is using `startFlowServer`:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

void main() async {
  final ai = Genkit();

  final flow = ai.defineFlow(
    name: 'myFlow',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (String input, _) async => 'Hello $input',
  );

  await startFlowServer(
    flows: [flow],
    port: 8080,
  );
}
```

### Existing Shelf Application

You can also integrate Genkit flows into an existing Shelf application using `shelfHandler`. This allows you to use your own routing, middleware, and server configuration.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final ai = Genkit();

  final flow = ai.defineFlow(
    name: 'myFlow',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (String input, _) async => 'Hello $input',
  );

  // Create a Shelf Router
  final router = Router();

  // Mount the flow handler at a specific path
  router.post('/myFlow', shelfHandler(flow));

  // Add other application routes
  router.get('/health', (Request request) => Response.ok('OK'));

  // Start the server
  await io.serve(router.call, 'localhost', 8080);
}
```
