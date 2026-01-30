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

// ignore_for_file: constant_identifier_names

/// Exception thrown for errors encountered during Genkit flow operations.
/// Common status codes for Genkit operations.
///
/// These correspond to gRPC status codes.
enum StatusCodes {
  /// The operation completed successfully.
  OK(0),

  /// The operation was cancelled, typically by the caller.
  CANCELLED(1),

  /// Unknown error.
  UNKNOWN(2),

  /// The client specified an invalid argument.
  INVALID_ARGUMENT(3),

  /// The deadline expired before the operation could complete.
  DEADLINE_EXCEEDED(4),

  /// Some requested entity (e.g., file or directory) was not found.
  NOT_FOUND(5),

  /// The entity that a client attempted to create (e.g., file or directory)
  /// already exists.
  ALREADY_EXISTS(6),

  /// The caller does not have permission to execute the specified operation.
  PERMISSION_DENIED(7),

  /// The request does not have valid authentication credentials for the
  /// operation.
  UNAUTHENTICATED(16),

  /// Some resource has been exhausted, perhaps a per-user quota.
  RESOURCE_EXHAUSTED(8),

  /// The operation was rejected because the system is not in a state
  /// required for the operation's execution.
  FAILED_PRECONDITION(9),

  /// The operation was aborted, typically due to a concurrency issue.
  ABORTED(10),

  /// The operation was attempted past the valid range.
  OUT_OF_RANGE(11),

  /// The operation is not implemented or is not supported/enabled.
  UNIMPLEMENTED(12),

  /// Internal errors.
  INTERNAL(13),

  /// The service is currently unavailable.
  UNAVAILABLE(14),

  /// Unrecoverable data loss or corruption.
  DATA_LOSS(15);

  final int value;
  const StatusCodes(this.value);

  static StatusCodes fromHttpStatus(int code) {
    switch (code) {
      case 200:
        return StatusCodes.OK;
      case 400:
        return StatusCodes.INVALID_ARGUMENT;
      case 401:
        return StatusCodes.UNAUTHENTICATED;
      case 403:
        return StatusCodes.PERMISSION_DENIED;
      case 404:
        return StatusCodes.NOT_FOUND;
      case 409:
        return StatusCodes.ABORTED; // Or ALREADY_EXISTS
      case 429:
        return StatusCodes.RESOURCE_EXHAUSTED;
      case 499:
        return StatusCodes.CANCELLED;
      case 500:
        return StatusCodes.INTERNAL;
      case 501:
        return StatusCodes.UNIMPLEMENTED;
      case 503:
        return StatusCodes.UNAVAILABLE;
      case 504:
        return StatusCodes.DEADLINE_EXCEEDED;
      default:
        return StatusCodes.UNKNOWN;
    }
  }
}

/// Exception thrown for errors encountered during Genkit flow operations.
class GenkitException implements Exception {
  final String message;
  final StatusCodes status;
  final String? details; // Further details, potentially response body
  final Object? underlyingException; // For wrapping other exceptions
  final StackTrace? stackTrace; // For capturing the stack trace

  GenkitException(
    this.message, {
    StatusCodes? status,
    this.details,
    this.underlyingException,
    this.stackTrace,
  }) : status = status ?? StatusCodes.INTERNAL;

  /// Returns the integer value of the status code.
  int get statusCode => status.value;

  @override
  String toString() {
    var str = 'GenkitException: $message';
    if (status != StatusCodes.UNKNOWN) {
      str += ' (Status: ${status.name}, Code: ${status.value})';
    }
    if (details != null && details!.isNotEmpty) {
      str += '\nDetails: $details';
    }
    if (underlyingException != null) {
      str += '\nUnderlying exception: $underlyingException';
    }
    if (stackTrace != null) {
      str += '\nStackTrace:\n$stackTrace';
    }
    return str;
  }
}
