import 'package:genkit/genkit.dart';
import 'package:genkit/plugins/google_genai.dart';

part 'tool_calling_example.schema.g.dart';

@GenkitSchema()
abstract class WeatherToolInputSchema {
  String get location;
}

void main() async {
  configureCollectorExporter();

  final ai = Genkit(plugins: [googleAI()]);

  ai.defineTool(
    name: 'getWeather',
    description: 'Get the weather for a location',
    inputType: WeatherToolInputType,
    fn: (input, context) async {
      if (input.location.toLowerCase().contains('boston')) {
        return 'The weather in Boston is 72 and sunny.';
      }
      return 'The weather in ${input.location} is 75 and cloudy.';
    },
  );

  final weatherFlow = ai.defineFlow(
    name: 'weatherFlow',
    inputType: StringType,
    outputType: StringType,
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: prompt,
        tools: ['getWeather'],
      );
      return response.text;
    },
  );
  final result = await weatherFlow('What is the weather in Boston?');
  print(result);
}
