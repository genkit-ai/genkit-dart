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


enum StatusName {
  OK,
  CANCELLED,
  UNKNOWN,
  INVALID_ARGUMENT,
  DEADLINE_EXCEEDED,
  NOT_FOUND,
  ALREADY_EXISTS,
  PERMISSION_DENIED,
  UNAUTHENTICATED,
  RESOURCE_EXHAUSTED,
  FAILED_PRECONDITION,
  ABORTED,
  OUT_OF_RANGE,
  UNIMPLEMENTED,
  INTERNAL,
  UNAVAILABLE,
  DATA_LOSS,
}


class RetryMiddleware extends GenerateMiddleware {
  final int maxRetries;
  final List<StatusName> statuses;
  final int initialDelayMs;
  final int maxDelayMs;
  final double backoffFactor;
  final bool noJitter;
  final bool Function(Object error, int attempt)? onError;
  final bool retryModel;
  final bool retryTools;

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
