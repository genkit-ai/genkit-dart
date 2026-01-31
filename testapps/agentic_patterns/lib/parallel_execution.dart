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

import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

part 'parallel_execution.g.dart';

@Schematic()
abstract class $ProductInput {
  String get product;
}

@Schematic()
abstract class $MarketingCopy {
  String get name;
  String get tagline;
}

Flow<ProductInput, MarketingCopy, void, void> defineMarketingCopyFlow(
  Genkit ai,
  ModelRef geminiFlash,
) {
  return ai.defineFlow(
    name: 'marketingCopyFlow',
    inputSchema: ProductInput.$schema,
    outputSchema: MarketingCopy.$schema,
    fn: (input, _) async {
      // Task 1: Generate a creative name
      final nameFuture = ai.generate(
        model: geminiFlash,
        prompt: 'Generate a creative name for a new product: ${input.product}.',
      );

      // Task 2: Generate a catchy tagline
      final taglineFuture = ai.generate(
        model: geminiFlash,
        prompt:
            'Generate a catchy tagline for a new product: ${input.product}.',
      );

      final results = await Future.wait([nameFuture, taglineFuture]);

      return MarketingCopy(
        name: results[0].text,
        tagline: results[1].text,
      );
    },
  );
}
