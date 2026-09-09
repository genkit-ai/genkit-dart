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

/// Drives the plugin against OpenAI-compatible providers, which the other
/// samples here never exercise - they all use plain `openAI(apiKey:)`.
///
/// Set whichever provider keys you have and run:
///
/// ```sh
/// GROQ_API_KEY=... genkit start -- dart run lib/compatible_providers.dart
/// ```
///
/// Backends with no key are skipped rather than registered, so this starts up
/// with none set - `listBackends` then just reports that nothing is
/// configured.
library;

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

/// One OpenAI-compatible backend: where it lives and what it serves.
class CompatBackend {
  /// Namespace for the plugin instance, e.g. `groq`.
  final String name;

  /// Environment variable holding this provider's key.
  final String apiKeyEnvVar;

  /// The provider's OpenAI-compatible endpoint.
  ///
  /// Overridable per backend with `<NAME>_BASE_URL` (e.g. `GROQ_BASE_URL`), so
  /// the same flows can be pointed at a proxy or a local server such as
  /// llama.cpp, Ollama or LM Studio.
  final String defaultBaseUrl;

  /// Models to register.
  ///
  /// Required, not decorative: a compat backend is not given the curated
  /// OpenAI catalog, and most providers' `GET /models` is either absent or
  /// enormous, so this is what the Dev UI has to list. Models omitted here
  /// still work when named explicitly.
  final List<CustomModelDefinition> models;

  const CompatBackend({
    required this.name,
    required this.apiKeyEnvVar,
    required this.defaultBaseUrl,
    required this.models,
  });

  /// This provider's key, or null when it is not configured.
  String? get apiKey => _env(apiKeyEnvVar);

  /// The endpoint to use, honouring the `<NAME>_BASE_URL` override.
  String get baseUrl =>
      _env('${name.toUpperCase()}_BASE_URL') ?? defaultBaseUrl;

  static String? _env(String name) {
    final value = Platform.environment[name];
    return (value == null || value.isEmpty) ? null : value;
  }
}

ModelInfo _chatModel(String label) => ModelInfo(
  label: label,
  supports: {
    'multiturn': true,
    'tools': true,
    'systemRole': true,
    'media': false,
  },
);

/// The providers the README advertises.
final List<CompatBackend> compatBackends = [
  CompatBackend(
    name: 'groq',
    apiKeyEnvVar: 'GROQ_API_KEY',
    defaultBaseUrl: 'https://api.groq.com/openai/v1',
    models: [
      CustomModelDefinition(
        name: 'llama-3.3-70b-versatile',
        info: _chatModel('Llama 3.3 70B'),
      ),
    ],
  ),
  CompatBackend(
    name: 'deepseek',
    apiKeyEnvVar: 'DEEPSEEK_API_KEY',
    defaultBaseUrl: 'https://api.deepseek.com/v1',
    models: [
      CustomModelDefinition(
        name: 'deepseek-chat',
        info: _chatModel('DeepSeek Chat'),
      ),
    ],
  ),
  CompatBackend(
    name: 'xai',
    apiKeyEnvVar: 'XAI_API_KEY',
    defaultBaseUrl: 'https://api.x.ai/v1',
    models: [CustomModelDefinition(name: 'grok-4', info: _chatModel('Grok 4'))],
  ),
];

/// The backends that actually have a key set.
List<CompatBackend> get configuredBackends =>
    compatBackends.where((b) => b.apiKey != null).toList();

/// Reports which backends are configured and what each one lists.
Flow<String, String, void, void> defineListBackendsFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'listBackends',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (_, _) async {
      final configured = configuredBackends.map((b) => b.name).toSet();
      if (configured.isEmpty) {
        final vars = compatBackends.map((b) => b.apiKeyEnvVar).join(', ');
        return 'No compatible backends configured. Set one of: $vars';
      }

      final actions = await ai.registry.listActions();
      final lines = <String>[];
      for (final name in configured) {
        final models = actions
            .where((a) => a.actionType == .model && a.name.startsWith('$name/'))
            .map((a) => a.name);
        lines.add('$name:\n  ${models.join('\n  ')}');
      }
      return lines.join('\n');
    },
  );
}

/// Generates against one backend, chosen by name (`groq`, `deepseek`, `xai`).
Flow<String, String, void, void> defineCompatGenerateFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'compatGenerate',
    inputSchema: .string(defaultValue: 'groq'),
    outputSchema: .string(),
    fn: (backendName, _) async {
      final backend = compatBackends
          .where((b) => b.name == backendName)
          .firstOrNull;
      if (backend == null) {
        final known = compatBackends.map((b) => b.name).join(', ');
        return 'Unknown backend "$backendName". Try one of: $known';
      }
      if (backend.apiKey == null) {
        return '${backend.name} is not configured; set ${backend.apiKeyEnvVar}.';
      }

      final response = await ai.generate(
        model: openAI.model(backend.models.first.name, namespace: backend.name),
        prompt: 'In one sentence, what are you and who made you?',
      );
      return response.text;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [
      for (final backend in configuredBackends)
        openAI(
          name: backend.name,
          apiKey: backend.apiKey,
          baseUrl: backend.baseUrl,
          models: backend.models,
          // Several compatible hosts read headers for attribution or
          // routing. None of the three below require one; this is here to
          // show where a provider-specific header goes.
          headers: {'X-Title': 'Genkit Dart sample'},
        ),
    ],
  );

  defineListBackendsFlow(ai);
  defineCompatGenerateFlow(ai);
}
