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

/// Reflection v1 authentication and dev-only endpoints.
library;

import 'package:genkit/src/core/reflection/reflection_config.dart';
import 'package:genkit/src/core/reflection/reflection_v1.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _secret = 'test-secret';

void main() {
  late ReflectionServerV1 server;

  Future<ReflectionServerV1> start({
    String? secret,
    bool devMode = false,
  }) async {
    server = ReflectionServerV1(
      Registry(),
      port: 0,
      secret: secret,
      devMode: devMode,
    );
    await server.start();
    return server;
  }

  String url() => 'http://localhost:${server.actualPort}';

  tearDown(() async => server.stop());

  test('rejects a request with no secret', () async {
    await start(secret: _secret);
    final response = await http.get(Uri.parse('${url()}/api/actions'));
    expect(response.statusCode, 401);
    expect(response.body, isEmpty);
  });

  test('rejects a request with the wrong secret', () async {
    await start(secret: _secret);
    final response = await http.get(
      Uri.parse('${url()}/api/actions'),
      headers: {reflectionSecretHeader: 'nope'},
    );
    expect(response.statusCode, 401);
  });

  test('accepts a request with the right secret', () async {
    await start(secret: _secret);
    final response = await http.get(
      Uri.parse('${url()}/api/actions'),
      headers: {reflectionSecretHeader: _secret},
    );
    expect(response.statusCode, 200);
  });

  test('leaves the health endpoint open', () async {
    await start(secret: _secret);
    final response = await http.get(Uri.parse('${url()}/api/__health'));
    expect(response.statusCode, 200);
  });

  test('requires nothing when no secret is configured', () async {
    await start();
    final response = await http.get(Uri.parse('${url()}/api/actions'));
    expect(response.statusCode, 200);
  });

  test('does not serve quitquitquit outside dev', () async {
    await start();
    final response = await http.get(Uri.parse('${url()}/api/__quitquitquit'));
    expect(response.statusCode, 404);
  });

  test('writes no runtime file outside dev', () async {
    await start();
    expect(server.runtimeFilePath, isNull);
  });
}
