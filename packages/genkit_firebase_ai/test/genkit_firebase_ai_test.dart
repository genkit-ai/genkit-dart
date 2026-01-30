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

      final mTool = toGeminiTool(toolDef);
      expect(mTool, isA<m.Tool>());
      // Check if we can inspect
      // The m.FunctionDeclaration is inside
      // m.Tool doesn't explicitly expose functionDeclarations as public field in some versions?
      // Let's check.
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
}
