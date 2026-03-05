import 'package:genkit/genkit.dart';
// import plugin
// import 'package:genkit_google_genai/genkit_google_genai.dart';
// import 'package:genkit_anthropic/genkit_anthropic.dart';
// import 'package:genkit_openai/genkit_openai.dart';

void main() async {
  // Initialize Genkit
  final ai = Genkit(plugins: [
    // install plugin:
    //
    // googleAI(),
    // anthropic(),
    // openAI(),
  ]);

  // Define a simple flow
  final basicFlow = ai.defineFlow(
    name: 'basic',
    inputSchema: .string(defaultValue: 'World'),
    outputSchema: .string(),
    fn: (String subject, _) async {
      // call generate action:
      //
      // final response = await ai.generate(
      //   model: googleAI.gemini('gemini-flash-latest'),
      //   prompt: 'Say hello to $subject!',
      // );
      // return response.text;
      return 'hello $subject';
    },
  );

  // Run the flow directly
  final result = await basicFlow('World');
  print(result);
}
