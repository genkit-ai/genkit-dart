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
import 'dart:io' show Platform;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:genkit/genkit.dart';
import 'package:genkit/telemetry.dart';
import 'package:logging/logging.dart';

import 'genai/gen_ai_attributes.dart';
import 'genai/gen_ai_message_mapping.dart';
import 'genai/gen_ai_metrics.dart';

final _logger = Logger('GenAiInstrumentation');

/// Where captured prompt/response content is recorded.
enum GenAiContentMode {
  /// Emit a single `gen_ai.client.inference.operation.details` event carrying
  /// the content, correlated to the span via context. Keeps large bodies off
  /// the span. This is the default when content capture is enabled.
  event,

  /// Attach content directly to the span as `gen_ai.*` JSON-string attributes.
  span,
}

/// An [Instrumentation] that emits OpenTelemetry telemetry following the
/// [OTel GenAI semantic conventions][spec] using the `dartastic_opentelemetry`
/// SDK.
///
/// The application owns SDK setup: call `OTel.initialize(endpoint: ...)` (or
/// otherwise configure a dartastic tracer/logger provider) before constructing
/// `Genkit`. When the SDK is not initialized, dartastic returns non-recording
/// spans and this provider is effectively a no-op.
///
/// This provider is independent of the built-in dev `OtelInstrumentation`
/// (which uses a different OpenTelemetry package). The two compose freely and
/// export to separate pipelines.
///
/// [spec]: https://github.com/open-telemetry/semantic-conventions-genai
class GenAiInstrumentation implements Instrumentation {
  /// Whether to capture spec-shaped GenAI message content on model spans, i.e.
  /// the `gen_ai.*.messages` attributes / operation.details event.
  ///
  /// Content may contain PII, so it is off by default. Also enabled when the
  /// env var `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true` is set.
  final bool captureContent;

  /// Where captured content is recorded (event vs span attributes).
  final GenAiContentMode contentMode;

  /// Whether to capture raw Genkit action input/output as `genkit.input` /
  /// `genkit.output` JSON attributes on every span (model, tool, flow, util,
  /// etc.).
  ///
  /// This is independent of [captureContent]: it records the raw Genkit
  /// payloads (useful for debugging or the Genkit Dev UI) rather than the
  /// spec-shaped `gen_ai.*` content. May contain PII, so off by default.
  final bool captureActionIO;

  /// Whether to emit `execute_tool` spans for tool actions. Off by default.
  final bool emitToolSpans;

  /// Whether to emit the spec's GenAI client metrics (token usage, operation
  /// duration) for model operations. On by default; low cardinality and cheap.
  final bool emitMetrics;

  /// Instrumentation scope name for the tracer/logger/meter.
  final String scopeName;

  /// Optional explicit tracer (escape hatch). When null, the tracer is resolved
  /// lazily from `OTel.tracerProvider().getTracer(scopeName)`.
  final otel.APITracer? _injectedTracer;

  /// Optional explicit meter (escape hatch). When null, the meter is resolved
  /// lazily from `OTel.meter(scopeName)`.
  final otel.APIMeter? _injectedMeter;

  otel.APITracer? _cachedTracer;
  otel.APILogger? _cachedLogger;
  GenAiMetrics? _cachedMetrics;
  bool _warnedNotInitialized = false;

  GenAiInstrumentation({
    bool? captureContent,
    this.contentMode = GenAiContentMode.event,
    this.captureActionIO = false,
    this.emitToolSpans = false,
    this.emitMetrics = true,
    this.scopeName = 'genkit-genai',
    otel.APITracer? tracer,
    otel.APIMeter? meter,
  }) : captureContent = captureContent ?? _captureContentFromEnv(),
       _injectedTracer = tracer,
       _injectedMeter = meter;

  static bool _captureContentFromEnv() {
    final value = Platform.environment[captureContentEnvVar];
    return value != null && value.toLowerCase() == 'true';
  }

  otel.APITracer get _tracer => _cachedTracer ??=
      _injectedTracer ?? otel.OTel.tracerProvider().getTracer(scopeName);

  otel.APILogger get _logger_ => _cachedLogger ??= otel.OTel.logger(scopeName);

  GenAiMetrics get _metrics => _cachedMetrics ??= GenAiMetrics(
    _injectedMeter ?? otel.OTel.meter(scopeName),
  );

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) {
    switch (metadata.actionType) {
      case 'model':
        return _runModelSpan(metadata, next);
      case 'tool' when emitToolSpans:
        return _runToolSpan(metadata, next);
      default:
        return _runGenericSpan(metadata, next);
    }
  }

  Future<O> _runModelSpan<O>(
    SpanMetadata metadata,
    Future<O> Function(SpanContext span) next,
  ) {
    final split = splitModelName(metadata.name);
    final provider = deriveProviderName(split.prefix);
    final request = metadata.input is ModelRequest
        ? metadata.input as ModelRequest
        : null;

    final attrs = <String, Object>{
      GenAiAttr.operationName: GenAiOperation.chat,
      GenAiAttr.requestModel: split.model,
      GenAiAttr.providerName: ?provider,
    };

    if (request != null) {
      _addRequestConfigAttributes(attrs, request);
    }

    final span = _tracer.startSpan(
      'chat ${split.model}',
      kind: otel.SpanKind.client,
      attributes: otel.OTel.attributesFromMap(attrs),
    );
    _maybeWarnNotRecording(span);

    // Base metric attributes shared by both histograms: low cardinality only.
    final metricAttrs = <String, Object>{
      GenAiAttr.operationName: GenAiOperation.chat,
      GenAiAttr.requestModel: split.model,
      GenAiAttr.providerName: ?provider,
    };
    final stopwatch = Stopwatch()..start();

    return _tracer.withSpanAsync(span, () async {
      try {
        final output = await next(_GenAiSpanContext(span));
        final response = output is ModelResponse ? output : null;
        if (response != null) {
          _addResponseAttributes(span, response, failed: false);
        }
        if (captureContent) {
          _recordContent(span, request, response);
        }
        _maybeCaptureActionIO(span, metadata.input, output);
        if (emitMetrics) {
          _recordModelMetrics(stopwatch, metricAttrs, response: response);
        }
        return output;
      } catch (e, s) {
        _recordError(span, e, s);
        if (emitMetrics) {
          _recordModelMetrics(
            stopwatch,
            metricAttrs,
            errorType: e.runtimeType.toString(),
          );
        }
        rethrow;
      } finally {
        span.end();
      }
    });
  }

  /// Records the token-usage and operation-duration metrics for a model call.
  void _recordModelMetrics(
    Stopwatch stopwatch,
    Map<String, Object> baseAttrs, {
    ModelResponse? response,
    String? errorType,
  }) {
    stopwatch.stop();

    final usage = response?.usage;
    if (usage != null) {
      _metrics.recordTokenUsage(
        baseAttributes: baseAttrs,
        inputTokens: usage.inputTokens?.toInt(),
        outputTokens: usage.outputTokens?.toInt(),
      );
    }

    _metrics.recordDuration(stopwatch.elapsedMicroseconds / 1e6, {
      ...baseAttrs,
      GenAiAttr.errorType: ?errorType,
    });
  }

  Future<O> _runToolSpan<O>(
    SpanMetadata metadata,
    Future<O> Function(SpanContext span) next,
  ) {
    final attrs = <String, Object>{
      GenAiAttr.operationName: GenAiOperation.executeTool,
      GenAiAttr.toolName: metadata.name,
      GenAiAttr.toolType: 'function',
    };
    final span = _tracer.startSpan(
      'execute_tool ${metadata.name}',
      kind: otel.SpanKind.internal,
      attributes: otel.OTel.attributesFromMap(attrs),
    );
    _maybeWarnNotRecording(span);

    return _tracer.withSpanAsync(span, () async {
      try {
        final output = await next(_GenAiSpanContext(span));
        _maybeCaptureActionIO(span, metadata.input, output);
        return output;
      } catch (e, s) {
        _recordError(span, e, s);
        rethrow;
      } finally {
        span.end();
      }
    });
  }

  Future<O> _runGenericSpan<O>(
    SpanMetadata metadata,
    Future<O> Function(SpanContext span) next,
  ) {
    final attrs = <String, Object>{
      if (metadata.actionType != null)
        GenkitAttr.actionType: metadata.actionType!,
    };
    final span = _tracer.startSpan(
      metadata.name,
      kind: otel.SpanKind.internal,
      attributes: otel.OTel.attributesFromMap(attrs),
    );
    _maybeWarnNotRecording(span);

    return _tracer.withSpanAsync(span, () async {
      try {
        final output = await next(_GenAiSpanContext(span));
        _maybeCaptureActionIO(span, metadata.input, output);
        return output;
      } catch (e, s) {
        _recordError(span, e, s);
        rethrow;
      } finally {
        span.end();
      }
    });
  }

  /// Records raw Genkit input/output on [span] as `genkit.*` JSON attributes
  /// when [captureActionIO] is enabled. Kept out of the reserved `gen_ai.*`
  /// namespace so GenAI-aware backends don't misrender it.
  void _maybeCaptureActionIO(otel.APISpan span, Object? input, Object? output) {
    if (!captureActionIO) return;
    _setJsonAttribute(span, GenkitAttr.input, input);
    _setJsonAttribute(span, GenkitAttr.output, output);
  }

  void _addRequestConfigAttributes(
    Map<String, Object> attrs,
    ModelRequest request,
  ) {
    final config = request.config;
    if (config != null) {
      final temperature = asDouble(config['temperature']);
      if (temperature != null) {
        attrs[GenAiAttr.requestTemperature] = temperature;
      }
      final topP = asDouble(config['topP']);
      if (topP != null) attrs[GenAiAttr.requestTopP] = topP;
      final topK = asInt(config['topK']);
      if (topK != null) attrs[GenAiAttr.requestTopK] = topK;
      final maxTokens = asInt(config['maxOutputTokens']);
      if (maxTokens != null) attrs[GenAiAttr.requestMaxTokens] = maxTokens;
      final stopSequences = asStringList(config['stopSequences']);
      if (stopSequences != null && stopSequences.isNotEmpty) {
        attrs[GenAiAttr.requestStopSequences] = stopSequences;
      }
      final frequencyPenalty = asDouble(config['frequencyPenalty']);
      if (frequencyPenalty != null) {
        attrs[GenAiAttr.requestFrequencyPenalty] = frequencyPenalty;
      }
      final presencePenalty = asDouble(config['presencePenalty']);
      if (presencePenalty != null) {
        attrs[GenAiAttr.requestPresencePenalty] = presencePenalty;
      }
      final seed = asInt(config['seed']);
      if (seed != null) attrs[GenAiAttr.requestSeed] = seed;
      final choiceCount = asInt(config['candidateCount']);
      if (choiceCount != null && choiceCount != 1) {
        attrs[GenAiAttr.requestChoiceCount] = choiceCount;
      }
    }
    final output = request.output;
    if (output != null) {
      final outputType = deriveOutputType(
        format: output.format,
        contentType: output.contentType,
      );
      if (outputType != null) attrs[GenAiAttr.outputType] = outputType;
    }
  }

  void _addResponseAttributes(
    otel.APISpan span,
    ModelResponse response, {
    required bool failed,
  }) {
    final finishReasons = _resolveFinishReasons(response, failed: failed);
    if (finishReasons.isNotEmpty) {
      span.setStringListAttribute(
        GenAiAttr.responseFinishReasons,
        finishReasons,
      );
    }
    final usage = response.usage;
    if (usage != null) {
      final inputTokens = usage.inputTokens?.toInt();
      if (inputTokens != null) {
        span.setIntAttribute(GenAiAttr.usageInputTokens, inputTokens);
      }
      final outputTokens = usage.outputTokens?.toInt();
      if (outputTokens != null) {
        span.setIntAttribute(GenAiAttr.usageOutputTokens, outputTokens);
      }
      final thoughtsTokens = usage.thoughtsTokens?.toInt();
      if (thoughtsTokens != null) {
        span.setIntAttribute(
          GenAiAttr.usageReasoningOutputTokens,
          thoughtsTokens,
        );
      }
      final cachedTokens = usage.cachedContentTokens?.toInt();
      if (cachedTokens != null) {
        span.setIntAttribute(GenAiAttr.usageCacheReadInputTokens, cachedTokens);
      }
    }
  }

  List<String> _resolveFinishReasons(
    ModelResponse response, {
    required bool failed,
  }) {
    final message = response.message;
    final hasToolRequest = message?.content.any(isToolRequestPart) ?? false;

    if (hasToolRequest) {
      // Following the OpenAI GenAI profile: a turn ending in tool calls is the
      // more informative signal for consumers.
      return const ['tool_calls'];
    }
    return [mapFinishReason(response.finishReason.value, failed: failed)];
  }

  void _recordContent(
    otel.APISpan span,
    ModelRequest? request,
    ModelResponse? response,
  ) {
    final inputMessages = request != null
        ? normalizeMessages(request.messages)
        : null;
    final outputMessages = <Map<String, Object?>>[];
    if (response?.message != null) {
      final reason = _resolveFinishReasons(response!, failed: false).first;
      outputMessages.add(mapOutputMessage(response.message!, reason));
    }

    if (contentMode == GenAiContentMode.span) {
      if (inputMessages != null) {
        _setJsonAttribute(
          span,
          GenAiAttr.inputMessages,
          inputMessages.messages,
        );
        if (inputMessages.systemInstructions.isNotEmpty) {
          _setJsonAttribute(
            span,
            GenAiAttr.systemInstructions,
            inputMessages.systemInstructions,
          );
        }
      }
      if (outputMessages.isNotEmpty) {
        _setJsonAttribute(span, GenAiAttr.outputMessages, outputMessages);
      }
      return;
    }

    // Event mode (default): emit a single operation.details event correlated to
    // the span via the current context.
    final eventAttrs = <String, Object>{};
    if (inputMessages != null) {
      eventAttrs[GenAiAttr.inputMessages] = jsonEncode(inputMessages.messages);
      if (inputMessages.systemInstructions.isNotEmpty) {
        eventAttrs[GenAiAttr.systemInstructions] = jsonEncode(
          inputMessages.systemInstructions,
        );
      }
    }
    if (outputMessages.isNotEmpty) {
      eventAttrs[GenAiAttr.outputMessages] = jsonEncode(outputMessages);
    }
    _logger_.emit(
      eventName: genAiOperationDetailsEvent,
      context: otel.Context.current,
      attributes: otel.OTel.attributesFromMap(eventAttrs),
    );
  }

  void _recordError(otel.APISpan span, Object e, StackTrace s) {
    span.setStatus(otel.SpanStatusCode.Error, e.toString());
    span.setStringAttribute(GenAiAttr.errorType, e.runtimeType.toString());
    span.recordException(e, stackTrace: s);
  }

  void _setJsonAttribute(otel.APISpan span, String key, Object? value) {
    if (value == null) return;
    String encoded;
    try {
      encoded = jsonEncode(value);
    } catch (e) {
      encoded = 'Unable to encode: $e';
    }
    span.setStringAttribute(key, encoded);
  }

  void _maybeWarnNotRecording(otel.APISpan span) {
    if (span.isRecording || _warnedNotInitialized) return;
    _warnedNotInitialized = true;
    _logger.warning(
      'GenAiInstrumentation is configured but the dartastic OpenTelemetry SDK '
      'is not initialized, so GenAI telemetry will not be recorded. Call '
      'OTel.initialize(...) before constructing Genkit.',
    );
  }
}

/// A [SpanContext] backed by a dartastic span.
class _GenAiSpanContext implements SpanContext {
  final otel.APISpan _span;

  _GenAiSpanContext(this._span);

  @override
  String get traceId => _span.spanContext.traceId.toString();

  @override
  String get spanId => _span.spanContext.spanId.toString();

  @override
  void setMetadata(Map<String, Object?> metadata) {
    metadata.forEach((key, value) {
      String valueString;
      try {
        valueString = value is String ? value : jsonEncode(value);
      } catch (e) {
        valueString = 'Error encoding metadata: $e';
      }
      // Keep ad-hoc metadata out of the reserved gen_ai.* namespace.
      _span.setStringAttribute('genkit:metadata:$key', valueString);
    });
  }
}
