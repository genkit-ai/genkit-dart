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
import 'package:schemantic/schemantic.dart';

import '../util/common.dart';
import '../util/convert_messages.dart';
import '../util/errors.dart';
import '../util/logging.dart';
import 'transports/client_transport.dart';
import 'transports/stdio_transport.dart';
import 'transports/streamable_http_transport.dart';

/// Handler for server-initiated `sampling/createMessage` requests.
typedef McpSamplingHandler =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> params);

/// Handler for server-initiated `elicitation/create` requests.
typedef McpElicitationHandler =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> params);

/// Handler for server notifications (e.g. `notifications/tools/list_changed`).
typedef McpNotificationHandler =
    void Function(String method, Map<String, dynamic> params);

/// An MCP root entry advertised to the server via `roots/list`.
class McpRoot {
  final String uri;
  final String? name;

  const McpRoot({required this.uri, this.name});

  Map<String, dynamic> toJson() {
    return {'uri': uri, 'name': ?name};
  }
}

/// Configuration for connecting to a single MCP server.
///
/// Provide one of [command] (stdio), [url] (Streamable HTTP), or
/// [transport] (custom transport).
class McpServerConfig {
  final McpClientTransport? transport;
  final String? command;
  final List<String> args;
  final Map<String, String>? environment;
  final Uri? url;
  final Map<String, String>? headers;
  final Duration? timeout;
  final bool disabled;
  final List<McpRoot>? roots;

  const McpServerConfig({
    this.transport,
    this.command,
    this.args = const [],
    this.environment,
    this.url,
    this.headers,
    this.timeout,
    this.disabled = false,
    this.roots,
  });
}

/// Options for a [GenkitMcpClient] instance.
class McpClientOptions {
  /// Client name advertised to the server during initialization.
  final String name;

  /// Overrides the server name used for action namespacing.
  final String? serverName;
  final String? version;

  /// When `true`, tool results are returned as raw MCP maps.
  final bool rawToolResponses;
  final McpServerConfig mcpServer;
  final McpSamplingHandler? samplingHandler;
  final McpElicitationHandler? elicitationHandler;
  final McpNotificationHandler? notificationHandler;

  const McpClientOptions({
    required this.name,
    required this.mcpServer,
    this.serverName,
    this.version,
    this.rawToolResponses = false,
    this.samplingHandler,
    this.elicitationHandler,
    this.notificationHandler,
  });
}

/// [McpClientOptions] with an additional [cacheTtlMillis] for the
/// registry plugin created by `defineMcpClient`.
class McpClientOptionsWithCache extends McpClientOptions {
  final int? cacheTtlMillis;

  const McpClientOptionsWithCache({
    required super.name,
    required super.mcpServer,
    this.cacheTtlMillis,
    super.serverName,
    super.version,
    super.rawToolResponses,
    super.samplingHandler,
    super.elicitationHandler,
    super.notificationHandler,
  });
}

/// A client connection to a single MCP server.
///
/// Handles the connection lifecycle and provides methods to discover and
/// invoke remote tools, prompts, and resources.
class GenkitMcpClient {
  final McpClientOptions options;

  McpClientTransport? _transport;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  int _requestId = 0;
  Completer<void> _readyCompleter = Completer<void>();

  bool _connected = false;
  bool _disabled = false;
  String? _error;
  String? _serverName;
  List<McpRoot> _roots;
  final Map<String, _ClientTaskState> _tasks = {};
  final Set<Object> _cancelledRequests = {};
  final Map<Object, num> _progressCounters = {};
  int _taskCounter = 0;

  GenkitMcpClient(this.options)
    : _roots = List.of(options.mcpServer.roots ?? const []) {
    _disabled = options.mcpServer.disabled;
    if (_disabled) {
      _readyCompleter.complete();
    } else {
      _connect();
    }
  }

  bool get disabled => _disabled;
  bool get enabled => !_disabled;
  String? get error => _error;
  String get serverName => _serverName ?? options.serverName ?? options.name;
  List<McpRoot> get roots => List.unmodifiable(_roots);

  bool isEnabled() => !_disabled;

  Future<void> ready() {
    return _readyCompleter.future;
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _transport?.close();
    _subscription = null;
    _transport = null;
    _connected = false;
  }

  Future<void> disable() async {
    _disabled = true;
    await close();
  }

  Future<void> enable() async {
    if (!_disabled) return;
    _disabled = false;
    _readyCompleter = Completer<void>();
    _connect();
  }

  Future<void> restart() async {
    await close();
    _disabled = false;
    _readyCompleter = Completer<void>();
    _connect();
  }

  Future<void> updateRoots(List<McpRoot> roots) async {
    _roots = List.of(roots);
    if (_connected && !_disabled) {
      await _sendNotification('notifications/roots/list_changed', {});
    }
  }

  Future<List<Tool<Map<String, dynamic>, dynamic>>> getActiveTools(
    Genkit ai,
  ) async {
    await ready();
    if (_disabled) return [];
    final tools = await _fetchTools();
    return tools
        .map((tool) => _createToolAction(ai, tool))
        .whereType<Tool<Map<String, dynamic>, dynamic>>()
        .toList();
  }

  Future<List<PromptAction<Map<String, dynamic>>>> getActivePrompts(
    Genkit ai,
  ) async {
    await ready();
    if (_disabled) return [];
    final prompts = await _fetchPrompts();
    return prompts
        .map((prompt) => _createPromptAction(ai, prompt))
        .whereType<PromptAction<Map<String, dynamic>>>()
        .toList();
  }

  Future<PromptAction<Map<String, dynamic>>?> getPrompt(
    Genkit ai,
    String promptName,
  ) async {
    await ready();
    if (_disabled) return null;
    final prompts = await _fetchPrompts();
    final prompt = prompts.firstWhere(
      (p) => p['name'] == promptName,
      orElse: () => const {},
    );
    if (prompt.isEmpty) return null;
    return _createPromptAction(ai, prompt);
  }

  Future<List<ResourceAction>> getActiveResources(Genkit ai) async {
    await ready();
    if (_disabled) return [];
    final resources = await _fetchResources();
    return resources
        .map((resource) => _createResourceAction(ai, resource))
        .whereType<ResourceAction>()
        .toList();
  }

  Future<Map<String, dynamic>> callTool({
    required String name,
    Map<String, dynamic>? arguments,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    final params = <String, dynamic>{
      'name': name,
      'arguments': ?arguments,
      '_meta': ?meta,
      'task': ?task,
    };
    final response = await _sendRequest('tools/call', params);
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> getPromptResult({
    required String name,
    Map<String, dynamic>? arguments,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    final params = <String, dynamic>{
      'name': name,
      'arguments': ?arguments,
      '_meta': ?meta,
      'task': ?task,
    };
    final response = await _sendRequest('prompts/get', params);
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> readResource({
    required String uri,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    final params = <String, dynamic>{'uri': uri, '_meta': ?meta, 'task': ?task};
    final response = await _sendRequest('resources/read', params);
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> listTools({String? cursor}) async {
    final response = await _sendRequest(
      'tools/list',
      cursor == null ? {} : {'cursor': cursor},
    );
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> listPrompts({String? cursor}) async {
    final response = await _sendRequest(
      'prompts/list',
      cursor == null ? {} : {'cursor': cursor},
    );
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> listResources({String? cursor}) async {
    final response = await _sendRequest(
      'resources/list',
      cursor == null ? {} : {'cursor': cursor},
    );
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> listResourceTemplates({String? cursor}) async {
    final response = await _sendRequest(
      'resources/templates/list',
      cursor == null ? {} : {'cursor': cursor},
    );
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> complete({
    required Map<String, dynamic> ref,
    required Map<String, dynamic> argument,
    Map<String, dynamic>? context,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    final params = <String, dynamic>{
      'ref': ref,
      'argument': argument,
      'context': ?context,
      '_meta': ?meta,
      'task': ?task,
    };
    final response = await _sendRequest('completion/complete', params);
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> subscribeResource({
    required String uri,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    final params = <String, dynamic>{'uri': uri, '_meta': ?meta, 'task': ?task};
    final response = await _sendRequest('resources/subscribe', params);
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> unsubscribeResource({
    required String uri,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    final params = <String, dynamic>{'uri': uri, '_meta': ?meta, 'task': ?task};
    final response = await _sendRequest('resources/unsubscribe', params);
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> setLogLevel(String level) async {
    final response = await _sendRequest('logging/setLevel', {'level': level});
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> ping() async {
    final response = await _sendRequest('ping', {});
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> listTasks({String? cursor}) async {
    final response = await _sendRequest(
      'tasks/list',
      cursor == null ? {} : {'cursor': cursor},
    );
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> getTask(String taskId) async {
    final response = await _sendRequest('tasks/get', {'taskId': taskId});
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> getTaskResult(String taskId) async {
    final response = await _sendRequest('tasks/result', {'taskId': taskId});
    return asMap(response['result']);
  }

  Future<Map<String, dynamic>> cancelTask(String taskId) async {
    final response = await _sendRequest('tasks/cancel', {'taskId': taskId});
    return asMap(response['result']);
  }

  Future<void> _connect() async {
    if (_connected) return;
    try {
      _transport =
          options.mcpServer.transport ??
          await _startTransportFromConfig(options.mcpServer);
      _subscription = _transport!.inbound.listen(
        _handleInbound,
        onError: _handleTransportError,
        onDone: _handleTransportDone,
      );
      await _initialize();
      _connected = true;
      if (_roots.isNotEmpty) {
        await updateRoots(_roots);
      }
      _readyCompleter.complete();
    } catch (e, st) {
      _error = e.toString();
      _disabled = true;
      _readyCompleter.completeError(e, st);
    }
  }

  Future<McpClientTransport> _startTransportFromConfig(
    McpServerConfig config,
  ) async {
    if (config.url != null) {
      return _startHttpTransport(config);
    }
    final command = config.command;
    if (command == null) {
      throw GenkitException(
        '[MCP Client] Could not determine valid transport config from supplied options.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    return StdioClientTransport.start(
      command: command,
      args: config.args,
      environment: config.environment,
    );
  }

  Future<McpClientTransport> _startHttpTransport(McpServerConfig config) async {
    final url = config.url;
    if (url == null) {
      throw GenkitException(
        '[MCP Client] HTTP transport requires a URL.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    return StreamableHttpClientTransport.connect(
      url: url,
      headers: config.headers,
      timeout: config.timeout,
    );
  }

  Future<void> _initialize() async {
    final result = await _sendRequest('initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': _clientCapabilities(),
      'clientInfo': {
        'name': options.name,
        'version': options.version ?? '1.0.0',
      },
    });
    final serverInfo = asMap(result['serverInfo']);
    if (options.serverName == null && serverInfo['name'] is String) {
      _serverName = serverInfo['name'] as String;
    }
    final negotiatedVersion = result['protocolVersion'];
    if (negotiatedVersion is String &&
        _transport is StreamableHttpClientTransport) {
      (_transport as StreamableHttpClientTransport).setProtocolVersion(
        negotiatedVersion,
      );
    }
    await _sendNotification('notifications/initialized', {});
  }

  Map<String, dynamic> _clientCapabilities() {
    final capabilities = <String, dynamic>{
      'roots': {'listChanged': true},
    };
    if (options.samplingHandler != null) {
      capabilities['sampling'] = {'context': {}, 'tools': {}};
    }
    if (options.elicitationHandler != null) {
      capabilities['elicitation'] = {'form': {}, 'url': {}};
    }
    if (options.samplingHandler != null || options.elicitationHandler != null) {
      capabilities['tasks'] = {
        'cancel': {},
        'list': {},
        'requests': {
          if (options.samplingHandler != null)
            'sampling': {'createMessage': {}},
          if (options.elicitationHandler != null) 'elicitation': {'create': {}},
        },
      };
    }
    return capabilities;
  }

  Future<List<Map<String, dynamic>>> _fetchTools() async {
    final tools = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final result = await listTools(cursor: cursor);
      tools.addAll(asListOfMaps(result['tools']));
      cursor = result['nextCursor'] as String?;
    } while (cursor != null);
    return tools;
  }

  Future<List<Map<String, dynamic>>> _fetchPrompts() async {
    final prompts = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final result = await listPrompts(cursor: cursor);
      prompts.addAll(asListOfMaps(result['prompts']));
      cursor = result['nextCursor'] as String?;
    } while (cursor != null);
    return prompts;
  }

  Future<List<Map<String, dynamic>>> _fetchResources() async {
    final resources = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final result = await listResources(cursor: cursor);
      resources.addAll(asListOfMaps(result['resources']));
      cursor = result['nextCursor'] as String?;
    } while (cursor != null);
    do {
      final templates = await listResourceTemplates(cursor: cursor);
      resources.addAll(asListOfMaps(templates['resourceTemplates']));
      cursor = templates['nextCursor'] as String?;
    } while (cursor != null);
    return resources;
  }

  Tool<Map<String, dynamic>, dynamic>? _createToolAction(
    Genkit ai,
    Map<String, dynamic> tool,
  ) {
    final name = tool['name'];
    if (name is! String) return null;
    final description = tool['description']?.toString() ?? '';
    final meta = extractMcpMeta(tool);
    return Tool<Map<String, dynamic>, dynamic>(
      name: '$serverName/$name',
      description: description,
      inputSchema: mcpToolInputSchemaFromJson(tool['inputSchema']),
      outputSchema: dynamicSchema(),
      metadata: {
        if (meta != null) 'mcp': {'_meta': meta},
      },
      fn: (input, ctx) async {
        final result = await callTool(
          name: name,
          arguments: input,
          meta: extractMcpMeta(ctx.context),
        );
        if (options.rawToolResponses) return result;
        return processToolResult(result);
      },
    );
  }

  PromptAction<Map<String, dynamic>>? _createPromptAction(
    Genkit ai,
    Map<String, dynamic> prompt,
  ) {
    final name = prompt['name'];
    if (name is! String) return null;
    final description = prompt['description']?.toString();
    final meta = extractMcpMeta(prompt);
    final args = asListOfMaps(prompt['arguments']);
    final inputSchema = promptSchemaFromArgs(args);
    return PromptAction<Map<String, dynamic>>(
      name: name,
      description: description,
      inputSchema: inputSchema,
      metadata: {
        if (meta != null) 'mcp': {'_meta': meta},
      },
      fn: (input, ctx) async {
        final result = await getPromptResult(
          name: name,
          arguments: input,
          meta: extractMcpMeta(ctx.context),
        );
        final messages = asListOfMaps(
          result['messages'],
        ).map(fromMcpPromptMessage).toList();
        return GenerateRequest(messages: messages);
      },
    );
  }

  ResourceAction? _createResourceAction(
    Genkit ai,
    Map<String, dynamic> resource,
  ) {
    final name = resource['name'];
    if (name is! String) return null;
    final description = resource['description']?.toString();
    final uri = resource['uri'] as String?;
    final template = resource['uriTemplate'] as String?;
    if (uri == null && template == null) return null;
    final meta = extractMcpMeta(resource);
    return ResourceAction(
      name: '$serverName/$name',
      description: description,
      metadata: {
        'resource': {'uri': uri, 'template': template},
        if (meta != null) 'mcp': {'_meta': meta},
      },
      matches: createMcpResourceMatcher(uri: uri, template: template),
      fn: (input, ctx) async {
        final result = await readResource(
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

  Future<Map<String, dynamic>> _sendRequest(
    String method,
    Map<String, dynamic>? params,
  ) async {
    final id = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    await _transport!.send({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': ?params,
    });
    return completer.future;
  }

  Future<void> _sendNotification(
    String method,
    Map<String, dynamic>? params,
  ) async {
    await _transport!.send({
      'jsonrpc': '2.0',
      'method': method,
      'params': ?params,
    });
  }

  Future<void> _sendResponse(Object? id, Map<String, dynamic> result) async {
    if (id == null) return;
    await _transport!.send({'jsonrpc': '2.0', 'id': id, 'result': result});
  }

  Future<void> _sendError(Object? id, Map<String, dynamic> error) async {
    if (id == null) return;
    await _transport!.send({'jsonrpc': '2.0', 'id': id, 'error': error});
  }

  void _handleInbound(Map<String, dynamic> message) {
    final method = message['method'];
    if (method is String) {
      _handleRequest(message);
      return;
    }
    final id = message['id'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['error'] is Map) {
      completer.completeError(_toRpcException(message['error'] as Map));
      return;
    }
    completer.complete(message);
  }

  void _handleRequest(Map<String, dynamic> message) {
    final method = message['method'];
    final params = asMap(message['params']);
    try {
      switch (method) {
        case 'roots/list':
          final roots = _roots.map((root) => root.toJson()).toList();
          _sendResponse(message['id'], {'roots': roots});
          return;
        case 'ping':
          _sendResponse(message['id'], {});
          return;
        case 'sampling/createMessage':
          unawaited(_handleSamplingRequest(message['id'], params));
          return;
        case 'elicitation/create':
          unawaited(_handleElicitationRequest(message['id'], params));
          return;
        case 'tasks/list':
          _sendResponse(message['id'], _listClientTasks());
          return;
        case 'tasks/get':
          _sendResponse(message['id'], _getClientTask(params));
          return;
        case 'tasks/result':
          _sendTaskResult(message['id'], params);
          return;
        case 'tasks/cancel':
          _sendResponse(message['id'], _cancelClientTask(params));
          return;
        case 'notifications/cancelled':
          _handleCancelled(params);
          _dispatchNotification(method?.toString(), params);
          return;
        default:
          if (method is String && method.startsWith('notifications/')) {
            _dispatchNotification(method, params);
            return;
          }
          _sendError(message['id'], {
            'code': -32601,
            'message': 'Method not found: $method',
          });
          return;
      }
    } catch (e) {
      _sendError(message['id'], _toRpcError(e));
    }
  }

  Future<void> _handleSamplingRequest(
    Object? id,
    Map<String, dynamic> params,
  ) async {
    final handler = options.samplingHandler;
    if (handler == null) {
      _sendError(id, {
        'code': -32601,
        'message': 'Method not found: sampling/createMessage',
      });
      return;
    }
    await _respondWithClientTask(
      id,
      params,
      handler,
      requestType: 'sampling/createMessage',
    );
  }

  Future<void> _handleElicitationRequest(
    Object? id,
    Map<String, dynamic> params,
  ) async {
    final handler = options.elicitationHandler;
    if (handler == null) {
      _sendError(id, {
        'code': -32601,
        'message': 'Method not found: elicitation/create',
      });
      return;
    }
    await _respondWithClientTask(
      id,
      params,
      handler,
      requestType: 'elicitation/create',
    );
  }

  Future<void> _respondWithClientTask(
    Object? id,
    Map<String, dynamic> params,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) handler, {
    required String requestType,
  }) async {
    if (id == null) return;
    final taskMeta = params['task'];
    if (taskMeta is Map) {
      final task = _createClientTask(
        requestType: requestType,
        meta: taskMeta.cast<String, dynamic>(),
        progressToken: _extractProgressToken(params),
        action: () => handler(params),
      );
      _sendResponse(id, {'task': _clientTaskToJson(task)});
      return;
    }
    try {
      final result = await handler(params);
      if (_isCancelled(id)) return;
      _sendResponse(id, result);
    } catch (e) {
      _sendError(id, _toRpcError(e));
    }
  }

  _ClientTaskState _createClientTask({
    required String requestType,
    required Map<String, dynamic> meta,
    required Object? progressToken,
    required Future<Map<String, dynamic>> Function() action,
  }) {
    final taskId = _nextTaskId();
    final ttl = (meta['ttl'] is num) ? (meta['ttl'] as num).toInt() : null;
    final task = _ClientTaskState(
      id: taskId,
      requestType: requestType,
      ttl: ttl,
    );
    _tasks[taskId] = task;
    unawaited(_notifyTaskStatus(task));
    unawaited(_runClientTask(task, progressToken, action));
    return task;
  }

  Future<void> _runClientTask(
    _ClientTaskState task,
    Object? progressToken,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    await _sendProgress(progressToken, message: 'started');
    try {
      final result = await action();
      if (task.isCancelled) return;
      task.complete(result);
      await _sendProgress(progressToken, message: 'completed');
    } catch (e) {
      if (task.isCancelled) return;
      task.fail(_toRpcError(e));
      await _sendProgress(progressToken, message: 'failed');
    } finally {
      await _notifyTaskStatus(task);
    }
  }

  Map<String, dynamic> _listClientTasks() {
    _purgeExpiredTasks();
    return {'tasks': _tasks.values.map(_clientTaskToJson).toList()};
  }

  Map<String, dynamic> _getClientTask(Map<String, dynamic> params) {
    _purgeExpiredTasks();
    final taskId = params['taskId']?.toString();
    final task = taskId == null ? null : _tasks[taskId];
    if (task == null) {
      throw GenkitException(
        '[MCP Client] Task "$taskId" not found.',
        status: StatusCodes.NOT_FOUND,
      );
    }
    return _clientTaskToJson(task);
  }

  void _sendTaskResult(Object? id, Map<String, dynamic> params) {
    _purgeExpiredTasks();
    final taskId = params['taskId']?.toString();
    final task = taskId == null ? null : _tasks[taskId];
    if (task == null) {
      _sendError(id, {
        'code': 404,
        'message': '[MCP Client] Task "$taskId" not found.',
      });
      return;
    }
    if (task.status == 'failed' && task.error != null) {
      _sendError(id, task.error!);
      return;
    }
    if (!task.isCompleted) {
      _sendError(id, {
        'code': 409,
        'message': '[MCP Client] Task "$taskId" not completed yet.',
      });
      return;
    }
    _sendResponse(id, task.result ?? {});
  }

  Map<String, dynamic> _cancelClientTask(Map<String, dynamic> params) {
    _purgeExpiredTasks();
    final taskId = params['taskId']?.toString();
    final task = taskId == null ? null : _tasks[taskId];
    if (task == null) {
      throw GenkitException(
        '[MCP Client] Task "$taskId" not found.',
        status: StatusCodes.NOT_FOUND,
      );
    }
    task.cancel('Cancelled by request');
    unawaited(_notifyTaskStatus(task));
    return _clientTaskToJson(task);
  }

  void _handleCancelled(Map<String, dynamic> params) {
    final requestId = params['requestId'];
    if (requestId != null) {
      _cancelledRequests.add(requestId);
    }
  }

  void _dispatchNotification(String? method, Map<String, dynamic> params) {
    if (method == null) return;
    options.notificationHandler?.call(method, params);
  }

  Future<void> _sendProgress(
    Object? progressToken, {
    required String message,
  }) async {
    if (progressToken == null) return;
    final current = (_progressCounters[progressToken] ?? 0) + 1;
    _progressCounters[progressToken] = current;
    await _sendNotification('notifications/progress', {
      'progressToken': progressToken,
      'progress': current,
      'message': message,
    });
  }

  Future<void> _notifyTaskStatus(_ClientTaskState task) async {
    await _sendNotification(
      'notifications/tasks/status',
      _clientTaskToJson(task),
    );
  }

  Map<String, dynamic> _toRpcError(Object error) {
    try {
      return toJsonRpcError(error);
    } catch (_) {
      return {'code': -32603, 'message': error.toString()};
    }
  }

  void _purgeExpiredTasks() {
    final now = DateTime.now();
    final expiredIds = <String>[];
    for (final entry in _tasks.entries) {
      if (entry.value.isExpired(now)) {
        expiredIds.add(entry.key);
      }
    }
    for (final id in expiredIds) {
      _tasks.remove(id);
    }
  }

  String _nextTaskId() {
    _taskCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_taskCounter';
  }

  Map<String, dynamic> _clientTaskToJson(_ClientTaskState task) {
    return {
      'taskId': task.id,
      'status': task.status,
      'createdAt': task.createdAt.toIso8601String(),
      'lastUpdatedAt': task.lastUpdatedAt.toIso8601String(),
      'pollInterval': task.pollInterval,
      'ttl': task.ttl ?? 0,
      if (task.statusMessage != null) 'statusMessage': task.statusMessage,
    };
  }

  bool _isCancelled(Object? id) {
    if (id == null) return false;
    return _cancelledRequests.remove(id);
  }

  Object? _extractProgressToken(Map<String, dynamic> params) {
    final meta = params['_meta'];
    if (meta is Map && meta['progressToken'] != null) {
      return meta['progressToken'];
    }
    return null;
  }

  void _handleTransportError(Object error) {
    mcpLogger.warning('[MCP Client] Transport error: $error');
  }

  void _handleTransportDone() {
    mcpLogger.info('[MCP Client] Transport closed.');
  }

  GenkitException _toRpcException(Map error) {
    final message = error['message']?.toString() ?? 'MCP error';
    final code = error['code'];
    final status = code is int && code >= 100
        ? StatusCodes.fromHttpStatus(code)
        : StatusCodes.INTERNAL;
    final details = error['data']?.toString();
    return GenkitException(message, status: status, details: details);
  }
}

class _ClientTaskState {
  final String id;
  final String requestType;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  final int? ttl;
  final int pollInterval;
  String status;
  String? statusMessage;
  Map<String, dynamic>? result;
  Map<String, dynamic>? error;

  _ClientTaskState({required this.id, required this.requestType, this.ttl})
    : createdAt = DateTime.now(),
      lastUpdatedAt = DateTime.now(),
      pollInterval = 1000,
      status = 'working';

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool isExpired(DateTime now) {
    if (ttl == null || ttl == 0) return false;
    return now.difference(createdAt).inMilliseconds > ttl!;
  }

  void complete(Map<String, dynamic> value) {
    status = 'completed';
    result = value;
    _touch();
  }

  void fail(Map<String, dynamic> value) {
    status = 'failed';
    error = value;
    _touch();
  }

  void cancel(String message) {
    status = 'cancelled';
    statusMessage = message;
    _touch();
  }

  void _touch() {
    lastUpdatedAt = DateTime.now();
  }
}

/// A [GenkitPlugin] that exposes a single [GenkitMcpClient]'s tools, prompts,
/// and resources through the Genkit registry.
///
/// This is the single-server counterpart of the host plugin.
class McpClientPlugin extends GenkitPlugin {
  final GenkitMcpClient client;
  final int? cacheTtlMillis;
  final Map<String, _McpClientActionDescriptor> _actionIndex = {};
  List<ActionMetadata> _cachedActions = [];
  DateTime? _cacheExpiresAt;
  Future<List<ActionMetadata>>? _inflight;

  McpClientPlugin({required this.client, this.cacheTtlMillis});

  @override
  String get name => client.serverName;

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
    switch (actionType) {
      case 'tool':
        return _resolveToolAction(descriptor);
      case 'prompt':
        return _resolvePromptAction(descriptor);
      case 'resource':
        return _resolveResourceAction(descriptor);
      default:
        return null;
    }
  }

  Future<List<ActionMetadata>> _buildCache() async {
    await client.ready();
    if (client.disabled) return [];
    final actions = <ActionMetadata>[];
    final index = <String, _McpClientActionDescriptor>{};
    final serverName = client.serverName;

    final tools = await _listAll(client.listTools);
    for (final tool in tools) {
      final toolName = tool['name'];
      if (toolName is! String) continue;
      final fullName = '$serverName/$toolName';
      final meta = extractMcpMeta(tool);
      actions.add(
        ActionMetadata(
          name: fullName,
          actionType: 'tool',
          description: tool['description']?.toString(),
          inputSchema: mcpToolInputSchemaFromJson(tool['inputSchema']),
          outputSchema: dynamicSchema(),
          metadata: meta == null
              ? null
              : {
                  'mcp': {'_meta': meta},
                },
        ),
      );
      index[_descriptorKey('tool', toolName)] = _McpClientActionDescriptor(
        actionName: toolName,
        payload: tool,
      );
    }

    final prompts = await _listAll(client.listPrompts);
    for (final prompt in prompts) {
      final promptName = prompt['name'];
      if (promptName is! String) continue;
      final fullName = '$serverName/$promptName';
      final meta = extractMcpMeta(prompt);
      final args = asListOfMaps(prompt['arguments']);
      actions.add(
        ActionMetadata(
          name: fullName,
          actionType: 'prompt',
          description: prompt['description']?.toString(),
          inputSchema: promptSchemaFromArgs(args),
          outputSchema: GenerateRequest.$schema,
          metadata: meta == null
              ? null
              : {
                  'mcp': {'_meta': meta},
                },
        ),
      );
      index[_descriptorKey('prompt', promptName)] = _McpClientActionDescriptor(
        actionName: promptName,
        payload: prompt,
      );
    }

    final resources = await _listAll(client.listResources);
    for (final resource in resources) {
      final resourceName = resource['name'];
      if (resourceName is! String) continue;
      final uri = resource['uri'] as String?;
      if (uri == null) continue;
      final fullName = '$serverName/$resourceName';
      final meta = extractMcpMeta(resource);
      actions.add(
        ActionMetadata(
          name: fullName,
          actionType: 'resource',
          description: resource['description']?.toString(),
          inputSchema: ResourceInput.$schema,
          outputSchema: ResourceOutput.$schema,
          metadata: {
            'resource': {'uri': uri, 'template': null},
            if (meta != null) 'mcp': {'_meta': meta},
          },
        ),
      );
      index[_descriptorKey(
        'resource',
        resourceName,
      )] = _McpClientActionDescriptor(
        actionName: resourceName,
        payload: resource,
      );
    }

    final templates = await _listAll(client.listResourceTemplates);
    for (final template in templates) {
      final templateName = template['name'];
      if (templateName is! String) continue;
      final uriTemplate = template['uriTemplate'] as String?;
      if (uriTemplate == null) continue;
      final fullName = '$serverName/$templateName';
      final meta = extractMcpMeta(template);
      actions.add(
        ActionMetadata(
          name: fullName,
          actionType: 'resource',
          description: template['description']?.toString(),
          inputSchema: ResourceInput.$schema,
          outputSchema: ResourceOutput.$schema,
          metadata: {
            'resource': {'uri': null, 'template': uriTemplate},
            if (meta != null) 'mcp': {'_meta': meta},
          },
        ),
      );
      index[_descriptorKey(
        'resource',
        templateName,
      )] = _McpClientActionDescriptor(
        actionName: templateName,
        payload: template,
      );
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

  Tool<Map<String, dynamic>, dynamic> _resolveToolAction(
    _McpClientActionDescriptor descriptor,
  ) {
    final fullName = '${client.serverName}/${descriptor.actionName}';
    final tool = descriptor.payload;
    final description = tool['description']?.toString() ?? '';
    final meta = extractMcpMeta(tool);
    return Tool<Map<String, dynamic>, dynamic>(
      name: fullName,
      description: description,
      inputSchema: mcpToolInputSchemaFromJson(tool['inputSchema']),
      outputSchema: dynamicSchema(),
      metadata: {
        if (meta != null) 'mcp': {'_meta': meta},
      },
      fn: (input, ctx) async {
        final result = await client.callTool(
          name: descriptor.actionName,
          arguments: input,
          meta: extractMcpMeta(ctx.context),
        );
        return processToolResult(result);
      },
    );
  }

  PromptAction<Map<String, dynamic>> _resolvePromptAction(
    _McpClientActionDescriptor descriptor,
  ) {
    final fullName = '${client.serverName}/${descriptor.actionName}';
    final prompt = descriptor.payload;
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
          name: descriptor.actionName,
          arguments: input,
          meta: extractMcpMeta(ctx.context),
        );
        final messages = asListOfMaps(
          result['messages'],
        ).map(fromMcpPromptMessage).toList();
        return GenerateRequest(messages: messages);
      },
    );
  }

  ResourceAction _resolveResourceAction(_McpClientActionDescriptor descriptor) {
    final fullName = '${client.serverName}/${descriptor.actionName}';
    final resource = descriptor.payload;
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
      matches: createMcpResourceMatcher(uri: uri, template: template),
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

  bool _shouldUseCache() {
    return cacheTtlMillis == null || cacheTtlMillis! >= 0;
  }

  int _effectiveCacheTtlMillis() {
    if (cacheTtlMillis == null || cacheTtlMillis == 0) return 3000;
    return cacheTtlMillis!.abs();
  }

  static String _descriptorKey(String actionType, String name) =>
      '$actionType|$name';

  static Future<List<Map<String, dynamic>>> _listAll(
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
}

class _McpClientActionDescriptor {
  final String actionName;
  final Map<String, dynamic> payload;

  _McpClientActionDescriptor({required this.actionName, required this.payload});
}
