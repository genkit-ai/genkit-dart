import 'package:genkit/genkit.dart';
import 'package:genkit/plugins/google-genai.dart';

void main() async {
  final genkit = Genkit(
    plugins: [googleAI()],
  );

  final model = 'gemini-2.5-flash';

  final response = await genkit.generate(
    model: model,
    prompt:
        'Tell me a joke about a developer who is trying to learn a new language.',
  );

  print(response.text);

  await genkit.shutdown();
}