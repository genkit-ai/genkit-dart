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

  /// Distinguishes token-usage measurements: `input` vs `output`.
  static const tokenType = 'gen_ai.token.type';

  static const usageInputTokens = 'gen_ai.usage.input_tokens';
  static const usageOutputTokens = 'gen_ai.usage.output_tokens';
  static const usageReasoningOutputTokens =
      'gen_ai.usage.reasoning.output_tokens';
  static const usageCacheReadInputTokens =
      'gen_ai.usage.cache_read.input_tokens';

  static const toolName = 'gen_ai.tool.name';
  static const toolType = 'gen_ai.tool.type';

  // Tool call content (opt-in; may contain PII).
  static const toolCallArguments = 'gen_ai.tool.call.arguments';
  static const toolCallResult = 'gen_ai.tool.call.result';

  // TODO: capture gen_ai.tool.call.id and gen_ai.tool.description once they're
  // reachable at this layer. Neither is on SpanMetadata today: the call id lives
  // in the model/generate layer (never handed to the tool span), and the tool
  // description is on Action.metadata. Both need a core change to surface here.

  // Content attributes (opt-in; may contain PII).
  static const inputMessages = 'gen_ai.input.messages';
  static const outputMessages = 'gen_ai.output.messages';
  static const systemInstructions = 'gen_ai.system_instructions';

  static const errorType = 'error.type';
}

/// Non-reserved `genkit.*` attributes. Kept out of the `gen_ai.*` namespace so
/// GenAI-aware backends (e.g. Jaeger's GenAI view) never try to render raw
/// Genkit payloads as spec message content.
abstract final class GenkitAttr {
  /// Genkit action type and name. Emitted on every span (model, tool, generic)
  /// since they carry meaning throughout the span tree, not just where there's
  /// no GenAI mapping.
  static const actionType = 'genkit.action.type';
  static const actionName = 'genkit.action.name';

  /// Raw Genkit action input/output as JSON strings (opt-in; may contain PII).
  static const input = 'genkit.input';
  static const output = 'genkit.output';

  /// Prefix for dynamic metadata attached via `SpanContext.setMetadata`. Dotted
  /// to match the rest of the `genkit.*` namespace this provider emits (the
  /// dev-UI provider uses colons, but that pipeline is separate).
  static const metadataPrefix = 'genkit.metadata.';
}

/// Well-known values for `gen_ai.operation.name`.
abstract final class GenAiOperation {
  static const chat = 'chat';
  static const executeTool = 'execute_tool';
}

/// Canonical `gen_ai.*` metric instrument names.
abstract final class GenAiMetric {
  static const tokenUsage = 'gen_ai.client.token.usage';
  static const operationDuration = 'gen_ai.client.operation.duration';
}

/// The OTel GenAI semantic-conventions version this instrumentation targets.
/// Recorded so future readers know which shape the mapping was written against.
const genAiSemConvVersion = '1.38.0';

/// The dedicated event that carries prompt/response content independently of
/// the span, per the spec.
const genAiOperationDetailsEvent = 'gen_ai.client.inference.operation.details';

/// The spec's canonical opt-in env var for capturing message content.
const captureContentEnvVar =
    'OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT';

/// Where captured GenAI message content is recorded, mirroring the OTel GenAI
/// `ContentCapturingMode`.
///
/// Content may contain PII and is often large, so the default is [noContent].
/// [eventOnly] keeps structured content on a dedicated log event and is
/// preferred for production; [spanOnly] puts it on span attributes as a JSON
/// string (easy to eyeball, but subject to backend attribute/envelope limits),
/// best for development. [spanAndEvent] does both.
///
/// The member names are Dart-idiomatic; the spec's UPPER_SNAKE env tokens
/// (`NO_CONTENT`, `SPAN_ONLY`, `EVENT_ONLY`, `SPAN_AND_EVENT`) map to them via
/// [parseContentCapturingMode].
enum ContentCapturingMode { noContent, spanOnly, eventOnly, spanAndEvent }

/// Parses a spec `ContentCapturingMode` env token (case-insensitive,
/// UPPER_SNAKE).
///
/// Returns [ContentCapturingMode.noContent] for a null/empty value, the
/// matching mode for a known token, and `null` for an unknown token (callers
/// decide the fallback).
ContentCapturingMode? parseContentCapturingMode(String? raw) {
  switch (raw?.trim().toUpperCase()) {
    case null:
    case '':
    case 'NO_CONTENT':
      return ContentCapturingMode.noContent;
    case 'SPAN_ONLY':
      return ContentCapturingMode.spanOnly;
    case 'EVENT_ONLY':
      return ContentCapturingMode.eventOnly;
    case 'SPAN_AND_EVENT':
      return ContentCapturingMode.spanAndEvent;
    default:
      return null;
  }
}

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
      // Gemini API (AI Studio), distinct from Vertex AI.
      return 'gcp.gemini';
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
    case 'failed':
    case 'aborted':
      // Dart resolves failed/aborted turns gracefully (no throw) rather than
      // raising, so the success path still lands here. Stamp `error` so
      // consumers don't count a failed turn as a clean `stop`.
      return 'error';
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
