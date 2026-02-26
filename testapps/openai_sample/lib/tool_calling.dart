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

import 'dart:io';
import 'dart:math';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

part 'tool_calling.g.dart';

@Schematic()
abstract class $WeatherFlowInput {
  /// Natural language weather query, e.g. "What's the weather in Boston?"
  String get prompt;
}

@Schematic()
abstract class $WeatherToolInput {
  /// City name or coordinates to look up
  String get location;

  /// Temperature unit — 'celsius' or 'fahrenheit'
  @StringField(enumValues: ['celsius', 'fahrenheit'])
  String? get unit;
}

@Schematic()
abstract class $WeatherToolOutput {
  double get temperature;
  String get condition;
  String get unit;
  int? get humidity;
}

/// Defines a flow that demonstrates OpenAI tool/function calling.
///
/// Registers a mock weather tool and lets the model decide when and how to
/// invoke it. The model receives the tool's result and composes a final answer.
Flow<WeatherFlowInput, String, void, void> defineToolCallingFlow(Genkit ai, Tool getWeather) {

  return ai.defineFlow(
    name: 'toolCalling',
    inputSchema: WeatherFlowInput.$schema,
    outputSchema: .string(),
    fn: (input, _) async {
      final response = await ai.generate(
        model: openAI.model('gpt-4o-mini'),
        prompt: input.prompt,
        toolNames: [getWeather.name],
      );
      return response.text;
    },
  );
}

/// Defines a flow that demonstrates streaming tool/function calling.
///
/// This flow works just like [defineToolCallingFlow], but emits text as it streams from the model.
Flow<WeatherFlowInput, String, String, void> defineStreamedToolCallingFlow(Genkit ai, Tool getWeather) {
  return ai.defineFlow(
    name: 'streamedToolCalling',
    inputSchema: WeatherFlowInput.$schema,
    outputSchema: .string(),
    streamSchema: .string(),
    fn: (input, ctx) async {
      final stream = ai.generateStream(
        model: openAI.model('gpt-4o-mini'),
        prompt: input.prompt,
        toolNames: [getWeather.name],
      );

      await for (final chunk in stream) {
        if (ctx.streamingRequested) {
          ctx.sendChunk(chunk.text);
        }
      }

      return (await stream.onResult).text;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [openAI(apiKey: Platform.environment['OPENAI_API_KEY'])],
  );

  final getWeather = ai.defineTool(
    name: 'getWeather',
    description:
        'Get the current weather for a specific location. Returns temperature and conditions.',
    inputSchema: WeatherToolInput.$schema,
    outputSchema: WeatherToolOutput.$schema,
    fn: (input, _) async {
      final unit = input.unit ?? 'celsius';
      final random = Random();
      final tempCelsius = 15 + random.nextInt(20);
      final temperature =
          unit == 'fahrenheit' ? (tempCelsius * 9 / 5) + 32 : tempCelsius.toDouble();
      final conditions = ['sunny', 'cloudy', 'rainy', 'partly cloudy'];

      return WeatherToolOutput(
        temperature: temperature,
        condition: conditions[random.nextInt(conditions.length)],
        unit: unit,
        humidity: 50 + random.nextInt(30),
      );
    },
  );

  defineToolCallingFlow(ai, getWeather);
  defineStreamedToolCallingFlow(ai, getWeather);
}
