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
import 'package:mcp_dart/mcp_dart.dart' as mcp;

import '../util/common.dart';
import '../util/convert_messages.dart';
import '../util/errors.dart';
import '../util/logging.dart';
import '../util/mcp_dart_transport.dart';
import '../util/task_state.dart';
import 'transports/client_transport.dart';

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

  /// Cache TTL for remote action listings.
  ///
  /// Positive values override server hints, negative values disable caching,
  /// and `null` or zero uses the MCP 2026-07-28 server `ttlMs` hint when
  /// available, falling back to three seconds.
  final int? cacheTtlMillis;

  const McpClientOptions({
    required this.name,
    required this.mcpServer,
    this.serverName,
    this.version,
    this.rawToolResponses = false,
    this.samplingHandler,
    this.elicitationHandler,
    this.notificationHandler,
    this.cacheTtlMillis,
  });
}

/// A client connection to a single MCP server.
///
/// Handles the connection lifecycle and provides methods to discover and
/// invoke remote tools, prompts, and resources.
class GenkitMcpClient {
  final McpClientOptions options;

  mcp.McpClient? _client;
  Completer<void> _readyCompleter = Completer<void>();

  bool _connected = false;
  bool _disabled = false;
  String? _error;
  String? _serverName;
  List<McpRoot> _roots;
  final Map<String, McpTaskState> _tasks = {};
  final Map<Object, num> _progressCounters = {};
  final Set<String> _requestedResourceSubscriptions = {};
  final Set<mcp.McpSubscription> _openingSubscriptions = {};
  _ClientSubscription? _resourceSubscription;
  Future<void> _resourceSubscriptionMutation = Future<void>.value();
  _ClientSubscription? _listChangeSubscription;
  mcp.LoggingLevel? _statelessLogLevel;
  bool _subscriptionsClosing = false;
  int _taskCounter = 0;

  GenkitMcpClient(this.options)
    : _roots = List.of(options.mcpServer.roots ?? const []) {
    _disabled = options.mcpServer.disabled;
    if (_disabled) {
      _readyCompleter.complete();
    } else {
      unawaited(_connect());
    }
  }

  bool get disabled => _disabled;
  bool get enabled => !_disabled;
  String? get error => _error;
  String get serverName => _serverName ?? options.serverName ?? options.name;

  /// The MCP protocol version negotiated with the server.
  String? get protocolVersion => _client?.getProtocolVersion();

  List<McpRoot> get roots => List.unmodifiable(_roots);

  bool isEnabled() => !_disabled;

  Future<void> ready() {
    return _readyCompleter.future;
  }

  Future<void> close() async {
    await _closeSubscriptions();
    await _client?.close();
    _client = null;
    _connected = false;
  }

  Future<void> disable() async {
    _disabled = true;
    await close();
  }

  /// Enables this client and completes once the connection is ready.
  ///
  /// Throws when the connection attempt fails.
  Future<void> enable() async {
    if (!_disabled) return;
    _disabled = false;
    _subscriptionsClosing = false;
    _readyCompleter = Completer<void>();
    await _connect();
    await ready();
  }

  /// Reconnects this client and completes once the new connection is ready.
  ///
  /// Throws when the connection attempt fails.
  Future<void> restart() async {
    await close();
    _disabled = false;
    _subscriptionsClosing = false;
    _readyCompleter = Completer<void>();
    await _connect();
    await ready();
  }

  Future<void> updateRoots(List<McpRoot> roots) async {
    _roots = List.of(roots);
    if (_connected && !_disabled && !_usesStatelessProtocol) {
      await _client!.sendRootsListChanged();
    }
  }

  Future<List<Tool<Map<String, dynamic>, dynamic>>> getActiveTools(
    Genkit ai,
  ) async {
    await ready();
    if (_disabled) return [];
    final tools = await _fetchTools();
    return tools
        .map(_createToolAction)
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
        .map(_createPromptAction)
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
    return _createPromptAction(prompt);
  }

  Future<List<ResourceAction>> getActiveResources(Genkit ai) async {
    await ready();
    if (_disabled) return [];
    final resources = await _fetchResources();
    return resources
        .map(_createResourceAction)
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
    if (meta != null || task != null) {
      return _sendRawRequest(mcp.Method.toolsCall, params);
    }
    return (await _client!.callTool(
      mcp.CallToolRequest(name: name, arguments: arguments ?? const {}),
      options: _requestOptions,
    )).toJson();
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
    if (meta != null || task != null) {
      return _sendRawRequest(mcp.Method.promptsGet, params);
    }
    return (await _client!.getPrompt(
      mcp.GetPromptRequest.fromJson(params),
      _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> readResource({
    required String uri,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    final params = <String, dynamic>{'uri': uri, '_meta': ?meta, 'task': ?task};
    if (meta != null || task != null) {
      return _sendRawRequest(mcp.Method.resourcesRead, params);
    }
    return (await _client!.readResource(
      mcp.ReadResourceRequest(uri: uri),
      _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> listTools({String? cursor}) async {
    return (await _client!.listTools(
      params: cursor == null ? null : mcp.ListToolsRequest(cursor: cursor),
      options: _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> listPrompts({String? cursor}) async {
    return (await _client!.listPrompts(
      params: cursor == null ? null : mcp.ListPromptsRequest(cursor: cursor),
      options: _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> listResources({String? cursor}) async {
    return (await _client!.listResources(
      params: cursor == null ? null : mcp.ListResourcesRequest(cursor: cursor),
      options: _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> listResourceTemplates({String? cursor}) async {
    return (await _client!.listResourceTemplates(
      params: cursor == null
          ? null
          : mcp.ListResourceTemplatesRequest(cursor: cursor),
      options: _requestOptions,
    )).toJson();
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
    if (meta != null || task != null) {
      return _sendRawRequest(mcp.Method.completionComplete, params);
    }
    return (await _client!.complete(
      mcp.CompleteRequest.fromJson(params),
      _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> subscribeResource({
    required String uri,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    if (_usesStatelessProtocol) {
      return _mutateResourceSubscriptions(() async {
        final added = _requestedResourceSubscriptions.add(uri);
        if (!added && _resourceSubscription != null) return {};
        try {
          await _replaceResourceSubscription();
          return {};
        } catch (_) {
          if (added) {
            _requestedResourceSubscriptions.remove(uri);
          }
          rethrow;
        }
      });
    }
    final params = <String, dynamic>{'uri': uri, '_meta': ?meta, 'task': ?task};
    if (meta != null || task != null) {
      return _sendRawRequest(mcp.Method.resourcesSubscribe, params);
    }
    return (await _client!.subscribeResource(
      mcp.SubscribeRequest(uri: uri),
      _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> unsubscribeResource({
    required String uri,
    Object? meta,
    Map<String, dynamic>? task,
  }) async {
    if (_usesStatelessProtocol) {
      return _mutateResourceSubscriptions(() async {
        final removed = _requestedResourceSubscriptions.remove(uri);
        if (!removed) return {};
        try {
          await _replaceResourceSubscription();
          return {};
        } catch (_) {
          _requestedResourceSubscriptions.add(uri);
          rethrow;
        }
      });
    }
    final params = <String, dynamic>{'uri': uri, '_meta': ?meta, 'task': ?task};
    if (meta != null || task != null) {
      return _sendRawRequest(mcp.Method.resourcesUnsubscribe, params);
    }
    return (await _client!.unsubscribeResource(
      mcp.UnsubscribeRequest(uri: uri),
      _requestOptions,
    )).toJson();
  }

  Future<Map<String, dynamic>> setLogLevel(String level) async {
    final logLevel = mcp.LoggingLevel.values.byName(level);
    if (_usesStatelessProtocol) {
      _statelessLogLevel = logLevel;
      return {};
    }
    return (await _client!.setLoggingLevel(logLevel, _requestOptions)).toJson();
  }

  Future<Map<String, dynamic>> ping() async {
    if (_usesStatelessProtocol) {
      final discovery = _client!.discoverServer();
      final timeout = _effectiveTimeout;
      if (timeout == null) {
        await discovery;
      } else {
        await discovery.timeout(timeout);
      }
      return {};
    }
    return (await _client!.ping(_requestOptions)).toJson();
  }

  Future<Map<String, dynamic>> listTasks({String? cursor}) async {
    return _sendRawRequest(
      mcp.Method.tasksList,
      cursor == null ? {} : {'cursor': cursor},
    );
  }

  Future<Map<String, dynamic>> getTask(String taskId) async {
    return _sendRawRequest(mcp.Method.tasksGet, {'taskId': taskId});
  }

  Future<Map<String, dynamic>> getTaskResult(String taskId) async {
    return _sendRawRequest(mcp.Method.tasksResult, {'taskId': taskId});
  }

  Future<Map<String, dynamic>> cancelTask(String taskId) async {
    return _sendRawRequest(mcp.Method.tasksCancel, {'taskId': taskId});
  }

  Future<void> _connect() async {
    if (_connected) return;
    mcp.McpClient? client;
    try {
      client = mcp.McpClient(
        mcp.Implementation(
          name: options.name,
          version: options.version ?? '1.0.0',
        ),
        options: mcp.McpClientOptions(
          capabilities: mcp.ClientCapabilities.fromJson(_clientCapabilities()),
          legacyDiscoveryTimeout:
              _effectiveTimeout ?? const Duration(seconds: 5),
        ),
      );
      _configureClient(client);
      _client = client;
      final connect = client.connect(await _createTransport(options.mcpServer));
      final timeout = _effectiveTimeout;
      if (timeout == null) {
        await connect;
      } else {
        await connect.timeout(timeout);
      }
      final serverInfo = client.getServerVersion();
      if (options.serverName == null && serverInfo != null) {
        _serverName = serverInfo.name;
      }
      _connected = true;
      if (_roots.isNotEmpty) {
        await updateRoots(_roots);
      }
      if (_usesStatelessProtocol) {
        await _startListChangeSubscription();
      }
      _error = null;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    } catch (e, st) {
      _connected = false;
      await _closeSubscriptions();
      try {
        await client?.close();
      } catch (closeError) {
        mcpLogger.warning(
          '[MCP Client] Failed to close after connection error: $closeError',
        );
      }
      if (identical(_client, client)) {
        _client = null;
      }
      final error = e is mcp.McpError ? _toGenkitException(e) : e;
      _error = error.toString();
      _disabled = true;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(error, st);
      }
    }
  }

  void _configureClient(mcp.McpClient client) {
    client.onerror = (error) {
      mcpLogger.warning('[MCP Client] Protocol error: $error');
    };
    client.onclose = () {
      _connected = false;
      mcpLogger.info('[MCP Client] Transport closed.');
    };
    client.setRequestHandler<mcp.JsonRpcListRootsRequest>(
      mcp.Method.rootsList,
      (request, extra) async => mcp.ListRootsResult(
        roots: _roots
            .map((root) => mcp.Root(uri: root.uri, name: root.name))
            .toList(),
      ),
      (id, params, meta) => mcp.JsonRpcListRootsRequest(id: id, meta: meta),
    );
    client.fallbackNotificationHandler = (notification) async {
      _dispatchNotification(
        notification.method,
        notification.params ?? const {},
      );
    };

    _configureSamplingHandler(client);
    _configureElicitationHandler(client);
    _configureTaskHandlers(client);
  }

  bool get _usesStatelessProtocol {
    final version = protocolVersion;
    return version != null && mcp.isStatelessProtocolVersion(version);
  }

  mcp.RequestOptions? get _requestOptions {
    final timeout = _effectiveTimeout;
    final logLevel = _statelessLogLevel;
    if (timeout == null && logLevel == null) return null;
    return mcp.RequestOptions(timeout: timeout, logLevel: logLevel);
  }

  Duration? get _effectiveTimeout {
    final configured = options.mcpServer.timeout;
    if (configured != null) return configured;
    final transport = options.mcpServer.transport;
    if (transport is McpDartClientTransport) {
      return (transport as McpDartClientTransport).requestTimeout;
    }
    return null;
  }

  Future<void> _startListChangeSubscription() async {
    final capabilities = _serverCapabilities;
    final filter = mcp.SubscriptionFilter(
      toolsListChanged: capabilities?.tools?.listChanged == true ? true : null,
      promptsListChanged: capabilities?.prompts?.listChanged == true
          ? true
          : null,
      resourcesListChanged: capabilities?.resources?.listChanged == true
          ? true
          : null,
    );
    if (filter.toJson().isEmpty) return;
    final subscription = await _openSubscription(filter);
    _listChangeSubscription = subscription;
    _watchListChangeSubscription(subscription, filter);
    _logMissingListChangeAcknowledgments(
      requested: filter,
      acknowledged: subscription.acknowledged,
    );
  }

  Future<_ClientSubscription> _openSubscription(
    mcp.SubscriptionFilter filter,
  ) async {
    if (_subscriptionsClosing) {
      throw StateError('MCP client is closing.');
    }
    final subscription = _client!.listenSubscriptions(
      mcp.SubscriptionsListenRequest(notifications: filter),
    );
    _openingSubscriptions.add(subscription);
    final notifications = subscription.notifications.listen(
      (notification) {
        _dispatchNotification(
          notification.method,
          notification.params ?? const {},
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        mcpLogger.warning('[MCP Client] Subscription error: $error');
      },
    );
    try {
      final acknowledgment = subscription.acknowledged;
      final timeout = _effectiveTimeout;
      final acknowledged =
          (await (timeout == null
                  ? acknowledgment
                  : acknowledgment.timeout(timeout)))
              .notifications;
      return _ClientSubscription(subscription, notifications, acknowledged);
    } catch (_) {
      subscription.cancel();
      await notifications.cancel();
      rethrow;
    } finally {
      _openingSubscriptions.remove(subscription);
    }
  }

  Future<void> _closeSubscriptions() async {
    _subscriptionsClosing = true;
    for (final subscription in _openingSubscriptions.toList()) {
      subscription.cancel(StateError('MCP client is closing.'));
    }
    try {
      await _resourceSubscriptionMutation;
    } catch (_) {
      // A failed mutation has already been reported to its caller.
    }
    final subscriptions = <_ClientSubscription>{
      ?_listChangeSubscription,
      ?_resourceSubscription,
    };
    _listChangeSubscription = null;
    _resourceSubscription = null;
    _requestedResourceSubscriptions.clear();
    for (final subscription in subscriptions) {
      await _closeSubscription(subscription);
    }
  }

  Future<void> _closeSubscription(_ClientSubscription subscription) async {
    if (!subscription.cancelled) {
      subscription.cancelled = true;
      subscription.subscription.cancel();
    }
    await _disposeSubscriptionStreams(subscription);
    try {
      await subscription.subscription.done;
    } catch (_) {
      // The connection may have closed before local cancellation completed.
    }
  }

  Future<void> _disposeSubscriptionStreams(_ClientSubscription subscription) {
    return subscription.cleanupFuture ??= () async {
      await subscription.notifications.cancel();
      await subscription.acknowledgmentChanges?.cancel();
    }();
  }

  Future<Map<String, dynamic>> _mutateResourceSubscriptions(
    Future<Map<String, dynamic>> Function() operation,
  ) {
    if (_subscriptionsClosing) {
      return Future.error(StateError('MCP client is closing.'));
    }
    final result = Completer<Map<String, dynamic>>();
    _resourceSubscriptionMutation = _resourceSubscriptionMutation
        .catchError((Object _, StackTrace _) {})
        .then<void>((_) async {
          try {
            result.complete(await operation());
          } catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        });
    return result.future;
  }

  Future<void> _replaceResourceSubscription() async {
    final uris = _requestedResourceSubscriptions.toList()..sort();
    if (uris.isEmpty) {
      final previous = _resourceSubscription;
      _resourceSubscription = null;
      if (previous != null) {
        await _closeSubscription(previous);
      }
      return;
    }

    final next = await _openSubscription(
      mcp.SubscriptionFilter(resourceSubscriptions: uris),
    );
    final acknowledged = next.acknowledged.resourceSubscriptions ?? const [];
    final missing = uris.where((uri) => !acknowledged.contains(uri)).toList();
    if (missing.isNotEmpty) {
      await _closeSubscription(next);
      throw mcp.McpError(
        mcp.ErrorCode.methodNotFound.value,
        'Server did not acknowledge resource subscriptions for '
        '${missing.join(', ')}.',
      );
    }

    final previous = _resourceSubscription;
    _resourceSubscription = next;
    _watchResourceSubscription(next);
    if (previous != null) {
      await _closeSubscription(previous);
    }
  }

  void _watchResourceSubscription(_ClientSubscription subscription) {
    subscription.acknowledgmentChanges = subscription
        .subscription
        .acknowledgmentChanges
        .listen(
          (acknowledgment) {
            final acknowledged = acknowledgment.notifications;
            subscription.acknowledged = acknowledged;
            if (!identical(_resourceSubscription, subscription)) return;
            final accepted = acknowledged.resourceSubscriptions ?? const [];
            final missing = _requestedResourceSubscriptions
                .where((uri) => !accepted.contains(uri))
                .toList();
            if (missing.isEmpty) return;
            _resourceSubscription = null;
            mcpLogger.warning(
              '[MCP Client] Replayed resource subscription no longer '
              'acknowledges: ${missing.join(', ')}',
            );
            unawaited(_closeSubscription(subscription));
          },
          onError: (Object error, StackTrace stackTrace) {
            mcpLogger.warning(
              '[MCP Client] Subscription acknowledgment error: $error',
            );
          },
        );
    _watchSubscriptionDone(subscription, () {
      if (identical(_resourceSubscription, subscription)) {
        _resourceSubscription = null;
      }
    });
  }

  void _watchListChangeSubscription(
    _ClientSubscription subscription,
    mcp.SubscriptionFilter requested,
  ) {
    subscription.acknowledgmentChanges = subscription
        .subscription
        .acknowledgmentChanges
        .listen(
          (acknowledgment) {
            subscription.acknowledged = acknowledgment.notifications;
            _logMissingListChangeAcknowledgments(
              requested: requested,
              acknowledged: acknowledgment.notifications,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            mcpLogger.warning(
              '[MCP Client] Subscription acknowledgment error: $error',
            );
          },
        );
    _watchSubscriptionDone(subscription, () {
      if (identical(_listChangeSubscription, subscription)) {
        _listChangeSubscription = null;
      }
    });
  }

  void _watchSubscriptionDone(
    _ClientSubscription subscription,
    void Function() onDone,
  ) {
    unawaited(
      subscription.subscription.done.then<void>(
        (_) {
          onDone();
          unawaited(_disposeSubscriptionStreams(subscription));
        },
        onError: (Object error, StackTrace stackTrace) {
          onDone();
          mcpLogger.warning('[MCP Client] Subscription closed: $error');
          unawaited(_disposeSubscriptionStreams(subscription));
        },
      ),
    );
  }

  void _logMissingListChangeAcknowledgments({
    required mcp.SubscriptionFilter requested,
    required mcp.SubscriptionFilter acknowledged,
  }) {
    final missing = <String>[
      if (requested.toolsListChanged == true &&
          acknowledged.toolsListChanged != true)
        'tools',
      if (requested.promptsListChanged == true &&
          acknowledged.promptsListChanged != true)
        'prompts',
      if (requested.resourcesListChanged == true &&
          acknowledged.resourcesListChanged != true)
        'resources',
    ];
    if (missing.isNotEmpty) {
      mcpLogger.warning(
        '[MCP Client] Server did not acknowledge list-change '
        'subscriptions for: ${missing.join(', ')}',
      );
    }
  }

  void _configureSamplingHandler(mcp.McpClient client) {
    final handler = options.samplingHandler;
    if (handler == null) return;
    client.removeRequestHandler(mcp.Method.samplingCreateMessage);
    client.setRequestHandler<mcp.JsonRpcCreateMessageRequest>(
      mcp.Method.samplingCreateMessage,
      (request, extra) async {
        final params = _withMeta(request.createParams.toJson(), request.meta);
        return _respondWithClientTask(
          params,
          () async => _samplingResult(await handler(params)),
        );
      },
      (id, params, meta) => mcp.JsonRpcCreateMessageRequest(
        id: id,
        createParams: mcp.CreateMessageRequest.fromJson(params ?? const {}),
        meta: meta,
      ),
    );
  }

  void _configureElicitationHandler(mcp.McpClient client) {
    final handler = options.elicitationHandler;
    if (handler == null) return;
    client.removeRequestHandler(mcp.Method.elicitationCreate);
    client.setRequestHandler<mcp.JsonRpcElicitRequest>(
      mcp.Method.elicitationCreate,
      (request, extra) async {
        final protocolVersion =
            request.meta?[mcp.McpMetaKey.protocolVersion] as String? ??
            client.getProtocolVersion();
        final params = _withMeta(
          request.elicitParams.toJson(protocolVersion: protocolVersion),
          request.meta,
        );
        return _respondWithClientTask(
          params,
          () async => mcp.ElicitResult.fromJson(await handler(params)),
        );
      },
      (id, params, meta) {
        final protocolVersion =
            meta?[mcp.McpMetaKey.protocolVersion] as String? ??
            client.getProtocolVersion();
        return mcp.JsonRpcElicitRequest(
          id: id,
          elicitParams: mcp.ElicitRequest.fromJson(
            params ?? const {},
            protocolVersion: protocolVersion,
          ),
          meta: meta,
          protocolVersion: protocolVersion,
        );
      },
    );
  }

  void _configureTaskHandlers(mcp.McpClient client) {
    if (options.samplingHandler == null && options.elicitationHandler == null) {
      return;
    }
    client.setRequestHandler<mcp.JsonRpcListTasksRequest>(
      mcp.Method.tasksList,
      (request, extra) async => mcp.ListTasksResult(
        tasks: _listClientTasks().map(mcp.Task.fromJson).toList(),
      ),
      (id, params, meta) => mcp.JsonRpcListTasksRequest.fromJson({
        'jsonrpc': '2.0',
        'id': id,
        'method': mcp.Method.tasksList,
        'params': ?params,
        '_meta': ?meta,
      }),
    );
    client.setRequestHandler<mcp.JsonRpcGetTaskRequest>(
      mcp.Method.tasksGet,
      (request, extra) async =>
          mcp.Task.fromJson(_getClientTask(request.getParams.taskId)),
      (id, params, meta) => mcp.JsonRpcGetTaskRequest.fromJson({
        'jsonrpc': '2.0',
        'id': id,
        'method': mcp.Method.tasksGet,
        'params': params,
        '_meta': ?meta,
      }),
    );
    client.setRequestHandler<mcp.JsonRpcTaskResultRequest>(
      mcp.Method.tasksResult,
      (request, extra) async =>
          _getClientTaskResult(request.resultParams.taskId),
      (id, params, meta) => mcp.JsonRpcTaskResultRequest.fromJson({
        'jsonrpc': '2.0',
        'id': id,
        'method': mcp.Method.tasksResult,
        'params': params,
        '_meta': ?meta,
      }),
    );
    client.setRequestHandler<mcp.JsonRpcCancelTaskRequest>(
      mcp.Method.tasksCancel,
      (request, extra) async =>
          mcp.Task.fromJson(_cancelClientTask(request.cancelParams.taskId)),
      (id, params, meta) => mcp.JsonRpcCancelTaskRequest.fromJson({
        'jsonrpc': '2.0',
        'id': id,
        'method': mcp.Method.tasksCancel,
        'params': params,
        '_meta': ?meta,
      }),
    );
  }

  Map<String, dynamic> _withMeta(
    Map<String, dynamic> params,
    Map<String, dynamic>? meta,
  ) {
    return {...params, '_meta': ?meta};
  }

  mcp.CreateMessageResult _samplingResult(Map<String, dynamic> result) {
    final message = result['message'];
    if (message is Map) {
      return mcp.CreateMessageResult.fromJson(
        {...result, ...message.cast<String, dynamic>()}..remove('message'),
      );
    }
    return mcp.CreateMessageResult.fromJson(result);
  }

  Future<mcp.Transport> _createTransport(McpServerConfig config) async {
    final customTransport = config.transport;
    if (customTransport != null) {
      if (customTransport is McpDartClientTransport) {
        return (customTransport as McpDartClientTransport).mcpDartTransport;
      }
      return _adaptTransport(customTransport);
    }
    final url = config.url;
    if (url != null) {
      return mcp.StreamableHttpClientTransport(
        url,
        opts: mcp.StreamableHttpClientTransportOptions(
          requestInit: {
            if (config.headers != null)
              'headers': <String, dynamic>{...config.headers!},
          },
        ),
      );
    }
    final command = config.command;
    if (command == null) {
      throw GenkitException(
        '[MCP Client] Could not determine valid transport config from supplied options.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    return mcp.StdioClientTransport(
      mcp.StdioServerParameters(
        command: command,
        args: config.args,
        environment: config.environment,
      ),
    );
  }

  mcp.Transport _adaptTransport(McpClientTransport transport) {
    return McpDartTransport(
      inbound: transport.inbound,
      send: transport.send,
      close: transport.close,
    );
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

  mcp.ServerCapabilities? get _serverCapabilities =>
      _client?.getServerCapabilities();

  bool get _supportsTools => _serverCapabilities?.tools != null;
  bool get _supportsPrompts => _serverCapabilities?.prompts != null;
  bool get _supportsResources => _serverCapabilities?.resources != null;

  Future<List<Map<String, dynamic>>> _fetchTools() async {
    if (!_supportsTools) return [];
    return _listAll('tools', listTools);
  }

  Future<List<Map<String, dynamic>>> _fetchPrompts() async {
    if (!_supportsPrompts) return [];
    return _listAll('prompts', listPrompts);
  }

  Future<List<Map<String, dynamic>>> _fetchResources() async {
    if (!_supportsResources) return [];
    return [
      ...await _listAll('resources', listResources),
      ...await _listAll('resourceTemplates', listResourceTemplates),
    ];
  }

  Tool<Map<String, dynamic>, dynamic>? _createToolAction(
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
      outputSchema: .dynamicSchema(),
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
    Map<String, dynamic> prompt,
  ) {
    final name = prompt['name'];
    if (name is! String) return null;
    final description = prompt['description']?.toString();
    final meta = extractMcpMeta(prompt);
    final args = asListOfMaps(prompt['arguments']);
    final inputSchema = promptSchemaFromArgs(args);
    return PromptAction<Map<String, dynamic>>(
      name: '$serverName/$name',
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
        return GenerateActionOptions(messages: messages);
      },
    );
  }

  ResourceAction? _createResourceAction(Map<String, dynamic> resource) {
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
      matches: createResourceMatcher(uri: uri, template: template),
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

  Future<Map<String, dynamic>> _sendRawRequest(
    String method,
    Map<String, dynamic>? params,
  ) async {
    if (method.startsWith('tasks/') && _serverCapabilities?.tasks == null) {
      throw mcp.McpError(
        mcp.ErrorCode.invalidRequest.value,
        'Server does not advertise task support.',
      );
    }
    final result = await _client!.request<_RawMcpResult>(
      mcp.JsonRpcRequest(id: -1, method: method, params: params),
      _RawMcpResult.fromJson,
      _requestOptions,
    );
    return result.toJson();
  }

  GenkitException _toGenkitException(mcp.McpError error) {
    return GenkitException(
      error.message,
      status: error.code >= 100
          ? StatusCodes.fromHttpStatus(error.code)
          : StatusCodes.INTERNAL,
      details: error.data?.toString(),
    );
  }

  void _dispatchNotification(String method, Map<String, dynamic> params) {
    if (method == mcp.Method.notificationsToolsListChanged ||
        method == mcp.Method.notificationsPromptsListChanged ||
        method == mcp.Method.notificationsResourcesListChanged) {
      invalidateCache();
    }
    options.notificationHandler?.call(method, params);
  }

  Future<mcp.BaseResultData> _respondWithClientTask(
    Map<String, dynamic> params,
    Future<mcp.BaseResultData> Function() action,
  ) {
    final taskMeta = params['task'];
    if (taskMeta is Map) {
      final task = _createClientTask(
        meta: taskMeta.cast<String, dynamic>(),
        progressToken: _extractProgressToken(params),
        action: action,
      );
      return Future.value(
        mcp.CreateTaskResult(task: mcp.Task.fromJson(task.toJson())),
      );
    }
    return action();
  }

  McpTaskState _createClientTask({
    required Map<String, dynamic> meta,
    required Object? progressToken,
    required Future<mcp.BaseResultData> Function() action,
  }) {
    final task = McpTaskState(
      id: _nextTaskId(),
      ttl: (meta['ttl'] as num?)?.toInt(),
    );
    _tasks[task.id] = task;
    unawaited(_notifyTaskStatus(task));
    unawaited(_runClientTask(task, progressToken, action));
    return task;
  }

  Future<void> _runClientTask(
    McpTaskState task,
    Object? progressToken,
    Future<mcp.BaseResultData> Function() action,
  ) async {
    await _sendProgress(progressToken, message: 'started');
    try {
      final result = await action();
      if (task.isCancelled) return;
      task.complete(result.toJson());
      await _sendProgress(progressToken, message: 'completed');
    } catch (error) {
      if (task.isCancelled) return;
      task.fail(toJsonRpcError(error));
      await _sendProgress(progressToken, message: 'failed');
    } finally {
      await _notifyTaskStatus(task);
      if (progressToken != null) {
        _progressCounters.remove(progressToken);
      }
    }
  }

  List<Map<String, dynamic>> _listClientTasks() {
    _purgeExpiredTasks();
    return _tasks.values.map((task) => task.toJson()).toList();
  }

  Map<String, dynamic> _getClientTask(String taskId) {
    _purgeExpiredTasks();
    final task = _tasks[taskId];
    if (task == null) {
      throw mcp.McpError(
        mcp.ErrorCode.invalidParams.value,
        'Task "$taskId" not found.',
      );
    }
    return task.toJson();
  }

  mcp.BaseResultData _getClientTaskResult(String taskId) {
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
    return _RawMcpResult(task.result ?? const {});
  }

  Map<String, dynamic> _cancelClientTask(String taskId) {
    _purgeExpiredTasks();
    final task = _tasks[taskId];
    if (task == null) {
      throw mcp.McpError(
        mcp.ErrorCode.invalidParams.value,
        'Task "$taskId" not found.',
      );
    }
    task.cancel('Cancelled by request');
    unawaited(_notifyTaskStatus(task));
    return task.toJson();
  }

  Future<void> _sendProgress(
    Object? progressToken, {
    required String message,
  }) async {
    if (progressToken == null || _client == null) return;
    final current = (_progressCounters[progressToken] ?? 0) + 1;
    _progressCounters[progressToken] = current;
    await _client!.notification(
      mcp.JsonRpcNotification(
        method: mcp.Method.notificationsProgress,
        params: {
          'progressToken': progressToken,
          'progress': current,
          'message': message,
        },
      ),
    );
  }

  Future<void> _notifyTaskStatus(McpTaskState task) async {
    if (_client == null) return;
    final value = task.toJson();
    await _client!.notification(
      mcp.JsonRpcTaskStatusNotification(
        statusParams: mcp.TaskStatusNotification.fromJson(value),
      ),
    );
  }

  void _purgeExpiredTasks() {
    final now = DateTime.now();
    _tasks.removeWhere((_, task) => task.isExpired(now));
  }

  String _nextTaskId() {
    _taskCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_taskCounter';
  }

  Object? _extractProgressToken(Map<String, dynamic> params) {
    final meta = params['_meta'];
    return meta is Map ? meta['progressToken'] : null;
  }

  int? get cacheTtlMillis => options.cacheTtlMillis;

  final Map<String, _McpClientActionDescriptor> _actionIndex = {};
  List<ActionMetadata> _cachedActions = [];
  DateTime? _cacheExpiresAt;
  int _cacheGeneration = 0;
  _ActionCacheBuild? _inflight;

  void invalidateCache() {
    _cacheGeneration += 1;
    _cachedActions = [];
    _cacheExpiresAt = null;
    _actionIndex.clear();
  }

  Future<List<ActionMetadata>> getCachedActions() async {
    while (true) {
      final now = DateTime.now();
      if (_shouldUseCache() &&
          _cacheExpiresAt != null &&
          now.isBefore(_cacheExpiresAt!)) {
        return _cachedActions;
      }

      final generation = _cacheGeneration;
      var build = _inflight;
      if (build == null || build.generation != generation) {
        build = _ActionCacheBuild(generation, _buildCache(generation));
        _inflight = build;
      }

      try {
        final actions = await build.future;
        if (generation == _cacheGeneration) return actions;
      } finally {
        if (identical(_inflight, build)) {
          _inflight = null;
        }
      }
    }
  }

  Action? resolveAction(String actionName) {
    final descriptor = _actionIndex[actionName];
    if (descriptor == null) return null;

    switch (descriptor.actionType) {
      case 'tool':
        return _createToolAction(descriptor.payload);
      case 'executable-prompt':
        return _createPromptAction(descriptor.payload);
      case 'resource':
        return _createResourceAction(descriptor.payload);
      default:
        return null;
    }
  }

  Future<List<ActionMetadata>> _buildCache(int generation) async {
    await ready();
    if (disabled) return [];
    final actions = <ActionMetadata>[];
    final index = <String, _McpClientActionDescriptor>{};
    int? serverTtlMillis;

    void observeCacheMetadata(Map<String, dynamic> result) {
      final value = result['ttlMs'];
      if (value is! num || value < 0) return;
      final ttl = value.toInt();
      if (serverTtlMillis == null || ttl < serverTtlMillis!) {
        serverTtlMillis = ttl;
      }
    }

    final tools = _supportsTools
        ? await _listAll('tools', listTools, onPage: observeCacheMetadata)
        : const <Map<String, dynamic>>[];
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
          outputSchema: .dynamicSchema(),
          metadata: meta == null
              ? null
              : {
                  'mcp': {'_meta': meta},
                },
        ),
      );
      index[fullName] = _McpClientActionDescriptor(
        actionType: 'tool',
        payload: tool,
      );
    }

    final prompts = _supportsPrompts
        ? await _listAll('prompts', listPrompts, onPage: observeCacheMetadata)
        : const <Map<String, dynamic>>[];
    for (final prompt in prompts) {
      final promptName = prompt['name'];
      if (promptName is! String) continue;
      final fullName = '$serverName/$promptName';
      final meta = extractMcpMeta(prompt);
      final args = asListOfMaps(prompt['arguments']);
      actions.add(
        ActionMetadata(
          name: fullName,
          actionType: 'executable-prompt',
          description: prompt['description']?.toString(),
          inputSchema: promptSchemaFromArgs(args),
          outputSchema: GenerateActionOptions.$schema,
          metadata: meta == null
              ? null
              : {
                  'mcp': {'_meta': meta},
                },
        ),
      );
      index[fullName] = _McpClientActionDescriptor(
        actionType: 'executable-prompt',
        payload: prompt,
      );
    }

    final resources = _supportsResources
        ? await _listAll(
            'resources',
            listResources,
            onPage: observeCacheMetadata,
          )
        : const <Map<String, dynamic>>[];
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
      index[fullName] = _McpClientActionDescriptor(
        actionType: 'resource',
        payload: resource,
      );
    }

    final templates = _supportsResources
        ? await _listAll(
            'resourceTemplates',
            listResourceTemplates,
            onPage: observeCacheMetadata,
          )
        : const <Map<String, dynamic>>[];
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
      index[fullName] = _McpClientActionDescriptor(
        actionType: 'resource',
        payload: template,
      );
    }

    if (generation != _cacheGeneration) return actions;

    _actionIndex
      ..clear()
      ..addAll(index);
    _cachedActions = actions;
    final effectiveTtl = _effectiveCacheTtlMillis(serverTtlMillis);
    if (_shouldUseCache() && effectiveTtl > 0) {
      _cacheExpiresAt = DateTime.now().add(
        Duration(milliseconds: effectiveTtl),
      );
    } else {
      _cacheExpiresAt = null;
    }
    return actions;
  }

  bool _shouldUseCache() {
    return cacheTtlMillis == null || cacheTtlMillis! >= 0;
  }

  int _effectiveCacheTtlMillis(int? serverTtlMillis) {
    final configured = cacheTtlMillis;
    if (configured != null && configured != 0) return configured.abs();
    if (_usesStatelessProtocol && serverTtlMillis != null) {
      return serverTtlMillis;
    }
    return 3000;
  }

  static Future<List<Map<String, dynamic>>> _listAll(
    String resultKey,
    Future<Map<String, dynamic>> Function({String? cursor}) lister, {
    void Function(Map<String, dynamic> result)? onPage,
  }) async {
    final items = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final result = await lister(cursor: cursor);
      onPage?.call(result);
      items.addAll(asListOfMaps(result[resultKey]));
      cursor = result['nextCursor'] as String?;
    } while (cursor != null);
    return items;
  }
}

class _ClientSubscription {
  final mcp.McpSubscription subscription;
  final StreamSubscription<mcp.JsonRpcNotification> notifications;
  mcp.SubscriptionFilter acknowledged;
  StreamSubscription<mcp.SubscriptionsAcknowledgedNotification>?
  acknowledgmentChanges;
  Future<void>? cleanupFuture;
  bool cancelled = false;

  _ClientSubscription(this.subscription, this.notifications, this.acknowledged);
}

class _RawMcpResult implements mcp.BaseResultData {
  final Map<String, dynamic> data;

  const _RawMcpResult(this.data);

  factory _RawMcpResult.fromJson(Map<String, dynamic> json) {
    return _RawMcpResult(Map<String, dynamic>.from(json));
  }

  @override
  Map<String, dynamic>? get meta {
    final value = data['_meta'];
    return value is Map ? value.cast<String, dynamic>() : null;
  }

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}

class _McpClientActionDescriptor {
  final String actionType;
  final Map<String, dynamic> payload;

  _McpClientActionDescriptor({required this.actionType, required this.payload});
}

class _ActionCacheBuild {
  final int generation;
  final Future<List<ActionMetadata>> future;

  _ActionCacheBuild(this.generation, this.future);
}
