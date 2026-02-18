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

import 'package:firebase_ai/firebase_ai.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

void main() {
  group('Schema Conversion', () {
    test('converts simple string schema', () {
      final json = {'type': 'string', 'description': 'desc', 'nullable': true};
      final schema = toGeminiSchema(json);
      // We can't easily inspect properties of Schema if they are internal,
      // but we can check runtime type or usage.
      // FirebaseAI Schema doesn't expose fields easily for inspection in tests without dynamic or toString check?
      // Let's rely on it completing without error, and maybe check debug types if possible.
      expect(schema, isA<m.Schema>());
    });

    test('converts object schema', () {
      final json = {
        'type': 'object',
        'properties': {
          'foo': {'type': 'string'},
          'bar': {'type': 'integer'},
        },
      };
      final schema = toGeminiSchema(json);
      expect(schema, isA<m.Schema>());
    });

    test('converts array schema', () {
      final json = {
        'type': 'array',
        'items': {'type': 'string'},
      };
      final schema = toGeminiSchema(json);
      expect(schema, isA<m.Schema>());
    });

    test('flatten schemas with \$ref', () {
      final json = {
        "\$ref": "#/\$defs/WeatherToolInput",
        "\$defs": {
          "WeatherToolInput": {
            "type": "object",
            "properties": {
              "city": {
                "type": "string",
                "description": "The city to get the weather for",
              },
            },
            "required": ["city"],
          },
        },
        "\$schema": "http://json-schema.org/draft-07/schema#",
      };
      final schema = toGeminiSchema(json);
      expect(schema.toJson(), {
        'type': 'OBJECT',
        'nullable': false,
        'properties': {
          'city': {
            'type': 'STRING',
            'description': 'The city to get the weather for',
            'nullable': false,
          },
        },
        'required': ['city'],
      });
    });
  });

  group('Tool Conversion', () {
    test('converts tool definition', () {
      final toolDef = ToolDefinition(
        name: 'myTool',
        description: 'desc',
        inputSchema: {
          'type': 'object',
          'properties': {
            'a': {'type': 'string'},
          },
        },
        outputSchema: {'type': 'string'},
      );
      final mTools = toGeminiTools([toolDef]);
      expect(mTools, isNotNull);
      expect(mTools!.length, 1);
      final mTool = mTools.first;
      expect(mTool, isA<m.Tool>());
      expect(mTool.toJson(), {
        'functionDeclarations': [
          {
            'name': 'myTool',
            'description': 'desc',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'a': {'type': 'STRING', 'nullable': false},
              },
              'required': [],
            },
          },
        ],
      });
    });

    test('flattens schema', () {
      final toolDef = ToolDefinition(
        name: 'myTool',
        description: 'desc',
        inputSchema: {
          "\$ref": "#/\$defs/WeatherToolInput",
          "\$defs": {
            "WeatherToolInput": {
              "type": "object",
              "properties": {
                "city": {
                  "type": "string",
                  "description": "The city to get the weather for",
                },
              },
              "required": ["city"],
            },
          },
          "\$schema": "http://json-schema.org/draft-07/schema#",
        },
        outputSchema: {'type': 'string'},
      );
      final mTools = toGeminiTools([toolDef]);
      expect(mTools, isNotNull);
      expect(mTools!.length, 1);
      final mTool = mTools.first;
      expect(mTool, isA<m.Tool>());
      expect(mTool.toJson(), {
        'functionDeclarations': [
          {
            'name': 'myTool',
            'description': 'desc',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'city': {
                  'type': 'STRING',
                  'description': 'The city to get the weather for',
                  'nullable': false,
                },
              },
              'required': ['city'],
            },
          },
        ],
      });
    });
  });

  group('Part Conversion', () {
    test('FunctionCall (ToolRequestPart)', () {
      final part = ToolRequestPart(
        toolRequest: ToolRequest(name: 'foo', input: {'a': 1}),
      );
      final mPart = toGeminiPart(part);
      expect(mPart, isA<m.FunctionCall>());
      final fc = mPart as m.FunctionCall;
      expect(fc.name, 'foo');
      expect(fc.args, {'a': 1});
    });

    test('FunctionResponse (ToolResponsePart)', () {
      final part = ToolResponsePart(
        toolResponse: ToolResponse(name: 'foo', output: {'b': 2}),
      );
      final mPart = toGeminiPart(part);
      expect(mPart, isA<m.FunctionResponse>());
      final fr = mPart as m.FunctionResponse;
      expect(fr.name, 'foo');
      // check result structure if possible
      // FunctionResponse has 'response' field?
    });
  });

  group('Configuration Mapping', () {
    test('toGeminiSettings maps options', () {
      final options = GeminiOptions(
        temperature: 0.7,
        candidateCount: 2,
        maxOutputTokens: 100,
        topK: 10,
        topP: 0.9,
        responseMimeType: 'text/plain',
      );
      final jsonSchema = {'type': 'string'};
      final settings = toGeminiSettings(options, jsonSchema, false);

      expect(settings.temperature, 0.7);
      expect(settings.candidateCount, 2);
      expect(settings.maxOutputTokens, 100);
      expect(settings.topK, 10);
      expect(settings.topP, 0.9);
      expect(settings.responseMimeType, 'text/plain');
      expect(settings.responseSchema, isNotNull);
    });

    test('toGeminiSettings overrides mimeType for JSON mode', () {
      final options = GeminiOptions(temperature: 0.5);
      final settings = toGeminiSettings(options, null, true);
      expect(settings.responseMimeType, 'application/json');
    });

    test('toGeminiToolConfig maps to AUTO by default', () {
      final config = toGeminiToolConfig(null);
      expect(config, isNull);

      final autoConfig = toGeminiToolConfig(
        FunctionCallingConfig(mode: 'AUTO'),
      );
      expect(
        autoConfig?.functionCallingConfig?.mode,
        m.FunctionCallingMode.auto,
      );
    });

    test('toGeminiToolConfig maps to ANY with allowed functions', () {
      final config = toGeminiToolConfig(
        FunctionCallingConfig(
          mode: 'ANY',
          allowedFunctionNames: ['getWeather'],
        ),
      );
      expect(config?.functionCallingConfig?.mode, m.FunctionCallingMode.any);
      expect(
        config?.functionCallingConfig?.allowedFunctionNames?.contains(
          'getWeather',
        ),
        isTrue,
      );
    });
  });
}
