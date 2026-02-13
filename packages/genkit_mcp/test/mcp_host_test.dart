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

class FakeHostTransport implements McpClientTransport {
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();

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
    final method = message['method'];
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
    if (message['result'] is Map && message['id'] == 999) {
      final result = message['result'] as Map;
      roots = (result['roots'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
  }

  @override
  Future<void> close() async {
    // Keep the stream open to allow reconnects in tests.
  }

  void _respond(Object? id, Map<String, dynamic> result) {
    _inboundController.add({'jsonrpc': '2.0', 'id': id, 'result': result});
  }
}

void main() {
  test('host connects, disables, and disconnects servers', () async {
    final ai = Genkit();
    final host = GenkitMcpHost(const McpHostOptions(name: 'test-host'));

    final transport1 = FakeHostTransport();
    transport1.tools = [
      {
        'name': 'testTool1',
        'description': 'test tool 1',
        'inputSchema': {
          r'$schema': 'http://json-schema.org/draft-07/schema#',
          'type': 'object',
        },
      },
    ];
    final transport2 = FakeHostTransport();
    transport2.tools = [
      {
        'name': 'testTool2',
        'description': 'test tool 2',
        'inputSchema': {
          r'$schema': 'http://json-schema.org/draft-07/schema#',
          'type': 'object',
        },
      },
    ];

    expect(await host.getActiveTools(ai), isEmpty);

    await host.connect('server1', McpServerConfig(transport: transport1));
    var tools = await host.getActiveTools(ai);
    var names = tools.map((tool) => tool.name).toList()..sort();
    expect(names, ['server1/testTool1']);

    await host.connect('server2', McpServerConfig(transport: transport2));
    tools = await host.getActiveTools(ai);
    names = tools.map((tool) => tool.name).toList()..sort();
    expect(names, ['server1/testTool1', 'server2/testTool2']);

    await host.disable('server1');
    tools = await host.getActiveTools(ai);
    names = tools.map((tool) => tool.name).toList()..sort();
    expect(names, ['server2/testTool2']);

    await host.enable('server1');
    tools = await host.getActiveTools(ai);
    names = tools.map((tool) => tool.name).toList()..sort();
    expect(names, ['server1/testTool1', 'server2/testTool2']);

    await host.disconnect('server1');
    tools = await host.getActiveTools(ai);
    names = tools.map((tool) => tool.name).toList()..sort();
    expect(names, ['server2/testTool2']);
  });

  test('host updates roots', () async {
    final host = GenkitMcpHost(const McpHostOptions(name: 'test-host'));
    final transport = FakeHostTransport();

    await host.connect(
      'server1',
      McpServerConfig(
        transport: transport,
        roots: const [McpRoot(uri: 'file:///foo', name: 'foo')],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(transport.roots, [
      {'uri': 'file:///foo', 'name': 'foo'},
    ]);

    await host.getClient('server1')?.updateRoots(const [
      McpRoot(uri: 'file:///bar', name: 'bar'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(transport.roots, [
      {'uri': 'file:///bar', 'name': 'bar'},
    ]);
  });

  test('host exposes prompts and resources', () async {
    final ai = Genkit();
    final host = GenkitMcpHost(const McpHostOptions(name: 'test-host'));
    final transport = FakeHostTransport();
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

    await host.connect('server1', McpServerConfig(transport: transport));

    final prompts = await host.getActivePrompts(ai);
    expect(prompts, hasLength(1));
    final request = await prompts.first.call({'input': 'hello'});
    expect(request.messages.first.content.first.text, 'prompt says: hello');

    final resources = await host.getActiveResources(ai);
    expect(resources, hasLength(1));
    final output = await resources.first.call(
      ResourceInput(uri: 'my://resource'),
    );
    expect(output.content, hasLength(2));
  });

  test('host aggregates tools from multiple servers via mcpServers', () async {
    final ai = Genkit();
    final transport1 = FakeHostTransport();
    transport1.tools = [
      {'name': 'tool1', 'description': 'tool 1'},
    ];
    final transport2 = FakeHostTransport();
    transport2.tools = [
      {'name': 'tool2', 'description': 'tool 2'},
    ];

    // Use mcpServers map in the constructor (the README pattern).
    final host = defineMcpHost(
      ai,
      McpHostOptionsWithCache(
        name: 'multi-host',
        mcpServers: {
          'serverA': McpServerConfig(transport: transport1),
          'serverB': McpServerConfig(transport: transport2),
        },
      ),
    );
    await host.getClient('serverA')?.ready();
    await host.getClient('serverB')?.ready();

    final tools = await host.getActiveTools(ai);
    final names = tools.map((t) => t.name).toList()..sort();
    expect(names, ['serverA/tool1', 'serverB/tool2']);

    // Also verify registry integration.
    final actions = await ai.registry.listActions();
    final mcpNames =
        actions
            .where((a) => a.name.startsWith('multi-host/'))
            .map((a) => a.name)
            .toList()
          ..sort();
    expect(mcpNames, ['multi-host/serverA:tool1', 'multi-host/serverB:tool2']);
  });

  test('defineMcpHost registers plugin actions', () async {
    final ai = Genkit();
    final transport = FakeHostTransport();
    transport.tools = [
      {'name': 'testTool', 'description': 'test tool'},
    ];

    final host = defineMcpHost(
      ai,
      McpHostOptionsWithCache(
        name: 'mcp-host',
        mcpServers: {'server1': McpServerConfig(transport: transport)},
      ),
    );
    await host.getClient('server1')?.ready();

    final actions = await ai.registry.listActions();
    expect(
      actions.any((action) => action.name == 'mcp-host/server1:testTool'),
      isTrue,
    );

    final resolved = await ai.registry.lookupAction(
      'tool',
      'mcp-host/server1:testTool',
    );
    expect(resolved, isNotNull);
    final result = await (resolved as Tool).call({'foo': 'bar'});
    expect(result, 'ok');
  });
}
