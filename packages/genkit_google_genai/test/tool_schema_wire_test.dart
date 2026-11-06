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

Future<Map<String, dynamic>> _declarationFor(
  Map<String, dynamic>? inputSchema,
) async {
  final captured = <Map<String, dynamic>>[];
  final plugin = WirePlugin(captured);
  // A model pinned to generateContent (`-latest` names use Interactions).
  final action = plugin.resolve(.model, 'gemini-3.1-flash-lite') as Model;
  await action(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'Call the tool.')],
        ),
      ],
      tools: [
        ToolDefinition(
          name: 'anyTool',
          description: 'Takes anything',
          inputSchema: inputSchema,
        ),
      ],
    ),
  );
  final tools = captured.single['tools'] as List;
  final declarations =
      (tools.single as Map<String, dynamic>)['functionDeclarations'] as List;
  return declarations.single as Map<String, dynamic>;
}

void main() {
  group('tool input schema on the wire', () {
    test(
      'omits parametersJsonSchema for a schema that accepts any input',
      () async {
        final declaration = await _declarationFor({
          r'$schema': 'http://json-schema.org/draft-07/schema#',
        });
        expect(declaration['name'], 'anyTool');
        expect(declaration, isNot(contains('parametersJsonSchema')));
      },
    );

    test(
      'omits parametersJsonSchema when the tool has no input schema',
      () async {
        final declaration = await _declarationFor(null);
        expect(declaration, isNot(contains('parametersJsonSchema')));
      },
    );

    test('keeps a schema that constrains the input', () async {
      final schema = {
        'type': 'object',
        'properties': {
          'city': {'type': 'string'},
        },
      };
      final declaration = await _declarationFor(schema);
      expect(declaration['parametersJsonSchema'], schema);
    });
  });
}
