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

import 'openai_flows.dart';

Future<void> main(List<String> args) async {
  // Get API key from args or environment
  final apiKey = args.isNotEmpty
      ? args[0]
      : Platform.environment['OPENAI_API_KEY'];

  if (apiKey == null || apiKey.isEmpty) {
    print('Error: OPENAI_API_KEY is required.');
    print('Usage: dart run lib/main.dart [API_KEY]');
    print('   or: Set OPENAI_API_KEY environment variable');
    print('   or: Run with Genkit UI: npx genkit start -- dart run lib/main.dart');
    exit(1);
  }

  // Configure telemetry for Genkit UI
  configureCollectorExporter();

  // Initialize Genkit with OpenAI plugin
  final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

  print('OpenAI Compatibility Test Application');
  print('======================================\n');

  // Define weather tool
  ai.defineTool(
    name: 'getWeather',
    description: 'Get the current weather for a specific location. Returns temperature and conditions.',
    inputSchema: WeatherInput.$schema,
    outputSchema: WeatherOutput.$schema,
    fn: (input, ctx) async {
      final location = input.location;
      final unit = input.unit ?? 'celsius';
      
      print('  [Tool] Getting weather for: $location (unit: $unit)');
      
      // Mock weather data
      final random = Random();
      final tempCelsius = 15 + random.nextInt(20);
      final temperature = unit == 'fahrenheit' 
          ? (tempCelsius * 9 / 5) + 32 
          : tempCelsius.toDouble();
      
      final conditions = ['sunny', 'cloudy', 'rainy', 'partly cloudy'];
      final condition = conditions[random.nextInt(conditions.length)];
      
      return WeatherOutput(
        temperature: temperature,
        condition: condition,
        unit: unit,
        humidity: 50 + random.nextInt(30),
      );
    },
  );

  // Flow 1: Simple text generation
  ai.defineFlow(
    name: 'simpleGenerate',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: openAI.gpt4oMini,
        prompt: prompt,
      );
      return response.text;
    },
  );

  // Flow 2: Creative generation with higher temperature
  ai.defineFlow(
    name: 'creativeGenerate',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: openAI.gpt4oMini,
        prompt: prompt,
        config: OpenAIOptionsSchema(
          temperature: 0.9,
          maxTokens: 300,
        ),
      );
      return response.text;
    },
  );

  // Flow 3: Streaming generation
  ai.defineFlow(
    name: 'streamGenerate',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    streamSchema: stringSchema(),
    fn: (prompt, context) async {
      final buffer = StringBuffer();
      
      if (context.streamingRequested) {
        await for (final chunk in ai.generateStream(
          model: openAI.gpt4oMini,
          prompt: prompt,
        )) {
          for (final part in chunk.content) {
            if (part.isText && part.text != null) {
              context.sendChunk(part.text!);
              buffer.write(part.text);
            }
          }
        }
        return buffer.toString();
      }
      
      final response = await ai.generate(
        model: openAI.gpt4oMini,
        prompt: prompt,
      );
      return response.text;
    },
  );

  // Flow 4: Weather query
  ai.defineFlow(
    name: 'weatherQuery',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (query, context) async {
      final response = await ai.generate(
        model: openAI.gpt4oMini,
        prompt: 'Answer this weather question: $query. Use the getWeather tool.',
        tools: ['getWeather'],
      );
      return response.text;
    },
  );

  // Flow 5: Multi-tool assistant
  ai.defineFlow(
    name: 'assistant',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (query, context) async {
      final response = await ai.generate(
        model: openAI.gpt4oMini,
        prompt: query,
        tools: ['getWeather'],
      );
      return response.text;
    },
  );

  // Flow 6: Chat with system prompt
  ai.defineFlow(
    name: 'dartExpert',
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    fn: (userMessage, context) async {
      final messages = <Message>[
        Message(
          role: Role.system,
          content: [
            TextPart(
              text: 'You are a helpful expert in Dart and Flutter development. '
                  'Provide clear, concise, and accurate answers.',
            ),
          ],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: userMessage)],
        ),
      ];

      final response = await ai.generate(
        model: openAI.gpt4oMini,
        messages: messages,
      );
      return response.text;
    },
  );

  print('Flows defined successfully!');
  print('Available flows:');
  print('  - simpleGenerate: Basic text generation');
  print('  - creativeGenerate: Creative generation with high temperature');
  print('  - streamGenerate: Streaming text generation');
  print('  - weatherQuery: Get weather using tool calling');
  print('  - assistant: AI assistant with weather tool');
  print('  - dartExpert: Dart/Flutter expert with system prompt');
  print('\nReady for Genkit UI or direct execution!');
}
