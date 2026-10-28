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
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:schemantic/schemantic.dart';

import 'wire_harness.dart';

/// Every keyword the old conversion dropped or changed.
const _inputSchema = <String, Object?>{
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  r'$ref': r'#/$defs/Order',
  r'$defs': {
    'Order': {
      'type': 'object',
      'properties': {
        'size': {
          'type': 'string',
          'enum': ['S', 'M', 'L'],
        },
        'quantity': {'type': 'integer', 'minimum': 1, 'maximum': 10},
        'note': {
          'type': ['string', 'null'],
        },
        'delivery': {
          'anyOf': [
            {'type': 'string', 'format': 'date'},
            {'type': 'boolean'},
          ],
        },
        'code': {'type': 'string', 'pattern': r'^[A-Z]{3}$'},
      },
      'required': ['size'],
      'additionalProperties': false,
    },
  },
};

void main() {
  setUpAll(setUpFirebaseApp);

  test('ai.generate sends a tool input schema unchanged', () async {
    final client = WireClient();
    final ai = Genkit(
      isDevEnv: false,
      plugins: [firebaseAI(httpClient: client)],
    );
    addTearDown(ai.shutdown);
    ai.defineTool(
      name: 'placeOrder',
      description: 'Places an order.',
      inputSchema: SchemanticType.from<Map<String, dynamic>>(
        jsonSchema: _inputSchema,
        parse: (json) => json as Map<String, dynamic>,
      ),
      fn: (input, _) async => .response('ok'),
    );

    await ai.generate(
      model: firebaseAI.gemini('gemini-2.5-flash'),
      prompt: 'Order a medium.',
      toolNames: ['placeOrder'],
    );

    final tools = client.requests.single.body['tools'] as List;
    final declaration =
        ((tools.single as Map)['functionDeclarations'] as List).single as Map;
    expect(declaration['name'], 'placeOrder');
    expect(declaration, isNot(contains('parameters')));
    final sent = declaration['parametersJsonSchema'] as Map;
    expect(sent[r'$ref'], r'#/$defs/Order');
    expect(
      (sent[r'$defs'] as Map)['Order'],
      (_inputSchema[r'$defs']! as Map)['Order'],
    );
  });
}
