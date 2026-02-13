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
import 'package:genkit_mcp/src/client/transports/client_transport.dart';
import 'package:test/test.dart';

class FakeClientTransport implements McpClientTransport {
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();
  final List<Map<String, dynamic>> sent = [];

  List<Map<String, dynamic>> tools = [];
  List<Map<String, dynamic>> prompts = [];
  List<Map<String, dynamic>> resources = [];
  List<Map<String, dynamic>> resourceTemplates = [];
  List<Map<String, dynamic>> roots = [];

  Map<String, dynamic> callToolResult = {
    'content': [
      {'type': 'text', 'text': 'ok'},
    ],
  };
  Map<String, dynamic> promptResult = {
    'messages': [
      {
        'role': 'user',
        'content': {'type': 'text', 'text': 'prompt says: hello'},
      },
    ],
  };
  Map<String, dynamic> readResourceResult = {
    'contents': [
      {'uri': 'my://resource', 'text': 'my resource'},
    ],
  };

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    sent.add(message);
    final method = message['method'];
    if (method is! String) {
      if (message['result'] is Map && message['id'] == 999) {
        final result = message['result'] as Map;
        roots = (result['roots'] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
      return;
    }
    if (method == 'initialize') {
      _respond(message['id'], {
        'protocolVersion': '2025-11-25',
        'capabilities': {'prompts': {}, 'tools': {}, 'resources': {}},
        'serverInfo': {'name': 'fake-server', 'version': '0.0.1'},
      });
      return;
    }
    if (method == 'notifications/initialized') {
      return;
    }
    if (method == 'tools/list') {
      _respond(message['id'], {'tools': tools});
      return;
    }
    if (method == 'tools/call') {
      final result = Map<String, dynamic>.from(callToolResult);
      final params = message['params'];
      if (params is Map && params['_meta'] != null) {
        final content = (result['content'] as List?)?.toList() ?? [];
        content.add({'type': 'text', 'text': jsonEncode(params['_meta'])});
        result['content'] = content;
      }
      _respond(message['id'], result);
      return;
    }
    if (method == 'prompts/list') {
      _respond(message['id'], {'prompts': prompts});
      return;
    }
    if (method == 'prompts/get') {
      final result = Map<String, dynamic>.from(promptResult);
      final params = message['params'];
      if (params is Map && params['_meta'] != null) {
        final messages = (result['messages'] as List?)?.toList() ?? [];
        messages.add({
          'role': 'assistant',
          'content': {'type': 'text', 'text': jsonEncode(params['_meta'])},
        });
        result['messages'] = messages;
      }
      _respond(message['id'], result);
      return;
    }
    if (method == 'resources/list') {
      _respond(message['id'], {'resources': resources});
      return;
    }
    if (method == 'resources/templates/list') {
      _respond(message['id'], {'resourceTemplates': resourceTemplates});
      return;
    }
    if (method == 'resources/read') {
      _respond(message['id'], readResourceResult);
      return;
    }
    if (method == 'notifications/roots/list_changed') {
      _inboundController.add({
        'jsonrpc': '2.0',
        'id': 999,
        'method': 'roots/list',
      });
      return;
    }
  }

  @override
  Future<void> close() async {
    await _inboundController.close();
  }

  void _respond(Object? id, Map<String, dynamic> result) {
    _inboundController.add({'jsonrpc': '2.0', 'id': id, 'result': result});
  }

  void pushInbound(Map<String, dynamic> message) {
    _inboundController.add(message);
  }
}

void main() {
  test('client lists tools and forwards _meta on calls', () async {
    final transport = FakeClientTransport();
    transport.tools = [
      {
        'name': 'testTool',
        'description': 'test tool',
        'inputSchema': {
          r'$schema': 'http://json-schema.org/draft-07/schema#',
          'type': 'object',
        },
        '_meta': {'toolMeta': true},
      },
    ];
    transport.callToolResult = {
      'content': [
        {'type': 'text', 'text': 'yep {"foo":"bar"}'},
      ],
    };

    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    final tools = await client.getActiveTools(Genkit());
    expect(tools, hasLength(1));
    final result = await tools.first.call(
      {'foo': 'bar'},
      context: {
        'mcp': {
          '_meta': {'soMeta': true},
        },
      },
    );
    expect(result, 'yep {"foo":"bar"}{"soMeta":true}');
  });

  test('client converts prompts and resources', () async {
    final transport = FakeClientTransport();
    transport.prompts = [
      {'name': 'testPrompt', 'description': 'test prompt'},
    ];
    transport.resources = [
      {'name': 'testResource', 'uri': 'my://resource'},
    ];
    transport.readResourceResult = {
      'contents': [
        {'uri': 'my://resource', 'text': 'my resource'},
        {'uri': 'my://resource', 'blob': 'QUJD', 'mimeType': 'image/png'},
      ],
    };

    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    final prompts = await client.getActivePrompts(Genkit());
    final request = await prompts.first.call({'input': 'hello'});
    expect(request.messages.first.content.first.text, 'prompt says: hello');

    final resources = await client.getActiveResources(Genkit());
    final output = await resources.first.call(
      ResourceInput(uri: 'my://resource'),
    );
    expect(output.content, hasLength(2));
    expect(output.content.first.toJson()['text'], 'my resource');
    final mediaJson = output.content.last.toJson();
    expect(mediaJson['media'], isNotNull);
  });

  test('client responds to roots/list after roots update', () async {
    final transport = FakeClientTransport();
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    await client.updateRoots([const McpRoot(uri: 'file:///foo', name: 'foo')]);
    await Future<void>.delayed(Duration.zero);

    expect(transport.roots, [
      {'uri': 'file:///foo', 'name': 'foo'},
    ]);
  });

  test('client reflects remote tool inputSchema in Genkit tool', () async {
    final transport = FakeClientTransport();
    transport.tools = [
      {
        'name': 'typedTool',
        'description': 'typed tool',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'city': {'type': 'string', 'description': 'city name'},
            'count': {'type': 'integer'},
          },
          'required': ['city'],
        },
      },
      {'name': 'noSchemaTool', 'description': 'no schema tool'},
    ];

    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    final tools = await client.getActiveTools(Genkit());
    expect(tools, hasLength(2));

    // Tool with explicit inputSchema should reflect it.
    final typedTool = tools.firstWhere((t) => t.name.endsWith('/typedTool'));
    final typedJsonSchema = typedTool.inputSchema!.jsonSchema(useRefs: false);
    final typedProps = typedJsonSchema.value['properties'] as Map?;
    expect(typedProps, isNotNull);
    expect(typedProps!.containsKey('city'), isTrue);
    expect(typedProps.containsKey('count'), isTrue);
    final requiredFields = typedJsonSchema.value['required'] as List?;
    expect(requiredFields, contains('city'));

    // Tool without inputSchema should fall back to Map<String, dynamic>.
    final noSchemaTool = tools.firstWhere(
      (t) => t.name.endsWith('/noSchemaTool'),
    );
    expect(noSchemaTool.inputSchema, isNotNull);
  });

  test('defineMcpClient registers plugin actions in registry', () async {
    final ai = Genkit();
    final transport = FakeClientTransport();
    transport.tools = [
      {
        'name': 'regTool',
        'description': 'registered tool',
        'inputSchema': {'type': 'object'},
      },
    ];
    transport.prompts = [
      {'name': 'regPrompt', 'description': 'registered prompt'},
    ];
    transport.resources = [
      {'name': 'regResource', 'uri': 'my://resource'},
    ];

    final client = defineMcpClient(
      ai,
      McpClientOptionsWithCache(
        name: 'plugin-client',
        serverName: 'my-server',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    // Plugin should expose actions through the registry.
    // serverName is 'my-server' (explicitly set), so action names are
    // 'my-server/<actionName>'.
    final actions = await ai.registry.listActions();
    final actionNames = actions.map((a) => a.name).toList();

    expect(actionNames, contains('my-server/regTool'));
    expect(actionNames, contains('my-server/regPrompt'));
    expect(actionNames, contains('my-server/regResource'));

    // Resolve and call a tool through the registry.
    final resolved = await ai.registry.lookupAction(
      'tool',
      'my-server/regTool',
    );
    expect(resolved, isNotNull);
    final result = await (resolved as Tool).call({'foo': 'bar'});
    expect(result, 'ok');
  });

  test('rawToolResponses returns unprocessed MCP result', () async {
    final transport = FakeClientTransport();
    transport.tools = [
      {
        'name': 'rawTool',
        'description': 'raw tool',
        'inputSchema': {'type': 'object'},
      },
    ];
    transport.callToolResult = {
      'content': [
        {'type': 'text', 'text': '{"answer":42}'},
      ],
    };

    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'raw-client',
        mcpServer: McpServerConfig(transport: transport),
        rawToolResponses: true,
      ),
    );
    await client.ready();

    final tools = await client.getActiveTools(Genkit());
    final result = await tools.first.call({'foo': 'bar'});

    // With rawToolResponses=true, the raw MCP map (with 'content' array)
    // should be returned instead of the parsed JSON.
    expect(result, isA<Map>());
    final resultMap = result as Map<String, dynamic>;
    expect(resultMap['content'], isA<List>());
    final content = (resultMap['content'] as List).first as Map;
    expect(content['text'], '{"answer":42}');
  });

  test('client handles sampling and elicitation requests', () async {
    final transport = FakeClientTransport();
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
        samplingHandler: (params) async {
          return {
            'message': {
              'role': 'assistant',
              'content': {'type': 'text', 'text': 'ok'},
            },
            'model': 'test-model',
          };
        },
        elicitationHandler: (params) async {
          return {
            'action': 'accept',
            'content': {'name': 'user'},
          };
        },
      ),
    );
    await client.ready();

    transport.pushInbound({
      'jsonrpc': '2.0',
      'id': 100,
      'method': 'sampling/createMessage',
      'params': {'messages': []},
    });
    transport.pushInbound({
      'jsonrpc': '2.0',
      'id': 101,
      'method': 'elicitation/create',
      'params': {
        'message': 'who?',
        'mode': 'form',
        'requestedSchema': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
        },
      },
    });

    await Future<void>.delayed(Duration.zero);

    final samplingResponse = transport.sent.firstWhere(
      (entry) => entry['id'] == 100,
    );
    expect(samplingResponse['result'], isA<Map>());

    final elicitationResponse = transport.sent.firstWhere(
      (entry) => entry['id'] == 101,
    );
    expect(elicitationResponse['result'], isA<Map>());
  });
}
