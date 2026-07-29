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
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:test/test.dart';

class FakeClientTransport implements McpClientTransport {
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();
  final List<Map<String, dynamic>> sent = [];
  final bool supportsDiscovery;
  final bool completeSubscriptionsImmediately;

  List<Map<String, dynamic>> tools = [];
  List<Map<String, dynamic>> prompts = [];
  List<Map<String, dynamic>> resources = [];
  List<Map<String, dynamic>> resourceTemplates = [];
  List<Map<String, dynamic>> roots = [];
  final List<Map<String, dynamic>> subscriptionFilters = [];
  Completer<void>? toolsListGate;
  bool hangRepeatedDiscovery = false;
  bool requireUrlElicitation = false;
  bool acknowledgeSubscriptions = true;
  final bool closeInboundOnClose;
  int latestListTtlMs = 0;
  bool failSends = false;
  bool closed = false;
  int closeCalls = 0;
  Map<String, dynamic> capabilities = {
    'prompts': {},
    'tools': {},
    'resources': {},
  };

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

  FakeClientTransport({
    this.supportsDiscovery = false,
    this.completeSubscriptionsImmediately = false,
    this.closeInboundOnClose = true,
  });

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (failSends) {
      throw StateError('send failed');
    }
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
    if (method == 'server/discover') {
      if (hangRepeatedDiscovery && requestCount(method) > 1) {
        return;
      }
      if (!supportsDiscovery) {
        _respondError(message['id'], -32601, 'Method not found');
        return;
      }
      _respond(message['id'], {
        'resultType': 'complete',
        'supportedVersions': ['2026-07-28'],
        'capabilities': capabilities,
        'ttlMs': 0,
        'cacheScope': 'private',
        '_meta': {
          'io.modelcontextprotocol/serverInfo': {
            'name': 'fake-server',
            'version': '0.0.1',
          },
        },
      });
      return;
    }
    if (method == mcp.Method.subscriptionsListen) {
      final params = (message['params'] as Map).cast<String, dynamic>();
      final notifications = (params['notifications'] as Map)
          .cast<String, dynamic>();
      subscriptionFilters.add(Map<String, dynamic>.from(notifications));
      if (!acknowledgeSubscriptions) return;
      final subscriptionId = message['id'];
      _inboundController.add({
        'jsonrpc': '2.0',
        'method': mcp.Method.notificationsSubscriptionsAcknowledged,
        'params': {
          'notifications': notifications,
          '_meta': {mcp.McpMetaKey.subscriptionId: subscriptionId},
        },
      });
      if (completeSubscriptionsImmediately) {
        _respond(message['id'], {
          '_meta': {mcp.McpMetaKey.subscriptionId: subscriptionId},
        });
      }
      return;
    }
    if (method == 'initialize') {
      _respond(message['id'], {
        'protocolVersion': '2025-11-25',
        'capabilities': capabilities,
        'serverInfo': {'name': 'fake-server', 'version': '0.0.1'},
      });
      return;
    }
    if (method == 'notifications/initialized') {
      return;
    }
    if (method == 'tools/list') {
      final result = _listResult(
        'tools',
        tools.map(Map<String, dynamic>.from).toList(),
      );
      await toolsListGate?.future;
      _respond(message['id'], result);
      return;
    }
    if (method == 'tools/call') {
      final params = message['params'];
      if (requireUrlElicitation &&
          (params is! Map || params['inputResponses'] is! Map)) {
        _respond(
          message['id'],
          mcp.InputRequiredResult(
            requestState: 'approval-state',
            inputRequests: {
              'approval': mcp.InputRequest.elicit(
                const mcp.ElicitRequest.url(
                  message: 'Authorize access',
                  url: 'https://example.com/authorize',
                ),
              ),
            },
          ).toJson(),
        );
        return;
      }
      final result = Map<String, dynamic>.from(callToolResult);
      if (params is Map && params['_meta'] != null) {
        final content = (result['content'] as List?)?.toList() ?? [];
        content.add({'type': 'text', 'text': jsonEncode(params['_meta'])});
        result['content'] = content;
      }
      if (supportsDiscovery) {
        result['resultType'] = mcp.resultTypeComplete;
      }
      _respond(message['id'], result);
      return;
    }
    if (method == 'prompts/list') {
      _respond(message['id'], _listResult('prompts', prompts));
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
      _respond(message['id'], _listResult('resources', resources));
      return;
    }
    if (method == 'resources/templates/list') {
      _respond(
        message['id'],
        _listResult('resourceTemplates', resourceTemplates),
      );
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
    closeCalls += 1;
    if (closed) return;
    closed = true;
    if (closeInboundOnClose) {
      await _inboundController.close();
    }
  }

  Future<void> dispose() async {
    if (!_inboundController.isClosed) {
      await _inboundController.close();
    }
  }

  void _respond(Object? id, Map<String, dynamic> result) {
    _inboundController.add({'jsonrpc': '2.0', 'id': id, 'result': result});
  }

  void _respondError(Object? id, int code, String message) {
    _inboundController.add({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    });
  }

  Map<String, dynamic> _listResult(
    String key,
    List<Map<String, dynamic>> value,
  ) {
    return {
      key: value,
      if (supportsDiscovery) ...{
        'resultType': mcp.resultTypeComplete,
        'ttlMs': latestListTtlMs,
        'cacheScope': mcp.CacheScope.private,
      },
    };
  }

  void pushInbound(Map<String, dynamic> message) {
    _inboundController.add(message);
  }

  int requestCount(String method) {
    return sent.where((message) => message['method'] == method).length;
  }
}

void main() {
  test('client uses the negotiated server name', () async {
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: FakeClientTransport()),
      ),
    );

    await client.ready();

    expect(client.serverName, 'fake-server');
  });

  test('client falls back to legacy initialization', () async {
    final transport = FakeClientTransport();
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    await client.ready();

    expect(transport.requestCount('server/discover'), 1);
    expect(transport.requestCount('initialize'), 1);
    expect(client.protocolVersion, '2025-11-25');
  });

  test('client prefers MCP 2026-07-28 discovery', () async {
    final transport = FakeClientTransport(supportsDiscovery: true);
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    await client.ready();

    expect(transport.requestCount('server/discover'), 1);
    expect(transport.requestCount('initialize'), 0);
    expect(client.protocolVersion, '2026-07-28');
  });

  test('client discovers only advertised server capabilities', () async {
    final transport = FakeClientTransport()..capabilities = {'tools': {}};
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    await client.getCachedActions();

    final discoveryMethods = transport.sent
        .map((message) => message['method'])
        .whereType<String>()
        .where((method) => method.endsWith('/list'));
    expect(discoveryMethods, ['tools/list']);
  });

  test('client caches empty action listings', () async {
    final transport = FakeClientTransport()..capabilities = {'tools': {}};
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        cacheTtlMillis: 60000,
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    expect(await client.getCachedActions(), isEmpty);
    expect(await client.getCachedActions(), isEmpty);

    expect(transport.requestCount('tools/list'), 1);
  });

  test('client invalidates cached actions on list changes', () async {
    final transport = FakeClientTransport()..capabilities = {'tools': {}};
    transport.tools = [
      {
        'name': 'firstTool',
        'inputSchema': {'type': 'object'},
      },
    ];
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        cacheTtlMillis: 60000,
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    final initial = await client.getCachedActions();
    expect(initial.single.name, 'fake-server/firstTool');

    transport.tools = [
      {
        'name': 'secondTool',
        'inputSchema': {'type': 'object'},
      },
    ];
    expect(
      (await client.getCachedActions()).single.name,
      endsWith('/firstTool'),
    );
    expect(transport.requestCount('tools/list'), 1);

    transport.pushInbound({
      'jsonrpc': '2.0',
      'method': 'notifications/tools/list_changed',
    });
    await Future<void>.delayed(Duration.zero);

    final refreshed = await client.getCachedActions();
    expect(refreshed.single.name, 'fake-server/secondTool');
    expect(transport.requestCount('tools/list'), 2);
  });

  test('list changes cannot publish an in-flight stale action cache', () async {
    final gate = Completer<void>();
    final transport = FakeClientTransport()
      ..capabilities = {'tools': {}}
      ..tools = [
        {
          'name': 'firstTool',
          'inputSchema': {'type': 'object'},
        },
      ]
      ..toolsListGate = gate;
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        cacheTtlMillis: 60000,
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    final actions = client.getCachedActions();
    while (transport.requestCount('tools/list') < 1) {
      await Future<void>.delayed(Duration.zero);
    }

    transport.tools = [
      {
        'name': 'secondTool',
        'inputSchema': {'type': 'object'},
      },
    ];
    transport.pushInbound({
      'jsonrpc': '2.0',
      'method': 'notifications/tools/list_changed',
    });
    await Future<void>.delayed(Duration.zero);
    gate.complete();

    expect((await actions).single.name, 'fake-server/secondTool');
    expect(transport.requestCount('tools/list'), 2);
    await client.close();
  });

  test('latest action cache honors a zero server TTL', () async {
    final transport = FakeClientTransport(supportsDiscovery: true)
      ..capabilities = {'tools': {}};
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    expect(await client.getCachedActions(), isEmpty);
    expect(await client.getCachedActions(), isEmpty);

    expect(transport.requestCount('tools/list'), 2);
    await client.close();
  });

  test('explicit cache TTL overrides the latest server hint', () async {
    final transport = FakeClientTransport(supportsDiscovery: true)
      ..capabilities = {'tools': {}};
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        cacheTtlMillis: 60000,
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    expect(await client.getCachedActions(), isEmpty);
    expect(await client.getCachedActions(), isEmpty);

    expect(transport.requestCount('tools/list'), 1);
    await client.close();
  });

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
      {
        'name': 'emptySchemaTool',
        'description': 'empty schema tool',
        'inputSchema': {'type': 'object'},
      },
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
    final typedProps = typedJsonSchema['properties'] as Map?;
    expect(typedProps, isNotNull);
    expect(typedProps!.containsKey('city'), isTrue);
    expect(typedProps.containsKey('count'), isTrue);
    final requiredFields = typedJsonSchema['required'] as List?;
    expect(requiredFields, contains('city'));

    // An empty object inputSchema should map to Map<String, dynamic>.
    final emptySchemaTool = tools.firstWhere(
      (t) => t.name.endsWith('/emptySchemaTool'),
    );
    expect(emptySchemaTool.inputSchema, isNotNull);
  });

  test('createMcpClient with DAP registers actions in registry', () async {
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

    final client = createMcpClient(
      McpClientOptions(
        name: 'plugin-client',
        serverName: 'my-server',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    ai.defineDynamicActionProvider(
      name: client.serverName,
      listActionsFn: client.getCachedActions,
      getActionFn: client.resolveAction,
    );
    await client.ready();

    // Plugin should expose actions through the registry.
    final dap =
        await ai.registry.lookupAction('dynamic-action-provider', 'my-server')
            as DynamicActionProvider;
    expect(dap, isNotNull);

    final actions = await dap.listActions();
    final actionNames = actions.map((a) => a.name).toList();

    expect(actionNames, contains('my-server/regTool'));
    expect(actionNames, contains('my-server/regPrompt'));
    expect(actionNames, contains('my-server/regResource'));

    // Test getAction
    final resolved = await dap.getAction('my-server/regTool');
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
      'params': {'messages': [], 'maxTokens': 32},
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

  test('latest URL elicitation uses the negotiated protocol version', () async {
    final transport = FakeClientTransport(supportsDiscovery: true)
      ..requireUrlElicitation = true;
    Map<String, dynamic>? handledParams;
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
        elicitationHandler: (params) async {
          handledParams = params;
          return {'action': 'accept'};
        },
      ),
    );
    await client.ready();

    final result = await client.callTool(name: 'authorize');

    expect(handledParams, {
      'mode': 'url',
      'message': 'Authorize access',
      'url': 'https://example.com/authorize',
    });
    expect((result['content'] as List).first, {'type': 'text', 'text': 'ok'});
    final retry = transport.sent
        .where((entry) => entry['method'] == mcp.Method.toolsCall)
        .last;
    expect((retry['params'] as Map)['requestState'], 'approval-state');
    await client.close();
  });

  test('completed latest subscriptions can be opened again', () async {
    final transport =
        FakeClientTransport(
            supportsDiscovery: true,
            completeSubscriptionsImmediately: true,
          )
          ..capabilities = {
            'resources': {'subscribe': true},
          };
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    await client.subscribeResource(uri: 'file:///project/config.json');
    await Future<void>.delayed(Duration.zero);
    await client.subscribeResource(uri: 'file:///project/config.json');

    expect(transport.subscriptionFilters, hasLength(2));
    await client.close();
  });

  test('latest resource subscriptions share one changing filter', () async {
    final transport = FakeClientTransport(supportsDiscovery: true)
      ..capabilities = {
        'resources': {'subscribe': true},
      };
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    await client.subscribeResource(uri: 'file:///project/a.json');
    await client.subscribeResource(uri: 'file:///project/b.json');
    await client.unsubscribeResource(uri: 'file:///project/a.json');

    expect(transport.subscriptionFilters, [
      {
        'resourceSubscriptions': ['file:///project/a.json'],
      },
      {
        'resourceSubscriptions': [
          'file:///project/a.json',
          'file:///project/b.json',
        ],
      },
      {
        'resourceSubscriptions': ['file:///project/b.json'],
      },
    ]);
    await client.close();
  });

  test('close aborts a subscription awaiting acknowledgment', () async {
    final transport = FakeClientTransport(supportsDiscovery: true)
      ..acknowledgeSubscriptions = false
      ..capabilities = {
        'resources': {'subscribe': true},
      };
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    final subscription = client.subscribeResource(
      uri: 'file:///project/config.json',
    );
    final failure = expectLater(subscription, throwsA(isA<Object>()));
    while (transport.subscriptionFilters.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }

    await client.close().timeout(const Duration(seconds: 1));
    await failure;
  });

  test('close rejects a queued resource subscription mutation', () async {
    final transport = FakeClientTransport(supportsDiscovery: true)
      ..acknowledgeSubscriptions = false
      ..capabilities = {
        'resources': {'subscribe': true},
      };
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );
    await client.ready();

    final subscription = client.subscribeResource(
      uri: 'file:///project/config.json',
    );
    final failure = expectLater(subscription, throwsA(isA<StateError>()));

    await client.close().timeout(const Duration(seconds: 1));
    await failure;
    expect(transport.subscriptionFilters, isEmpty);
  });

  test('connection failure closes the underlying transport', () async {
    final transport = FakeClientTransport()..failSends = true;
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    await expectLater(client.ready(), throwsA(isA<Object>()));
    expect(transport.closed, isTrue);
    expect(transport.closeCalls, 1);
  });

  test('enable waits for readiness and clears a prior error', () async {
    final transport = FakeClientTransport(closeInboundOnClose: false)
      ..failSends = true;
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
      ),
    );

    await expectLater(client.ready(), throwsA(isA<Object>()));
    expect(client.disabled, isTrue);
    expect(client.error, isNotNull);

    transport
      ..failSends = false
      ..closed = false;
    await client.enable();

    expect(client.disabled, isFalse);
    expect(client.error, isNull);
    expect(client.protocolVersion, '2025-11-25');

    await client.close();
    await transport.dispose();
  });

  test('latest ping honors the configured timeout', () async {
    final transport = FakeClientTransport(supportsDiscovery: true)
      ..hangRepeatedDiscovery = true;
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(
          transport: transport,
          timeout: const Duration(milliseconds: 20),
        ),
      ),
    );
    await client.ready();

    await expectLater(
      client.ping(),
      throwsA(
        predicate(
          (error) =>
              error is mcp.McpError &&
              error.code == mcp.ErrorCode.requestTimeout.value,
        ),
      ),
    );
    await client.close();
  });

  test('client preserves task-augmented sampling lifecycle', () async {
    final transport = FakeClientTransport();
    final client = GenkitMcpClient(
      McpClientOptions(
        name: 'test-client',
        mcpServer: McpServerConfig(transport: transport),
        samplingHandler: (params) async => {
          'message': {
            'role': 'assistant',
            'content': {'type': 'text', 'text': 'task complete'},
          },
          'model': 'test-model',
        },
      ),
    );
    await client.ready();

    transport.pushInbound({
      'jsonrpc': '2.0',
      'id': 200,
      'method': 'sampling/createMessage',
      'params': {
        'messages': [],
        'maxTokens': 32,
        'task': {'ttl': 60000},
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final createResponse = transport.sent.firstWhere(
      (entry) => entry['id'] == 200,
    );
    final createResult = createResponse['result'] as Map<String, dynamic>;
    final task = createResult['task'] as Map<String, dynamic>;
    expect(task['status'], anyOf('working', 'completed'));
    final taskId = task['taskId'] as String;

    transport.pushInbound({
      'jsonrpc': '2.0',
      'id': 201,
      'method': 'tasks/result',
      'params': {'taskId': taskId},
    });
    await Future<void>.delayed(Duration.zero);

    final resultResponse = transport.sent.firstWhere(
      (entry) => entry['id'] == 201,
    );
    final result = resultResponse['result'] as Map<String, dynamic>;
    expect(result['model'], 'test-model');
    expect(
      transport.sent.any(
        (entry) => entry['method'] == 'notifications/tasks/status',
      ),
      isTrue,
    );
  });
}
