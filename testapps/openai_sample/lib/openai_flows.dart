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

part 'openai_flows.g.dart';

@Schematic()
abstract class $WeatherInput {
  /// The location to get weather for (city name or coordinates)
  String get location;

  /// Optional unit system ('celsius' or 'fahrenheit')
  @StringField(enumValues: ['celsius', 'fahrenheit'])
  String? get unit;
}

@Schematic()
abstract class $WeatherOutput {
  /// Temperature value
  double get temperature;

  /// Weather condition description
  String get condition;

  /// Unit used for temperature
  String get unit;

  /// Optional humidity percentage
  int? get humidity;
}

/// Simple text generation example
Future<void> simpleGenerateExample(String apiKey) async {
  print('=== Simple Text Generation ===\n');
  
  final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

  final response = await ai.generate(
    model: openAI.gpt4oMini,
    prompt: 'Tell me a joke about Dart programming.',
  );

  print('Prompt: Tell me a joke about Dart programming.');
  print('Response: ${response.text}\n');
}

/// Streaming generation example
Future<void> streamingExample(String apiKey) async {
  print('=== Streaming Text Generation ===\n');
  
  final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

  print('Prompt: Write a very short story about a robot learning to laugh.\n');
  print('Streaming response:\n');

  await for (final chunk in ai.generateStream(
    model: openAI.gpt4oMini,
    prompt: 'Write a very short story about a robot learning to laugh. Keep it under 100 words.',
    config: OpenAIOptionsSchema(
      temperature: 0.8,
      maxTokens: 150,
    ),
  )) {
    for (final part in chunk.content) {
      if (part.isText && part.text != null) {
        stdout.write(part.text);
      }
    }
  }

  print('\n');
}

/// Tool calling example with weather
Future<void> toolCallingExample(String apiKey) async {
  print('=== Tool Calling with Weather ===\n');
  
  final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

  // Define weather tool
  ai.defineTool(
    name: 'getWeather',
    description: 'Get the current weather for a specific location. Returns temperature and conditions.',
    inputSchema: WeatherInput.$schema,
    outputSchema: WeatherOutput.$schema,
    fn: (input, ctx) async {
      final location = input.location;
      final unit = input.unit ?? 'celsius';
      
      print('  [Tool Called] Getting weather for: $location (unit: $unit)');
      
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

  print('Query: What\'s the weather in Boston?\n');

  final response = await ai.generate(
    model: openAI.gpt4oMini,
    prompt: 'What\'s the weather in Boston? Use the getWeather tool.',
    tools: ['getWeather'],
  );

  print('\nAssistant: ${response.text}\n');
}

/// Conversation with context example
Future<void> conversationExample(String apiKey) async {
  print('=== Multi-turn Conversation ===\n');
  
  final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

  final messages = <Message>[];

  // Turn 1
  print('User: My name is Alice and I love Dart programming.');
  messages.add(Message(
    role: Role.user,
    content: [TextPart(text: 'My name is Alice and I love Dart programming.')],
  ));

  var response = await ai.generate(
    model: openAI.gpt4oMini,
    messages: messages,
  );

  print('Assistant: ${response.text}\n');
  final message1 = response.message;
  if (message1 != null) messages.add(message1);

  // Turn 2
  print('User: What is my name?');
  messages.add(Message(
    role: Role.user,
    content: [TextPart(text: 'What is my name?')],
  ));

  response = await ai.generate(
    model: openAI.gpt4oMini,
    messages: messages,
  );

  print('Assistant: ${response.text}\n');
}

/// Run all examples
Future<void> runAllExamples(String apiKey) async {
  await simpleGenerateExample(apiKey);
  await streamingExample(apiKey);
  await toolCallingExample(apiKey);
  await conversationExample(apiKey);
}
