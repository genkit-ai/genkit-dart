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

import 'package:mcp_dart/mcp_dart.dart';

Future<void> main() async {
  final server = McpServer(
    const Implementation(name: 'mcp-dart-test-server', version: '0.0.1'),
    options: const McpServerOptions(
      capabilities: ServerCapabilities(tools: ServerCapabilitiesTools()),
    ),
  );
  server.registerTool(
    'echo',
    description: 'Echoes a value through a native mcp_dart server.',
    inputSchema: JsonSchema.object(
      properties: {'value': JsonSchema.string()},
      required: ['value'],
    ),
    callback: (arguments, extra) async => CallToolResult.fromContent([
      TextContent(text: 'native ${arguments['value']}'),
    ]),
  );

  await server.connect(StdioServerTransport());
}
