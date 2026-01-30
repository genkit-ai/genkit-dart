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

// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';

import '../../core/action.dart';
import '../../exception.dart';
import '../../types.dart';

import '../generate_middleware.dart';

final _logger = Logger('genkit.middleware.retry');


/// Common status codes for Genkit operations.
///
/// These correspond to gRPC status codes.
enum StatusName {
  /// The operation completed successfully.
  OK,
  /// The operation was cancelled.
  CANCELLED,
  /// Unknown error.
  UNKNOWN,
  /// Client specified an invalid argument.
  INVALID_ARGUMENT,
  /// Deadline expired before operation could complete.
  DEADLINE_EXCEEDED,
  /// Some requested entity (e.g., file or directory) was not found.
  NOT_FOUND,
  /// Some entity that we attempted to create (e.g., file or directory) already exists.
  ALREADY_EXISTS,
  /// The caller does not have permission to execute the specified operation.
  PERMISSION_DENIED,
  /// The request does not have valid authentication credentials for the operation.
  UNAUTHENTICATED,
  /// Some resource has been exhausted, perhaps a per-user quota.
  RESOURCE_EXHAUSTED,
  /// Operation was rejected because the system is not in a state required for the operation's execution.
  FAILED_PRECONDITION,
  /// The operation was aborted.
  ABORTED,
  /// Operation was attempted past the valid range.
  OUT_OF_RANGE,
  /// Operation is not implemented or not supported/enabled in this service.
  UNIMPLEMENTED,
  /// Internal errors.
  INTERNAL,
  /// The service is currently unavailable.
  UNAVAILABLE,
  /// Unrecoverable data loss or corruption.
  DATA_LOSS,
}


/// A middleware that retries model and tool requests on failure.
///
/// Only [GenkitException]s with specific status codes are retried.
/// By default, it retries on [StatusName.UNAVAILABLE], [StatusName.DEADLINE_EXCEEDED],
/// [StatusName.RESOURCE_EXHAUSTED], [StatusName.ABORTED], and [StatusName.INTERNAL].
///
/// It uses exponential backoff with jitter to calculate the delay between retries.
class RetryMiddleware extends GenerateMiddleware {
  /// The maximum number of retry attempts.
  final int maxRetries;

  /// The list of status codes that should trigger a retry.
  final List<StatusName> statuses;

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

  /// Creates a [RetryMiddleware].
  RetryMiddleware({
    this.maxRetries = 3,
    this.statuses = const [
      StatusName.UNAVAILABLE,
      StatusName.DEADLINE_EXCEEDED,
      StatusName.RESOURCE_EXHAUSTED,
      StatusName.ABORTED,
      StatusName.INTERNAL,
    ],
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
        _logger.warning('Retry attempt $attempt after ${delay.inMilliseconds}ms due to error: $e');
        await Future.delayed(delay);
      }
    }
  }

  bool _shouldRetry(Object e) {
    if (statuses.isEmpty) return true;
    
    StatusName? status;
    if (e is GenkitException) {
      status = _mapStatusCodeToStatus(e.statusCode);
    }
    
    if (status != null) {
      return statuses.contains(status);
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

  StatusName? _mapStatusCodeToStatus(int? statusCode) {
    if (statusCode == null) return null;
    switch (statusCode) {
      case 200: return StatusName.OK;
      case 400: return StatusName.INVALID_ARGUMENT;
      case 401: return StatusName.UNAUTHENTICATED;
      case 403: return StatusName.PERMISSION_DENIED;
      case 404: return StatusName.NOT_FOUND;
      case 409: return StatusName.ABORTED; // Or ALREADY_EXISTS
      case 429: return StatusName.RESOURCE_EXHAUSTED;
      case 499: return StatusName.CANCELLED;
      case 500: return StatusName.INTERNAL;
      case 501: return StatusName.UNIMPLEMENTED;
      case 503: return StatusName.UNAVAILABLE;
      case 504: return StatusName.DEADLINE_EXCEEDED;
      default: return StatusName.UNKNOWN;
    }
  }
}
