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
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

final class _PromptInputSchema extends SchemanticType<Map<String, dynamic>> {
  const _PromptInputSchema();

  @override
  Map<String, dynamic> parse(dynamic input) {
    return input as Map<String, dynamic>;
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: {
      'type': 'object',
      'properties': {
        'input': {'type': 'string'},
      },
      'required': ['input'],
    },
    dependencies: const [],
  );
}

String _resolveTestScript(String name) {
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
          'test${Platform.pathSeparator}$name',
        );
        if (!script.existsSync()) {
          throw StateError('Failed to locate test script at ${script.path}');
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
    ai.defineTool<Map<String, dynamic>, String>(
      name: 'testTool',
      description: 'test tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (input, _) async => 'yep ${input['foo']}',
    );
    ai.defineCustomPrompt<Map<String, dynamic>>(
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
    final serverScript = _resolveTestScript('stdio_test_server.dart');
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

  test(
    'native mcp_dart client interoperates with Genkit HTTP server',
    () async {
      final ai = Genkit();
      ai.defineTool<Map<String, dynamic>, String>(
        name: 'echo',
        description: 'echo tool',
        inputSchema: .map(.string(), .dynamicSchema()),
        fn: (input, _) async => 'genkit ${input['value']}',
      );
      final server = GenkitMcpServer(
        ai,
        McpServerOptions(name: 'genkit-test-server', version: '0.0.1'),
      );
      final transport = await StreamableHttpServerTransport.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        enableJsonResponse: true,
      );
      await server.start(transport);

      final nativeClient = mcp.McpClient(
        const mcp.Implementation(name: 'mcp-dart-client', version: '0.0.1'),
      );
      try {
        await nativeClient.connect(
          mcp.StreamableHttpClientTransport(
            Uri.parse(
              'http://${transport.address.address}:${transport.port}/mcp',
            ),
          ),
        );

        final tools = await nativeClient.listTools();
        expect(tools.tools.map((tool) => tool.name), contains('echo'));
        final result = await nativeClient.callTool(
          const mcp.CallToolRequest(
            name: 'echo',
            arguments: {'value': 'works'},
          ),
        );
        expect((result.content.single as mcp.TextContent).text, 'genkit works');
      } finally {
        await nativeClient.close();
        await server.close();
      }
    },
  );

  test(
    'Genkit client interoperates with native mcp_dart stdio server',
    () async {
      final serverScript = _resolveTestScript(
        'mcp_dart_stdio_test_server.dart',
      );
      final packageConfig = _resolvePackageConfig();
      final client = GenkitMcpClient(
        McpClientOptions(
          name: 'genkit-test-client',
          mcpServer: McpServerConfig(
            command: Platform.resolvedExecutable,
            args: ['--packages=$packageConfig', serverScript],
          ),
        ),
      );

      try {
        await client.ready();
        expect(client.serverName, 'mcp-dart-test-server');
        final tools = await client.getActiveTools(Genkit());
        expect(tools, hasLength(1));
        expect(await tools.single.call({'value': 'works'}), 'native works');
      } finally {
        await client.close();
      }
    },
  );
}
