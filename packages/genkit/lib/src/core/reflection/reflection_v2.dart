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

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../exception.dart';
import '../../schema.dart';
import '../../utils.dart';
import '../registry.dart';

const genkitVersion = '0.9.0';
const genkitReflectionApiSpecVersion = 2;

int reflectionInstanceCount = 0;

class ReflectionServerV2 {
  final Registry registry;
  final String url;
  final List<String> configuredEnvs;
  final String? name;

  WebSocketChannel? _ws;
  final String _pid = getPid();
  final int _apiIndex = reflectionInstanceCount++;
  final Map<dynamic, StreamController> _inputStreams = {};

  ReflectionServerV2(
    this.registry, {
    required this.url,
    this.configuredEnvs = const ['dev'],
    this.name,
  });

  Future<void> start() async {
    print('Connecting to Reflection V2 server at $url');
    try {
      _ws = WebSocketChannel.connect(Uri.parse(url));
      print('Connected to Reflection V2 server.');

      _register();

      _ws!.stream.listen(
        (data) {
          if (data is String) {
            _handleMessage(data);
          }
        },
        onDone: () {
          print('Reflection V2 WebSocket closed.');
        },
        onError: (error) {
          print('Reflection V2 WebSocket error: $error');
        },
      );
    } catch (e) {
      print('Failed to connect to Reflection V2 server: $e');
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
        print('Error sending message: $e');
      }
    }
  }

  void _sendResponse(dynamic id, dynamic result) {
    _send({'jsonrpc': '2.0', 'result': result, 'id': id});
  }

  void _sendError(dynamic id, int code, String message, [dynamic data]) {
    _send({
      'jsonrpc': '2.0',
      'error': {'code': code, 'message': message, 'data': ?data},
      'id': id,
    });
  }

  void _sendNotification(String method, dynamic params) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  String get _runtimeId => '$_pid${_apiIndex > 0 ? '-$_apiIndex' : ''}';

  void _register() {
    final params = {
      'id': getEnvVar('GENKIT_RUNTIME_ID') ?? _runtimeId,
      'pid': _pid,
      'name': name ?? _runtimeId,
      'genkitVersion': genkitVersion,
      'reflectionApiSpecVersion': genkitReflectionApiSpecVersion,
      'envs': configuredEnvs,
    };
    _sendNotification('register', params);
  }

  Future<void> _handleMessage(String data) async {
    try {
      final message = jsonDecode(data) as Map<String, dynamic>;
      if (message.containsKey('method')) {
        await _handleRequest(message);
      }
    } catch (e, stack) {
      print('Error handling message: $e\n$stack');
    }
  }

  Future<void> _handleRequest(Map<String, dynamic> request) async {
    final method = request['method'];
    final id = request['id'];

    try {
      switch (method) {
        case 'listActions':
          await _handleListActions(id);
          break;
        case 'runAction':
          await _handleRunAction(id, request['params']);
          break;
        case 'configure':
          // Not implemented yet
          break;
        case 'streamInputChunk':
          await _handleStreamInputChunk(request['params']);
          break;
        case 'endStreamInput':
          await _handleEndStreamInput(request['params']);
          break;
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

  Future<void> _handleListActions(dynamic id) async {
    if (id == null) return;
    final actions = await registry.listActions();
    final convertedActions = <String, dynamic>{};
    for (final action in actions) {
      final key = getKey(action.actionType, action.name);
      convertedActions[key] = {
        'key': key,
        'name': action.name,
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
    _sendResponse(id, convertedActions);
  }

  Future<void> _handleRunAction(dynamic id, Map<String, dynamic> params) async {
    if (id == null) return;

    final key = params['key'] as String;
    final input = params['input'];
    final context = params['context'] as Map<String, dynamic>?;
    final stream = params['stream'] == true;
    final streamInput = params['streamInput'] == true;

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
            _sendNotification('streamChunk', {'requestId': id, 'chunk': chunk});
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
          context: context,
          inputStream: inputStream,
        );
        _sendResponse(id, {
          'result': result.result,
          'telemetry': {'traceId': result.traceId},
        });
      }
    } catch (e, stack) {
      printError(e, stack);
      final errorResponse = {
        'code': 13, // StatusCodes.INTERNAL
        'message': e.toString(),
        'details': {'stack': stack.toString()},
      };
      _sendError(id, -32000, e.toString(), errorResponse);
    }
  }

  Future<void> _handleStreamInputChunk(Map<String, dynamic> params) async {
    final id = params['requestId'];
    final chunk = params['chunk'];
    if (id != null && _inputStreams.containsKey(id)) {
      _inputStreams[id]!.add(chunk);
    }
  }

  Future<void> _handleEndStreamInput(Map<String, dynamic> params) async {
    final id = params['requestId'];
    if (id != null && _inputStreams.containsKey(id)) {
      await _inputStreams[id]!.close();
      _inputStreams.remove(id);
    }
  }
}
