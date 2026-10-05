// Copyright 2026 Google LLC
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

/// An app-level middleware defined with `ai.defineGenerateMiddleware`, no
/// plugin needed. It logs each model call and enforces a per-call turn budget.
///
/// Run with `dart run bin/custom_middleware.dart` (or `genkit start -- dart
/// run bin/custom_middleware.dart` to try it from the Developer UI, where the
/// `turnBudget` middleware can be configured on any generate request).
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'custom_middleware.g.dart';

@Schema()
abstract class $TurnBudgetOptions {
  @Field(description: 'Maximum number of model calls per generate call.')
  int? get maxModelCalls;

  @Field(description: 'Prefix for log lines.')
  String? get label;
}

/// One instance per `generate` call, so `_calls` counts calls for that
/// generation only.
class TurnBudgetMiddleware extends GenerateMiddleware {
  TurnBudgetMiddleware(TurnBudgetOptions? options)
    : maxModelCalls = options?.maxModelCalls ?? 3,
      label = options?.label ?? 'turnBudget';

  final int maxModelCalls;
  final String label;
  int _calls = 0;

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) async {
    if (++_calls > maxModelCalls) {
      throw GenkitException(
        'Model call budget of $maxModelCalls exceeded.',
        status: StatusCode.resourceExhausted,
      );
    }
    print('[$label] model call $_calls/$maxModelCalls');
    return next(request, ctx);
  }
}

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  // Registers the middleware (so it shows up in the Developer UI) and returns
  // a callable that builds the ref for `use:`.
  final turnBudget = ai.defineGenerateMiddleware<TurnBudgetOptions>(
    name: 'turnBudget',
    configSchema: TurnBudgetOptions.$schema,
    create: (config, ctx) => TurnBudgetMiddleware(config),
  );

  final weather = ai.defineTool(
    name: 'getWeather',
    description: 'Returns the current weather for a city.',
    inputSchema: .string(),
    fn: (city, _) async => .response('Sunny and 22C in $city.'),
  );

  ai.defineFlow(
    name: 'weatherWithBudget',
    inputSchema: .string(defaultValue: 'What is the weather in Paris?'),
    outputSchema: .string(),
    fn: (question, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        prompt: question,
        tools: [weather],
        use: [
          turnBudget(TurnBudgetOptions(maxModelCalls: 4, label: 'weather')),
          retry(maxRetries: 2),
        ],
      );
      return response.text;
    },
  );
}
