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

import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../schema.dart';
import '../../types.dart';
import '../../utils.dart';
import '../registry.dart';

final _logger = Logger('genkit.reflection.v2');

const genkitReflectionApiSpecVersion = 2;

int reflectionInstanceCount = 0;

class ReflectionServerV2 {
  final Registry registry;
  final String url;
  final List<String> configuredEnvs;
  final String? name;
  final String runtimeId;

  WebSocketChannel? _ws;
  final int _apiIndex = reflectionInstanceCount++;
  final Map<dynamic, StreamController> _inputStreams = {};

  ReflectionServerV2(
    this.registry, {
    required this.url,
    this.configuredEnvs = const [],
    this.name,
    required this.runtimeId,
  });

  Future<void> start() async {
    _logger.info('Connecting to Reflection V2 server at $url');
    try {
      _ws = WebSocketChannel.connect(Uri.parse(url));
      _logger.info('Connected to Reflection V2 server.');

      _register();

      _ws!.stream.listen(
        (data) {
          if (data is String) {
            _handleMessage(data);
          }
        },
        onDone: () {
          _logger.info('Reflection V2 WebSocket closed.');
        },
        onError: (error) {
          _logger.severe('Reflection V2 WebSocket error: $error');
        },
      );
    } catch (e) {
      _logger.severe('Failed to connect to Reflection V2 server: $e');
    }
  }

  Future<void> stop() async {
    await _ws?.sink.close();
    _ws = null;
  }

  void _send(Map<String, dynamic> message) {
    if (_ws != null) {
      try {
        _ws!.sink.add(jsonEncode(message));
      } catch (e) {
        _logger.severe('Error sending message: $e');
      }
    }
  }

  void _sendResponse(String id, dynamic result) {
    _send({'jsonrpc': '2.0', 'result': result, 'id': id});
  }

  void _sendError(String? id, int code, String message, [dynamic data]) {
    _send({
      'jsonrpc': '2.0',
      'error': {'code': code, 'message': message, 'data': ?data},
      'id': id,
    });
  }

  void _sendNotification(String method, dynamic params) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  String get _runtimeId => runtimeId.isEmpty
      ? '${getPid() == 0 ? 'web' : getPid()}${_apiIndex > 0 ? '-$_apiIndex' : ''}'
      : runtimeId;

  void _register() {
    final params = ReflectionRegisterParams(
      id: _runtimeId,
      pid: getPid(),
      name: name ?? _runtimeId,
      genkitVersion: genkitVersion,
      reflectionApiSpecVersion: genkitReflectionApiSpecVersion.toDouble(),
      envs: configuredEnvs,
    );
    _send({
      'jsonrpc': '2.0',
      'method': 'register',
      'params': params.toJson(),
      'id': '$_runtimeId-register',
    });
  }

  Future<void> _handleMessage(String data) async {
    try {
      final message = jsonDecode(data) as Map<String, dynamic>;
      if (message.containsKey('method')) {
        await _handleRequest(message);
      } else if (message.containsKey('id')) {
        _handleResponse(message);
      }
    } catch (e, stack) {
      _logger.severe('Error handling message: $e', stack);
    }
  }

  void _handleResponse(Map<String, dynamic> response) {
    final id = response['id'];
    final result = response['result'];
    final error = response['error'];

    if (id == '$_runtimeId-register') {
      if (error != null) {
        _logger.severe('Failed to register with Manager: $error');
      } else {
        _logger.info('Successfully registered with Manager. Config: $result');
      }
    }
  }

  Future<void> _handleRequest(Map<String, dynamic> request) async {
    final method = request['method'];
    final id = request['id'] as String?;

    try {
      switch (method) {
        case 'listActions':
          await _handleListActions(id);
        case 'listValues':
          final params = request['params'] != null
              ? ReflectionListValuesParams.fromJson(
                  request['params'] as Map<String, dynamic>,
                )
              : null;
          await _handleListValues(id, params);
        case 'runAction':
          final params = ReflectionRunActionParams.fromJson(
            request['params'] as Map<String, dynamic>,
          );
          await _handleRunAction(id, params);
        case 'sendInputStreamChunk':
          final params = ReflectionSendInputStreamChunkParams.fromJson(
            request['params'] as Map<String, dynamic>,
          );
          await _handleSendInputStreamChunk(params);
        case 'endInputStream':
          final params = ReflectionEndInputStreamParams.fromJson(
            request['params'] as Map<String, dynamic>,
          );
          await _handleEndInputStream(params);
        default:
          if (id != null) {
            _sendError(id, -32601, 'Method not found: $method');
          }
      }
    } catch (e, stack) {
      if (id != null) {
        _sendError(id, -32000, e.toString(), {'stack': stack.toString()});
      }
    }
  }

  Future<void> _handleListActions(String? id) async {
    if (id == null) return;
    final actions = await registry.listActions();
    final convertedActions = <String, dynamic>{};
    for (final action in actions) {
      final key = getKey(action.actionType, action.name);
      convertedActions[key] = {
        'key': key,
        'name': action.name,
        if (action.metadata['description'] != null)
          'description': action.metadata['description'],
        'metadata': action.metadata,
        if (action.inputSchema != null)
          'inputSchema': toJsonSchema(type: action.inputSchema),
        if (action.outputSchema != null)
          'outputSchema': toJsonSchema(type: action.outputSchema),
        if (action.initSchema != null)
          'initSchema': toJsonSchema(type: action.initSchema),
      };
    }
    final response = ReflectionListActionsResponse(actions: convertedActions);
    _sendResponse(id, response.toJson());
  }

  Future<void> _handleListValues(
    String? id,
    ReflectionListValuesParams? params,
  ) async {
    if (id == null) return;
    final type = params?.type;
    if (type == null) {
      _sendError(id, -32602, 'Missing type parameter for listValues');
      return;
    }
    final values = registry.listValues<dynamic>(type);
    final response = ReflectionListValuesResponse(values: values);
    _sendResponse(id, response.toJson());
  }

  Future<void> _handleRunAction(
    String? id,
    ReflectionRunActionParams params,
  ) async {
    if (id == null) return;
    final key = params.key;
    final input = params.input;
    final context = params.context as Map<String, dynamic>?;
    final stream = params.stream == true;
    final streamInput = params.streamInput == true;

    final parts = key.split('/');
    if (parts.length < 3 || parts[0] != '') {
      _sendError(id, 404, 'Invalid action key format');
      return;
    }

    final action = await registry.lookupAction(parts[1], parts[2]);
    if (action == null) {
      _sendError(id, 404, 'action $key not found');
      return;
    }

    Stream<dynamic>? inputStream;
    if (streamInput) {
      final controller = StreamController<dynamic>();
      _inputStreams[id] = controller;
      inputStream = controller.stream;
    }

    try {
      if (stream) {
        final result = await action.runRaw(
          input,
          onChunk: (chunk) {
            final params = ReflectionStreamChunkParams(
              requestId: id.toString(),
              chunk: chunk,
            );
            _sendNotification('streamChunk', params.toJson());
          },
          onTraceStart: ({required String traceId, required String spanId}) {
            final params = ReflectionRunActionStateParams(
              requestId: id.toString(),
              state: {'traceId': traceId, 'spanId': spanId},
            );
            _sendNotification('runActionState', params.toJson());
          },
          context: context,
          inputStream: inputStream,
        );

        _sendResponse(id, {
          'result': result.result,
          'telemetry': {'traceId': result.traceId},
        });
      } else {
        final result = await action.runRaw(
          input,
          onTraceStart: ({required String traceId, required String spanId}) {
            final params = ReflectionRunActionStateParams(
              requestId: id.toString(),
              state: {'traceId': traceId, 'spanId': spanId},
            );
            _sendNotification('runActionState', params.toJson());
          },
          context: context,
          inputStream: inputStream,
        );
        _sendResponse(id, {
          'result': result.result,
          'telemetry': {'traceId': result.traceId},
        });
      }
    } catch (e, stack) {
      _logger.severe('Error running action: $e', stack);
      final errorResponse = {
        'code': 13, // StatusCodes.INTERNAL
        'message': e.toString(),
        'details': {'stack': stack.toString()},
      };
      _sendError(id, -32000, e.toString(), errorResponse);
    }
  }

  Future<void> _handleSendInputStreamChunk(
    ReflectionSendInputStreamChunkParams params,
  ) async {
    final id = params.requestId;
    final chunk = params.chunk;
    if (_inputStreams.containsKey(id)) {
      _inputStreams[id]!.add(chunk);
    }
  }

  Future<void> _handleEndInputStream(
    ReflectionEndInputStreamParams params,
  ) async {
    final id = params.requestId;
    if (_inputStreams.containsKey(id)) {
      await _inputStreams[id]!.close();
      _inputStreams.remove(id);
    }
  }
}
