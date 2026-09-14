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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

import 'test_harness.dart';

const _schema = {
  'type': 'object',
  'properties': {
    'answer': {'type': 'string'},
  },
};

Future<Map<String, dynamic>> _generationConfigOnTheWire({
  OutputConfig? output,
  Map<String, dynamic>? config,
  String model = 'gemini-2.0-flash',
}) async {
  final captured = <Map<String, dynamic>>[];
  final plugin = WirePlugin(captured);
  final action = plugin.resolve(.model, model) as Model;
  await action(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ],
      config: config,
      output: output,
    ),
  );
  return (captured.single['generationConfig'] as Map).cast<String, dynamic>();
}

void main() {
  group('generationConfig on the wire', () {
    test('text-mode request with an output schema sends no '
        'responseJsonSchema', () async {
      final config = await _generationConfigOnTheWire(
        output: OutputConfig(
          format: 'text',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('request without output omits responseMimeType entirely', () async {
      final config = await _generationConfigOnTheWire();
      expect(config, isNot(contains('responseMimeType')));
    });

    test('JSON-mode unconstrained request sends mime type but no '
        'schema', () async {
      final config = await _generationConfigOnTheWire(
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: false,
        ),
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('JSON-mode constrained request sends application/json and the '
        'schema', () async {
      final config = await _generationConfigOnTheWire(
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], _schema);
    });

    test('TTS model text-mode request with an output schema sends no '
        'responseJsonSchema', () async {
      final config = await _generationConfigOnTheWire(
        model: 'gemini-2.5-flash-preview-tts',
        output: OutputConfig(
          format: 'text',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('TTS model JSON-mode unconstrained request sends no '
        'responseJsonSchema', () async {
      final config = await _generationConfigOnTheWire(
        model: 'gemini-2.5-flash-preview-tts',
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: false,
        ),
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('TTS model JSON-mode constrained request sends the '
        'schema', () async {
      final config = await _generationConfigOnTheWire(
        model: 'gemini-2.5-flash-preview-tts',
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config['responseJsonSchema'], _schema);
    });

    test('non-JSON mode passes a user-configured responseMimeType '
        'through', () async {
      final config = await _generationConfigOnTheWire(
        config: {'responseMimeType': 'text/x-foo'},
        output: OutputConfig(format: 'text'),
      );
      expect(config['responseMimeType'], 'text/x-foo');
    });

    test('contentType application/json alone selects JSON mode and sends '
        'the schema', () async {
      final config = await _generationConfigOnTheWire(
        output: OutputConfig(
          contentType: 'application/json',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], _schema);
    });

    test('full Genkit generate with outputSchema sends schema and '
        'application/json', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [WirePlugin(captured)],
        promptDir: null,
        isDevEnv: false,
      );
      addTearDown(ai.shutdown);
      await ai.generate(
        model: modelRef('googleai/gemini-2.0-flash'),
        prompt: 'hello',
        outputSchema: .string(),
      );
      final config = (captured.single['generationConfig'] as Map)
          .cast<String, dynamic>();
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], isNotNull);
    });
  });
}
