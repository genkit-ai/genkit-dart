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

import 'package:genkit_vertex_auth/genkit_vertex_auth.dart';
import 'package:test/test.dart';

void main() {
  group('project ID extraction', () {
    test('extracts project_id from map', () {
      expect(
        extractProjectIdFromServiceAccountJson({'project_id': 'my-project'}),
        'my-project',
      );
    });

    test('extracts project_id from JSON string', () {
      expect(
        extractProjectIdFromServiceAccountJson('{"project_id": "my-project"}'),
        'my-project',
      );
    });

    test('returns null for missing project_id', () {
      expect(
        extractProjectIdFromServiceAccountJson({'type': 'service_account'}),
        isNull,
      );
    });

    test('returns null for malformed JSON string', () {
      expect(extractProjectIdFromServiceAccountJson('{not-json'), isNull);
    });
  });

  test('builds google API client header', () {
    final header = googleApiClientHeaderValue();

    expect(header, startsWith('genkit-dart/'));
    expect(header, contains(' gl-dart/'));
  });

  test('creates token provider factories', () {
    final adcProvider = createAdcAccessTokenProvider();
    final serviceAccountProvider = createServiceAccountAccessTokenProvider(
      credentialsJson: {'type': 'service_account'},
    );

    expect(adcProvider, isA<Function>());
    expect(serviceAccountProvider, isA<Function>());
  });
}
