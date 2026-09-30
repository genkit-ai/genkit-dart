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

### Serving flows and models

Register actions on a `GenkitRouter` and start a server. Any action works: flows, models, tools and so on. Each one is served as a POST endpoint at `/<action name>`.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

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
    ..addAction(flow) // POST /myFlow
    ..addAction(geminiFlash); // POST /googleai/gemini-flash-latest

  await genkit.serve(port: 8080);
}
```

`serve` options:

```dart
await genkit.serve(
  host: InternetAddress.loopbackIPv4, // default: anyIPv4
  port: 8080, // default: $PORT, then 3400
  cors: const CorsOptions(allowedOrigins: ['https://myapp.dev']), // default: no CORS
);
```

Use `path` to serve an action somewhere other than `/<action name>`:

```dart
genkit.addAction(flow, path: '/v1/hello');
```

### Authentication and ContextProvider

Pass a `contextProvider` to verify the request (for example the `Authorization` header) before the action runs. What it returns becomes the action context. If it throws, the request is rejected with `403`.

```dart
// checkUserToken is where you implement your custom auth logic.
Future<Map<String, dynamic>> bearerAuth(Request request) async {
  final user = await checkUserToken(request.headers['authorization']);
  if (user == null) throw Exception('Unauthorized');
  return {'userId': user.id};
}

final secureFlow = ai.defineFlow(
  name: 'secureFlow',
  inputSchema: .string(),
  outputSchema: .string(),
  fn: (input, ctx) async => 'Hello $input, your ID is ${ctx.context?['userId']}!',
);

final genkit = GenkitRouter()
  ..addAction(publicFlow)
  ..addAction(secureFlow, contextProvider: bearerAuth)
  ..addAction(geminiFlash, contextProvider: bearerAuth);
```

When consuming these remote endpoints from a client using `defineRemoteModel` or `defineRemoteAction`, you can pass the required headers:

```dart
import 'package:genkit/client.dart';

// Consuming a secure flow
final remoteFlow = defineRemoteAction(
  url: 'http://localhost:8080/secureFlow',
  inputSchema: .string(),
  outputSchema: .string(),
);

final response = await remoteFlow(
  input: 'World',
  headers: {'Authorization': 'Bearer ${await getUserToken()}'},
);

// Consuming a secure model
final remoteModel = ai.defineRemoteModel(
  name: 'remoteModel',
  url: 'http://localhost:8080/googleai/gemini-flash-latest',
  headers: (context) async => {'Authorization': 'Bearer ${await getUserToken()}'},
);

final generateResponse = await ai.generate(
  model: remoteModel,
  prompt: 'Hello!',
);
```

### Serving agents (experimental)

`addAgent` comes from `package:genkit_shelf/agents.dart`. Like `package:genkit/experimental.dart`, that library isn't covered by semver.

```dart
import 'package:genkit_shelf/agents.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

final genkit = GenkitRouter()
  ..addAgent(weatherAgent)
  ..addAgent(bankingAgent, contextProvider: bearerAuth, hideAbort: true)
  ..addAgent(statelessAgent);

await genkit.serve();
```

Each agent gets the routes that `remoteAgent` from `package:genkit/client.dart` expects, depending on what the agent supports:

| Route | Mounted when |
| --- | --- |
| `POST /<name>` | always (runs a turn) |
| `POST /<name>/getSnapshot` | the agent has a session store, unless `hideGetSnapshot` |
| `POST /<name>/abort` | the agent's store can signal a running turn, unless `hideAbort` |

So a client-managed (store-less) agent gets only its turn route. All the built-in stores support abort. The `contextProvider` applies to every mounted route.

```dart
final agent = remoteAgent(url: 'http://localhost:3400/weatherAgent');
final res = await agent.chat().send(text: 'Weather in Paris?');
```

### Existing Shelf application

`GenkitRouter` is also a shelf handler, so you can mount it into your own app and keep your own routing, middleware and server setup:

```dart
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final genkit = GenkitRouter()
    ..addAction(myFlow)
    ..addAction(geminiFlash);

  final app = Router()
    ..get('/health', (Request request) => Response.ok('OK'))
    ..mount('/api/', genkit.call); // POST /api/myFlow, ...

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(app.call);

  await io.serve(handler, 'localhost', 8080);
}
```

To mount a single action yourself, use `shelfHandler`:

```dart
router.post('/myFlow', shelfHandler(myFlow, contextProvider: bearerAuth));
```

## Consuming Remote Models

When you serve a model using `genkit_shelf`, you can consume it from another Genkit application using `defineRemoteModel`:

```dart
final ai = Genkit();

final remoteModel = ai.defineRemoteModel(
  name: 'myRemoteModel',
  url: 'http://localhost:8080/googleai/gemini-flash-latest',
);

final response = await ai.generate(
  model: remoteModel,
  prompt: 'Hello!',
);

print(response.text);
```
