import 'package:genkit/genkit.dart';
import 'package:genkit/plugins/google_genai.dart';

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt:
        'Tell me a joke about a developer who is trying to learn a new language.',
  );

  print(response.text);
}
