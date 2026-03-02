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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_mcp/genkit_mcp.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mock server: serves both OAuth endpoints and a protected MCP endpoint.
// ---------------------------------------------------------------------------

class _MockOAuthMcpServer {
  late HttpServer _server;
  late Uri baseUrl;

  final String validToken = 'test-access-token-abc123';
  int tokenRequestCount = 0;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = Uri.parse('http://${_server.address.address}:${_server.port}');
    _server.listen(_handleRequest);
  }

  Future<void> close() => _server.close(force: true);

  void _handleRequest(HttpRequest request) async {
    try {
      final key = '${request.method} ${request.uri.path}';
      switch (key) {
        case 'GET /.well-known/oauth-protected-resource':
          _respondJson(request, {
            'resource': baseUrl.toString(),
            'authorization_servers': [baseUrl.toString()],
          });
        case 'GET /.well-known/oauth-authorization-server':
          _respondJson(request, {
            'issuer': baseUrl.toString(),
            'authorization_endpoint': '$baseUrl/authorize',
            'token_endpoint': '$baseUrl/token',
            'registration_endpoint': '$baseUrl/register',
            'response_types_supported': ['code'],
            'token_endpoint_auth_methods_supported': [
              'client_secret_post',
              'none',
            ],
            'code_challenge_methods_supported': ['S256'],
          });
        case 'POST /register':
          await _handleRegister(request);
        case 'POST /token':
          await _handleToken(request);
        case 'POST /mcp':
          await _handleMcp(request);
        case 'GET /mcp':
          request.response.statusCode = HttpStatus.methodNotAllowed;
          await request.response.close();
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _handleRegister(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    _respondJson(request, {
      ...json,
      'client_id': 'registered-client-id',
      'client_secret': 'registered-client-secret',
    });
  }

  Future<void> _handleToken(HttpRequest request) async {
    tokenRequestCount++;
    final body = await utf8.decoder.bind(request).join();
    final params = Uri.splitQueryString(body);

    switch (params['grant_type']) {
      case 'client_credentials':
        _respondJson(request, {
          'access_token': validToken,
          'token_type': 'bearer',
          'expires_in': 3600,
        });
      case 'refresh_token':
        _respondJson(request, {
          'access_token': 'refreshed-$validToken',
          'token_type': 'bearer',
          'refresh_token': 'new-refresh-token',
        });
      default:
        request.response.statusCode = HttpStatus.badRequest;
        _respondJson(request, {'error': 'unsupported_grant_type'});
    }
  }

  Future<void> _handleMcp(HttpRequest request) async {
    final authHeader = request.headers.value('authorization');
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.set(
        'www-authenticate',
        'Bearer resource_metadata='
            '"$baseUrl/.well-known/oauth-protected-resource"',
      );
      await request.response.close();
      return;
    }

    final token = authHeader.substring('Bearer '.length);
    if (token != validToken && token != 'refreshed-$validToken') {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.set('www-authenticate', 'Bearer');
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final rpc = jsonDecode(body) as Map<String, dynamic>;
    final method = rpc['method'] as String?;
    final id = rpc['id'];

    switch (method) {
      case 'initialize':
        _respondJson(request, {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2025-11-25',
            'serverInfo': {'name': 'oauth-test-server', 'version': '1.0.0'},
            'capabilities': {
              'tools': {'listChanged': true},
            },
          },
        });
      case 'notifications/initialized':
        request.response.statusCode = HttpStatus.accepted;
        await request.response.close();
      case 'tools/list':
        _respondJson(request, {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'tools': [
              {
                'name': 'add',
                'description': 'Add two numbers',
                'inputSchema': {
                  'type': 'object',
                  'properties': {
                    'a': {'type': 'number'},
                    'b': {'type': 'number'},
                  },
                },
              },
            ],
          },
        });
      case 'tools/call':
        final args =
            (rpc['params'] as Map?)?['arguments'] as Map<String, dynamic>?;
        final a = num.tryParse('${args?['a']}') ?? 0;
        final b = num.tryParse('${args?['b']}') ?? 0;
        _respondJson(request, {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'content': [
              {'type': 'text', 'text': '${a + b}'},
            ],
          },
        });
      default:
        _respondJson(request, {'jsonrpc': '2.0', 'id': id, 'result': {}});
    }
  }

  void _respondJson(HttpRequest request, Map<String, dynamic> body) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }
}

// ---------------------------------------------------------------------------
// Mock server: returns a cross-origin authorization server (SSRF test).
// ---------------------------------------------------------------------------

class _SsrfMockServer {
  late HttpServer _server;
  late Uri baseUrl;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = Uri.parse('http://${_server.address.address}:${_server.port}');
    _server.listen(_handleRequest);
  }

  Future<void> close() => _server.close(force: true);

  void _handleRequest(HttpRequest request) async {
    try {
      final key = '${request.method} ${request.uri.path}';
      switch (key) {
        case 'GET /.well-known/oauth-protected-resource':
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'resource': baseUrl.toString(),
              'authorization_servers': ['https://evil.example.com'],
            }),
          );
          await request.response.close();
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }
}

// ---------------------------------------------------------------------------
// Test OAuthClientProvider — client_credentials flow (non-interactive).
// ---------------------------------------------------------------------------

class _TestOAuthProvider extends OAuthClientProvider {
  OAuthClientInformation? _clientInfo;
  OAuthTokens? _tokens;
  String _codeVerifier = '';

  _TestOAuthProvider({OAuthTokens? initialTokens}) : _tokens = initialTokens;

  @override
  Uri? get redirectUrl => null;

  @override
  OAuthClientMetadata get clientMetadata => const OAuthClientMetadata(
    redirectUris: [],
    grantTypes: ['client_credentials'],
    clientName: 'test-oauth-client',
  );

  @override
  Future<OAuthClientInformation?> clientInformation() async => _clientInfo;

  @override
  Future<void> saveClientInformation(OAuthClientInformation info) async {
    _clientInfo = info;
  }

  @override
  Future<OAuthTokens?> tokens() async => _tokens;

  @override
  Future<void> saveTokens(OAuthTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> redirectToAuthorization(Uri url) async {
    throw StateError('Should not redirect in client_credentials flow');
  }

  @override
  Future<void> saveCodeVerifier(String v) async {
    _codeVerifier = v;
  }

  @override
  Future<String> codeVerifier() async => _codeVerifier;

  @override
  Future<Map<String, String>?> prepareTokenRequest(String? scope) async {
    final params = {'grant_type': 'client_credentials'};
    if (scope != null) params['scope'] = scope;
    return params;
  }
}

/// Provider that stores and returns a saved state for CSRF testing.
class _StatefulTestProvider extends _TestOAuthProvider {
  final String? savedStateValue;

  _StatefulTestProvider({this.savedStateValue});

  @override
  Future<String?> savedState() async => savedStateValue;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockOAuthMcpServer mockServer;

  setUp(() async {
    mockServer = _MockOAuthMcpServer();
    await mockServer.start();
  });

  tearDown(() async {
    await mockServer.close();
  });

  test(
    'client_credentials: discovers, registers, gets token, calls tool',
    () async {
      final provider = _TestOAuthProvider();
      final client = GenkitMcpClient(
        McpClientOptions(
          name: 'oauth-test-client',
          mcpServer: McpServerConfig(
            url: Uri.parse('${mockServer.baseUrl}/mcp'),
            authProvider: provider,
          ),
        ),
      );

      try {
        await client.ready();

        // Provider should now have client info and tokens.
        final clientInfo = await provider.clientInformation();
        expect(clientInfo, isNotNull);
        expect(clientInfo!.clientId, 'registered-client-id');

        final tokens = await provider.tokens();
        expect(tokens, isNotNull);
        expect(tokens!.accessToken, mockServer.validToken);

        // Server should have received at least one token request.
        expect(mockServer.tokenRequestCount, greaterThanOrEqualTo(1));

        // Tools should be discoverable through the authenticated connection.
        final tools = await client.getActiveTools(Genkit());
        expect(tools, hasLength(1));
        expect(tools.first.name, contains('add'));

        // Tool call should succeed.
        final result = await tools.first.call({'a': 3, 'b': 7});
        expect(result, '10');
      } finally {
        await client.close();
      }
    },
  );

  test(
    'pre-authenticated: skips auth flow when tokens already present',
    () async {
      final provider = _TestOAuthProvider(
        initialTokens: OAuthTokens(
          accessToken: mockServer.validToken,
          tokenType: 'bearer',
        ),
      );

      final client = GenkitMcpClient(
        McpClientOptions(
          name: 'pre-auth-client',
          mcpServer: McpServerConfig(
            url: Uri.parse('${mockServer.baseUrl}/mcp'),
            authProvider: provider,
          ),
        ),
      );

      try {
        await client.ready();

        // No token requests should have been made.
        expect(mockServer.tokenRequestCount, 0);

        final tools = await client.getActiveTools(Genkit());
        expect(tools, hasLength(1));

        final result = await tools.first.call({'a': 100, 'b': 200});
        expect(result, '300');
      } finally {
        await client.close();
      }
    },
  );

  test('rejects cross-origin authorization server (SSRF defence)', () async {
    final ssrfServer = _SsrfMockServer();
    await ssrfServer.start();

    try {
      final provider = _TestOAuthProvider();
      await expectLater(
        auth(
          provider,
          serverUrl: Uri.parse('${ssrfServer.baseUrl}/mcp'),
          resourceMetadataUrl: Uri.parse(
            '${ssrfServer.baseUrl}/.well-known/oauth-protected-resource',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    } finally {
      await ssrfServer.close();
    }
  });

  test('finishAuth rejects mismatched state (CSRF defence)', () async {
    final provider = _StatefulTestProvider(
      savedStateValue: 'expected-state-abc',
    );
    final transport = await StreamableHttpClientTransport.connect(
      url: Uri.parse('http://localhost:1/mcp'),
      authProvider: provider,
    );

    try {
      await expectLater(
        transport.finishAuth('some-code', state: 'wrong-state'),
        throwsA(isA<UnauthorizedError>()),
      );
    } finally {
      await transport.close();
    }
  });

  test(
    'works without authProvider (no OAuth, server allows anonymous)',
    () async {
      // Verify that existing non-OAuth behaviour is unchanged: a client
      // connecting without an authProvider to a server that doesn't require
      // auth should still work as before.

      // Start a plain unprotected MCP server.
      final ai = Genkit();
      ai.defineTool<Map<String, dynamic>, String>(
        name: 'echo',
        description: 'echo',
        inputSchema: .map(.string(), .dynamicSchema()),
        fn: (input, _) async => 'echo: ${input['msg']}',
      );
      final server = GenkitMcpServer(
        ai,
        McpServerOptions(name: 'plain-server', version: '0.0.1'),
      );
      final transport = await StreamableHttpServerTransport.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      await server.start(transport);

      final client = GenkitMcpClient(
        McpClientOptions(
          name: 'no-auth-client',
          mcpServer: McpServerConfig(
            url: Uri.parse(
              'http://${transport.address.address}:${transport.port}/mcp',
            ),
          ),
        ),
      );

      try {
        await client.ready();
        final tools = await client.getActiveTools(Genkit());
        expect(tools, hasLength(1));
        final result = await tools.first.call({'msg': 'hello'});
        expect(result, 'echo: hello');
      } finally {
        await client.close();
        await server.close();
      }
    },
  );
}
