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
import 'package:genkit_mcp/genkit_mcp.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

class _PromptInputSchema extends SchemanticType<Map<String, dynamic>> {
  const _PromptInputSchema();

  @override
  Map<String, dynamic> parse(dynamic input) {
    return input as Map<String, dynamic>;
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: Schema.fromMap({
      'type': 'object',
      'properties': {
        'input': {'type': 'string'},
      },
      'required': ['input'],
    }),
    dependencies: const [],
  );
}

GenkitMcpServer _createServer(Genkit ai) {
  return GenkitMcpServer(
    ai,
    McpServerOptions(name: 'test-server', version: '0.0.1'),
  );
}

Future<Map<String, dynamic>?> _request(
  GenkitMcpServer server,
  String method, {
  Object? id,
  Map<String, dynamic>? params,
}) {
  return server.handleRequest({
    'jsonrpc': '2.0',
    'id': ?id,
    'method': method,
    'params': ?params,
  });
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<Object?> _asList(Object? value) {
  if (value is List) return value.cast<Object?>();
  return const [];
}

class _Unencodable {
  @override
  String toString() => 'unencodable';
}

class _EnumPromptSchema extends SchemanticType<Map<String, dynamic>> {
  const _EnumPromptSchema();

  @override
  Map<String, dynamic> parse(dynamic input) {
    return input as Map<String, dynamic>;
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: Schema.fromMap({
      'type': 'object',
      'properties': {
        'color': {
          'type': 'string',
          'enum': ['red', 'blue'],
        },
      },
      'required': ['color'],
    }),
    dependencies: const [],
  );
}

class _FakeServerTransport implements McpServerTransport {
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();
  final List<Map<String, dynamic>> sent = [];

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    sent.add(message);
  }

  @override
  Future<void> close() async {
    await _inboundController.close();
  }
}

void main() {
  test('MCP server lists and executes actions', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'testTool',
      description: 'test tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (input, _) async => 'yep ${jsonEncode(input)}',
    );
    ai.definePrompt<Map<String, dynamic>>(
      name: 'testPrompt',
      description: 'test prompt',
      inputSchema: const _PromptInputSchema(),
      fn: (input, _) async {
        return GenerateActionOptions(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'prompt says: ${input['input']}')],
            ),
          ],
        );
      },
    );
    ai.defineResource(
      name: 'testResources',
      uri: 'my://resource',
      fn: (input, _) async {
        return ResourceOutput(content: [TextPart(text: 'my resource')]);
      },
    );
    ai.defineResource(
      name: 'testTmpl',
      template: 'file://{path}',
      fn: (input, _) async {
        return ResourceOutput(
          content: [TextPart(text: 'file contents for ${input.uri}')],
        );
      },
    );

    final server = _createServer(ai);

    final init = await _request(server, 'initialize', id: 1, params: {});
    final initResult = init?['result'] as Map<String, dynamic>?;
    expect(initResult?['protocolVersion'], '2025-11-25');

    final tools = await _request(server, 'tools/list', id: 2, params: {});
    final toolsResult = _asMap(tools?['result']);
    final toolList = _asList(toolsResult['tools']);
    final toolEntry = _asMap(toolList.first);
    expect(toolEntry['name'], 'testTool');

    final toolCall = await _request(
      server,
      'tools/call',
      id: 3,
      params: {
        'name': 'testTool',
        'arguments': {'foo': 'bar'},
      },
    );
    final toolCallResult = _asMap(toolCall?['result']);
    final toolContent = _asList(toolCallResult['content']);
    final toolFirst = _asMap(toolContent.first);
    expect(toolFirst['text'], 'yep {"foo":"bar"}');

    final prompts = await _request(server, 'prompts/list', id: 4, params: {});
    final promptsResult = _asMap(prompts?['result']);
    final promptList = _asList(promptsResult['prompts']);
    final promptEntry = _asMap(promptList.first);
    expect(promptEntry['name'], 'testPrompt');

    final prompt = await _request(
      server,
      'prompts/get',
      id: 5,
      params: {
        'name': 'testPrompt',
        'arguments': {'input': 'hello'},
      },
    );
    final promptResult = _asMap(prompt?['result']);
    final promptMessages = _asList(promptResult['messages']);
    final promptMessage = _asMap(promptMessages.first);
    final promptContent = _asMap(promptMessage['content']);
    expect(promptContent['text'], 'prompt says: hello');

    final resources = await _request(
      server,
      'resources/list',
      id: 6,
      params: {},
    );
    final resourcesResult = _asMap(resources?['result']);
    final resourceList = _asList(resourcesResult['resources']);
    final resourceEntry = _asMap(resourceList.first);
    expect(resourceEntry['uri'], 'my://resource');

    final templates = await _request(
      server,
      'resources/templates/list',
      id: 7,
      params: {},
    );
    final templatesResult = _asMap(templates?['result']);
    final templateList = _asList(templatesResult['resourceTemplates']);
    final templateEntry = _asMap(templateList.first);
    expect(templateEntry['uriTemplate'], 'file://{path}');

    final read = await _request(
      server,
      'resources/read',
      id: 8,
      params: {'uri': 'my://resource'},
    );
    final readResult = _asMap(read?['result']);
    final readContents = _asList(readResult['contents']);
    final readEntry = _asMap(readContents.first);
    expect(readEntry['text'], 'my resource');
  });

  test('MCP server supports completion, tasks, and ping', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'taskTool',
      description: 'task tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async => 'done',
    );
    ai.definePrompt<Map<String, dynamic>>(
      name: 'enumPrompt',
      inputSchema: const _EnumPromptSchema(),
      fn: (_, _) async => GenerateActionOptions(messages: []),
    );

    final server = _createServer(ai);

    final ping = await _request(server, 'ping', id: 1, params: {});
    expect(_asMap(ping?['result']), isEmpty);

    final completion = await _request(
      server,
      'completion/complete',
      id: 2,
      params: {
        'ref': {'type': 'ref/prompt', 'name': 'enumPrompt'},
        'argument': {'name': 'color', 'value': 'r'},
      },
    );
    final completionResult = _asMap(completion?['result']);
    final completionData = _asMap(completionResult['completion']);
    final values = _asList(completionData['values']);
    expect(values, ['red']);

    final taskResponse = await _request(
      server,
      'tools/call',
      id: 3,
      params: {
        'name': 'taskTool',
        'arguments': {'foo': 'bar'},
        'task': {},
      },
    );
    final taskResult = _asMap(taskResponse?['result']);
    final task = _asMap(taskResult['task']);
    final taskId = task['taskId'];
    expect(task['status'], 'working');

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final taskPayload = await _request(
      server,
      'tasks/result',
      id: 4,
      params: {'taskId': taskId},
    );
    final payloadResult = _asMap(taskPayload?['result']);
    final payloadContent = _asList(payloadResult['content']);
    expect(payloadContent, isNotEmpty);
  });

  test('MCP server supports logging level and notifications', () async {
    final ai = Genkit();
    final server = _createServer(ai);
    final transport = _FakeServerTransport();

    await server.start(transport);
    try {
      final response = await _request(
        server,
        'logging/setLevel',
        id: 1,
        params: {'level': 'error'},
      );
      expect(_asMap(response?['result']), isEmpty);

      await server.logMessage(level: 'info', data: {'msg': 'skip'});
      await server.logMessage(level: 'error', data: {'msg': 'boom'});

      expect(transport.sent.length, 1);
      final notification = transport.sent.first;
      expect(notification['method'], 'notifications/message');
      final params = _asMap(notification['params']);
      expect(params['level'], 'error');
      expect(_asMap(params['data'])['msg'], 'boom');
    } finally {
      await server.close();
    }
  });

  test('MCP server supports resource subscribe/unsubscribe', () async {
    final ai = Genkit();
    final server = _createServer(ai);
    final transport = _FakeServerTransport();

    await server.start(transport);
    try {
      final response = await _request(
        server,
        'resources/subscribe',
        id: 1,
        params: {'uri': 'my://resource'},
      );
      expect(_asMap(response?['result']), isEmpty);

      await server.notifyResourceUpdated('other://resource');
      expect(transport.sent, isEmpty);

      await server.notifyResourceUpdated('my://resource');
      expect(transport.sent.length, 1);
      final notification = transport.sent.first;
      expect(notification['method'], 'notifications/resources/updated');
      final params = _asMap(notification['params']);
      expect(params['uri'], 'my://resource');

      transport.sent.clear();
      final unsubscribe = await _request(
        server,
        'resources/unsubscribe',
        id: 2,
        params: {'uri': 'my://resource'},
      );
      expect(_asMap(unsubscribe?['result']), isEmpty);

      await server.notifyResourceUpdated('my://resource');
      expect(transport.sent, isEmpty);
    } finally {
      await server.close();
    }
  });

  test('MCP server sends list_changed notifications', () async {
    final ai = Genkit();
    final server = _createServer(ai);
    final transport = _FakeServerTransport();

    await server.start(transport);
    try {
      await server.notifyToolsChanged();
      await server.notifyPromptsChanged();
      await server.notifyResourcesChanged();

      final methods = transport.sent
          .map((message) => message['method'])
          .whereType<String>()
          .toList();
      expect(methods, contains('notifications/tools/list_changed'));
      expect(methods, contains('notifications/prompts/list_changed'));
      expect(methods, contains('notifications/resources/list_changed'));
    } finally {
      await server.close();
    }
  });

  test('MCP server supports tasks list/get/cancel', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'slowTool',
      description: 'slow tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 'done';
      },
    );

    final server = _createServer(ai);

    final taskResponse = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'name': 'slowTool',
        'arguments': {'foo': 'bar'},
        'task': {},
      },
    );
    final taskResult = _asMap(taskResponse?['result']);
    final task = _asMap(taskResult['task']);
    final taskId = task['taskId'];
    expect(task['status'], 'working');

    await Future<void>.delayed(const Duration(milliseconds: 1));
    final listResponse = await _request(
      server,
      'tasks/list',
      id: 2,
      params: {},
    );
    final listResult = _asMap(listResponse?['result']);
    final tasks = _asList(listResult['tasks']);
    final taskIds = tasks
        .whereType<Map>()
        .map((entry) => entry['taskId']?.toString())
        .whereType<String>()
        .toList();
    expect(taskIds, contains(taskId?.toString()));

    final getResponse = await _request(
      server,
      'tasks/get',
      id: 3,
      params: {'taskId': taskId},
    );
    final getResult = _asMap(getResponse?['result']);
    expect(getResult['taskId'], taskId);

    final cancelResponse = await _request(
      server,
      'tasks/cancel',
      id: 4,
      params: {'taskId': taskId},
    );
    final cancelResult = _asMap(cancelResponse?['result']);
    expect(cancelResult['status'], 'cancelled');
  });

  test('MCP server reports task errors as completed with isError', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'failTool',
      description: 'fail tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async {
        throw GenkitException(
          'bad input',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      },
    );

    final server = _createServer(ai);
    final taskResponse = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'name': 'failTool',
        'arguments': {'foo': 'bar'},
        'task': {},
      },
    );
    final taskResult = _asMap(taskResponse?['result']);
    final task = _asMap(taskResult['task']);
    final taskId = task['taskId'];

    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Tool execution errors produce an isError result, so the task
    // completes successfully (the result itself carries the error info).
    final getResponse = await _request(
      server,
      'tasks/get',
      id: 2,
      params: {'taskId': taskId},
    );
    final getResult = _asMap(getResponse?['result']);
    expect(getResult['status'], 'completed');

    final resultResponse = await _request(
      server,
      'tasks/result',
      id: 3,
      params: {'taskId': taskId},
    );
    final resultBody = _asMap(resultResponse?['result']);
    expect(resultBody['isError'], true);
    final content = _asList(resultBody['content']);
    final text = _asMap(content.first)['text'] as String;
    expect(text, contains('bad input'));
  });

  test('MCP server returns 409 when task is not completed', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'delayTool',
      description: 'delay tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 'done';
      },
    );

    final server = _createServer(ai);
    final taskResponse = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'name': 'delayTool',
        'arguments': {'foo': 'bar'},
        'task': {},
      },
    );
    final taskResult = _asMap(taskResponse?['result']);
    final task = _asMap(taskResult['task']);
    final taskId = task['taskId'];

    final resultResponse = await _request(
      server,
      'tasks/result',
      id: 2,
      params: {'taskId': taskId},
    );
    final error = _asMap(resultResponse?['error']);
    expect(error['code'], 409);
  });

  test('MCP server sends progress notifications', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'progressTool',
      description: 'progress tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'done';
      },
    );

    final server = _createServer(ai);
    final transport = _FakeServerTransport();
    await server.start(transport);
    try {
      await _request(
        server,
        'tools/call',
        id: 1,
        params: {
          'name': 'progressTool',
          'arguments': {'foo': 'bar'},
          'task': {},
          '_meta': {'progressToken': 'token-1'},
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final progressEvents = transport.sent.where((message) {
        if (message['method'] != 'notifications/progress') return false;
        final params = _asMap(message['params']);
        return params['progressToken'] == 'token-1';
      }).toList();
      expect(progressEvents, isNotEmpty);
    } finally {
      await server.close();
    }
  });

  test('MCP server purges tasks after TTL', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'fastTool',
      description: 'fast tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async => 'done',
    );

    final server = _createServer(ai);
    final taskResponse = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'name': 'fastTool',
        'arguments': {'foo': 'bar'},
        'task': {'ttl': 1},
      },
    );
    final taskResult = _asMap(taskResponse?['result']);
    final task = _asMap(taskResult['task']);
    final taskId = task['taskId'];

    await Future<void>.delayed(const Duration(milliseconds: 20));
    final listResponse = await _request(
      server,
      'tasks/list',
      id: 2,
      params: {},
    );
    final listResult = _asMap(listResponse?['result']);
    final tasks = _asList(listResult['tasks']);
    final remaining = tasks
        .where((entry) => _asMap(entry)['taskId'] == taskId)
        .toList();
    expect(remaining, isEmpty);
  });

  test('MCP server drops responses for cancelled requests', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'echoTool',
      description: 'echo tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async => 'ok',
    );
    final server = _createServer(ai);

    await _request(
      server,
      'notifications/cancelled',
      params: {'requestId': 99},
    );
    final response = await _request(
      server,
      'tools/call',
      id: 99,
      params: {
        'name': 'echoTool',
        'arguments': {'foo': 'bar'},
      },
    );
    expect(response, isNull);
  });

  test('MCP server includes _meta in prompt/resource listings', () async {
    final ai = Genkit();
    ai.definePrompt<Map<String, dynamic>>(
      name: 'metaPrompt',
      description: 'meta prompt',
      inputSchema: const _PromptInputSchema(),
      metadata: {
        'mcp': {
          '_meta': {'promptMeta': true},
        },
      },
      fn: (input, _) async {
        return GenerateActionOptions(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
        );
      },
    );
    ai.defineResource(
      name: 'metaResource',
      uri: 'meta://resource',
      metadata: {
        'mcp': {
          '_meta': {'resourceMeta': true},
        },
      },
      fn: (_, _) async {
        return ResourceOutput(content: [TextPart(text: 'meta resource')]);
      },
    );
    ai.defineResource(
      name: 'metaTemplate',
      template: 'meta://{id}',
      metadata: {
        'mcp': {
          '_meta': {'templateMeta': true},
        },
      },
      fn: (input, _) async {
        return ResourceOutput(
          content: [TextPart(text: 'meta template ${input.uri}')],
        );
      },
    );

    final server = _createServer(ai);

    final prompts = await _request(server, 'prompts/list', id: 1, params: {});
    final promptsResult = _asMap(prompts?['result']);
    final promptList = _asList(promptsResult['prompts']);
    final promptEntry = _asMap(promptList.first);
    expect(promptEntry['_meta'], {'promptMeta': true});

    final resources = await _request(
      server,
      'resources/list',
      id: 2,
      params: {},
    );
    final resourcesResult = _asMap(resources?['result']);
    final resourceList = _asList(resourcesResult['resources']);
    final resourceEntry = _asMap(resourceList.first);
    expect(resourceEntry['_meta'], {'resourceMeta': true});

    final templates = await _request(
      server,
      'resources/templates/list',
      id: 3,
      params: {},
    );
    final templatesResult = _asMap(templates?['result']);
    final templateList = _asList(templatesResult['resourceTemplates']);
    final templateEntry = _asMap(templateList.first);
    expect(templateEntry['_meta'], {'templateMeta': true});
  });

  test('MCP server reports method not found', () async {
    final ai = Genkit();
    final server = _createServer(ai);

    final response = await _request(
      server,
      'unknown/method',
      id: 1,
      params: {},
    );
    final error = _asMap(response?['error']);
    expect(error['code'], -32601);
  });

  test('MCP server maps Genkit errors to HTTP status codes', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'boomTool',
      description: 'boom tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async {
        throw GenkitException(
          'bad input',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      },
    );
    ai.definePrompt<Map<String, dynamic>>(
      name: 'badPrompt',
      description: 'bad prompt',
      inputSchema: const _PromptInputSchema(),
      fn: (input, _) async {
        return GenerateActionOptions(
          messages: [
            Message(
              role: Role.system,
              content: [TextPart(text: 'nope')],
            ),
          ],
        );
      },
    );

    final server = _createServer(ai);

    final missingName = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'arguments': {'foo': 'bar'},
      },
    );
    final missingNameError = _asMap(missingName?['error']);
    expect(missingNameError['code'], 400);

    // Tool execution errors are returned as isError per MCP spec,
    // not as JSON-RPC errors.
    final toolError = await _request(
      server,
      'tools/call',
      id: 2,
      params: {
        'name': 'boomTool',
        'arguments': {'foo': 'bar'},
      },
    );
    final toolErrorResult = _asMap(toolError?['result']);
    expect(toolErrorResult['isError'], true);
    final toolErrorContent = _asList(toolErrorResult['content']);
    final toolErrorText = _asMap(toolErrorContent.first)['text'] as String;
    expect(toolErrorText, contains('bad input'));

    final toolNotFound = await _request(
      server,
      'tools/call',
      id: 3,
      params: {'name': 'nope', 'arguments': {}},
    );
    final toolNotFoundError = _asMap(toolNotFound?['error']);
    expect(toolNotFoundError['code'], 404);

    final promptError = await _request(
      server,
      'prompts/get',
      id: 4,
      params: {
        'name': 'badPrompt',
        'arguments': {'input': 'hello'},
      },
    );
    final promptErrorMap = _asMap(promptError?['error']);
    expect(promptErrorMap['code'], 501);
  });

  test('MCP server returns isError for non-Genkit tool exceptions', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, String, void>(
      name: 'throwTool',
      description: 'throw tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async {
        throw StateError('boom');
      },
    );
    final server = _createServer(ai);

    // Tool execution errors (even non-Genkit exceptions) are returned as
    // isError per MCP spec so that models can self-correct.
    final response = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'name': 'throwTool',
        'arguments': {'foo': 'bar'},
      },
    );
    final result = _asMap(response?['result']);
    expect(result['isError'], true);
    final content = _asList(result['content']);
    final text = _asMap(content.first)['text'] as String;
    expect(text, contains('boom'));
  });

  test('MCP server JSON-encodes non-string tool outputs', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, Map<String, dynamic>, void>(
      name: 'mapTool',
      description: 'map tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (input, _) async {
        return {'ok': true, 'input': input};
      },
    );
    final server = _createServer(ai);

    final response = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'name': 'mapTool',
        'arguments': {'foo': 'bar'},
      },
    );
    final responseResult = _asMap(response?['result']);
    final responseContent = _asList(responseResult['content']);
    final responseEntry = _asMap(responseContent.first);
    final text = responseEntry['text'];
    expect(text, '{"ok":true,"input":{"foo":"bar"}}');
    expect(_asMap(responseResult['structuredContent']), {
      'ok': true,
      'input': {'foo': 'bar'},
    });
  });

  test('MCP server falls back to toString for unencodable outputs', () async {
    final ai = Genkit();
    ai.defineTool<Map<String, dynamic>, Object, void>(
      name: 'weirdTool',
      description: 'weird tool',
      inputSchema: .map(.string(), .dynamicSchema()),
      fn: (_, _) async => _Unencodable(),
    );
    final server = _createServer(ai);

    final response = await _request(
      server,
      'tools/call',
      id: 1,
      params: {
        'name': 'weirdTool',
        'arguments': {'foo': 'bar'},
      },
    );
    final responseResult = _asMap(response?['result']);
    final responseContent = _asList(responseResult['content']);
    final responseEntry = _asMap(responseContent.first);
    expect(responseEntry['text'], 'unencodable');
  });
}
