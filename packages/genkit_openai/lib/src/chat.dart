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

import 'package:openai_dart/openai_dart.dart';
import 'package:schemantic/schemantic.dart';

part 'chat.g.dart';

/// Chat-specific options for OpenAI chat models.
@Schema()
abstract class $OpenAIChatOptions {
  /// Model version override (e.g., 'gpt-4o-2024-08-06')
  String? get version;

  /// Sampling temperature (0.0 - 2.0)
  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  /// Nucleus sampling (0.0 - 1.0)
  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  /// Maximum tokens to generate
  int? get maxTokens;

  /// Stop sequences
  List<String>? get stop;

  /// Presence penalty (-2.0 - 2.0)
  @DoubleField(minimum: -2.0, maximum: 2.0)
  double? get presencePenalty;

  /// Frequency penalty (-2.0 - 2.0)
  @DoubleField(minimum: -2.0, maximum: 2.0)
  double? get frequencyPenalty;

  /// Seed for deterministic sampling
  int? get seed;

  /// User identifier for abuse detection
  String? get user;

  /// Forces `{"type": "json_object"}` on the request.
  ///
  /// Only consulted when Genkit's own output config does not already imply
  /// JSON - `outputFormat: 'json'` or an `outputSchema` takes precedence, and
  /// a schema additionally constrains the shape.
  ///
  /// OpenAI rejects json_object unless the conversation also asks for JSON, so
  /// the prompt must say so. Prefer `outputSchema` where the shape is known.
  bool? get jsonMode;

  /// Visual detail level for images ('auto', 'low', 'high')
  @StringField(enumValues: ['auto', 'low', 'high'])
  String? get visualDetailLevel;
}

/// Alias for [OpenAIChatOptions].
///
/// Provided for convenience; prefer [OpenAIChatOptions] in new code.
typedef OpenAIOptions = OpenAIChatOptions;

/// Internal alias for [OpenAIChatOptions] used within the plugin.
typedef ChatModelOptions = OpenAIChatOptions;

/// Returns true when the output config indicates JSON-structured output
/// (format is 'json' or contentType is 'application/json').
bool isJsonStructuredOutput(String? format, String? contentType) {
  return format == 'json' || contentType == 'application/json';
}

/// Maps Genkit's output config onto OpenAI's `response_format`.
///
/// Mirrors the JS plugin: JSON output with a schema becomes `json_schema`,
/// JSON output without one becomes `json_object`, and an explicit text format
/// becomes `text`. Anything else sends no `response_format` at all, which
/// matters for OpenAI-compatible hosts that reject the field.
///
/// Returning `json_object` for a schemaless JSON request is not a nicety: with
/// no schema, Genkit's json formatter also emits no prompt instructions, so
/// without this nothing would ask the model for JSON at all.
ResponseFormat? buildOpenAIResponseFormat({
  String? format,
  String? contentType,
  Map<String, dynamic>? schema,
  bool? jsonMode,
}) {
  if (isJsonStructuredOutput(format, contentType)) {
    if (schema == null) return ResponseFormat.jsonObject();

    // Flattened because OpenAI needs `type` at the top level, so `$ref`/
    // `$defs` have to be resolved away first.
    return ResponseFormat.jsonSchema(
      name: 'output',
      schema: schema.flatten(),
      // Strict mode demands `additionalProperties: false` on every object and
      // every property listed in `required`. Genkit schemas are not authored
      // that way - an optional field is simply absent from `required` - so
      // strict rejects ordinary schemas with a 400. JS omits the flag
      // entirely; the SDK always serializes it, so false is how we say that.
      strict: false,
    );
  }

  if (format == 'text') return ResponseFormat.text();

  // Reached only when the caller opts in without using Genkit's output config.
  if (jsonMode == true) return ResponseFormat.jsonObject();

  return null;
}

/// Returns custom options schema for standard chat models.
SchemanticType<ChatModelOptions> chatModelOptionsSchema() =>
    OpenAIChatOptions.$schema;

/// Parses chat-model options from action config.
ChatModelOptions parseChatModelOptions(Map<String, dynamic>? config) {
  return config != null
      ? OpenAIChatOptions.$schema.parse(config)
      : OpenAIChatOptions();
}
