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

class _TestServer {
  final GenkitMcpServer server;
  final StreamableHttpServerTransport transport;

  const _TestServer(this.server, this.transport);

  Uri get url =>
      Uri.parse('http://${transport.address.address}:${transport.port}/mcp');
}

Future<_TestServer> _startServer({
  bool enableJsonResponse = false,
  String? sessionId,
}) async {
  final ai = Genkit();
  final server = GenkitMcpServer(
    ai,
    McpServerOptions(name: 'test-server', version: '0.0.1'),
  );
  final transport = await StreamableHttpServerTransport.bind(
    address: InternetAddress.loopbackIPv4,
    port: 0,
    enableJsonResponse: enableJsonResponse,
    sessionIdGenerator: sessionId == null ? null : () => sessionId,
  );
  await server.start(transport);
  return _TestServer(server, transport);
}

Map<String, dynamic> _initializeRequest(int id) {
  return {'jsonrpc': '2.0', 'id': id, 'method': 'initialize', 'params': {}};
}

Future<HttpClientResponse> _postJson(
  HttpClient client,
  Uri url,
  Object body, {
  String accept = 'application/json, text/event-stream',
  Map<String, String>? headers,
}) async {
  final request = await client.postUrl(url);
  request.headers.contentType = ContentType.json;
  request.headers.set(HttpHeaders.acceptHeader, accept);
  headers?.forEach(request.headers.set);
  request.write(jsonEncode(body));
  return request.close();
}

Future<HttpClientResponse> _postRaw(
  HttpClient client,
  Uri url,
  String body, {
  String accept = 'application/json, text/event-stream',
  Map<String, String>? headers,
}) async {
  final request = await client.postUrl(url);
  request.headers.contentType = ContentType.json;
  request.headers.set(HttpHeaders.acceptHeader, accept);
  headers?.forEach(request.headers.set);
  request.write(body);
  return request.close();
}

Future<HttpClientResponse> _getSse(
  HttpClient client,
  Uri url, {
  Map<String, String>? headers,
}) async {
  final request = await client.getUrl(url);
  request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
  headers?.forEach(request.headers.set);
  return request.close();
}

Future<HttpClientResponse> _delete(
  HttpClient client,
  Uri url, {
  Map<String, String>? headers,
}) async {
  final request = await client.deleteUrl(url);
  headers?.forEach(request.headers.set);
  return request.close();
}

Future<void> _closeSse(HttpClientResponse response) async {
  try {
    final socket = await response.detachSocket();
    socket.destroy();
  } catch (_) {
    await response.drain();
  }
}

void main() {
  test('rejects invalid protocol version header', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final response = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
        headers: {'mcp-protocol-version': '1900-01-01'},
      );

      expect(response.statusCode, HttpStatus.badRequest);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['message'], contains('Unsupported MCP-Protocol-Version'));
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('POST requires Accept header for json and event-stream', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final response = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
        accept: 'application/json',
      );

      expect(response.statusCode, HttpStatus.notAcceptable);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['message'], contains('Not Acceptable'));
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('GET requires MCP-Session-Id after initialize', () async {
    final testServer = await _startServer(
      enableJsonResponse: true,
      sessionId: 'session-1',
    );
    final client = HttpClient();
    try {
      final initResponse = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );
      expect(initResponse.statusCode, HttpStatus.ok);
      final sessionId = initResponse.headers.value('mcp-session-id');
      expect(sessionId, 'session-1');
      await initResponse.drain();

      final response = await _getSse(client, testServer.url);
      expect(response.statusCode, HttpStatus.badRequest);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['message'], contains('Missing MCP-Session-Id'));
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('POST rejects mismatched MCP-Session-Id', () async {
    final testServer = await _startServer(
      enableJsonResponse: true,
      sessionId: 'session-1',
    );
    final client = HttpClient();
    try {
      final initResponse = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );
      expect(initResponse.statusCode, HttpStatus.ok);
      await initResponse.drain();

      final response = await _postJson(
        client,
        testServer.url,
        {'jsonrpc': '2.0', 'id': 2, 'method': 'ping', 'params': {}},
        headers: {'mcp-session-id': 'wrong-session'},
      );

      expect(response.statusCode, HttpStatus.notFound);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['message'], contains('Session not found'));
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('GET rejects concurrent SSE streams', () async {
    final testServer = await _startServer(
      enableJsonResponse: true,
      sessionId: 'session-1',
    );
    final client = HttpClient();
    try {
      final initResponse = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );
      expect(initResponse.statusCode, HttpStatus.ok);
      final sessionId = initResponse.headers.value('mcp-session-id');
      expect(sessionId, 'session-1');
      await initResponse.drain();

      final first = await _getSse(
        client,
        testServer.url,
        headers: {'mcp-session-id': sessionId!},
      );
      expect(first.statusCode, HttpStatus.ok);

      final second = await _getSse(
        client,
        testServer.url,
        headers: {'mcp-session-id': sessionId},
      );
      expect(second.statusCode, HttpStatus.conflict);
      await second.drain();

      await _closeSse(first);
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('GET allows reconnect after disconnect', () async {
    final testServer = await _startServer(
      enableJsonResponse: true,
      sessionId: 'session-1',
    );
    final client = HttpClient();
    try {
      final initResponse = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );
      expect(initResponse.statusCode, HttpStatus.ok);
      final sessionId = initResponse.headers.value('mcp-session-id');
      expect(sessionId, 'session-1');
      await initResponse.drain();

      final first = await _getSse(
        client,
        testServer.url,
        headers: {'mcp-session-id': sessionId!},
      );
      expect(first.statusCode, HttpStatus.ok);
      await _closeSse(first);

      HttpClientResponse? second;
      for (var attempt = 0; attempt < 5; attempt += 1) {
        second = await _getSse(
          client,
          testServer.url,
          headers: {'mcp-session-id': sessionId},
        );
        if (second.statusCode == HttpStatus.ok) break;
        await second.drain();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(second?.statusCode, HttpStatus.ok);
      if (second != null) {
        await _closeSse(second);
      }
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('DELETE closes session', () async {
    final testServer = await _startServer(
      enableJsonResponse: true,
      sessionId: 'session-1',
    );
    final client = HttpClient();
    try {
      final initResponse = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );
      expect(initResponse.statusCode, HttpStatus.ok);
      final sessionId = initResponse.headers.value('mcp-session-id');
      expect(sessionId, 'session-1');
      await initResponse.drain();

      final response = await _delete(
        client,
        testServer.url,
        headers: {'mcp-session-id': sessionId!},
      );
      expect(response.statusCode, HttpStatus.ok);
      await response.drain();
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('returns JSON response when enabled', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final response = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'application/json');
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final result = decoded['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2025-11-25');
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('POST rejects invalid JSON payload', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final response = await _postRaw(client, testServer.url, '{');

      expect(response.statusCode, HttpStatus.badRequest);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['code'], -32700);
      expect(error['message'], contains('Parse error'));
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('POST rejects non-object JSON payload', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final response = await _postRaw(
        client,
        testServer.url,
        '"not-an-object"',
      );

      expect(response.statusCode, HttpStatus.badRequest);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['code'], -32600);
      expect(error['message'], contains('payload must be an object or array'));
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('POST rejects invalid batch entries', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final response = await _postJson(client, testServer.url, [
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping', 'params': {}},
        'not-an-object',
      ]);

      expect(response.statusCode, HttpStatus.badRequest);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['code'], -32600);
      expect(error['message'], contains('batch entries must be objects'));
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('supports JSON-RPC batch requests', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final initResponse = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );
      expect(initResponse.statusCode, HttpStatus.ok);
      await initResponse.drain();

      final response = await _postJson(client, testServer.url, [
        {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list', 'params': {}},
        {'jsonrpc': '2.0', 'id': 3, 'method': 'resources/list', 'params': {}},
      ]);

      expect(response.statusCode, HttpStatus.ok);
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      expect(decoded, isA<List<dynamic>>());
      final results = decoded as List<dynamic>;
      expect(results.length, 2);
      final first = results.first as Map<String, dynamic>;
      final second = results.last as Map<String, dynamic>;
      expect({first['id'], second['id']}, {2, 3});
      expect(first['result'], isNotNull);
      expect(second['result'], isNotNull);
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });

  test('handles concurrent POST requests', () async {
    final testServer = await _startServer(enableJsonResponse: true);
    final client = HttpClient();
    try {
      final initResponse = await _postJson(
        client,
        testServer.url,
        _initializeRequest(1),
      );
      expect(initResponse.statusCode, HttpStatus.ok);
      await initResponse.drain();

      final responses = await Future.wait([
        _postJson(client, testServer.url, {
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/list',
          'params': {},
        }),
        _postJson(client, testServer.url, {
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'resources/list',
          'params': {},
        }),
      ]);

      for (final response in responses) {
        expect(response.statusCode, HttpStatus.ok);
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        expect(decoded['result'], isNotNull);
      }
    } finally {
      client.close(force: true);
      await testServer.server.close();
    }
  });
}
