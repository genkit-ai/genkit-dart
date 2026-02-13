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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_mcp/genkit_mcp.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

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

String _resolveStdioServerScript() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync()) {
      final contents = pubspec.readAsStringSync();
      if (contents.contains('name: genkit_workspace')) {
        final script = File(
          '${dir.path}${Platform.pathSeparator}'
          'packages${Platform.pathSeparator}'
          'genkit_mcp${Platform.pathSeparator}'
          'test${Platform.pathSeparator}'
          'stdio_test_server.dart',
        );
        if (!script.existsSync()) {
          throw StateError(
            'Failed to locate stdio test server script at ${script.path}',
          );
        }
        return script.path;
      }
    }
    if (dir.parent.path == dir.path) {
      throw StateError('Failed to locate genkit workspace root.');
    }
    dir = dir.parent;
  }
}

String _resolvePackageConfig() {
  var dir = Directory.current;
  while (true) {
    final config = File(
      '${dir.path}${Platform.pathSeparator}'
      '.dart_tool${Platform.pathSeparator}'
      'package_config.json',
    );
    if (config.existsSync()) return config.path;
    if (dir.parent.path == dir.path) {
      throw StateError('Failed to locate package_config.json.');
    }
    dir = dir.parent;
  }
}

void main() {
  test('HTTP/SSE end-to-end server and client', () async {
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
        return GenerateActionOptions(
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
    final transport = await StreamableHttpServerTransport.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    await server.start(transport);

    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(
          url: Uri.parse(
            'http://${transport.address.address}:${transport.port}/mcp',
          ),
        ),
      ),
    );
    await client.ready();

    final tools = await client.getActiveTools(Genkit());
    expect(tools, hasLength(1));
    final toolResult = await tools.first.call({'foo': 'bar'});
    expect(toolResult, 'yep bar');

    final prompts = await client.getActivePrompts(Genkit());
    expect(prompts, hasLength(1));
    final promptRequest = await prompts.first.call({'input': 'hello'});
    expect(
      promptRequest.messages.first.content.first.text,
      'prompt says: hello',
    );

    final resources = await client.getActiveResources(Genkit());
    expect(resources, hasLength(1));
    final resourceOutput = await resources.first.call(
      ResourceInput(uri: 'my://resource'),
    );
    expect(resourceOutput.content.first.toJson()['text'], 'my resource');

    await server.close();
  });

  test('stdio end-to-end server and client', () async {
    final serverScript = _resolveStdioServerScript();
    final packageConfig = _resolvePackageConfig();
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(
          command: Platform.resolvedExecutable,
          args: ['--packages=$packageConfig', serverScript],
        ),
      ),
    );

    try {
      await client.ready();

      final tools = await client.getActiveTools(Genkit());
      expect(tools, hasLength(1));
      final toolResult = await tools.first.call({'foo': 'bar'});
      expect(toolResult, 'yep bar');

      final prompts = await client.getActivePrompts(Genkit());
      expect(prompts, hasLength(1));
      final promptRequest = await prompts.first.call({'input': 'hello'});
      expect(
        promptRequest.messages.first.content.first.text,
        'prompt says: hello',
      );

      final resources = await client.getActiveResources(Genkit());
      expect(resources, hasLength(1));
      final resourceOutput = await resources.first.call(
        ResourceInput(uri: 'my://resource'),
      );
      expect(resourceOutput.content.first.toJson()['text'], 'my resource');
    } finally {
      await client.close();
    }
  });
}
