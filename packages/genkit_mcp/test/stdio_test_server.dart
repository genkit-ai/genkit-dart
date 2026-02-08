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

import 'dart:async';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_mcp/genkit_mcp.dart';
import 'package:genkit_mcp/src/server/transports/stdio_transport.dart';
import 'package:schemantic/schemantic.dart';

class _PromptInputSchema extends SchemanticType<Map<String, dynamic>> {
  const _PromptInputSchema();

  @override
  Map<String, dynamic> parse(dynamic input) {
    return input as Map<String, dynamic>;
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: Schema.fromMap({
      'type': 'object',
      'properties': {
        'input': {'type': 'string'},
      },
      'required': ['input'],
    }),
    dependencies: const [],
  );
}

Future<void> main() async {
  final ai = Genkit();
  ai.defineTool<Map<String, dynamic>, String, void>(
    name: 'testTool',
    description: 'test tool',
    inputSchema: mapSchema(stringSchema(), dynamicSchema()),
    fn: (input, _) async => 'yep ${input['foo']}',
  );
  ai.definePrompt<Map<String, dynamic>>(
    name: 'testPrompt',
    description: 'test prompt',
    inputSchema: const _PromptInputSchema(),
    fn: (input, _) async {
      return GenerateRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'prompt says: ${input['input']}')],
          ),
        ],
      );
    },
  );
  ai.defineResource(
    name: 'testResource',
    uri: 'my://resource',
    fn: (_, _) async {
      return ResourceOutput(content: [TextPart(text: 'my resource')]);
    },
  );

  final server = GenkitMcpServer(
    ai,
    McpServerOptions(name: 'test-server', version: '0.0.1'),
  );
  await server.start(StdioServerTransport());

  final completer = Completer<void>();
  void handleSignal(ProcessSignal _) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  ProcessSignal.sigterm.watch().listen(handleSignal);
  ProcessSignal.sigint.watch().listen(handleSignal);

  await completer.future;
  await server.close();
}
