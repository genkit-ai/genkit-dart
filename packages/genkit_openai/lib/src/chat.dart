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

import 'dart:convert';

import 'package:genkit/plugin.dart';
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
  /// Only consulted when Genkit's own output config says nothing about the
  /// format. Any explicit `outputFormat` wins, including `'text'`, which
  /// suppresses this rather than conflicting with it; `outputSchema` wins too
  /// and additionally constrains the shape.
  ///
  /// OpenAI rejects json_object unless the conversation also asks for JSON, so
  /// the prompt must say so. Prefer `outputSchema` where the shape is known.
  bool? get jsonMode;

  /// Visual detail level for images ('auto', 'low', 'high')
  @StringField(enumValues: ['auto', 'low', 'high'])
  String? get visualDetailLevel;

  /// How hard a reasoning model should think before answering.
  ///
  /// Which levels are accepted varies by model and host. A level newer than
  /// `openai_dart` needs an SDK bump.
  @StringField(
    enumValues: ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'],
  )
  String? get reasoningEffort;

  /// How much the model should say in its answer.
  ///
  /// A GPT-5-family parameter, and unrelated to [reasoningEffort]: this
  /// shortens or lengthens the reply, not the thinking behind it.
  @StringField(enumValues: ['low', 'medium', 'high'])
  String? get verbosity;
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
///
/// [supportsJsonSchema] is false for a host that takes `json_object` but not
/// `json_schema` - DeepSeek, among others. There the schema cannot travel as a
/// constraint, so the request asks for JSON and the plugin writes the schema
/// into the prompt instead (see [jsonObjectInstruction]). Sending the schema
/// anyway would be a 400, which is worse than an unconstrained answer.
ResponseFormat? buildOpenAIResponseFormat({
  String? format,
  String? contentType,
  Map<String, dynamic>? schema,
  bool? jsonMode,
  bool supportsJsonSchema = true,
}) {
  if (isJsonStructuredOutput(format, contentType)) {
    if (schema == null || !supportsJsonSchema) {
      return ResponseFormat.jsonObject();
    }

    // Flattened because OpenAI needs `type` at the top level, so `$ref`/
    // `$defs` have to be resolved away first.
    return ResponseFormat.jsonSchema(
      name: 'output',
      schema: schema.flatten(),
      // Strict mode demands `additionalProperties: false` on every object and
      // every property listed in `required`. Genkit schemas are not authored
      // that way - an optional field is simply absent from `required` - so
      // strict rejects ordinary schemas with a 400. JS omits the flag
      // entirely; `ResponseFormat.jsonSchema` declares `bool strict = true`
      // and always serializes it, so false is the closest Dart gets.
      //
      // The trade is deliberate and visible: `strict: true` had OpenAI
      // guarantee the reply conformed to the schema. It no longer does, and
      // the schema is advisory. Schemas that did satisfy strict lose that
      // guarantee; schemas that did not stop 400ing.
      strict: false,
    );
  }

  if (format == 'text') return ResponseFormat.text();

  // Reached only when the caller opts in without using Genkit's output
  // config. An explicit `outputFormat: 'text'` has already returned above, so
  // it suppresses jsonMode rather than competing with it.
  if (jsonMode == true) return ResponseFormat.jsonObject();

  return null;
}

/// The JSON instruction a `json_object`-only host needs in the prompt.
///
/// Null when there is nothing to add. Without `json_schema` the prompt is the
/// only place the schema can go, so it is written out unless the rendered
/// schema is already there - as it is when the caller adds the
/// `simulateConstrainedGeneration` middleware, which writes the same JSON
/// under different wording. Otherwise the word "json" is added unless a
/// message already says it: DeepSeek rejects a `json_object` request whose
/// prompt lacks it, and a caller's own instructions may not use it.
///
/// Matching the rendered schema rather than a `purpose: 'output'` marker is
/// deliberate: `outputInstructions` carries that marker too, so keying off it
/// let a caller's own instructions suppress the schema entirely and the model
/// never saw the shape it was being asked for.
String? jsonObjectInstruction(
  List<Message> messages,
  Map<String, dynamic>? schema,
) {
  if (schema != null) {
    final rendered = const JsonEncoder.withIndent('  ').convert(schema);
    final alreadyCarried = messages.any(
      (message) => message.content.any(
        (part) => part.isText && (part.text?.contains(rendered) ?? false),
      ),
    );
    if (!alreadyCarried) {
      return 'Respond with JSON only. The JSON must conform to the following '
          'schema:\n\n```\n$rendered\n```';
    }
  }

  final alreadyAsked = messages.any(
    (message) => message.text.toLowerCase().contains('json'),
  );
  return alreadyAsked ? null : 'Respond with JSON only.';
}

/// Returns custom options schema for standard chat models.
SchemanticType<ChatModelOptions> chatModelOptionsSchema() =>
    OpenAIChatOptions.$schema;

/// Maps a [ChatModelOptions.reasoningEffort] string onto the SDK enum.
///
/// `ReasoningEffort.fromJson` answers `unknown` for a value it does not
/// recognise, which would go on the wire as `reasoning_effort: "unknown"` and
/// come back as a confusing 400. Better to name the value that was actually
/// wrong — whether it is a typo or a level newer than the SDK, which is the
/// one case where the caller is right and the plugin is behind.
ReasoningEffort? toReasoningEffort(String? value) {
  if (value == null) return null;
  final effort = ReasoningEffort.fromJson(value);
  if (effort == ReasoningEffort.unknown) {
    throw GenkitException(
      'Unknown reasoningEffort "$value". Known levels: '
      '${ReasoningEffort.values.where((e) => e != ReasoningEffort.unknown).map((e) => e.toJson()).join(', ')}.',
      status: StatusCode.invalidArgument,
    );
  }
  return effort;
}

/// Maps a [ChatModelOptions.verbosity] string onto the SDK enum, rejecting an
/// unrecognised level for the same reason [toReasoningEffort] does.
Verbosity? toVerbosity(String? value) {
  if (value == null) return null;
  final verbosity = Verbosity.fromJson(value);
  if (verbosity == Verbosity.unknown) {
    throw GenkitException(
      'Unknown verbosity "$value". Known levels: '
      '${Verbosity.values.where((v) => v != Verbosity.unknown).map((v) => v.toJson()).join(', ')}.',
      status: StatusCode.invalidArgument,
    );
  }
  return verbosity;
}

/// Parses chat-model options from action config.
ChatModelOptions parseChatModelOptions(Map<String, dynamic>? config) {
  return config != null
      ? OpenAIChatOptions.$schema.parse(config)
      : OpenAIChatOptions();
}
