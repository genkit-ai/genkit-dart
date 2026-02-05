---

## Genkit Lite API

For lightweight applications or scripts where you only need basic model orchestration without the full Genkit framework (no registries, flows, or Dev UI), you can use the Lite API.

```dart
import 'package:genkit/lite.dart' as lite;
import 'package:genkit/genkit.dart'; // For RetryMiddleware
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  final gemini = googleAI();

  // Direct function call, no Genkit instance required
  final response = await lite.generate(
    model: gemini.model('gemini-2.5-flash'),
    prompt: 'Hello from Lite API!',
    // Middleware objects are used directly in the Lite API
    use: [
      RetryMiddleware(maxRetries: 2),
    ],
  );

  print(response.text);
}
```

