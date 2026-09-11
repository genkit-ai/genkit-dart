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

/// Pure helpers for mapping Genkit data to OpenTelemetry GenAI semantic
/// conventions. Deliberately free of any OpenTelemetry imports so the mapping
/// logic can be unit tested in isolation.
///
/// See the spec:
/// https://github.com/open-telemetry/semantic-conventions-genai
library;

/// Canonical `gen_ai.*` attribute names used by this instrumentation.
///
/// Grouped as a namespace of constants so call sites read like
/// `GenAiAttr.requestModel` rather than repeating string literals.
abstract final class GenAiAttr {
  static const operationName = 'gen_ai.operation.name';
  static const providerName = 'gen_ai.provider.name';

  static const requestModel = 'gen_ai.request.model';
  static const requestTemperature = 'gen_ai.request.temperature';
  static const requestTopP = 'gen_ai.request.top_p';
  static const requestTopK = 'gen_ai.request.top_k';
  static const requestMaxTokens = 'gen_ai.request.max_tokens';
  static const requestStopSequences = 'gen_ai.request.stop_sequences';
  static const requestFrequencyPenalty = 'gen_ai.request.frequency_penalty';
  static const requestPresencePenalty = 'gen_ai.request.presence_penalty';
  static const requestSeed = 'gen_ai.request.seed';
  static const requestChoiceCount = 'gen_ai.request.choice.count';

  static const outputType = 'gen_ai.output.type';

  static const responseFinishReasons = 'gen_ai.response.finish_reasons';

  static const usageInputTokens = 'gen_ai.usage.input_tokens';
  static const usageOutputTokens = 'gen_ai.usage.output_tokens';
  static const usageReasoningOutputTokens =
      'gen_ai.usage.reasoning.output_tokens';
  static const usageCacheReadInputTokens =
      'gen_ai.usage.cache_read.input_tokens';

  static const toolName = 'gen_ai.tool.name';
  static const toolType = 'gen_ai.tool.type';

  // Content attributes (opt-in; may contain PII).
  static const inputMessages = 'gen_ai.input.messages';
  static const outputMessages = 'gen_ai.output.messages';
  static const systemInstructions = 'gen_ai.system_instructions';

  static const errorType = 'error.type';

  /// Non-standard attribute used to keep the GenAI span tree connected across
  /// Genkit action types that have no GenAI mapping (flow, util, etc.).
  static const genkitActionType = 'genkit.action.type';
}

/// Well-known values for `gen_ai.operation.name`.
abstract final class GenAiOperation {
  static const chat = 'chat';
  static const executeTool = 'execute_tool';
}

/// The dedicated event that carries prompt/response content independently of
/// the span, per the spec.
const genAiOperationDetailsEvent = 'gen_ai.client.inference.operation.details';

/// The spec's canonical opt-in env var for capturing message content.
const captureContentEnvVar =
    'OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT';

/// Splits a fully qualified Genkit model name into `(prefix, model)`.
///
/// `googleai/gemini-flash-latest` -> `('googleai', 'gemini-flash-latest')`.
/// A name without a `/` yields a `null` prefix and the name as the model.
({String? prefix, String model}) splitModelName(String name) {
  final i = name.indexOf('/');
  if (i < 0) return (prefix: null, model: name);
  return (prefix: name.substring(0, i), model: name.substring(i + 1));
}

/// Derives `gen_ai.provider.name` from a Genkit model-name prefix.
///
/// Maps known Genkit plugin prefixes to the spec's well-known provider names,
/// and passes unknown prefixes through lowercased so custom plugins still get a
/// discriminator. Returns `null` when there is no prefix.
String? deriveProviderName(String? prefix) {
  if (prefix == null || prefix.isEmpty) return null;
  switch (prefix.toLowerCase()) {
    case 'googleai':
    case 'google-genai':
    case 'google_genai':
      return 'gcp.gen_ai';
    case 'vertexai':
    case 'vertex-ai':
    case 'vertex_ai':
      return 'gcp.vertex_ai';
    case 'openai':
      return 'openai';
    case 'anthropic':
      return 'anthropic';
    default:
      return prefix.toLowerCase();
  }
}

/// Maps a Genkit finish reason string to the GenAI `finish_reasons` value.
///
/// [failed] selects the fallback for ambiguous reasons (`other`/`unknown`):
/// `error` when the span failed, otherwise `stop`.
String mapFinishReason(String? genkitReason, {required bool failed}) {
  switch (genkitReason) {
    case 'stop':
      return 'stop';
    case 'length':
      return 'length';
    case 'blocked':
      return 'content_filter';
    case 'interrupted':
      // No exact spec value; treat an interrupted turn as a normal stop.
      return 'stop';
    case 'other':
    case 'unknown':
    default:
      return failed ? 'error' : 'stop';
  }
}

/// Derives `gen_ai.output.type` from an output format / content type.
///
/// Returns `json` when JSON output was requested, `text` when a text format was
/// requested, otherwise `null` (omit the attribute).
String? deriveOutputType({String? format, String? contentType}) {
  final f = format?.toLowerCase();
  final ct = contentType?.toLowerCase();
  if (f == 'json' || (ct != null && ct.contains('json'))) return 'json';
  if (f == 'text' || (ct != null && ct.startsWith('text/'))) return 'text';
  return null;
}

/// Coerces a dynamic config value to an `int`, or `null` if not numeric.
int? asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Coerces a dynamic config value to a `double`, or `null` if not numeric.
double? asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Coerces a dynamic config value to a `List<String>`, or `null`.
///
/// Accepts a `List` of any element type (stringifying each) or a single scalar
/// (wrapped in a one-element list).
List<String>? asStringList(Object? value) {
  if (value == null) return null;
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  return [value.toString()];
}
