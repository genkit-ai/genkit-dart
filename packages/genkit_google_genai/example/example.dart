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
import 'package:genkit/lite.dart' as lite;
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'example.g.dart';

// --- Schemas for Tool Calling Example ---

@Schematic()
abstract class WeatherToolInputSchema {
  @Field(
    description:
        'The location (ex. city, state, country) to get the weather for',
  )
  String get location;
}

// --- Schemas for Structured Streaming Example ---

@Schematic()
abstract class CategorySchema {
  String get name;
  @Schematic(
    description: 'make sure there are at least 2-3 levels of subcategories',
  )
  List<CategorySchema>? get subcategories;
}

@Schematic()
abstract class WeaponSchema {
  String get name;
  double get damage;
  CategorySchema get category;
}

@Schematic()
abstract class RpgCharacterSchema {
  @Schematic(description: 'name of the character')
  String get name;

  @Schematic(description: "character's backstory, about a paragraph")
  String get backstory;

  List<WeaponSchema> get weapons;

  @StringField(enumValues: ['RANGER', 'WIZZARD', 'TANK', 'HEALER', 'ENGINEER'])
  String get classType;

  String? get affiliation;
}

void main(List<String> args) async {
  configureCollectorExporter();
  final ai = Genkit(plugins: [googleAI()]);

  // --- Basic Generate Flow ---
  ai.defineFlow(
    name: 'basicGenerate',
    inputType: stringType(),
    outputType: stringType(),
    fn: (input, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: input,
      );
      return response.text;
    },
  );

  // --- Lite Generate Flow (Wrapped) ---
  ai.defineFlow(
    name: 'liteGenerate',
    inputType: stringType(),
    outputType: stringType(),
    fn: (input, context) async {
      final gemini = googleAI();
      final response = await lite.generate(
        model: gemini.model('gemini-2.5-flash'),
        prompt: input,
      );
      return response.text;
    },
  );

  // --- Tool Calling Flow ---
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

  ai.defineFlow(
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

  // --- Structured Streaming Flow ---
  ai.defineFlow(
    name: 'structuredStreaming',
    inputType: stringType(),
    streamType: RpgCharacterType,
    outputType: RpgCharacterType,
    fn: (name, ctx) async {
      final stream = ai.generateStream(
        model: googleAI.gemini('gemini-2.5-flash'),
        config: GeminiOptions.from(temperature: 2.0),
        outputSchema: RpgCharacterType,
        prompt: 'Generate an RPC character called $name',
      );

      await for (final chunk in stream) {
        if (ctx.streamingRequested) {
          ctx.sendChunk(chunk.output!);
        }
      }

      final response = await stream.onResult;
      return response.output!;
    },
  );
}
