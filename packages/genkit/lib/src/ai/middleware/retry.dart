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
import '../../core/plugin.dart';
import '../../exception.dart';
import '../../types.dart';
import '../generate_middleware.dart';

part 'retry.g.dart';

final _logger = Logger('genkit.middleware.retry');

@Schematic()
abstract class $RetryOptions {
  int? get maxRetries;
  List<StatusCodes>? get statuses;
  int? get initialDelayMs;
  int? get maxDelayMs;
  double? get backoffFactor;
  bool? get noJitter;
  bool? get retryModel;
  bool? get retryTools;
}

class RetryPlugin extends GenkitPlugin {
  @override
  String get name => 'retry';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<RetryOptions>(
      name: 'retry',
      configSchema: RetryOptions.$schema,
      create: ([RetryOptions? config]) => RetryMiddleware(
        maxRetries: config?.maxRetries ?? 3,
        statuses: config?.statuses ?? RetryMiddleware.defaultRetryStatuses,
        initialDelayMs: config?.initialDelayMs ?? 1000,
        maxDelayMs: config?.maxDelayMs ?? 60000,
        backoffFactor: config?.backoffFactor ?? 2.0,
        noJitter: config?.noJitter ?? false,
        retryModel: config?.retryModel ?? true,
        retryTools: config?.retryTools ?? false,
      ),
    ),
  ];
}

GenerateMiddlewareRef<RetryOptions> retry({
  int? maxRetries,
  List<StatusCodes>? statuses,
  int? initialDelayMs,
  int? maxDelayMs,
  double? backoffFactor,
  bool? noJitter,
  bool? retryModel,
  bool? retryTools,
}) {
  return middlewareRef(
    name: 'retry',
    config: RetryOptions(
      maxRetries: maxRetries,
      statuses: statuses,
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
/// By default, it retries on [StatusCodes.UNAVAILABLE], [StatusCodes.DEADLINE_EXCEEDED],
/// [StatusCodes.RESOURCE_EXHAUSTED], [StatusCodes.ABORTED], and [StatusCodes.INTERNAL].
///
/// It uses exponential backoff with jitter to calculate the delay between retries.
class RetryMiddleware extends GenerateMiddleware {
  /// The maximum number of retry attempts.
  final int maxRetries;

  /// The list of status codes that should trigger a retry.
  final List<StatusCodes> statuses;

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
    StatusCodes.UNAVAILABLE,
    StatusCodes.DEADLINE_EXCEEDED,
    StatusCodes.RESOURCE_EXHAUSTED,
    StatusCodes.ABORTED,
    StatusCodes.INTERNAL,
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
    return _retry(() => next(request, ctx));
  }

  @override
  Future<ToolResponse> tool(
    ToolRequest request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponse> Function(
      ToolRequest request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) {
    if (!retryTools) {
      return next(request, ctx);
    }
    return _retry(() => next(request, ctx));
  }

  Future<T> _retry<T>(Future<T> Function() fn) async {
    var attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        if (attempt >= maxRetries || !_shouldRetry(e)) {
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
        await Future.delayed(delay);
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
