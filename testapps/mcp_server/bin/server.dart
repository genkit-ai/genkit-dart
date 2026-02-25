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
import 'package:mcp_server_sample/types.dart';

/// A simple MCP server that communicates over stdio (JSON-RPC via stdin/stdout).
///
/// Register this server in `mcp.json`:
/// ```json
/// "genkit-mcp-server": {
///   "command": "dart",
///   "args": ["run", "bin/server.dart"],
///   "cwd": "testapps/mcp_server"
/// }
/// ```
///
/// IMPORTANT: Do NOT write to stdout (e.g. print / stdout.writeln) in this
/// file. The stdio transport uses stdout exclusively for JSON-RPC messages.
/// Use stderr for any logging or debug output.
void main() async {
  final ai = Genkit();

  // --- Tools ---

  ai.defineTool<Map<String, dynamic>, String, void>(
    name: 'greet',
    description: 'Greets a user by name.',
    inputSchema: .map(.string(), .dynamicSchema()),
    fn: (input, _) async {
      final name = input['name']?.toString();
      return 'Hello, ${name ?? 'world'}!';
    },
  );

  ai.defineTool<Map<String, dynamic>, String, void>(
    name: 'add',
    description: 'Adds two numbers together.',
    inputSchema: .map(.string(), .dynamicSchema()),
    fn: (input, _) async {
      final a = (input['a'] as num?)?.toDouble() ?? 0;
      final b = (input['b'] as num?)?.toDouble() ?? 0;
      return '${a + b}';
    },
  );

  // --- Prompts ---

  ai.definePrompt<PromptInput>(
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

  // --- Resources ---

  ai.defineResource(
    name: 'info',
    uri: 'app://info',
    description: 'Returns basic server info.',
    fn: (_, _) async {
      return ResourceOutput(
        content: [
          TextPart(text: 'genkit-mcp-server is running (resource: app://info)'),
        ],
      );
    },
  );

  ai.defineResource(
    name: 'file',
    template: 'file://{path}',
    description: 'Returns the contents of a file (stub).',
    fn: (input, _) async {
      return ResourceOutput(
        content: [TextPart(text: 'file contents for ${input.uri}')],
      );
    },
  );

  // --- Start the MCP server over stdio ---

  final server = createMcpServer(
    ai,
    McpServerOptions(name: 'genkit-mcp-server', version: '0.0.1'),
  );

  // start() with no arguments defaults to StdioServerTransport.
  await server.start();

  // Log to stderr so it doesn't interfere with the JSON-RPC channel.
  stderr.writeln('[genkit-mcp-server] MCP server started (stdio).');
}
