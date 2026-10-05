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

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

import 'wire_harness.dart';

Future<Map<String, dynamic>> _thinkingConfigOnTheWire(
  Map<String, dynamic> thinkingConfig,
) async {
  final client = WireClient();
  final model = wireModel(client, modelName: 'gemini-3-flash-preview');
  await model(userRequest('hello', config: {'thinkingConfig': thinkingConfig}));
  final generationConfig =
      client.requests.single.body['generationConfig'] as Map;
  return (generationConfig['thinkingConfig'] as Map).cast<String, dynamic>();
}

void main() {
  setUpAll(setUpFirebaseApp);

  test('thinkingLevel is sent and no budget is sent', () async {
    final thinkingConfig = await _thinkingConfigOnTheWire({
      'thinkingLevel': 'high',
    });

    expect(thinkingConfig['thinkingLevel'], 'HIGH');
    expect(thinkingConfig, isNot(contains('thinkingBudget')));
  });

  test('thinkingBudget is sent and no level is sent', () async {
    final thinkingConfig = await _thinkingConfigOnTheWire({
      'thinkingBudget': 1024,
    });

    expect(thinkingConfig['thinkingBudget'], 1024);
    expect(thinkingConfig, isNot(contains('thinkingLevel')));
  });

  test('includeThoughts is sent with thinkingLevel', () async {
    final thinkingConfig = await _thinkingConfigOnTheWire({
      'thinkingLevel': 'low',
      'includeThoughts': true,
    });

    expect(thinkingConfig, {'thinkingLevel': 'LOW', 'includeThoughts': true});
  });

  test('includeThoughts is sent with thinkingBudget', () async {
    final thinkingConfig = await _thinkingConfigOnTheWire({
      'thinkingBudget': 1024,
      'includeThoughts': true,
    });

    expect(thinkingConfig, {'thinkingBudget': 1024, 'includeThoughts': true});
  });

  test('thinkingBudget with thinkingLevel throws invalidArgument and sends '
      'nothing', () async {
    final client = WireClient();
    final model = wireModel(client, modelName: 'gemini-3-flash-preview');

    await expectLater(
      model(
        userRequest(
          'hello',
          config: {
            'thinkingConfig': {'thinkingBudget': 1024, 'thinkingLevel': 'high'},
          },
        ),
      ),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.invalidArgument,
        ),
      ),
    );
    expect(client.requests, isEmpty);
  });

  test('an unknown thinkingLevel throws invalidArgument and sends '
      'nothing', () async {
    final client = WireClient();
    final model = wireModel(client, modelName: 'gemini-3-flash-preview');

    await expectLater(
      model(
        userRequest(
          'hello',
          config: {
            'thinkingConfig': {'thinkingLevel': 'extreme'},
          },
        ),
      ),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.invalidArgument,
        ),
      ),
    );
    expect(client.requests, isEmpty);
  });
}
