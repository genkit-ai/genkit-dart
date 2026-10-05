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

const _outputSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'colour': {
      'type': 'string',
      'enum': ['red', 'green'],
    },
    'count': {'type': 'integer', 'minimum': 1},
  },
  'required': ['colour'],
  'additionalProperties': false,
};

Future<Map<String, dynamic>> _generationConfigOnTheWire({
  OutputConfig? output,
  Map<String, dynamic>? config,
}) async {
  final client = WireClient(response: textResponse('{"colour":"red"}'));
  final model = wireModel(client);
  await model(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'pick a colour')],
        ),
      ],
      output: output,
      config: config,
    ),
  );
  return (client.requests.single.body['generationConfig'] as Map)
      .cast<String, dynamic>();
}

void main() {
  setUpAll(setUpFirebaseApp);

  test('a constrained JSON request sends the output schema verbatim as '
      'responseJsonSchema', () async {
    final config = await _generationConfigOnTheWire(
      output: OutputConfig(
        format: 'json',
        schema: _outputSchema,
        constrained: true,
      ),
    );

    expect(config['responseMimeType'], 'application/json');
    expect(config['responseJsonSchema'], _outputSchema);
    expect(config, isNot(contains('responseSchema')));
  });

  test('an unconstrained JSON request sends no schema', () async {
    final config = await _generationConfigOnTheWire(
      output: OutputConfig(
        format: 'json',
        schema: _outputSchema,
        constrained: false,
      ),
    );

    expect(config['responseMimeType'], 'application/json');
    expect(config, isNot(contains('responseJsonSchema')));
    expect(config, isNot(contains('responseSchema')));
  });

  test('options.responseJsonSchema is forwarded verbatim', () async {
    final config = await _generationConfigOnTheWire(
      config: {
        'responseMimeType': 'application/json',
        'responseJsonSchema': _outputSchema,
      },
    );

    expect(config['responseJsonSchema'], _outputSchema);
    expect(config, isNot(contains('responseSchema')));
  });

  test('options.responseJsonSchema wins over options.responseSchema', () async {
    final config = await _generationConfigOnTheWire(
      config: {
        'responseMimeType': 'application/json',
        'responseSchema': {'type': 'string'},
        'responseJsonSchema': _outputSchema,
      },
    );

    expect(config['responseJsonSchema'], _outputSchema);
    expect(config, isNot(contains('responseSchema')));
  });
}
