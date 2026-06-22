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

import 'package:schemantic/schemantic.dart';

part 'chat.g.dart';

/// Chat-specific options for Ollama models.
///
/// Mirrors the subset of Ollama's runtime options that map cleanly onto
/// Genkit's generation config, plus two Ollama-specific knobs (`numCtx` and
/// `keepAlive`) that are commonly tuned but absent from the JS plugin.
///
/// See https://github.com/ollama/ollama/blob/main/docs/modelfile.md and the
/// `/api/chat` options block for the full meaning of each field.
@Schema()
abstract class $OllamaChatOptions {
  /// Sampling temperature. Higher is more creative. Ollama default: 0.8.
  ///
  /// Ollama accepts values above 1.0; the JS plugin caps at 1.0, which rejects
  /// otherwise-valid configs.
  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  /// Top-k sampling. Ollama default: 40.
  int? get topK;

  /// Nucleus (top-p) sampling. Ollama default: 0.9.
  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  /// Maximum number of tokens to generate (Ollama `num_predict`).
  int? get maxOutputTokens;

  /// Stop sequences. Generation halts when any is produced.
  List<String>? get stop;

  /// Random seed for deterministic sampling.
  int? get seed;

  /// Size of the context window in tokens (Ollama `num_ctx`).
  ///
  /// Not exposed by the JS plugin; one of the most commonly tuned Ollama knobs.
  int? get numCtx;

  /// How long the model stays loaded in memory after the request, e.g. `'5m'`,
  /// `'0'` to unload immediately, or `'-1'` to keep loaded indefinitely.
  ///
  /// Accepts the same values as Ollama's `keep_alive` field.
  String? get keepAlive;
}

/// Internal alias for [OllamaChatOptions] used within the plugin.
typedef ChatModelOptions = OllamaChatOptions;

/// Returns true when the output config requests JSON-structured output
/// (format is `'json'` or contentType is `'application/json'`).
bool isJsonStructuredOutput(String? format, String? contentType) {
  return format == 'json' || contentType == 'application/json';
}

/// Returns the custom options schema for Ollama chat models.
SchemanticType<ChatModelOptions> chatModelOptionsSchema() =>
    OllamaChatOptions.$schema;

/// Parses chat-model options from action config.
ChatModelOptions parseChatModelOptions(Map<String, dynamic>? config) {
  return config != null
      ? OllamaChatOptions.$schema.parse(config)
      : OllamaChatOptions();
}
