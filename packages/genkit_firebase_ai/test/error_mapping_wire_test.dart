// Copyright 2026 Google LLC
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

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;

import 'wire_harness.dart';

Map<String, dynamic> _error(
  int code,
  String status,
  String message, {
  List<Map<String, dynamic>>? details,
}) => {
  'error': {
    'code': code,
    'message': message,
    'status': status,
    'details': ?details,
  },
};

Matcher _throwsGenkit(StatusCode status, String message, Matcher cause) =>
    throwsA(
      isA<GenkitException>()
          .having((e) => e.status, 'status', status)
          .having((e) => e.message, 'message', contains(message))
          .having((e) => e.cause, 'cause', cause),
    );

class _UnreachableClient extends WireClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw http.ClientException('Connection refused', request.url);
}

void main() {
  setUpAll(setUpFirebaseApp);

  Future<ModelResponse> generate(WireClient client, {bool stream = false}) =>
      wireModel(client)(userRequest('hello'), onChunk: stream ? (_) {} : null);

  test('a 429 quota error maps to RESOURCE_EXHAUSTED', () async {
    final client = WireClient(
      statusCode: 429,
      response: _error(
        429,
        'RESOURCE_EXHAUSTED',
        'Resource has been exhausted (e.g. check quota).',
      ),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.resourceExhausted,
        'Resource has been exhausted (e.g. check quota).',
        isA<fai.QuotaExceeded>(),
      ),
    );
  });

  test('a 429 without a quota message maps to RESOURCE_EXHAUSTED', () async {
    final client = WireClient(
      statusCode: 429,
      response: _error(429, 'RESOURCE_EXHAUSTED', 'Too many requests.'),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.resourceExhausted,
        'Too many requests.',
        isA<fai.ServerException>(),
      ),
    );
  });

  test('a 400 maps to INVALID_ARGUMENT', () async {
    final client = WireClient(
      statusCode: 400,
      response: _error(400, 'INVALID_ARGUMENT', 'Invalid JSON payload.'),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.invalidArgument,
        'Invalid JSON payload.',
        isA<fai.ServerException>(),
      ),
    );
  });

  test('an invalid API key maps to UNAUTHENTICATED', () async {
    final client = WireClient(
      statusCode: 400,
      response: _error(
        400,
        'INVALID_ARGUMENT',
        'API key not valid. Please pass a valid API key.',
        details: [
          {
            '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
            'reason': 'API_KEY_INVALID',
          },
        ],
      ),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.unauthenticated,
        'API key not valid.',
        isA<fai.InvalidApiKey>(),
      ),
    );
  });

  test('a 401 maps to UNAUTHENTICATED', () async {
    final client = WireClient(
      statusCode: 401,
      response: _error(401, 'UNAUTHENTICATED', 'Request is missing auth.'),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.unauthenticated,
        'Request is missing auth.',
        isA<fai.ServerException>(),
      ),
    );
  });

  test('a 403 maps to PERMISSION_DENIED', () async {
    final client = WireClient(
      statusCode: 403,
      response: _error(403, 'PERMISSION_DENIED', 'Permission denied.'),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.permissionDenied,
        'Permission denied.',
        isA<fai.ServerException>(),
      ),
    );
  });

  test('an unsupported user location maps to FAILED_PRECONDITION', () async {
    final client = WireClient(
      statusCode: 400,
      response: _error(
        400,
        'FAILED_PRECONDITION',
        'User location is not supported for the API use.',
      ),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.failedPrecondition,
        'User location is not supported',
        isA<fai.UnsupportedUserLocation>(),
      ),
    );
  });

  test('a disabled Firebase AI Logic API maps to PERMISSION_DENIED', () async {
    final client = WireClient(
      statusCode: 403,
      response: _error(
        403,
        'PERMISSION_DENIED',
        'Firebase AI Logic API has not been used in project 123.',
        details: [
          {
            'metadata': {
              'service': 'firebasevertexai.googleapis.com',
              'consumer': 'projects/123',
            },
          },
        ],
      ),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.permissionDenied,
        'Enable Firebase AI Logic',
        isA<fai.ServiceApiNotEnabled>(),
      ),
    );
  });

  test('a 500 maps to INTERNAL', () async {
    final client = WireClient(
      statusCode: 500,
      response: _error(500, 'INTERNAL', 'Internal error encountered.'),
    );

    await expectLater(
      generate(client),
      _throwsGenkit(
        StatusCode.internal,
        'Internal error encountered.',
        isA<fai.FirebaseAIException>(),
      ),
    );
  });

  test('a streaming 500 maps to INTERNAL', () async {
    final client = WireClient(
      statusCode: 500,
      response: _error(500, 'INTERNAL', 'Internal error encountered.'),
    );

    await expectLater(
      generate(client, stream: true),
      _throwsGenkit(
        StatusCode.internal,
        'Internal error encountered.',
        isA<fai.ServerException>(),
      ),
    );
  });

  test('a streaming 503 maps to UNAVAILABLE', () async {
    final client = WireClient(
      statusCode: 503,
      response: _error(503, 'UNAVAILABLE', 'The model is overloaded.'),
    );

    await expectLater(
      generate(client, stream: true),
      _throwsGenkit(
        StatusCode.unavailable,
        'The model is overloaded.',
        isA<fai.ServerException>(),
      ),
    );
  });

  test('a network failure maps to UNAVAILABLE', () async {
    await expectLater(
      generate(_UnreachableClient()),
      _throwsGenkit(
        StatusCode.unavailable,
        'Connection refused',
        isA<http.ClientException>(),
      ),
    );
  });

  test('a GenkitException from the plugin passes through unwrapped', () async {
    final client = WireClient(
      response: {
        'promptFeedback': {
          'blockReason': 'SAFETY',
          'safetyRatings': <Object>[],
        },
      },
    );

    await expectLater(
      generate(client),
      _throwsGenkit(StatusCode.invalidArgument, 'SAFETY', isNull),
    );
  });
}
