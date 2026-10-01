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

import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:schemantic/schemantic.dart';

import '../../core/action.dart';
import '../../core/cancellation.dart';
import '../../exception.dart';
import '../../types.dart';
import '../generate_middleware.dart';
import '../tool.dart';

part 'retry.g.dart';

final _logger = Logger('genkit.middleware.retry');

@Schema()
abstract class $RetryOptions {
  int? get maxRetries;

  // Wire names (see [StatusCode.wireName]) rather than `List<StatusCode>`:
  // schemantic serializes enums by Dart name, which would leak lowerCamelCase
  // into the JSON config. [retry] provides the typed API.
  // TODO: restore the `enum` constraint on items once schemantic supports
  // per-item string constraints (`@StringField` is String-only today).
  @Field(
    description:
        'Canonical status names that trigger a retry (e.g. UNAVAILABLE).',
  )
  List<String>? get statuses;
  int? get initialDelayMs;
  int? get maxDelayMs;
  double? get backoffFactor;
  bool? get noJitter;
  bool? get retryModel;
  bool? get retryTools;
}

/// Name under which [RetryMiddleware] is registered.
const _name = 'retry';

/// Lets [retry] refs resolve. Core registers it on every `Genkit` instance,
/// so callers never add it themselves.
final retryDef = defineMiddleware<RetryOptions>(
  name: _name,
  configSchema: RetryOptions.$schema,
  create: (config, ctx) => RetryMiddleware(
    maxRetries: config?.maxRetries ?? 3,
    statuses: switch (config?.statuses) {
      final names? => _parseStatuses(names),
      null => RetryMiddleware.defaultRetryStatuses,
    },
    initialDelayMs: config?.initialDelayMs ?? 1000,
    maxDelayMs: config?.maxDelayMs ?? 60000,
    backoffFactor: config?.backoffFactor ?? 2.0,
    noJitter: config?.noJitter ?? false,
    retryModel: config?.retryModel ?? true,
    retryTools: config?.retryTools ?? false,
  ),
);

/// Parses configured status names, rejecting any that are not a wire name.
///
/// Config arrives as JSON (Dev UI, raw middleware maps), so a typo or a Dart
/// name like `unavailable` must fail loudly. [StatusCode.fromWireName] maps
/// unrecognized names to `unknown`, which suits statuses from newer peers but
/// here would silently retry UNKNOWN errors instead. Matches on the exact
/// wire name so `UNKNOWN` itself stays valid.
List<StatusCode> _parseStatuses(List<String> names) => [
  for (final name in names)
    StatusCode.values.firstWhere(
      (c) => c.wireName == name,
      orElse: () => throw GenkitException(
        'Unknown retry status "$name". Expected one of: '
        '${StatusCode.values.map((c) => c.wireName).join(', ')}.',
        status: StatusCode.invalidArgument,
      ),
    ),
];

/// Retries failed model (and optionally tool) calls with exponential backoff.
///
/// Built in: no plugin needs to be registered.
///
/// ```dart
/// final response = await ai.generate(
///   model: googleAI.gemini('gemini-flash-latest'),
///   prompt: 'Reliable request',
///   use: [retry(maxRetries: 3)],
/// );
/// ```
///
/// With the Lite API, pass a [RetryMiddleware] instance instead.
GenerateMiddlewareRef<RetryOptions> retry({
  int? maxRetries,
  List<StatusCode>? statuses,
  int? initialDelayMs,
  int? maxDelayMs,
  double? backoffFactor,
  bool? noJitter,
  bool? retryModel,
  bool? retryTools,
}) {
  return middlewareRef(
    name: _name,
    config: RetryOptions(
      maxRetries: maxRetries,
      statuses: statuses?.map((s) => s.wireName).toList(),
      initialDelayMs: initialDelayMs,
      maxDelayMs: maxDelayMs,
      backoffFactor: backoffFactor,
      noJitter: noJitter,
      retryModel: retryModel,
      retryTools: retryTools,
    ),
  );
}

/// A middleware that retries model and tool requests on failure.
///
/// Only [GenkitException]s with specific status codes are retried.
/// By default, it retries on [StatusCode.unavailable],
/// [StatusCode.deadlineExceeded], [StatusCode.resourceExhausted],
/// [StatusCode.aborted], and [StatusCode.internal].
///
/// It uses exponential backoff with jitter to calculate the delay between retries.
final class RetryMiddleware extends GenerateMiddleware {
  /// The maximum number of retry attempts.
  final int maxRetries;

  /// The list of status codes that should trigger a retry.
  final List<StatusCode> statuses;

  /// The initial delay in milliseconds for the first retry.
  final int initialDelayMs;

  /// The maximum delay in milliseconds between retries.
  final int maxDelayMs;

  /// The factor by which the delay increases with each retry.
  final double backoffFactor;

  /// Whether to disable jitter. Jitter is enabled by default.
  final bool noJitter;

  /// An optional callback that is called on each error.
  ///
  /// The callback receives the error and the current attempt number (1-based).
  /// If the callback returns `false`, retrying is stopped immediately.
  /// If it returns `true` (or if it is null), retrying continues.
  final bool Function(Object error, int attempt)? onError;

  /// Whether to retry model requests. Defaults to `true`.
  final bool retryModel;

  /// Whether to retry tool requests. Defaults to `false`.
  final bool retryTools;

  /// The default list of status codes that trigger a retry.
  static const defaultRetryStatuses = [
    StatusCode.unavailable,
    StatusCode.deadlineExceeded,
    StatusCode.resourceExhausted,
    StatusCode.aborted,
    StatusCode.internal,
  ];

  /// Creates a [RetryMiddleware].
  RetryMiddleware({
    this.maxRetries = 3,
    this.statuses = defaultRetryStatuses,
    this.initialDelayMs = 1000,
    this.maxDelayMs = 60000,
    this.backoffFactor = 2.0,
    this.noJitter = false,
    this.onError,
    this.retryModel = true,
    this.retryTools = false,
  });

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) {
    if (!retryModel) {
      return next(request, ctx);
    }
    return _retry(() => next(request, ctx), ctx.cancel);
  }

  @override
  Future<ToolResult> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResult> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) {
    if (!retryTools) {
      return next(request, ctx);
    }
    return _retry(() => next(request, ctx), ctx.cancel);
  }

  Future<T> _retry<T>(
    Future<T> Function() fn, [
    CancellationToken? cancel,
  ]) async {
    var attempt = 0;
    while (true) {
      // Don't start (or restart) work once the caller has cancelled.
      cancel?.throwIfCancelled();
      try {
        return await fn();
      } catch (e) {
        if (attempt >= maxRetries ||
            !_shouldRetry(e) ||
            (cancel?.isCancelled ?? false)) {
          // A cancel that surfaces as a transport error (e.g. the plugin closed
          // its HTTP client) can look retryable; don't back off - let the
          // downstream cancel checkpoint resolve it as an abort.
          rethrow;
        }
        attempt++;
        final shouldContinue = onError?.call(e, attempt) ?? true;
        if (!shouldContinue) {
          rethrow;
        }
        final delay = _calculateDelay(attempt);
        _logger.warning(
          'Retry attempt $attempt after ${delay.inMilliseconds}ms due to error: $e',
        );
        // Race the backoff against cancellation so a cancel during the sleep
        // resolves promptly instead of waiting out the full (possibly long)
        // delay. When no token is wired up, just wait out the delay.
        if (cancel == null) {
          await Future<void>.delayed(delay);
        } else {
          await Future.any([Future<void>.delayed(delay), cancel.whenCancelled]);
        }
      }
    }
  }

  bool _shouldRetry(Object e) {
    if (e is GenkitException) {
      if (statuses.isEmpty) {
        return defaultRetryStatuses.contains(e.status);
      }
      return statuses.contains(e.status);
    }

    return false;
  }

  Duration _calculateDelay(int attempt) {
    var delayMs = initialDelayMs * pow(backoffFactor, attempt - 1);
    if (delayMs > maxDelayMs) {
      delayMs = maxDelayMs.toDouble();
    }
    if (!noJitter) {
      // Simple jitter: 0.5x to 1.5x
      delayMs = delayMs * (0.5 + Random().nextDouble());
    }
    return Duration(milliseconds: delayMs.toInt());
  }
}
