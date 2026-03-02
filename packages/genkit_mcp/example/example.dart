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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_mcp/genkit_mcp.dart';

import 'types.dart';

// This example demonstrates all three components:
// - GenkitMcpServer: expose Genkit actions via MCP
// - GenkitMcpClient: connect to an MCP server and consume actions
// - GenkitMcpHost: manage multiple MCP servers and aggregate actions
//
// To run:
//   cd packages/genkit_mcp
//   dart run example/example.dart

Future<void> main() async {
  // ----------------------------
  // 1) Start an MCP server
  // ----------------------------
  final serverAi = Genkit();

  serverAi.defineTool<GreetInput, String>(
    name: 'greet',
    description: 'Greets a user by name.',
    inputSchema: GreetInput.$schema,
    fn: (input, _) async {
      return 'Hello, ${input.name}!';
    },
  );

  serverAi.definePrompt<PromptInput>(
    name: 'echoPrompt',
    description: 'Returns a simple prompt with one user message.',
    inputSchema: PromptInput.$schema,
    fn: (input, _) async {
      return GenerateActionOptions(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'prompt says: ${input.input}')],
          ),
        ],
      );
    },
  );

  serverAi.defineResource(
    name: 'info',
    uri: 'app://info',
    fn: (_, _) async {
      return ResourceOutput(
        content: [
          TextPart(text: 'Hello from genkit_mcp (resource: app://info)'),
        ],
      );
    },
  );

  serverAi.defineResource(
    name: 'file',
    template: 'file://{path}',
    fn: (input, _) async {
      return ResourceOutput(
        content: [TextPart(text: 'file contents for ${input.uri}')],
      );
    },
  );

  serverAi.defineTool<Map<String, dynamic>, String>(
    name: 'slowEcho',
    description: 'A slow tool to demonstrate tasks.',
    inputSchema: .map(.string(), .dynamicSchema()),
    fn: (input, _) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return 'slow: ${input['value'] ?? ''}';
    },
  );

  final server = createMcpServer(
    serverAi,
    McpServerOptions(name: 'example-server', version: '0.0.1'),
  );
  final transport = await StreamableHttpServerTransport.bind(
    address: InternetAddress.loopbackIPv4,
    port: 0,
  );
  final serverUrl = Uri.parse(
    'http://${transport.address.address}:${transport.port}/mcp',
  );

  await server.start(transport);
  stdout.writeln('[server] listening on $serverUrl');

  GenkitMcpClient? client;
  GenkitMcpHost? host;

  try {
    // ----------------------------
    // 2) Connect via MCP client
    // ----------------------------
    client = createMcpClient(
      McpClientOptions(
        name: 'example-client',
        mcpServer: McpServerConfig(url: serverUrl),
        notificationHandler: (method, params) {
          // Optional: observe server notifications (tasks/progress/resources/etc.)
          if (method.startsWith('notifications/')) {
            stdout.writeln('[client][notify] $method ${_safeJson(params)}');
          }
        },
      ),
    );
    await client.ready();
    stdout.writeln('[client] connected (serverName=${client.serverName})');

    final clientAi = Genkit();

    final tools = await client.getActiveTools(clientAi);
    stdout.writeln('[client] tools: ${tools.map((t) => t.name).toList()}');

    final greetTool = tools.firstWhere((t) => t.name.endsWith('/greet'));
    final greetResult = await greetTool.call({'name': 'Dart'});
    stdout.writeln('[client] greet => $greetResult');

    final prompts = await client.getActivePrompts(clientAi);
    stdout.writeln('[client] prompts: ${prompts.map((p) => p.name).toList()}');
    final prompt = prompts.firstWhere(
      (p) => p.name == 'example-client/echoPrompt',
    );
    final request = await prompt.call({'input': 'hello'});
    stdout.writeln(
      '[client] echoPrompt => ${request.messages.first.content.first.text}',
    );

    final resources = await client.getActiveResources(clientAi);
    stdout.writeln(
      '[client] resources: ${resources.map((r) => r.name).toList()}',
    );

    final info = resources.firstWhere((r) => r.name.endsWith('/info'));
    final infoOut = await info.call(ResourceInput(uri: 'app://info'));
    stdout.writeln(
      '[client] read app://info => ${infoOut.content.first.toJson()['text']}',
    );

    final file = resources.firstWhere((r) => r.name.endsWith('/file'));
    final fileOut = await file.call(ResourceInput(uri: 'file://hello.txt'));
    stdout.writeln(
      '[client] read file://hello.txt => ${fileOut.content.first.toJson()['text']}',
    );

    // Demonstrate tasks: request tool execution as a task and poll the result.
    final taskCall = await client.callTool(
      name: 'slowEcho',
      arguments: {'value': 'task'},
      task: {},
    );
    final task = (taskCall['task'] as Map?)?.cast<String, dynamic>();
    final taskId = task?['taskId']?.toString();
    stdout.writeln(
      '[client] slowEcho taskId=$taskId status=${task?['status']}',
    );

    if (taskId != null) {
      // Wait briefly then fetch the result.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final taskResult = await client.getTaskResult(taskId);
      final contentList = taskResult['content'];
      Object? content;
      if (contentList is List && contentList.isNotEmpty) {
        content = contentList.first;
      }
      stdout.writeln('[client] slowEcho result => $content');
    }

    // ----------------------------
    // 3) Connect via MCP host
    // ----------------------------
    final hostAi = Genkit(plugins: [googleAI()]);

    // Create the MCP host which will automatically register tools.
    host = defineMcpHost(
      hostAi,
      McpHostOptionsWithCache(
        name: 'example-host',
        mcpServers: {'local': McpServerConfig(url: serverUrl)},
      ),
    );

    // Wait until the the MCP server finishes initialization
    await host.getClient('local')?.ready();

    // The tools are automatically discovered via the DAP wildcard syntax
    // and injected into generate by Genkit.
    try {
      final response = await hostAi.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: 'Say hello to Dart using the local tool.',
        toolNames: ['example-host:tool/local/*'],
      );
      stdout.writeln('[host] ai.generate output: \n${response.text}');
    } catch (e) {
      stdout.writeln('[host] generation error: $e');
    }
  } finally {
    await host?.close();
    await client?.close();
    await server.close();
  }
}

String _safeJson(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}
