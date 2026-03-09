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

import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/chat.dart'
    show buildOpenAIResponseFormat, isJsonStructuredOutput;
import 'package:openai_dart/openai_dart.dart' hide Model;
import 'package:test/test.dart';

JsonSchemaResponseFormat _jsonSchema(ResponseFormat format) {
  return format as JsonSchemaResponseFormat;
}

Map<String, dynamic> _createPersonSchema() {
  return {
    r'$defs': {
      'Person': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
        },
        'required': ['name', 'age'],
      },
    },
    'type': 'object',
    r'$ref': '#/\$defs/Person',
  };
}

void main() {
  group('OpenAIChatOptions', () {
    test('parses temperature', () {
      final options = OpenAIChatOptions.$schema.parse({'temperature': 0.7});
      expect(options.temperature, 0.7);
    });

    test('parses maxTokens', () {
      final options = OpenAIChatOptions.$schema.parse({'maxTokens': 100});
      expect(options.maxTokens, 100);
    });

    test('parses jsonMode', () {
      final options = OpenAIChatOptions.$schema.parse({'jsonMode': true});
      expect(options.jsonMode, true);
    });

    test('parses stop sequences', () {
      final options = OpenAIChatOptions.$schema.parse({
        'stop': ['stop1', 'stop2'],
      });
      expect(options.stop, ['stop1', 'stop2']);
    });

    test('creates default options', () {
      final options = OpenAIChatOptions();
      expect(options.temperature, isNull);
      expect(options.maxTokens, isNull);
    });
  });

  group('buildOpenAIResponseFormat', () {
    test('builds ResponseFormat from schema with \$defs', () {
      final result = buildOpenAIResponseFormat(_createPersonSchema());
      expect(result, isNotNull);
      final js = _jsonSchema(result!);
      expect(js.name, 'output');
      expect(js.schema['type'], 'object');
      expect(js.schema['additionalProperties'], false);
      expect(js.schema['properties'], isNotNull);
    });

    test('returns null only for null schema', () {
      expect(buildOpenAIResponseFormat(null), isNull);
    });

    test('builds ResponseFormat from schema without \$defs', () {
      final result = buildOpenAIResponseFormat({'type': 'object'});
      expect(result, isNotNull);
      final js = _jsonSchema(result!);
      expect(js.name, 'output');
      expect(js.schema['type'], 'object');
      expect(js.schema['additionalProperties'], false);
    });
  });

  group('isJsonStructuredOutput', () {
    test('true when format or contentType is json', () {
      expect(isJsonStructuredOutput('json', null), isTrue);
      expect(isJsonStructuredOutput(null, 'application/json'), isTrue);
    });

    test('false when neither set', () {
      expect(isJsonStructuredOutput(null, null), isFalse);
      expect(isJsonStructuredOutput('text', null), isFalse);
    });
  });
}
