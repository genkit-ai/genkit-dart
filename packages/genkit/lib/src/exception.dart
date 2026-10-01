// Copyright 2024 Google LLC
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

import 'package:stack_trace/stack_trace.dart';

/// Canonical status codes for Genkit operations.
///
/// These correspond to gRPC status codes. Use [wireName] (e.g. `NOT_FOUND`)
/// when a status crosses a process boundary; [name] follows Dart naming and is
/// not part of the wire format.
enum StatusCode {
  /// The operation completed successfully.
  ok(0, 'OK'),

  /// The operation was cancelled, typically by the caller.
  cancelled(1, 'CANCELLED'),

  /// Unknown error.
  unknown(2, 'UNKNOWN'),

  /// The client specified an invalid argument.
  invalidArgument(3, 'INVALID_ARGUMENT'),

  /// The deadline expired before the operation could complete.
  deadlineExceeded(4, 'DEADLINE_EXCEEDED'),

  /// Some requested entity (e.g., file or directory) was not found.
  notFound(5, 'NOT_FOUND'),

  /// The entity that a client attempted to create (e.g., file or directory)
  /// already exists.
  alreadyExists(6, 'ALREADY_EXISTS'),

  /// The caller does not have permission to execute the specified operation.
  permissionDenied(7, 'PERMISSION_DENIED'),

  /// The request does not have valid authentication credentials for the
  /// operation.
  unauthenticated(16, 'UNAUTHENTICATED'),

  /// Some resource has been exhausted, perhaps a per-user quota.
  resourceExhausted(8, 'RESOURCE_EXHAUSTED'),

  /// The operation was rejected because the system is not in a state
  /// required for the operation's execution.
  failedPrecondition(9, 'FAILED_PRECONDITION'),

  /// The operation was aborted, typically due to a concurrency issue.
  aborted(10, 'ABORTED'),

  /// The operation was attempted past the valid range.
  outOfRange(11, 'OUT_OF_RANGE'),

  /// The operation is not implemented or is not supported/enabled.
  unimplemented(12, 'UNIMPLEMENTED'),

  /// Internal errors.
  internal(13, 'INTERNAL'),

  /// The service is currently unavailable.
  unavailable(14, 'UNAVAILABLE'),

  /// Unrecoverable data loss or corruption.
  dataLoss(15, 'DATA_LOSS');

  const StatusCode(this.value, this.wireName);

  /// The numeric gRPC status code.
  final int value;

  /// The canonical gRPC status name (e.g. `NOT_FOUND`), as used in JSON
  /// payloads, HTTP error bodies and other Genkit SDKs.
  final String wireName;

  /// Parses a canonical status name (see [wireName]).
  ///
  /// Unrecognized names map to [StatusCode.unknown] rather than throwing, so
  /// that statuses from newer peers degrade gracefully.
  static StatusCode fromWireName(String wireName) {
    for (final code in values) {
      if (code.wireName == wireName) return code;
    }
    return unknown;
  }

  int get httpStatus {
    switch (this) {
      case StatusCode.ok:
        return 200;
      case StatusCode.cancelled:
        return 499;
      case StatusCode.unknown:
        return 500;
      case StatusCode.invalidArgument:
        return 400;
      case StatusCode.deadlineExceeded:
        return 504;
      case StatusCode.notFound:
        return 404;
      case StatusCode.alreadyExists:
        return 409;
      case StatusCode.permissionDenied:
        return 403;
      case StatusCode.unauthenticated:
        return 401;
      case StatusCode.resourceExhausted:
        return 429;
      case StatusCode.failedPrecondition:
        return 400;
      case StatusCode.aborted:
        return 409;
      case StatusCode.outOfRange:
        return 400;
      case StatusCode.unimplemented:
        return 501;
      case StatusCode.internal:
        return 500;
      case StatusCode.unavailable:
        return 503;
      case StatusCode.dataLoss:
        return 500;
    }
  }

  /// Maps an HTTP status code to the closest [StatusCode] value.
  ///
  /// This mapping is intentionally canonical and not fully reversible:
  /// multiple [StatusCode] values can share one HTTP status.
  /// For example, `400` maps to [StatusCode.invalidArgument],
  /// `409` maps to [StatusCode.aborted], and `500` maps to
  /// [StatusCode.internal].
  static StatusCode fromHttpStatus(int code) {
    switch (code) {
      case 200:
        return StatusCode.ok;
      case 400:
        return StatusCode.invalidArgument;
      case 401:
        return StatusCode.unauthenticated;
      case 403:
        return StatusCode.permissionDenied;
      case 404:
        return StatusCode.notFound;
      case 409:
        return StatusCode.aborted; // Or alreadyExists
      case 429:
        return StatusCode.resourceExhausted;
      case 499:
        return StatusCode.cancelled;
      case 500:
        return StatusCode.internal;
      case 501:
        return StatusCode.unimplemented;
      case 503:
        return StatusCode.unavailable;
      case 504:
        return StatusCode.deadlineExceeded;
      default:
        return StatusCode.unknown;
    }
  }
}

/// Exception thrown for errors encountered during Genkit flow operations.
class GenkitException implements Exception {
  final String message;
  final StatusCode status;
  final String? details; // Further details, potentially response body
  final Object? underlyingException; // For wrapping other exceptions
  final StackTrace? stackTrace; // For capturing the stack trace

  GenkitException(
    this.message, {
    StatusCode? status,
    this.details,
    this.underlyingException,
    this.stackTrace,
  }) : status = status ?? StatusCode.internal;

  /// Returns the integer value of the status code.
  int get statusCode => status.value;

  @override
  String toString() {
    // section 1: message and status
    final sb = StringBuffer('GenkitException: $message');
    if (status != StatusCode.unknown) {
      sb.write(' (Status: ${status.wireName}, Code: ${status.value})');
    }

    // section 2: details
    if (details != null && details!.isNotEmpty) {
      sb.write('\n\nDetails: $details');
    }

    // section 3: underlying exception
    if (underlyingException != null) {
      sb.write('\n\n');
      sb.write(
        '''INNER EXCEPTION:
$underlyingException'''
            .indent(),
      );
    }

    // section 4: stack trace
    if (stackTrace != null) {
      sb.write('\n\n');
      sb.write(
        '''INNER STACK TRACE:
${Trace.from(stackTrace!).terse}'''
            .indent(),
      );
    }
    return sb.toString();
  }
}

extension on String {
  /// Indents each line of the string by the given number of spaces.
  String indent({int spaces = 4}) {
    final indentation = ' ' * spaces;

    return LineSplitter.split(
      this,
    ).map((line) => '$indentation${line.trimRight()}').join('\n');
  }
}
