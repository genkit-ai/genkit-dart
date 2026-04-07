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

### Authentication and ContextProvider

You can secure your flows and models by providing a `contextProvider` to `shelfHandler`. This allows the server to verify headers (like `Authorization`) before executing the action, and pass that context down to the Genkit action.

```dart
// 1. Define a flow that requires authentication
final secureFlow = ai.defineFlow(
  name: 'secureFlow',
  inputSchema: .string(),
  outputSchema: .string(),
  fn: (input, ctx) async {
    final userId = ctx.context?['userId'];
    if (userId == null) throw Exception('Unauthorized');
    return 'Hello $input, your ID is $userId!';
  },
);

// 2. Define a model you want to secure
final geminiApi = googleAI();
final secureModel = geminiApi.model('gemini-2.5-flash');

final router = Router();

// 3. Shared context provider for authentication
Future<Map<String, dynamic>> authContextProvider(Request request) async {
  final authHeader = request.headers['authorization'];
  // checkUserToken is where you implement your custom auth logic
  final user = await checkUserToken(authHeader);
  if (user != null) {
    return {'userId': user.id};
  }
  return {}; // Or throw an exception to reject early
}

// 4. Secure the endpoints
router.post('/secureFlow', shelfHandler(
  secureFlow,
  contextProvider: authContextProvider,
));

router.post('/secureModel', shelfHandler(
  secureModel,
  contextProvider: authContextProvider,
));
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
  url: 'http://localhost:8080/secureModel',
  headers: (context) async => {'Authorization': 'Bearer ${await getUserToken()}'},
);

final generateResponse = await ai.generate(
  model: remoteModel,
  prompt: 'Hello!',
);
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
