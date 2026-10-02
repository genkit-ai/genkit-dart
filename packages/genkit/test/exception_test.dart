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

import 'package:genkit/client.dart';
import 'package:genkit/plugin.dart' show parseRetryAfter;
import 'package:test/test.dart';

void main() {
  group('StatusCode', () {
    test('should map to expected HTTP status codes', () {
      final expected = <StatusCode, int>{
        StatusCode.ok: 200,
        StatusCode.cancelled: 499,
        StatusCode.unknown: 500,
        StatusCode.invalidArgument: 400,
        StatusCode.deadlineExceeded: 504,
        StatusCode.notFound: 404,
        StatusCode.alreadyExists: 409,
        StatusCode.permissionDenied: 403,
        StatusCode.unauthenticated: 401,
        StatusCode.resourceExhausted: 429,
        StatusCode.failedPrecondition: 400,
        StatusCode.aborted: 409,
        StatusCode.outOfRange: 400,
        StatusCode.unimplemented: 501,
        StatusCode.internal: 500,
        StatusCode.unavailable: 503,
        StatusCode.dataLoss: 500,
      };

      expect(
        expected.length,
        StatusCode.values.length,
        reason: 'Ensure all StatusCode are tested.',
      );

      for (final entry in expected.entries) {
        expect(entry.key.httpStatus, entry.value);
      }
    });

    test('wireName is the canonical gRPC name, independent of Dart name', () {
      expect(StatusCode.notFound.wireName, 'NOT_FOUND');
      expect(StatusCode.invalidArgument.wireName, 'INVALID_ARGUMENT');
      expect(StatusCode.ok.wireName, 'OK');
      for (final code in StatusCode.values) {
        expect(code.wireName, matches(RegExp(r'^[A-Z]+(_[A-Z]+)*$')));
      }
    });

    test('fromWireName round-trips every value', () {
      for (final code in StatusCode.values) {
        expect(StatusCode.fromWireName(code.wireName), code);
      }
    });

    test('fromWireName maps unrecognized names to unknown', () {
      expect(StatusCode.fromWireName('NOT_A_STATUS'), StatusCode.unknown);
      // Dart names are not wire names.
      expect(StatusCode.fromWireName('notFound'), StatusCode.unknown);
    });
  });

  group('GenkitException', () {
    test('should set basic exception information correctly', () {
      final exception = GenkitException('Test error message');

      expect(exception.message, 'Test error message');
      expect(exception.status, StatusCode.internal);
      expect(exception.details, isNull);
      expect(exception.cause, isNull);
      expect(exception.stackTrace, isNull);
    });

    test('should create exception with all information', () {
      final cause = Exception('Underlying error');
      final stackTrace = StackTrace.current;

      final exception = GenkitException(
        'Main error message',
        status: StatusCode.internal,
        details: 'Error details',
        cause: cause,
        stackTrace: stackTrace,
      );

      expect(exception.message, 'Main error message');
      expect(exception.status, StatusCode.internal);
      expect(exception.details, 'Error details');
      expect(exception.cause, cause);
      expect(exception.stackTrace, stackTrace);
    });

    test('should return properly formatted string from toString()', () {
      final exception = GenkitException(
        'Test error',
        status: StatusCode.notFound,
        details: 'Not found',
      );

      final string = exception.toString();

      expect(string, contains('GenkitException: Test error'));
      expect(string, contains('Status: NOT_FOUND'));
      expect(string, contains('Code: 5'));
      expect(string, contains('Details: Not found'));
    });

    test('should return basic message only from toString()', () {
      final exception = GenkitException('Simple error');

      final string = exception.toString();

      expect(
        string,
        equals('GenkitException: Simple error (Status: INTERNAL, Code: 13)'),
      );
    });

    test('should include underlying exception in toString()', () {
      final cause = Exception('Network error');
      final exception = GenkitException('Main error', cause: cause);

      final string = exception.toString();

      expect(string, contains('GenkitException: Main error'));
      expect(
        string,
        contains('    INNER EXCEPTION:\n    Exception: Network error'),
      );
    });

    test('should ignore empty details in toString()', () {
      final exception = GenkitException('Test error', details: '');

      final string = exception.toString();

      expect(
        string,
        equals('GenkitException: Test error (Status: INTERNAL, Code: 13)'),
      );
      expect(string, isNot(contains('Details:')));
    });

    test('should implement Exception interface', () {
      final exception = GenkitException('Test');

      expect(exception, isA<Exception>());
    });

    test('should include all information in complete exception', () {
      final cause = FormatException('Invalid JSON');
      final stackTrace = StackTrace.current;

      final exception = GenkitException(
        'JSON parsing failed',
        status: StatusCode.invalidArgument,
        details: 'Response body: {"invalid": json}',
        cause: cause,
        stackTrace: stackTrace,
      );

      final string = exception.toString();

      expect(string, contains('GenkitException: JSON parsing failed'));
      expect(string, contains('Status: INVALID_ARGUMENT'));
      expect(string, contains('Code: 3'));
      expect(string, contains('Details: Response body: {"invalid": json}'));
      expect(
        string,
        contains('    INNER EXCEPTION:\n    FormatException: Invalid JSON'),
      );
      expect(string, contains('    INNER STACK TRACE:'));
    });

    test('toString includes retryAfter when set', () {
      final e = GenkitException(
        'slow down',
        status: StatusCode.resourceExhausted,
        retryAfter: const Duration(seconds: 2),
      );
      expect(e.toString(), contains('(Retry after: 2000ms)'));
    });
  });

  group('parseRetryAfter', () {
    final now = DateTime.utc(2026, 9, 30, 12);

    test('parses delay-seconds', () {
      expect(parseRetryAfter('120'), const Duration(seconds: 120));
      expect(parseRetryAfter(' 3 '), const Duration(seconds: 3));
      expect(parseRetryAfter('0'), Duration.zero);
    });

    test('tolerates fractional seconds', () {
      expect(parseRetryAfter('1.5'), const Duration(milliseconds: 1500));
    });

    test('parses an HTTP-date relative to now', () {
      expect(
        parseRetryAfter('Wed, 30 Sep 2026 12:00:30 GMT', now: now),
        const Duration(seconds: 30),
      );
    });

    test('clamps a past HTTP-date to zero', () {
      expect(
        parseRetryAfter('Wed, 30 Sep 2026 11:00:00 GMT', now: now),
        Duration.zero,
      );
    });

    test('returns null for missing or invalid values', () {
      expect(parseRetryAfter(null), isNull);
      expect(parseRetryAfter(''), isNull);
      expect(parseRetryAfter('   '), isNull);
      expect(parseRetryAfter('-5'), isNull);
      expect(parseRetryAfter('soon'), isNull);
      expect(parseRetryAfter('NaN'), isNull);
      expect(parseRetryAfter('Infinity'), isNull);
    });
  });
}
