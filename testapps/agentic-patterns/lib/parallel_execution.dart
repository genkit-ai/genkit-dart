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
