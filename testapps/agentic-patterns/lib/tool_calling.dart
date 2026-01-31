import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'tool_calling.g.dart';

@Schematic()
abstract class $ToolCallingInput {
  String get prompt;
}

@Schematic()
abstract class $ToolCallingWeatherInput {
  String get location;
}

// Define a tool that can be called by the LLM
final getWeather = ai.defineTool(
  name: 'getWeather',
  description: 'Get the current weather in a given location.',
  inputSchema: ToolCallingWeatherInput.$schema,
  outputSchema: stringSchema(),
  fn: (input, _) async {
    // In a real app, you would call a weather API here.
    return 'The weather in ${input.location} is 75°F and sunny.';
  },
);

final toolCallingFlow = ai.defineFlow(
  name: 'toolCallingFlow',
  inputSchema: ToolCallingInput.$schema,
  outputSchema: stringSchema(),
  fn: (input, _) async {
    final response = await ai.generate(
      model: geminiFlash,
      prompt: input.prompt,
      tools: [getWeather.name],
    );

    return response.text;
  },
);
