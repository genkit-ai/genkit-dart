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
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;

import '../util/common.dart';
import '../util/convert_prompts.dart';
import '../util/convert_resources.dart';
import '../util/convert_tools.dart';
import '../util/errors.dart';
import '../util/logging.dart';
import '../util/mcp_dart_transport.dart';
import 'transports/stdio_transport.dart';

/// Configuration for a [GenkitMcpServer].
class McpServerOptions {
  /// The name to advertise to MCP clients.
  final String name;

  /// The version to advertise. Defaults to `'1.0.0'`.
  final String? version;

  McpServerOptions({required this.name, this.version});
}

/// An MCP server that exposes Genkit tools, prompts, and resources
/// over the Model Context Protocol.
class GenkitMcpServer {
  final Genkit ai;
  final McpServerOptions options;

  bool _actionsResolved = false;
  final List<Tool> _toolActions = [];
  final List<PromptAction> _promptActions = [];
  final List<ResourceAction> _resourceActions = [];
  final Map<String, _TaskState> _tasks = {};
  final Set<String> _resourceSubscriptions = {};
  final Map<Object, num> _progressCounters = {};
  int _taskCounter = 0;
  String? _logLevel;

  McpServerTransport? _transport;
  mcp.McpServer? _mcpServer;
  mcp.McpServer? _directMcpServer;
  _DirectMcpConnection? _directTransport;
  Completer<void>? _directInitialized;
  bool _directReady = false;

  GenkitMcpServer(this.ai, this.options);

  Future<void> setup() async {
    if (_actionsResolved) return;
    _toolActions.clear();
    _promptActions.clear();
    _resourceActions.clear();

    final actions = await ai.registry.listActions();
    for (final action in actions) {
      final resolved = await ai.registry.lookupAction(
        action.actionType,
        action.name,
      );
      if (resolved == null) continue;
      if (resolved.actionType == 'tool') {
        _toolActions.add(resolved as Tool);
      } else if (resolved.actionType == 'executable-prompt') {
        _promptActions.add(resolved as PromptAction);
      } else if (resolved.actionType == 'resource') {
        _resourceActions.add(resolved as ResourceAction);
      }
    }

    _actionsResolved = true;
  }

  mcp.McpServer _createMcpDartServer() {
    final server = mcp.McpServer(
      mcp.Implementation(
        name: options.name,
        version: options.version ?? '1.0.0',
      ),
      options: mcp.McpServerOptions(
        capabilities: mcp.ServerCapabilities.fromJson(_serverCapabilities()),
      ),
    );
    server.onError = (error) {
      mcpLogger.warning('[MCP Server] Protocol error: $error');
    };
    final protocol = server.server;

    _setMcpHandler<mcp.JsonRpcListToolsRequest>(
      protocol,
      mcp.Method.toolsList,
      (request, extra) async =>
          mcp.ListToolsResult.fromJson(await _listTools()),
      mcp.JsonRpcListToolsRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcCallToolRequest>(protocol, mcp.Method.toolsCall, (
      request,
      extra,
    ) async {
      final params = _withRequestMeta(request.params ?? const {}, request.meta);
      final taskMeta = params['task'];
      if (taskMeta is Map) {
        final task = _createTask(
          requestType: mcp.Method.toolsCall,
          meta: taskMeta.cast<String, dynamic>(),
          progressToken: _extractProgressToken(params),
          action: () => _callTool(params),
        );
        return mcp.CreateTaskResult(task: mcp.Task.fromJson(_taskToJson(task)));
      }
      return mcp.CallToolResult.fromJson(await _callTool(params));
    }, mcp.JsonRpcCallToolRequest.fromJson);
    _setMcpHandler<mcp.JsonRpcListPromptsRequest>(
      protocol,
      mcp.Method.promptsList,
      (request, extra) async =>
          mcp.ListPromptsResult.fromJson(await _listPrompts()),
      mcp.JsonRpcListPromptsRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcGetPromptRequest>(
      protocol,
      mcp.Method.promptsGet,
      (request, extra) async => mcp.GetPromptResult.fromJson(
        await _getPrompt(
          _withRequestMeta(request.params ?? const {}, request.meta),
        ),
      ),
      mcp.JsonRpcGetPromptRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcListResourcesRequest>(
      protocol,
      mcp.Method.resourcesList,
      (request, extra) async =>
          mcp.ListResourcesResult.fromJson(await _listResources()),
      mcp.JsonRpcListResourcesRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcListResourceTemplatesRequest>(
      protocol,
      mcp.Method.resourcesTemplatesList,
      (request, extra) async => mcp.ListResourceTemplatesResult.fromJson(
        await _listResourceTemplates(),
      ),
      mcp.JsonRpcListResourceTemplatesRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcReadResourceRequest>(
      protocol,
      mcp.Method.resourcesRead,
      (request, extra) async => mcp.ReadResourceResult.fromJson(
        await _readResource(
          _withRequestMeta(request.params ?? const {}, request.meta),
        ),
      ),
      mcp.JsonRpcReadResourceRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcSubscribeRequest>(
      protocol,
      mcp.Method.resourcesSubscribe,
      (request, extra) async {
        _subscribeResource(request.params ?? const {});
        return const mcp.EmptyResult();
      },
      mcp.JsonRpcSubscribeRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcUnsubscribeRequest>(
      protocol,
      mcp.Method.resourcesUnsubscribe,
      (request, extra) async {
        _unsubscribeResource(request.params ?? const {});
        return const mcp.EmptyResult();
      },
      mcp.JsonRpcUnsubscribeRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcCompleteRequest>(
      protocol,
      mcp.Method.completionComplete,
      (request, extra) async => mcp.CompleteResult.fromJson(
        await _complete(
          _withRequestMeta(request.params ?? const {}, request.meta),
        ),
      ),
      mcp.JsonRpcCompleteRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcSetLevelRequest>(
      protocol,
      mcp.Method.loggingSetLevel,
      (request, extra) async {
        _logLevel = request.setParams.level.name;
        return const mcp.EmptyResult();
      },
      mcp.JsonRpcSetLevelRequest.fromJson,
    );
    _configureMcpTaskHandlers(server);
    return server;
  }

  void _configureMcpTaskHandlers(mcp.McpServer server) {
    final protocol = server.server;
    _setMcpHandler<mcp.JsonRpcListTasksRequest>(
      protocol,
      mcp.Method.tasksList,
      (request, extra) async => mcp.ListTasksResult.fromJson(_listTasks()),
      mcp.JsonRpcListTasksRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcGetTaskRequest>(
      protocol,
      mcp.Method.tasksGet,
      (request, extra) async =>
          mcp.Task.fromJson(_getTask({'taskId': request.getParams.taskId})),
      mcp.JsonRpcGetTaskRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcTaskResultRequest>(
      protocol,
      mcp.Method.tasksResult,
      (request, extra) async => _mcpTaskResult(request.resultParams.taskId),
      mcp.JsonRpcTaskResultRequest.fromJson,
    );
    _setMcpHandler<mcp.JsonRpcCancelTaskRequest>(
      protocol,
      mcp.Method.tasksCancel,
      (request, extra) async => mcp.Task.fromJson(
        _cancelTask({'taskId': request.cancelParams.taskId}),
      ),
      mcp.JsonRpcCancelTaskRequest.fromJson,
    );
  }

  void _setMcpHandler<Request extends mcp.JsonRpcRequest>(
    mcp.Protocol protocol,
    String method,
    Future<mcp.BaseResultData> Function(
      Request request,
      mcp.RequestHandlerExtra extra,
    )
    handler,
    Request Function(Map<String, dynamic> json) fromJson,
  ) {
    protocol.setRequestHandler<Request>(
      method,
      handler,
      (id, params, meta) => fromJson({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': ?params,
        '_meta': ?meta,
      }),
    );
  }

  Map<String, dynamic> _withRequestMeta(
    Map<String, dynamic> params,
    Map<String, dynamic>? meta,
  ) {
    return {...params, '_meta': ?meta};
  }

  mcp.BaseResultData _mcpTaskResult(String taskId) {
    _purgeExpiredTasks();
    final task = _tasks[taskId];
    if (task == null) {
      throw mcp.McpError(
        mcp.ErrorCode.invalidParams.value,
        'Task "$taskId" not found.',
      );
    }
    if (task.status == 'failed') {
      final error = task.error ?? const <String, dynamic>{};
      throw mcp.McpError(
        (error['code'] as num?)?.toInt() ?? mcp.ErrorCode.internalError.value,
        error['message']?.toString() ?? 'Task failed.',
        error['data'],
      );
    }
    if (!task.isCompleted) {
      throw mcp.McpError(
        mcp.ErrorCode.invalidRequest.value,
        'Task "$taskId" is not completed.',
      );
    }
    return mcp.CallToolResult.fromJson(task.result ?? const {});
  }

  Future<void> start([McpServerTransport? transport]) async {
    _transport = transport ?? StdioServerTransport();
    await setup();
    final server = _createMcpDartServer();
    _mcpServer = server;
    await server.connect(
      McpDartTransport(
        inbound: _transport!.inbound,
        send: _transport!.send,
        close: _transport!.close,
      ),
    );
    mcpLogger.fine('[MCP Server] MCP server "${options.name}" started.');
  }

  Future<void> close() async {
    await _mcpServer?.close();
    await _directMcpServer?.close();
    _mcpServer = null;
    _directMcpServer = null;
    _directTransport = null;
    _directInitialized = null;
    _directReady = false;
    _transport = null;
  }

  Future<void> notifyToolsChanged() async {
    await _sendNotification('notifications/tools/list_changed', {});
  }

  Future<void> notifyPromptsChanged() async {
    await _sendNotification('notifications/prompts/list_changed', {});
  }

  Future<void> notifyResourcesChanged() async {
    await _sendNotification('notifications/resources/list_changed', {});
  }

  Future<void> notifyResourceUpdated(String uri, {Object? meta}) async {
    if (_resourceSubscriptions.isEmpty ||
        !_resourceSubscriptions.contains(uri)) {
      return;
    }
    await _sendNotification('notifications/resources/updated', {
      'uri': uri,
      '_meta': ?meta,
    });
  }

  Future<void> logMessage({
    required String level,
    required Object data,
    Object? meta,
  }) async {
    if (!_shouldLog(level)) return;
    await _sendNotification('notifications/message', {
      'level': level,
      'data': data,
      '_meta': ?meta,
    });
  }

  Future<Map<String, dynamic>?> handleRequest(
    Map<String, dynamic> request,
  ) async {
    final method = request['method'];
    if (method is! String) return null;

    await _ensureDirectServer();
    if (method == mcp.Method.notificationsInitialized && _directReady) {
      return null;
    }
    if (method != mcp.Method.initialize && !_directReady) {
      await _initializeDirectServer();
    }

    final response = await _directTransport!.dispatch(
      _normalizeDirectRequest(request),
    );
    if (method == mcp.Method.initialize && response?['error'] == null) {
      await _directTransport!.dispatch({
        'jsonrpc': '2.0',
        'method': mcp.Method.notificationsInitialized,
      });
      await _directInitialized!.future;
    }
    return response;
  }

  Future<void> _ensureDirectServer() async {
    if (_directMcpServer != null) return;
    await setup();
    final transport = _DirectMcpConnection();
    final server = _createMcpDartServer();
    final initialized = Completer<void>();
    server.server.oninitialized = () {
      _directReady = true;
      if (!initialized.isCompleted) initialized.complete();
    };
    _directTransport = transport;
    _directMcpServer = server;
    _directInitialized = initialized;
    await server.connect(transport.transport);
  }

  Future<void> _initializeDirectServer() async {
    final response = await _directTransport!.dispatch({
      'jsonrpc': '2.0',
      'id': '__genkit_direct_initialize__',
      'method': mcp.Method.initialize,
      'params': {
        'protocolVersion': '2025-11-25',
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'genkit-handle-request', 'version': '1.0.0'},
      },
    });
    if (response?['error'] != null) {
      throw StateError('Failed to initialize direct MCP handler: $response');
    }
    await _directTransport!.dispatch({
      'jsonrpc': '2.0',
      'method': mcp.Method.notificationsInitialized,
    });
    await _directInitialized!.future;
  }

  Map<String, dynamic> _normalizeDirectRequest(Map<String, dynamic> request) {
    if (request['method'] != mcp.Method.initialize) {
      return {'jsonrpc': '2.0', ...request};
    }
    final params = asMap(request['params']);
    return {
      'jsonrpc': '2.0',
      ...request,
      'params': {
        'protocolVersion': params['protocolVersion'] ?? '2025-11-25',
        'capabilities': params['capabilities'] ?? <String, dynamic>{},
        'clientInfo':
            params['clientInfo'] ??
            {'name': 'genkit-handle-request', 'version': '1.0.0'},
      },
    };
  }

  Future<Map<String, dynamic>> _listTools() async {
    await setup();
    return {'tools': _toolActions.map(toMcpTool).toList()};
  }

  Future<Map<String, dynamic>> _callTool(Map<String, dynamic> params) async {
    await setup();
    final name = params['name'];
    if (name is! String) {
      // Protocol error: missing tool name → JSON-RPC error.
      throw GenkitException(
        '[MCP Server] Tool name must be provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    final tool = _toolActions.firstWhere(
      (t) => t.name == name,
      // Protocol error: unknown tool → JSON-RPC error.
      orElse: () => throw GenkitException(
        '[MCP Server] Tool "$name" not found.',
        status: StatusCodes.NOT_FOUND,
      ),
    );
    final input = params['arguments'];
    try {
      final result = await tool.runRaw(input);
      final output = result.result;
      final text = _stringifyToolOutput(output);
      final response = <String, dynamic>{
        'content': [
          {'type': 'text', 'text': text},
        ],
      };
      if (output is Map) {
        response['structuredContent'] = output;
      }
      return response;
    } catch (e) {
      // Tool execution errors (input validation, business logic, etc.)
      // are returned as isError per MCP spec, so that models can
      // self-correct and retry with adjusted parameters.
      return {
        'content': [
          {'type': 'text', 'text': e.toString()},
        ],
        'isError': true,
      };
    }
  }

  Future<Map<String, dynamic>> _listPrompts() async {
    await setup();
    final prompts = _promptActions.map((prompt) {
      final args = toMcpPromptArguments(prompt.inputSchema);
      final meta = extractMcpMeta(prompt.metadata);
      final metaEntry = meta == null ? null : {'_meta': meta};
      return {
        'name': prompt.name,
        'description': ?prompt.description,
        'arguments': ?args,
        ...?metaEntry,
      };
    }).toList();
    return {'prompts': prompts};
  }

  Future<Map<String, dynamic>> _getPrompt(Map<String, dynamic> params) async {
    await setup();
    final name = params['name'];
    if (name is! String) {
      throw GenkitException(
        '[MCP Server] Prompt name must be provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    final prompt = _promptActions.firstWhere(
      (p) => p.name == name,
      orElse: () => throw GenkitException(
        '[MCP Server] Prompt "$name" not found.',
        status: StatusCodes.NOT_FOUND,
      ),
    );
    final args = params['arguments'];
    final result = await prompt.runRaw(args);
    final request = result.result;
    return {
      if (prompt.description != null) 'description': prompt.description,
      'messages': toMcpPromptMessages(request.messages),
    };
  }

  Future<Map<String, dynamic>> _listResources() async {
    await setup();
    final resources = _resourceActions
        .map((resource) {
          final data = resource.metadata['resource'];
          if (data is Map<String, dynamic> && data['uri'] is String) {
            final meta = extractMcpMeta(resource.metadata);
            final metaEntry = meta == null ? null : {'_meta': meta};
            return {
              'name': resource.name,
              if (resource.description != null)
                'description': resource.description,
              'uri': data['uri'],
              ...?metaEntry,
            };
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    return {'resources': resources};
  }

  Future<Map<String, dynamic>> _listResourceTemplates() async {
    await setup();
    final templates = _resourceActions
        .map((resource) {
          final data = resource.metadata['resource'];
          if (data is Map<String, dynamic> && data['template'] is String) {
            final meta = extractMcpMeta(resource.metadata);
            final metaEntry = meta == null ? null : {'_meta': meta};
            return {
              'name': resource.name,
              if (resource.description != null)
                'description': resource.description,
              'uriTemplate': data['template'],
              ...?metaEntry,
            };
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    return {'resourceTemplates': templates};
  }

  Future<Map<String, dynamic>> _readResource(
    Map<String, dynamic> params,
  ) async {
    await setup();
    final uri = params['uri'];
    if (uri is! String) {
      throw GenkitException(
        '[MCP Server] Resource uri must be provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    final input = ResourceInput(uri: uri);
    final resource = _resourceActions.firstWhere(
      (r) => r.matches(input),
      orElse: () => throw GenkitException(
        '[MCP Server] Resource "$uri" not found.',
        status: StatusCodes.NOT_FOUND,
      ),
    );
    final result = await resource.runRaw({'uri': uri});
    return {'contents': toMcpResourceContents(uri, result.result.content)};
  }

  Future<Map<String, dynamic>> _complete(Map<String, dynamic> params) async {
    await setup();
    final ref = asMap(params['ref']);
    final argument = asMap(params['argument']);
    final argumentName = argument['name']?.toString();
    final argumentValue = argument['value']?.toString() ?? '';
    if (argumentName == null || argumentName.isEmpty) {
      throw GenkitException(
        '[MCP Server] Completion argument name must be provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final refType = ref['type']?.toString();
    final values = <String>[];
    if (refType == 'ref/prompt') {
      final promptName = ref['name']?.toString();
      if (promptName == null) {
        throw GenkitException(
          '[MCP Server] Completion prompt name must be provided.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
      final prompt = _promptActions.firstWhere(
        (p) => p.name == promptName,
        orElse: () => throw GenkitException(
          '[MCP Server] Prompt "$promptName" not found.',
          status: StatusCodes.NOT_FOUND,
        ),
      );
      final schema = prompt.inputSchema?.jsonSchema(useRefs: false);
      final objectSchema = extractObjectSchema(schema);
      final properties = objectSchema?['properties'];
      if (properties is Map && properties[argumentName] is Map) {
        final property = properties[argumentName] as Map;
        final enumValues = property['enum'];
        if (enumValues is List) {
          values.addAll(
            enumValues
                .map((e) => e.toString())
                .where((value) => value.startsWith(argumentValue)),
          );
        }
        final constValue = property['const'];
        if (constValue != null) {
          final value = constValue.toString();
          if (value.startsWith(argumentValue)) {
            values.add(value);
          }
        }
        if (property['type'] == 'boolean') {
          const boolValues = ['true', 'false'];
          values.addAll(
            boolValues.where((value) => value.startsWith(argumentValue)),
          );
        }
      }
    }

    return {
      'completion': {
        'values': values,
        'total': values.length,
        'hasMore': false,
      },
    };
  }

  Map<String, dynamic> _subscribeResource(Map<String, dynamic> params) {
    final uri = params['uri']?.toString();
    if (uri == null) {
      throw GenkitException(
        '[MCP Server] Resource uri must be provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    _resourceSubscriptions.add(uri);
    return {};
  }

  Map<String, dynamic> _unsubscribeResource(Map<String, dynamic> params) {
    final uri = params['uri']?.toString();
    if (uri == null) {
      throw GenkitException(
        '[MCP Server] Resource uri must be provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    _resourceSubscriptions.remove(uri);
    return {};
  }

  _TaskState _createTask({
    required String requestType,
    required Map<String, dynamic> meta,
    required Object? progressToken,
    required Future<Map<String, dynamic>> Function() action,
  }) {
    final taskId = _nextTaskId();
    final ttl = (meta['ttl'] is num) ? (meta['ttl'] as num).toInt() : null;
    final task = _TaskState(id: taskId, requestType: requestType, ttl: ttl);
    _tasks[taskId] = task;
    unawaited(_notifyTaskStatus(task));
    unawaited(_runTask(task, progressToken, action));
    return task;
  }

  Future<void> _runTask(
    _TaskState task,
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
      task.fail(toJsonRpcError(e));
      await _sendProgress(progressToken, message: 'failed');
    } finally {
      await _notifyTaskStatus(task);
    }
  }

  Map<String, dynamic> _listTasks() {
    _purgeExpiredTasks();
    return {'tasks': _tasks.values.map(_taskToJson).toList()};
  }

  Map<String, dynamic> _getTask(Map<String, dynamic> params) {
    _purgeExpiredTasks();
    final taskId = params['taskId']?.toString();
    final task = taskId == null ? null : _tasks[taskId];
    if (task == null) {
      throw GenkitException(
        '[MCP Server] Task "$taskId" not found.',
        status: StatusCodes.NOT_FOUND,
      );
    }
    return _taskToJson(task);
  }

  Map<String, dynamic> _cancelTask(Map<String, dynamic> params) {
    _purgeExpiredTasks();
    final taskId = params['taskId']?.toString();
    final task = taskId == null ? null : _tasks[taskId];
    if (task == null) {
      throw GenkitException(
        '[MCP Server] Task "$taskId" not found.',
        status: StatusCodes.NOT_FOUND,
      );
    }
    task.cancel('Cancelled by request');
    unawaited(_notifyTaskStatus(task));
    return _taskToJson(task);
  }

  Map<String, dynamic> _serverCapabilities() {
    return {
      'tools': {'listChanged': true},
      'prompts': {'listChanged': true},
      'resources': {'listChanged': true, 'subscribe': true},
      'logging': <String, dynamic>{},
      'completions': {},
      'tasks': {
        'cancel': {},
        'list': {},
        'requests': {
          'tools': {'call': {}},
        },
      },
    };
  }

  Future<void> _sendNotification(
    String method,
    Map<String, dynamic> params,
  ) async {
    final server = _mcpServer;
    if (server == null) return;
    await server.server.notification(
      mcp.JsonRpcNotification(method: method, params: params),
    );
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

  Future<void> _notifyTaskStatus(_TaskState task) async {
    await _sendNotification('notifications/tasks/status', _taskToJson(task));
  }

  bool _shouldLog(String level) {
    final configured = _logLevel;
    if (configured == null) return true;
    return _logSeverity(level) >= _logSeverity(configured);
  }

  int _logSeverity(String level) {
    const order = [
      'debug',
      'info',
      'notice',
      'warning',
      'error',
      'critical',
      'alert',
      'emergency',
    ];
    final index = order.indexOf(level);
    return index == -1 ? order.length : index;
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

  Map<String, dynamic> _taskToJson(_TaskState task) {
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

  Object? _extractProgressToken(Map<String, dynamic> params) {
    final meta = params['_meta'];
    if (meta is Map && meta['progressToken'] != null) {
      return meta['progressToken'];
    }
    return null;
  }
}

class _DirectMcpConnection {
  final StreamController<Map<String, dynamic>> _inbound = StreamController();
  final Map<Object, Completer<Map<String, dynamic>?>> _pending = {};
  final Set<Object> _cancelled = {};

  late final mcp.Transport transport = McpDartTransport(
    inbound: _inbound.stream,
    send: _send,
    close: _close,
  );

  Future<Map<String, dynamic>?> dispatch(Map<String, dynamic> message) async {
    message = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
    final id = message['id'];
    if (id == null) {
      _inbound.add(message);
      if (message['method'] == mcp.Method.notificationsCancelled) {
        final requestId = asMap(message['params'])['requestId'];
        if (requestId is Object) {
          _cancelled.add(requestId);
          _pending.remove(requestId)?.complete(null);
        }
      }
      await Future<void>.delayed(Duration.zero);
      return null;
    }
    final response = Completer<Map<String, dynamic>?>();
    _pending[id as Object] = response;
    _inbound.add(message);
    if (_cancelled.remove(id)) {
      _pending.remove(id)?.complete(null);
    }
    final result = await response.future;
    await Future<void>.delayed(Duration.zero);
    return result;
  }

  Future<void> _send(Map<String, dynamic> json) async {
    final id = json['id'];
    if (id != null) {
      _pending.remove(id)?.complete(json);
    }
  }

  Future<void> _close() async {
    for (final response in _pending.values) {
      response.completeError(StateError('Transport closed.'));
    }
    _pending.clear();
    _cancelled.clear();
    await _inbound.close();
  }
}

class _TaskState {
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

  _TaskState({required this.id, required this.requestType, this.ttl})
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

String _stringifyToolOutput(Object? output) {
  if (output is String) return output;
  try {
    return jsonEncode(output);
  } catch (_) {
    return output.toString();
  }
}
