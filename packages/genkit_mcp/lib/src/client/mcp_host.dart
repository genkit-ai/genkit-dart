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
import 'package:genkit/plugin.dart';

import '../util/common.dart';
import '../util/convert_messages.dart';
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

  final Map<String, GenkitMcpClient> _clients = {};
  final Map<String, _ClientState> _clientStates = {};
  final List<Completer<void>> _readyListeners = [];
  bool _ready = false;
  McpHostPlugin? _plugin;

  GenkitMcpHost(McpHostOptions options)
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

  set plugin(McpHostPlugin plugin) {
    _plugin = plugin;
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
            if (method == 'notifications/tools/list_changed' ||
                method == 'notifications/prompts/list_changed' ||
                method == 'notifications/resources/list_changed') {
              _invalidateCache();
            }
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
    _invalidateCache();
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
    _invalidateCache();
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
    _invalidateCache();
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
    _invalidateCache();
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
    _invalidateCache();
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
        .catchError((error) {
          while (_readyListeners.isNotEmpty) {
            _readyListeners.removeLast().completeError(error);
          }
        });

    _invalidateCache();
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
    _invalidateCache();
  }

  Iterable<GenkitMcpClient> get activeClients {
    return _clients.values.where((c) => c.isEnabled());
  }

  GenkitMcpClient? getClient(String name) => _clients[name];

  void _invalidateCache() {
    _plugin?.invalidateCache();
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

class McpHostPlugin extends GenkitPlugin {
  final GenkitMcpHost host;
  final int? cacheTtlMillis;
  final Map<String, _McpActionDescriptor> _actionIndex = {};
  List<ActionMetadata> _cachedActions = [];
  DateTime? _cacheExpiresAt;
  Future<List<ActionMetadata>>? _inflight;

  McpHostPlugin({required this.host, this.cacheTtlMillis});

  @override
  String get name => host.name;

  void invalidateCache() {
    _cachedActions = [];
    _cacheExpiresAt = null;
    _actionIndex.clear();
  }

  @override
  Future<List<ActionMetadata>> list() async {
    final now = DateTime.now();
    if (_shouldUseCache() &&
        _cacheExpiresAt != null &&
        now.isBefore(_cacheExpiresAt!) &&
        _cachedActions.isNotEmpty) {
      return _cachedActions;
    }
    if (_inflight != null) return _inflight!;
    _inflight = _buildCache();
    try {
      return await _inflight!;
    } finally {
      _inflight = null;
    }
  }

  @override
  Action? resolve(String actionType, String name) {
    final descriptor = _actionIndex[_descriptorKey(actionType, name)];
    if (descriptor == null) return null;
    final client = host.getClient(descriptor.serverName);
    if (client == null) return null;
    final fullName = '${host.name}/$name';
    switch (actionType) {
      case 'tool':
        return _createToolAction(
          client,
          fullName,
          descriptor.actionName,
          descriptor.payload,
          host.rawToolResponses,
        );
      case 'prompt':
        return _createPromptAction(
          client,
          fullName,
          descriptor.actionName,
          descriptor.payload,
        );
      case 'resource':
        return _createResourceAction(
          client,
          fullName,
          descriptor.actionName,
          descriptor.payload,
        );
      default:
        return null;
    }
  }

  Future<List<ActionMetadata>> _buildCache() async {
    await host.ready();
    final actions = <ActionMetadata>[];
    final index = <String, _McpActionDescriptor>{};

    for (final entry in host.activeClients) {
      final serverName = entry.serverName;
      if (host._hasError(serverName)) continue;
      final tools = await _listAll(entry.listTools);
      for (final tool in tools) {
        final name = tool['name'];
        if (name is! String) continue;
        final shortName = '$serverName:$name';
        final fullName = '${host.name}/$shortName';
        final meta = extractMcpMeta(tool);
        final metadata = meta == null
            ? null
            : {
                'mcp': {'_meta': meta},
              };
        actions.add(
          ActionMetadata(
            name: fullName,
            actionType: 'tool',
            description: tool['description']?.toString(),
            inputSchema: mcpToolInputSchemaFromJson(tool['inputSchema']),
            outputSchema: .dynamicSchema(),
            metadata: metadata,
          ),
        );
        index[_descriptorKey('tool', shortName)] = _McpActionDescriptor(
          serverName: serverName,
          actionName: name,
          payload: tool,
        );
      }

      final prompts = await _listAll(entry.listPrompts);
      for (final prompt in prompts) {
        final name = prompt['name'];
        if (name is! String) continue;
        final shortName = '$serverName:$name';
        final fullName = '${host.name}/$shortName';
        final meta = extractMcpMeta(prompt);
        final metadata = meta == null
            ? null
            : {
                'mcp': {'_meta': meta},
              };
        final args = asListOfMaps(prompt['arguments']);
        actions.add(
          ActionMetadata(
            name: fullName,
            actionType: 'prompt',
            description: prompt['description']?.toString(),
            inputSchema: promptSchemaFromArgs(args),
            outputSchema: GenerateActionOptions.$schema,
            metadata: metadata,
          ),
        );
        index[_descriptorKey('prompt', shortName)] = _McpActionDescriptor(
          serverName: serverName,
          actionName: name,
          payload: prompt,
        );
      }

      final resources = await _listAll(entry.listResources);
      for (final resource in resources) {
        final name = resource['name'];
        if (name is! String) continue;
        final uri = resource['uri'] as String?;
        if (uri == null) continue;
        final shortName = '$serverName:$name';
        final fullName = '${host.name}/$shortName';
        final meta = extractMcpMeta(resource);
        final metadata = {
          'resource': {'uri': uri, 'template': null},
          if (meta != null) 'mcp': {'_meta': meta},
        };
        actions.add(
          ActionMetadata(
            name: fullName,
            actionType: 'resource',
            description: resource['description']?.toString(),
            inputSchema: ResourceInput.$schema,
            outputSchema: ResourceOutput.$schema,
            metadata: metadata,
          ),
        );
        index[_descriptorKey('resource', shortName)] = _McpActionDescriptor(
          serverName: serverName,
          actionName: name,
          payload: resource,
        );
      }

      final templates = await _listAll(entry.listResourceTemplates);
      for (final template in templates) {
        final name = template['name'];
        if (name is! String) continue;
        final uriTemplate = template['uriTemplate'] as String?;
        if (uriTemplate == null) continue;
        final shortName = '$serverName:$name';
        final fullName = '${host.name}/$shortName';
        final meta = extractMcpMeta(template);
        final metadata = {
          'resource': {'uri': null, 'template': uriTemplate},
          if (meta != null) 'mcp': {'_meta': meta},
        };
        actions.add(
          ActionMetadata(
            name: fullName,
            actionType: 'resource',
            description: template['description']?.toString(),
            inputSchema: ResourceInput.$schema,
            outputSchema: ResourceOutput.$schema,
            metadata: metadata,
          ),
        );
        index[_descriptorKey('resource', shortName)] = _McpActionDescriptor(
          serverName: serverName,
          actionName: name,
          payload: template,
        );
      }
    }

    _actionIndex
      ..clear()
      ..addAll(index);
    _cachedActions = actions;
    if (_shouldUseCache()) {
      _cacheExpiresAt = DateTime.now().add(
        Duration(milliseconds: _effectiveCacheTtlMillis()),
      );
    }
    return actions;
  }

  bool _shouldUseCache() {
    return cacheTtlMillis == null || cacheTtlMillis! >= 0;
  }

  int _effectiveCacheTtlMillis() {
    if (cacheTtlMillis == null || cacheTtlMillis == 0) {
      return 3000;
    }
    return cacheTtlMillis!.abs();
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

class _McpActionDescriptor {
  final String serverName;
  final String actionName;
  final Map<String, dynamic> payload;

  _McpActionDescriptor({
    required this.serverName,
    required this.actionName,
    required this.payload,
  });
}

String _descriptorKey(String actionType, String name) => '$actionType|$name';

Future<List<Map<String, dynamic>>> _listAll(
  Future<Map<String, dynamic>> Function({String? cursor}) lister,
) async {
  final items = <Map<String, dynamic>>[];
  String? cursor;
  do {
    final result = await lister(cursor: cursor);
    items.addAll(asListOfMaps(result['tools']));
    items.addAll(asListOfMaps(result['prompts']));
    items.addAll(asListOfMaps(result['resources']));
    items.addAll(asListOfMaps(result['resourceTemplates']));
    cursor = result['nextCursor'] as String?;
  } while (cursor != null);
  return items;
}

Tool<Map<String, dynamic>, dynamic> _createToolAction(
  GenkitMcpClient client,
  String fullName,
  String toolName,
  Map<String, dynamic> tool,
  bool rawToolResponses,
) {
  final description = tool['description']?.toString() ?? '';
  final meta = extractMcpMeta(tool);
  return Tool<Map<String, dynamic>, dynamic>(
    name: fullName,
    description: description,
    inputSchema: mcpToolInputSchemaFromJson(tool['inputSchema']),
    outputSchema: .dynamicSchema(),
    metadata: {
      if (meta != null) 'mcp': {'_meta': meta},
    },
    fn: (input, ctx) async {
      final result = await client.callTool(
        name: toolName,
        arguments: input,
        meta: extractMcpMeta(ctx.context),
      );
      if (rawToolResponses) return result;
      return processToolResult(result);
    },
  );
}

PromptAction<Map<String, dynamic>> _createPromptAction(
  GenkitMcpClient client,
  String fullName,
  String promptName,
  Map<String, dynamic> prompt,
) {
  final description = prompt['description']?.toString();
  final meta = extractMcpMeta(prompt);
  final args = asListOfMaps(prompt['arguments']);
  return PromptAction<Map<String, dynamic>>(
    name: fullName,
    description: description,
    inputSchema: promptSchemaFromArgs(args),
    metadata: {
      if (meta != null) 'mcp': {'_meta': meta},
    },
    fn: (input, ctx) async {
      final result = await client.getPromptResult(
        name: promptName,
        arguments: input,
        meta: extractMcpMeta(ctx.context),
      );
      final messages = asListOfMaps(
        result['messages'],
      ).map(fromMcpPromptMessage).toList();
      return GenerateActionOptions(messages: messages);
    },
  );
}

ResourceAction _createResourceAction(
  GenkitMcpClient client,
  String fullName,
  String resourceName,
  Map<String, dynamic> resource,
) {
  final description = resource['description']?.toString();
  final meta = extractMcpMeta(resource);
  final uri = resource['uri'] as String?;
  final template = resource['uriTemplate'] as String?;
  return ResourceAction(
    name: fullName,
    description: description,
    metadata: {
      'resource': {'uri': uri, 'template': template},
      if (meta != null) 'mcp': {'_meta': meta},
    },
    matches: createResourceMatcher(uri: uri, template: template),
    fn: (input, ctx) async {
      final result = await client.readResource(
        uri: input.uri,
        meta: extractMcpMeta(ctx.context),
      );
      final contents = asListOfMaps(
        result['contents'],
      ).map(fromMcpResourceContent).toList();
      return ResourceOutput(content: contents);
    },
  );
}
