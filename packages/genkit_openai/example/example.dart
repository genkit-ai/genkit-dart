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

part 'example.g.dart';

@Schematic()
abstract class $WeatherFlowInput {
  /// Natural language weather query, e.g. "What's the weather in Boston?"
  String get prompt;
}

@Schematic()
abstract class $WeatherToolInput {
  /// City name or coordinates to look up
  String get location;

  /// Temperature unit - 'celsius' or 'fahrenheit'
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

@Schematic()
abstract class $MovieReviewInput {
  /// Title of the movie to review
  String get title;

  /// Optional release year to disambiguate
  int? get year;
}

@Schematic()
abstract class $MovieReview {
  /// Official movie title
  String get title;

  /// Rating from 1.0 to 10.0
  double get rating;

  /// One-paragraph summary of the film
  String get summary;

  /// List of standout positives
  List<String> get pros;

  /// List of notable negatives
  List<String> get cons;

  /// Recommended audience, e.g. "sci-fi fans", "families"
  String get recommendedFor;
}

/// Defines a flow that demonstrates basic text generation with an OpenAI model.
Flow<String, String, void, void> defineSimpleGenerationFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'simpleGeneration',
    inputSchema: stringSchema(
      defaultValue: 'Tell me a joke about Dart programming.',
    ),
    outputSchema: stringSchema(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: openAI.model('gpt-4o-mini'),
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Defines a flow that demonstrates real-time token streaming from OpenAI.
Flow<String, String, String, void> defineStreamedSimpleGenerationFlow(
  Genkit ai,
) {
  return ai.defineFlow(
    name: 'streamedSimpleGeneration',
    inputSchema: stringSchema(
      defaultValue: 'Tell me a joke about Dart programming.',
    ),
    outputSchema: stringSchema(),
    streamSchema: stringSchema(),
    fn: (prompt, ctx) async {
      final stream = ai.generateStream(
        model: openAI.model('gpt-4o-mini'),
        prompt: prompt,
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

/// Defines a flow that resolves a named OpenAI model from the Genkit registry.
Flow<String, String, void, void> defineModelResolutionFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'modelResolution',
    inputSchema: stringSchema(defaultValue: 'gpt-4o-mini'),
    outputSchema: stringSchema(),
    fn: (modelName, _) async {
      final action = await ai.registry.lookupAction(
        'model',
        'openai/$modelName',
      );

      if (action == null) {
        return 'Model not found: openai/$modelName';
      }

      return [
        'name: ${action.name}',
        'actionType: ${action.actionType}',
        'metadata: ${action.metadata}',
      ].join('\n');
    },
  );
}

/// Defines a flow that lists all models registered by the OpenAI plugin.
Flow<String, String, void, void> defineModelListFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'modelList',
    inputSchema: stringSchema(defaultValue: ''),
    outputSchema: stringSchema(),
    fn: (_, _) async {
      final actions = await ai.registry.listActions();
      final models = actions
          .where((a) => a.actionType == 'model')
          .map((a) => a.name)
          .toList();

      return models.join('\n');
    },
  );
}

/// Defines a flow that demonstrates OpenAI tool/function calling.
Flow<WeatherFlowInput, String, void, void> defineToolCallingFlow(
  Genkit ai,
  Tool getWeather,
) {
  return ai.defineFlow(
    name: 'toolCalling',
    inputSchema: WeatherFlowInput.$schema,
    outputSchema: stringSchema(),
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
Flow<WeatherFlowInput, String, String, void> defineStreamedToolCallingFlow(
  Genkit ai,
  Tool getWeather,
) {
  return ai.defineFlow(
    name: 'streamedToolCalling',
    inputSchema: WeatherFlowInput.$schema,
    outputSchema: stringSchema(),
    streamSchema: stringSchema(),
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

/// Defines a flow that demonstrates structured output with an OpenAI model.
Flow<MovieReviewInput, MovieReview, void, void> defineStructuredOutputFlow(
  Genkit ai,
) {
  return ai.defineFlow(
    name: 'structuredOutput',
    inputSchema: MovieReviewInput.$schema,
    outputSchema: MovieReview.$schema,
    fn: (input, _) async {
      final yearClause = input.year != null ? ' (${input.year})' : '';

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt:
            'Write a detailed review of the movie "${input.title}$yearClause".',
        outputFormat: 'json',
        outputSchema: MovieReview.$schema,
      );

      final output = response.output;
      if (output == null) {
        throw StateError('Model returned no structured output.');
      }
      return output;
    },
  );
}

/// Defines a flow that demonstrates streaming structured output.
Flow<MovieReviewInput, MovieReview, String, void>
defineStreamedStructuredOutputFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'streamedStructuredOutput',
    inputSchema: MovieReviewInput.$schema,
    outputSchema: MovieReview.$schema,
    streamSchema: stringSchema(),
    fn: (input, ctx) async {
      final yearClause = input.year != null ? ' (${input.year})' : '';
      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
        prompt:
            'Write a detailed review of the movie "${input.title}$yearClause".',
        outputFormat: 'json',
        outputSchema: MovieReview.$schema,
      );

      await for (final chunk in stream) {
        if (ctx.streamingRequested && chunk.text.isNotEmpty) {
          ctx.sendChunk(chunk.text);
        }
      }

      final response = await stream.onResult;
      final output = response.output;
      if (output == null) {
        throw StateError('Model returned no structured output.');
      }
      return output;
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
      final temperature = unit == 'fahrenheit'
          ? (tempCelsius * 9 / 5) + 32
          : tempCelsius.toDouble();
      final conditions = ['sunny', 'cloudy', 'rainy', 'partly cloudy'];

      return WeatherToolOutput(
        temperature: temperature,
        condition: conditions[random.nextInt(conditions.length)],
        unit: unit,
        humidity: 50 + random.nextInt(30),
      );
    },
  );

  defineSimpleGenerationFlow(ai);
  defineStreamedSimpleGenerationFlow(ai);
  defineModelResolutionFlow(ai);
  defineModelListFlow(ai);
  defineToolCallingFlow(ai, getWeather);
  defineStreamedToolCallingFlow(ai, getWeather);
  defineStructuredOutputFlow(ai);
  defineStreamedStructuredOutputFlow(ai);
}
