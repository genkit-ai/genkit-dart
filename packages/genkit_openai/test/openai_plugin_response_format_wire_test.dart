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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

/// Captures every chat-completions body so tests can assert on the actual
/// `response_format` sent, rather than on the helper in isolation.
MockClient wireClient(List<Map<String, dynamic>> capturedBodies) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'gpt-4o',
              'object': 'model',
              'created': 0,
              'owned_by': 'openai',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith('/chat/completions')) {
      capturedBodies.add(
        (jsonDecode(request.body) as Map).cast<String, dynamic>(),
      );
      return http.Response(
        jsonEncode({
          'id': 'chatcmpl-test',
          'object': 'chat.completion',
          'created': 0,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': '{"title":"ok"}'},
              'finish_reason': 'stop',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
}

Genkit wireGenkit(List<Map<String, dynamic>> captured) => Genkit(
  plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
);

Map<String, dynamic>? responseFormatOf(Map<String, dynamic> body) =>
    (body['response_format'] as Map?)?.cast<String, dynamic>();

void main() {
  group('response_format on the wire', () {
    test('schemaless json output sends json_object', () async {
      // The regression #359 is about: this previously sent no
      // response_format at all, and Genkit emits no prompt instructions
      // without a schema either - so nothing asked for JSON.
      final captured = <Map<String, dynamic>>[];
      final ai = wireGenkit(captured);

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Give me an object with a title.',
        outputFormat: 'json',
      );

      expect(responseFormatOf(captured.single), {'type': 'json_object'});

      await ai.shutdown();
    });

    test('a schema sends json_schema with strict false', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = wireGenkit(captured);

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Describe a book.',
        outputSchema: _bookSchema,
      );

      final format = responseFormatOf(captured.single)!;
      expect(format['type'], 'json_schema');
      final jsonSchema = (format['json_schema'] as Map).cast<String, dynamic>();
      expect(jsonSchema['name'], 'output');
      expect(
        jsonSchema['strict'],
        isFalse,
        reason: 'strict rejects schemas with optional fields',
      );

      await ai.shutdown();
    });

    test('an optional field reaches the wire unmodified', () async {
      // Under the old strict:true path OpenAI rejected this outright, because
      // strict requires every property to appear in `required`.
      final captured = <Map<String, dynamic>>[];
      final ai = wireGenkit(captured);

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Describe a book.',
        outputSchema: _bookSchema,
      );

      final schema =
          ((responseFormatOf(captured.single)!['json_schema'] as Map)['schema']
                  as Map)
              .cast<String, dynamic>();

      expect(schema['required'], ['title']);
      expect((schema['properties'] as Map).containsKey('year'), isTrue);
      expect(
        schema.containsKey('additionalProperties'),
        isFalse,
        reason: 'the plugin must not mutate the caller schema',
      );

      await ai.shutdown();
    });

    test('jsonMode forces json_object without an output config', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = wireGenkit(captured);

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Reply in JSON.',
        config: OpenAIChatOptions(jsonMode: true),
      );

      expect(responseFormatOf(captured.single), {'type': 'json_object'});

      await ai.shutdown();
    });

    test('a plain request sends no response_format at all', () async {
      // Compatible hosts that reject the field must keep working.
      final captured = <Map<String, dynamic>>[];
      final ai = wireGenkit(captured);

      await ai.generate(model: openAI.model('gpt-4o'), prompt: 'Hello.');

      expect(captured.single.containsKey('response_format'), isFalse);

      await ai.shutdown();
    });
  });
}

/// A schema with an optional field (`year`) and a nested object.
///
/// `year` is deliberately absent from `required`, which is exactly what
/// schemantic generates for a nullable field - and exactly what OpenAI's
/// strict mode rejects.
final _bookSchema = SchemanticType.from<Map<String, Object?>>(
  jsonSchema: {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'year': {'type': 'integer'},
      'author': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
        'required': ['name'],
      },
    },
    'required': ['title'],
  },
  parse: (json) => (json as Map).cast<String, Object?>(),
);
