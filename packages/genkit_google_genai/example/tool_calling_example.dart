// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'tool_calling_example.schema.g.dart';

@Schematic()
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
    inputType: stringType(),
    outputType: stringType(),
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
