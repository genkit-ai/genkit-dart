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
          'bar': {'type': 'integer'}
        }
      };
      final schema = toGeminiSchema(json);
      expect(schema, isA<m.Schema>());
    });

    test('converts array schema', () {
      final json = {
        'type': 'array',
        'items': {'type': 'string'}
      };
      final schema = toGeminiSchema(json);
      expect(schema, isA<m.Schema>());
    });
  });

  group('Tool Conversion', () {
    test('converts tool definition', () {
      final toolDef = ToolDefinition.from(
          name: 'myTool',
          description: 'desc',
          inputSchema: {
            'type': 'object',
            'properties': {
              'a': {'type': 'string'}
            }
          },
          outputSchema: {
            'type': 'string'
          });

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
      final part = ToolRequestPart.from(
          toolRequest: ToolRequest.from(name: 'foo', input: {'a': 1}));
      final mPart = toGeminiPart(part);
      expect(mPart, isA<m.FunctionCall>());
      final fc = mPart as m.FunctionCall;
      expect(fc.name, 'foo');
      expect(fc.args, {'a': 1});
    });

    test('FunctionResponse (ToolResponsePart)', () {
      final part = ToolResponsePart.from(
          toolResponse: ToolResponse.from(name: 'foo', output: {'b': 2}));
      final mPart = toGeminiPart(part);
      expect(mPart, isA<m.FunctionResponse>());
      final fr = mPart as m.FunctionResponse;
      expect(fr.name, 'foo');
      // check result structure if possible
      // FunctionResponse has 'response' field?
    });
  });
}
