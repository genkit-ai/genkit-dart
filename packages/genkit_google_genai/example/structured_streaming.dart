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

part 'structured_streaming.schema.g.dart';

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

void main() async {
  configureCollectorExporter();

  final ai = Genkit(plugins: [googleAI()]);

  ai.defineFlow(
    name: 'structured-output',
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
          ctx.sendChunk(chunk.output);
        } else {
          // For local run only
          print(chunk.output);
        }
      }

      final response = await stream.onResult;
      return response.output!;
    },
  );
}
