import 'package:genkit/lite.dart';
import 'package:genkit/plugins/google_genai.dart';

void main() async {
  final gemini = googleAI();

  final response = await generate(
    model: gemini.model('gemini-2.5-flash'),
    prompt:
        'Tell me a joke about a developer who is trying to learn a new language.',
  );

  print(response.text);
}
