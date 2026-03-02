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

import 'package:genkit/genkit.dart';

import '../util/logging.dart';
import 'mcp_client.dart';

/// Options for a [GenkitMcpHost] instance.
class McpHostOptions {
  /// Client name advertised to connected servers. Defaults to `'genkit-mcp'`.
  final String? name;
  final String? version;

  /// Map of server names to their configurations.
  final Map<String, McpServerConfig>? mcpServers;

  /// When `true`, tool results are returned as raw MCP maps.
  final bool rawToolResponses;

  /// Roots advertised to all servers unless overridden per-server.
  final List<McpRoot>? roots;

  const McpHostOptions({
    this.name,
    this.version,
    this.mcpServers,
    this.rawToolResponses = false,
    this.roots,
  });
}

/// [McpHostOptions] with an additional [cacheTtlMillis] for the
/// registry plugin created by `defineMcpHost`.
class McpHostOptionsWithCache extends McpHostOptions {
  final int? cacheTtlMillis;

  const McpHostOptionsWithCache({
    required super.name,
    this.cacheTtlMillis,
    super.version,
    super.mcpServers,
    super.rawToolResponses,
    super.roots,
  });
}

/// Manages connections to multiple MCP servers and aggregates their
/// tools, prompts, and resources.
class GenkitMcpHost {
  final String name;
  final String? version;
  final bool rawToolResponses;
  final List<McpRoot>? roots;
  final McpHostOptions options;

  final Map<String, GenkitMcpClient> _clients = {};
  final Map<String, _ClientState> _clientStates = {};
  final List<Completer<void>> _readyListeners = [];
  bool _ready = false;

  GenkitMcpHost(this.options)
    : name = options.name ?? 'genkit-mcp',
      version = options.version,
      rawToolResponses = options.rawToolResponses,
      roots = options.roots {
    if (options.mcpServers != null) {
      updateServers(options.mcpServers!);
    } else {
      _ready = true;
    }
  }

  Future<void> ready() {
    if (_ready) return Future.value();
    final completer = Completer<void>();
    _readyListeners.add(completer);
    return completer.future;
  }

  Future<void> connect(String serverName, McpServerConfig config) async {
    final existing = _clients[serverName];
    if (existing != null) {
      try {
        await existing.close();
      } catch (e) {
        existing.disable();
        _setError(
          serverName,
          message:
              '[MCP Host] Error disconnecting from existing connection for $serverName',
          detail: e,
        );
      }
    }

    mcpLogger.fine(
      '[MCP Host] Connecting to MCP server "$serverName" in host "$name".',
    );
    try {
      final client = GenkitMcpClient(
        McpClientOptions(
          name: name,
          serverName: serverName,
          version: version,
          rawToolResponses: rawToolResponses,
          notificationHandler: (method, _) {
            // Caching is handled entirely by the client now.
          },
          mcpServer: McpServerConfig(
            transport: config.transport,
            command: config.command,
            args: config.args,
            environment: config.environment,
            url: config.url,
            headers: config.headers,
            timeout: config.timeout,
            disabled: config.disabled,
            roots: config.roots ?? roots,
          ),
        ),
      );
      _clients[serverName] = client;
    } catch (e) {
      _setError(
        serverName,
        message:
            '[MCP Host] Error connecting to $serverName with config $config',
        detail: e,
      );
    }
  }

  Future<void> disconnect(String serverName) async {
    final client = _clients[serverName];
    if (client == null) {
      mcpLogger.warning('[MCP Host] Unable to find server $serverName.');
      return;
    }
    mcpLogger.fine(
      '[MCP Host] Disconnecting MCP server "$serverName" in host "$name".',
    );
    try {
      await client.close();
    } catch (e) {
      client.disable();
      _setError(
        serverName,
        message:
            '[MCP Host] Error disconnecting from existing connection for $serverName',
        detail: e,
      );
    }
    _clients.remove(serverName);
  }

  Future<void> disable(String serverName) async {
    final client = _clients[serverName];
    if (client == null) {
      mcpLogger.warning('[MCP Host] Unable to find server $serverName.');
      return;
    }
    if (!client.isEnabled()) {
      mcpLogger.warning('[MCP Host] Server $serverName already disabled.');
      return;
    }
    mcpLogger.fine(
      '[MCP Host] Disabling MCP server "$serverName" in host "$name".',
    );
    await client.disable();
  }

  Future<void> enable(String serverName) async {
    final client = _clients[serverName];
    if (client == null) {
      mcpLogger.warning('[MCP Host] Unable to find server $serverName.');
      return;
    }
    mcpLogger.fine(
      '[MCP Host] Re-enabling MCP server "$serverName" in host "$name".',
    );
    try {
      await client.enable();
    } catch (e) {
      client.disable();
      _setError(
        serverName,
        message: '[MCP Host] Error reenabling server $serverName',
        detail: e,
      );
    }
  }

  Future<void> reconnect(String serverName) async {
    final client = _clients[serverName];
    if (client == null) {
      mcpLogger.warning('[MCP Host] Unable to find server $serverName.');
      return;
    }
    mcpLogger.fine(
      '[MCP Host] Restarting MCP server "$serverName" in host "$name".',
    );
    try {
      await client.restart();
    } catch (e) {
      client.disable();
      _setError(
        serverName,
        message: '[MCP Host] Error restarting server $serverName',
        detail: e,
      );
    }
  }

  void updateServers(Map<String, McpServerConfig> mcpServers) {
    _ready = false;
    final newServers = mcpServers.keys.toSet();
    final currentServers = _clients.keys.toSet();
    final futures = <Future<void>>[];

    for (final entry in mcpServers.entries) {
      futures.add(connect(entry.key, entry.value));
    }
    for (final serverName in currentServers) {
      if (!newServers.contains(serverName)) {
        disconnect(serverName);
      }
    }

    Future.wait(futures)
        .then((_) {
          _ready = true;
          while (_readyListeners.isNotEmpty) {
            _readyListeners.removeLast().complete();
          }
        })
        .catchError((Object error) {
          while (_readyListeners.isNotEmpty) {
            _readyListeners.removeLast().completeError(error);
          }
        });
  }

  Future<List<Tool<Map<String, dynamic>, dynamic>>> getActiveTools(
    Genkit ai,
  ) async {
    await ready();
    final allTools = <Tool<Map<String, dynamic>, dynamic>>[];
    for (final entry in _clients.entries) {
      final serverName = entry.key;
      final client = entry.value;
      if (client.isEnabled() && !_hasError(serverName)) {
        try {
          allTools.addAll(await client.getActiveTools(ai));
        } catch (e) {
          mcpLogger.warning(
            '[MCP Host] Error fetching tools for $serverName: $e',
          );
        }
      }
    }
    return allTools;
  }

  Future<List<ResourceAction>> getActiveResources(Genkit ai) async {
    await ready();
    final allResources = <ResourceAction>[];
    for (final entry in _clients.entries) {
      final serverName = entry.key;
      final client = entry.value;
      if (client.isEnabled() && !_hasError(serverName)) {
        try {
          allResources.addAll(await client.getActiveResources(ai));
        } catch (e) {
          mcpLogger.warning(
            '[MCP Host] Error fetching resources for $serverName: $e',
          );
        }
      }
    }
    return allResources;
  }

  Future<List<PromptAction<Map<String, dynamic>>>> getActivePrompts(
    Genkit ai,
  ) async {
    await ready();
    final allPrompts = <PromptAction<Map<String, dynamic>>>[];
    for (final entry in _clients.entries) {
      final serverName = entry.key;
      final client = entry.value;
      if (client.isEnabled() && !_hasError(serverName)) {
        try {
          allPrompts.addAll(await client.getActivePrompts(ai));
        } catch (e) {
          mcpLogger.warning(
            '[MCP Host] Error fetching prompts for $serverName: $e',
          );
        }
      }
    }
    return allPrompts;
  }

  Future<PromptAction<Map<String, dynamic>>?> getPrompt(
    Genkit ai,
    String serverName,
    String promptName,
  ) async {
    await ready();
    final client = _clients[serverName];
    if (client == null) {
      mcpLogger.warning('[MCP Host] No client found for $serverName.');
      return null;
    }
    if (_hasError(serverName)) {
      mcpLogger.warning(
        '[MCP Host] Client "$serverName" is in an error state.',
      );
    }
    if (client.isEnabled()) {
      return client.getPrompt(ai, promptName);
    }
    return null;
  }

  Future<void> close() async {
    for (final client in _clients.values) {
      await client.close();
    }
  }

  Iterable<GenkitMcpClient> get activeClients {
    return _clients.values.where((c) => c.isEnabled());
  }

  GenkitMcpClient? getClient(String name) => _clients[name];

  int? get cacheTtlMillis => options is McpHostOptionsWithCache
      ? (options as McpHostOptionsWithCache).cacheTtlMillis
      : null;

  Future<List<ActionMetadata>> getCachedActions() async {
    final futures = activeClients.map((client) => client.getCachedActions());
    final results = await Future.wait(futures);
    return results.expand((actions) => actions).toList();
  }

  Action? resolveAction(String actionName) {
    for (final client in activeClients) {
      final action = client.resolveAction(actionName);
      if (action != null) {
        return action;
      }
    }
    return null;
  }

  void _setError(String serverName, {required String message, Object? detail}) {
    _clientStates[serverName] = _ClientState(
      error: _ClientError(message: message, detail: detail),
    );
    mcpLogger.warning(
      'An error occurred while managing MCP client "$serverName".',
    );
    mcpLogger.warning(message);
    if (detail != null) {
      mcpLogger.warning(detail);
    }
  }

  bool _hasError(String serverName) {
    return _clientStates[serverName]?.error != null;
  }
}

class _ClientState {
  final _ClientError? error;

  _ClientState({this.error});
}

class _ClientError {
  final String message;
  final Object? detail;

  _ClientError({required this.message, this.detail});
}
