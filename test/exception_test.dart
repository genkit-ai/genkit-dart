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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

void main() {
  group('GenkitException', () {
    test('should set basic exception information correctly', () {
      final exception = GenkitException('Test error message');

      expect(exception.message, 'Test error message');
      expect(exception.statusCode, isNull);
      expect(exception.details, isNull);
      expect(exception.underlyingException, isNull);
      expect(exception.stackTrace, isNull);
    });

    test('should create exception with all information', () {
      final underlyingException = Exception('Underlying error');
      final stackTrace = StackTrace.current;

      final exception = GenkitException(
        'Main error message',
        statusCode: 500,
        details: 'Error details',
        underlyingException: underlyingException,
        stackTrace: stackTrace,
      );

      expect(exception.message, 'Main error message');
      expect(exception.statusCode, 500);
      expect(exception.details, 'Error details');
      expect(exception.underlyingException, underlyingException);
      expect(exception.stackTrace, stackTrace);
    });

    test('should return properly formatted string from toString()', () {
      final exception = GenkitException(
        'Test error',
        statusCode: 404,
        details: 'Not found',
      );

      final string = exception.toString();

      expect(string, contains('GenkitException: Test error'));
      expect(string, contains('Status Code: 404'));
      expect(string, contains('Details: Not found'));
    });

    test('should return basic message only from toString()', () {
      final exception = GenkitException('Simple error');

      final string = exception.toString();

      expect(string, equals('GenkitException: Simple error'));
    });

    test('should include underlying exception in toString()', () {
      final underlyingException = Exception('Network error');
      final exception = GenkitException(
        'Main error',
        underlyingException: underlyingException,
      );

      final string = exception.toString();

      expect(string, contains('GenkitException: Main error'));
      expect(
        string,
        contains('Underlying exception: Exception: Network error'),
      );
    });

    test('should ignore empty details in toString()', () {
      final exception = GenkitException('Test error', details: '');

      final string = exception.toString();

      expect(string, equals('GenkitException: Test error'));
      expect(string, isNot(contains('Details:')));
    });

    test('should implement Exception interface', () {
      final exception = GenkitException('Test');

      expect(exception, isA<Exception>());
    });

    test('should handle HTTP status codes correctly', () {
      final exception = GenkitException('HTTP Error', statusCode: 429);

      expect(exception.statusCode, 429);
      expect(exception.toString(), contains('Status Code: 429'));
    });

    test('should include all information in complete exception', () {
      final underlyingException = FormatException('Invalid JSON');
      final stackTrace = StackTrace.current;

      final exception = GenkitException(
        'JSON parsing failed',
        statusCode: 400,
        details: 'Response body: {"invalid": json}',
        underlyingException: underlyingException,
        stackTrace: stackTrace,
      );

      final string = exception.toString();

      expect(string, contains('GenkitException: JSON parsing failed'));
      expect(string, contains('Status Code: 400'));
      expect(string, contains('Details: Response body: {"invalid": json}'));
      expect(
        string,
        contains('Underlying exception: FormatException: Invalid JSON'),
      );
      expect(string, contains('StackTrace:'));
    });
  });
}
