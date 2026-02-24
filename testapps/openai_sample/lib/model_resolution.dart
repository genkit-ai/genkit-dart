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

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

/// Defines a flow that resolves a named OpenAI model from the Genkit registry.
///
/// Accepts a model name (e.g. `gpt-4o-mini`) and returns a formatted string
/// with the resolved action's name, type, and metadata. Useful for verifying
/// which models are available and inspecting their registered properties.
Flow<String, String, void, void> defineModelResolutionFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'modelResolution',
    inputSchema: stringSchema(defaultValue: 'gpt-4o-mini'),
    outputSchema: stringSchema(),
    fn: (modelName, _) async {
      final action =
          await ai.registry.lookupAction('model', 'openai/$modelName');

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
///
/// Returns a newline-separated list of every model action available in the
/// registry, giving callers a quick overview of what is ready to use.
/// The input string is unused; pass any value (e.g. an empty string).
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

void main() {
  final ai = Genkit(
    plugins: [openAI(apiKey: Platform.environment['OPENAI_API_KEY'])],
  );

  defineModelResolutionFlow(ai);
  defineModelListFlow(ai);
}
