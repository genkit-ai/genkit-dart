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

import '../util/common.dart';
import '../util/convert_prompts.dart';
import '../util/convert_resources.dart';
import '../util/convert_tools.dart';
import '../util/errors.dart';
import '../util/logging.dart';
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
  final Set<Object> _cancelledRequests = {};
  final Map<Object, num> _progressCounters = {};
  int _taskCounter = 0;
  String? _logLevel;

  McpServerTransport? _transport;
  StreamSubscription<Map<String, dynamic>>? _subscription;

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
      } else if (resolved.actionType == 'prompt') {
        _promptActions.add(resolved as PromptAction);
      } else if (resolved.actionType == 'resource') {
        _resourceActions.add(resolved as ResourceAction);
      }
    }

    _actionsResolved = true;
  }

  Future<void> start([McpServerTransport? transport]) async {
    _transport = transport ?? StdioServerTransport();
    await setup();
    _subscription = _transport!.inbound.listen((message) async {
      final response = await handleRequest(message);
      if (response != null) {
        await _transport!.send(response);
      }
    });
    mcpLogger.fine('[MCP Server] MCP server "${options.name}" started.');
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _transport?.close();
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
    final id = request['id'];
    if (method is! String) return null;

    try {
      final params = asMap(request['params']);
      switch (method) {
        case 'initialize':
          return _respond(id, {
            'protocolVersion': '2025-11-25',
            'capabilities': _serverCapabilities(),
            'serverInfo': {
              'name': options.name,
              'version': options.version ?? '1.0.0',
            },
          });
        case 'notifications/initialized':
          return null;
        case 'notifications/cancelled':
          _handleCancelled(params);
          return null;
        case 'ping':
          return _respond(id, {});
        case 'logging/setLevel':
          return _respond(id, _setLogLevel(params));
        case 'completion/complete':
          return await _respondWithTask(
            id,
            params,
            () async => _complete(params),
            requestType: 'completion/complete',
          );
        case 'tools/list':
          return _respond(id, await _listTools());
        case 'tools/call':
          return await _respondWithTask(
            id,
            params,
            () async => _callTool(params),
            requestType: 'tools/call',
          );
        case 'prompts/list':
          return _respond(id, await _listPrompts());
        case 'prompts/get':
          return await _respondWithTask(
            id,
            params,
            () async => _getPrompt(params),
            requestType: 'prompts/get',
          );
        case 'resources/list':
          return _respond(id, await _listResources());
        case 'resources/templates/list':
          return _respond(id, await _listResourceTemplates());
        case 'resources/read':
          return await _respondWithTask(
            id,
            params,
            () async => _readResource(params),
            requestType: 'resources/read',
          );
        case 'resources/subscribe':
          return await _respondWithTask(
            id,
            params,
            () async => _subscribeResource(params),
            requestType: 'resources/subscribe',
          );
        case 'resources/unsubscribe':
          return await _respondWithTask(
            id,
            params,
            () async => _unsubscribeResource(params),
            requestType: 'resources/unsubscribe',
          );
        case 'tasks/list':
          return _respond(id, _listTasks());
        case 'tasks/get':
          return _respond(id, _getTask(params));
        case 'tasks/result':
          return _handleTaskResult(id, params);
        case 'tasks/cancel':
          return _respond(id, _cancelTask(params));
        default:
          return _error(id, {
            'code': -32601,
            'message': 'Method not found: $method',
          });
      }
    } catch (e) {
      return _error(id, toJsonRpcError(e));
    }
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
      if (output is Map || output is List) {
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

  Future<Map<String, dynamic>?> _respondWithTask(
    Object? id,
    Map<String, dynamic> params,
    Future<Map<String, dynamic>> Function() action, {
    required String requestType,
  }) async {
    if (id == null) return null;
    final taskMeta = params['task'];
    if (taskMeta is Map) {
      final task = _createTask(
        requestType: requestType,
        meta: taskMeta.cast<String, dynamic>(),
        progressToken: _extractProgressToken(params),
        action: action,
      );
      return _respond(id, {'task': _taskToJson(task)});
    }
    final result = await action();
    if (_isCancelled(id)) return null;
    return _respond(id, result);
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

  Map<String, dynamic>? _handleTaskResult(
    Object? id,
    Map<String, dynamic> params,
  ) {
    _purgeExpiredTasks();
    final taskId = params['taskId']?.toString();
    final task = taskId == null ? null : _tasks[taskId];
    if (task == null) {
      return _error(id, {
        'code': 404,
        'message': '[MCP Server] Task "$taskId" not found.',
      });
    }
    if (task.status == 'failed' && task.error != null) {
      return _error(id, task.error!);
    }
    if (!task.isCompleted) {
      return _error(id, {
        'code': 409,
        'message': '[MCP Server] Task "$taskId" not completed yet.',
      });
    }
    return _respond(id, task.result ?? {});
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

  void _handleCancelled(Map<String, dynamic> params) {
    final requestId = params['requestId'] as Object?;
    if (requestId != null) {
      _cancelledRequests.add(requestId);
    }
  }

  Map<String, dynamic> _serverCapabilities() {
    return {
      'tools': {'listChanged': true},
      'prompts': {'listChanged': true},
      'resources': {'listChanged': true, 'subscribe': true},
      'logging': {},
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

  Map<String, dynamic> _setLogLevel(Map<String, dynamic> params) {
    final level = params['level']?.toString();
    if (level == null) {
      throw GenkitException(
        '[MCP Server] Logging level must be provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    _logLevel = level;
    return {};
  }

  Future<void> _sendNotification(
    String method,
    Map<String, dynamic> params,
  ) async {
    final transport = _transport;
    if (transport == null) return;
    await transport.send({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
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

  Map<String, dynamic>? _respond(Object? id, Map<String, dynamic> result) {
    if (id == null) return null;
    return {'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, dynamic>? _error(Object? id, Map<String, dynamic> error) {
    if (id == null) return null;
    return {'jsonrpc': '2.0', 'id': id, 'error': error};
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
