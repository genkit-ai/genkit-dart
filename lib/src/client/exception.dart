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

/// Exception thrown for errors encountered during Genkit flow operations.
class GenkitException implements Exception {
  final String message;
  final int? statusCode; // HTTP status code if applicable
  final String? details; // Further details, potentially response body
  final Object? underlyingException; // For wrapping other exceptions
  final StackTrace? stackTrace; // For capturing the stack trace

  GenkitException(
    this.message, {
    this.statusCode,
    this.details,
    this.underlyingException,
    this.stackTrace,
  });

  @override
  String toString() {
    var str = 'GenkitException: $message';
    if (statusCode != null) {
      str += ' (Status Code: $statusCode)';
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
