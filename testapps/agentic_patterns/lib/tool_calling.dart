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
import 'package:schemantic/schemantic.dart';

part 'tool_calling.g.dart';

@Schematic()
abstract class $ToolCallingInput {
  String get prompt;
}

@Schematic()
abstract class $ToolCallingWeatherInput {
  String get location;
}

Flow<ToolCallingInput, String, void, void> defineToolCallingFlow(
  Genkit ai,
  ModelRef geminiFlash,
) {
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

  return ai.defineFlow(
    name: 'toolCallingFlow',
    inputSchema: ToolCallingInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      final response = await ai.generate(
        model: geminiFlash,
        prompt: input.prompt,
        toolNames: [getWeather.name],
      );

      return response.text;
    },
  );
}
