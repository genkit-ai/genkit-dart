[![Pub](https://img.shields.io/pub/v/genkit_shelf.svg)](https://pub.dev/packages/genkit_shelf)

Shelf integration for Genkit Dart.

> **Building with a coding agent? Install the Genkit Dart skill first.**
>
> ```bash
> npx skills add genkit-ai/skills --skill developing-genkit-dart
> ```
>
> It teaches your agent the current Genkit Dart APIs and common gotchas.
> Source, manual install and skills for other languages:
> [genkit-ai/skills](https://github.com/genkit-ai/skills).

## Usage

Genkit's HTTP serving lives in `package:genkit/io.dart` (see the
[genkit README](https://pub.dev/packages/genkit#serving-over-http)): register
actions and agents on a `GenkitRouter`, then serve it standalone or from your
own `dart:io` server. This package is the adapter for
[shelf](https://pub.dev/packages/shelf) apps.

### Mounting a GenkitRouter

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
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

  // Just an example, can use Anthropic, OpenAI, etc. models
  final geminiFlash = googleAI().model('gemini-flash-latest');

  final genkit = GenkitRouter()
    ..addAction(flow) // POST /api/myFlow
    ..addAction(geminiFlash, contextProvider: bearerAuth); // POST /api/googleai/gemini-flash-latest

  final app = Router()
    ..get('/health', (Request request) => Response.ok('OK'))
    ..mount('/api/', genkit.asShelfHandler());

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(app.call);

  await io.serve(handler, 'localhost', 8080);
}
```

Unknown paths get a `404`, so a shelf `Cascade` falls through to the next
handler. Streaming responses are passed through unbuffered.

For browser clients on another origin, pass `CorsOptions` (the same options as
`GenkitRouter.serve`). The defaults allow any origin and expose the
`x-genkit-trace-id` / `x-genkit-span-id` headers:

```dart
final app = Router()
  ..mount(
    '/api/',
    genkit.asShelfHandler(
      cors: const CorsOptions(allowedOrigins: ['https://myapp.dev']),
    ),
  );
```

### Single actions

`shelfHandler` serves one action on a route of your choosing:

```dart
router.post('/myFlow', shelfHandler(myFlow, contextProvider: bearerAuth));
```

### Authentication and ContextProvider

A `contextProvider` verifies the request before the action runs, and what it
returns becomes the action context. It receives a framework-neutral
`RequestData` (lowercased headers, method, parsed input), so the same function
works with shelf, plain `dart:io`, or any other adapter.

```dart
Future<Map<String, dynamic>> bearerAuth(RequestData request) async {
  final user = await checkUserToken(request.headers['authorization']);
  if (user == null) {
    throw GenkitException('Unauthorized', status: StatusCode.unauthenticated); // 401
  }
  return {'userId': user.id};
}
```

A thrown `GenkitException` is answered with its status; anything else with
`403`.

### Serving agents (experimental)

`addAgent` comes from `package:genkit/experimental_io.dart` and works the same
when the router is mounted into shelf:

```dart
import 'package:genkit/experimental_io.dart';
import 'package:genkit/io.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

final genkit = GenkitRouter()
  ..addAgent(weatherAgent) // turn + /getSnapshot + /abort
  ..addAgent(statelessAgent); // turn only

final app = Router()..mount('/api/', genkit.asShelfHandler());
```

```dart
final agent = remoteAgent(url: 'http://localhost:8080/api/weatherAgent');
final res = await agent.chat().send(text: 'Weather in Paris?');
```

## Migrating from 0.2.x

| 0.2.x | Now |
| --- | --- |
| `startFlowServer(flows: [...], port: ..., cors: {...})` | `GenkitRouter()..addAction(...)`, then `serve(port: ..., cors: CorsOptions(...))`, all from `package:genkit/io.dart` (no shelf needed) |
| `shelf_cors_headers` around Genkit routes | `genkit.asShelfHandler(cors: CorsOptions(...))` |
| `FlowWithContextProvider(flow: f, context: p)` | `addAction(f, contextProvider: p)` |
| `shelfHandler(action, contextProvider: ...)` | unchanged, but the provider takes `RequestData` instead of a shelf `Request` |
| `ContextProvider` from `genkit_shelf` | `ContextProvider` from `package:genkit/io.dart` |

If your server is already in production with Dart or Flutter clients on `package:genkit` 0.17 or earlier, set `sendLegacyErrorFrame: true` on the `GenkitRouter` (and on any `shelfHandler`/`ioHandler`) until those clients are updated. Without it, those older clients report a generic "stream finished" error instead of the server's message when a streamed call fails. Current Dart clients and JS/Python clients handle both frames.
