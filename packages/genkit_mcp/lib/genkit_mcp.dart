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

/// MCP (Model Context Protocol) integration for Genkit Dart.
///
/// Use this library to connect Genkit to MCP servers as a client or host,
/// or to expose Genkit tools, prompts, and resources as an MCP server.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart';

import 'src/client/mcp_client.dart';
import 'src/client/mcp_host.dart';
import 'src/server/mcp_server.dart';

export 'src/client/mcp_client.dart'
    show
        GenkitMcpClient,
        McpClientOptions,
        McpClientOptionsWithCache,
        McpClientPlugin,
        McpElicitationHandler,
        McpNotificationHandler,
        McpRoot,
        McpSamplingHandler,
        McpServerConfig;
export 'src/client/mcp_host.dart'
    show GenkitMcpHost, McpHostOptions, McpHostOptionsWithCache, McpHostPlugin;
export 'src/client/transports/streamable_http_transport.dart'
    show StreamableHttpClientTransport;
export 'src/server/mcp_server.dart' show GenkitMcpServer, McpServerOptions;
export 'src/server/transports/server_transport.dart' show McpServerTransport;
export 'src/server/transports/streamable_http_transport.dart'
    show StreamableHttpServerTransport;

/// Creates an MCP server that exposes all tools, prompts, and resources
/// registered in [ai] over the Model Context Protocol.
GenkitMcpServer createMcpServer(Genkit ai, McpServerOptions options) {
  return GenkitMcpServer(ai, options);
}

/// Creates an MCP client that connects to a single MCP server.
GenkitMcpClient createMcpClient(McpClientOptions options) {
  return GenkitMcpClient(options);
}

/// Creates an MCP host that manages connections to multiple MCP servers.
GenkitMcpHost createMcpHost(McpHostOptions options) {
  return GenkitMcpHost(options);
}

/// Creates an MCP client and registers it as a [GenkitPlugin] so that
/// tools, prompts, and resources are discoverable through [ai]'s registry.
GenkitMcpClient defineMcpClient(Genkit ai, McpClientOptionsWithCache options) {
  final client = GenkitMcpClient(options);
  final plugin = McpClientPlugin(
    client: client,
    cacheTtlMillis: options.cacheTtlMillis,
  );
  ai.registry.registerPlugin(plugin);
  return client;
}

/// Creates an MCP host and registers it as a [GenkitPlugin] so that
/// tools, prompts, and resources from all connected servers are
/// discoverable through [ai]'s registry.
GenkitMcpHost defineMcpHost(Genkit ai, McpHostOptionsWithCache options) {
  final host = GenkitMcpHost(options);
  final plugin = McpHostPlugin(
    host: host,
    cacheTtlMillis: options.cacheTtlMillis,
  );
  host.plugin = plugin;
  ai.registry.registerPlugin(plugin);
  return host;
}
