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
import 'dart:io';

import '../../util/logging.dart';
import '../auth/oauth.dart';
import '../auth/oauth_provider.dart';
import '../auth/oauth_types.dart';
import 'client_transport.dart';

class StreamableHttpClientTransport implements McpClientTransport {
  final Uri url;
  final Map<String, String> headers;
  final Duration? timeout;
  final OAuthClientProvider? authProvider;
  final HttpClient _client;
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();

  StreamSubscription<String>? _standaloneSubscription;
  bool _closed = false;
  String? _sessionId;
  String? _protocolVersion;

  // OAuth state — prevents infinite auth / scope-upgrade loops.
  bool _hasCompletedAuthFlow = false;
  Uri? _resourceMetadataUrl;
  String? _scope;
  String? _lastUpscopingHeader;

  StreamableHttpClientTransport._({
    required this.url,
    required this.headers,
    required this.timeout,
    required this.authProvider,
    required HttpClient client,
  }) : _client = client;

  static Future<StreamableHttpClientTransport> connect({
    required Uri url,
    Map<String, String>? headers,
    Duration? timeout,
    OAuthClientProvider? authProvider,
  }) async {
    final client = HttpClient();
    return StreamableHttpClientTransport._(
      url: url,
      headers: headers ?? const {},
      timeout: timeout,
      authProvider: authProvider,
      client: client,
    );
  }

  void setProtocolVersion(String version) {
    _protocolVersion = version;
  }

  /// Completes an OAuth authorization code exchange.
  ///
  /// Call this after the user has been redirected back from the authorization
  /// server with an authorization code.  Pass [state] to verify the CSRF
  /// `state` parameter returned by the authorization server callback.
  Future<void> finishAuth(String authorizationCode, {String? state}) async {
    if (authProvider == null) {
      throw const UnauthorizedError('No auth provider configured');
    }

    // Verify CSRF state parameter.
    final expectedState = await authProvider!.savedState();
    if (expectedState != null && state != expectedState) {
      throw const UnauthorizedError(
        'OAuth state parameter mismatch (possible CSRF attack)',
      );
    }

    final result = await auth(
      authProvider!,
      serverUrl: url,
      authorizationCode: authorizationCode,
      resourceMetadataUrl: _resourceMetadataUrl,
      scope: _scope,
      httpClient: _client,
    );
    if (result != AuthResult.authorized) {
      throw const UnauthorizedError('Failed to authorize');
    }
  }

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_closed) return;
    final response = await _postMessage(message);
    _captureSessionId(response);

    // --- OAuth: handle 401 Unauthorized ---
    if (response.statusCode == HttpStatus.unauthorized &&
        authProvider != null) {
      await _drain(response);
      if (_hasCompletedAuthFlow) {
        throw const UnauthorizedError(
          'Authorization failed after completing auth flow',
        );
      }
      final params = extractWwwAuthenticateParams(response);
      _resourceMetadataUrl = params.resourceMetadataUrl;
      _scope = params.scope;

      final result = await auth(
        authProvider!,
        serverUrl: url,
        resourceMetadataUrl: _resourceMetadataUrl,
        scope: _scope,
        httpClient: _client,
      );
      if (result != AuthResult.authorized) {
        throw const UnauthorizedError();
      }
      _hasCompletedAuthFlow = true;
      return send(message);
    }

    // --- OAuth: handle 403 Forbidden with insufficient_scope ---
    if (response.statusCode == HttpStatus.forbidden && authProvider != null) {
      final params = extractWwwAuthenticateParams(response);
      await _drain(response);
      if (params.error == 'insufficient_scope') {
        final wwwAuth = response.headers.value('www-authenticate');
        if (wwwAuth != null && _lastUpscopingHeader == wwwAuth) {
          throw const UnauthorizedError('Scope upgrade loop detected');
        }
        _scope = params.scope;
        _lastUpscopingHeader = wwwAuth;

        final result = await auth(
          authProvider!,
          serverUrl: url,
          resourceMetadataUrl: _resourceMetadataUrl,
          scope: _scope,
          httpClient: _client,
        );
        if (result != AuthResult.authorized) {
          throw const UnauthorizedError();
        }
        return send(message);
      }
    }

    if (response.statusCode == HttpStatus.accepted) {
      await _drain(response);
      if (_isInitializedNotification(message)) {
        await _startStandaloneSse();
      }
      return;
    }

    if (response.statusCode != HttpStatus.ok) {
      final text = await response.transform(utf8.decoder).join();
      throw StateError(
        '[MCP Client] HTTP ${response.statusCode}: ${text.trim()}',
      );
    }

    final contentType = response.headers.contentType?.mimeType ?? '';
    if (contentType.contains('text/event-stream')) {
      _listenToSse(response, isStandalone: false);
      return;
    }
    if (contentType.contains('application/json')) {
      final body = await response.transform(utf8.decoder).join();
      _handleJsonBody(body);
      return;
    }

    await _drain(response);
    throw StateError('[MCP Client] Unexpected content-type: $contentType');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _standaloneSubscription?.cancel();
    await _inboundController.close();
    _client.close(force: true);
  }

  Future<HttpClientResponse> _postMessage(Map<String, dynamic> message) async {
    final request = await _client.postUrl(url);
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/event-stream',
    );
    await _applyHeaders(request.headers);
    request.write(jsonEncode(message));
    final responseFuture = request.close();
    if (timeout == null) {
      return responseFuture;
    }
    return responseFuture.timeout(timeout!);
  }

  Future<void> _startStandaloneSse() async {
    if (_closed) return;
    if (_standaloneSubscription != null) return;
    final request = await _client.getUrl(url);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    await _applyHeaders(request.headers);
    final responseFuture = request.close();
    final response = timeout == null
        ? await responseFuture
        : await responseFuture.timeout(timeout!);

    // Handle 401 during SSE connection.
    if (response.statusCode == HttpStatus.unauthorized &&
        authProvider != null) {
      await _drain(response);
      final result = await auth(
        authProvider!,
        serverUrl: url,
        scope: _scope,
        httpClient: _client,
      );
      if (result != AuthResult.authorized) {
        throw const UnauthorizedError();
      }
      return _startStandaloneSse();
    }

    if (response.statusCode == HttpStatus.methodNotAllowed) {
      await _drain(response);
      return;
    }
    if (response.statusCode != HttpStatus.ok) {
      final text = await response.transform(utf8.decoder).join();
      mcpLogger.warning(
        '[MCP Client] Standalone SSE failed: ${response.statusCode} ${text.trim()}',
      );
      return;
    }

    _standaloneSubscription = _listenToSse(response, isStandalone: true);
  }

  StreamSubscription<String> _listenToSse(
    HttpClientResponse response, {
    required bool isStandalone,
  }) {
    var buffer = '';
    return response
        .transform(utf8.decoder)
        .listen(
          (chunk) {
            buffer += chunk;
            _parseSseBuffer(buffer, (event) {
              buffer = event.remainingBuffer;
              if (event.event != null) {
                _handleSseEvent(event.event!);
              }
            });
          },
          onError: (error) {
            mcpLogger.warning('[MCP Client] SSE error: $error');
          },
          onDone: () {
            if (isStandalone) {
              _standaloneSubscription = null;
            }
          },
        );
  }

  void _handleSseEvent(_SseEvent event) {
    final data = event.data.trim();
    if (data.isEmpty) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        _inboundController.add(decoded);
      } else if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map) {
            _inboundController.add(entry.cast<String, dynamic>());
          }
        }
      }
    } catch (e) {
      mcpLogger.warning('[MCP Client] Failed to parse SSE data: $e');
    }
  }

  void _parseSseBuffer(String buffer, void Function(_SseParseResult) onEvent) {
    var current = buffer;
    while (true) {
      final lfIndex = current.indexOf('\n\n');
      final crlfIndex = current.indexOf('\r\n\r\n');
      if (lfIndex == -1 && crlfIndex == -1) {
        onEvent(_SseParseResult(remainingBuffer: current, event: null));
        return;
      }

      final useCrlf = crlfIndex != -1 && (lfIndex == -1 || crlfIndex < lfIndex);
      final delimiter = useCrlf ? '\r\n\r\n' : '\n\n';
      final cutIndex = useCrlf ? crlfIndex : lfIndex;
      final block = current.substring(0, cutIndex);
      current = current.substring(cutIndex + delimiter.length);

      final event = _parseEventBlock(block);
      if (event != null) {
        onEvent(_SseParseResult(remainingBuffer: current, event: event));
      }
    }
  }

  _SseEvent? _parseEventBlock(String block) {
    String? eventName;
    String? eventId;
    final dataLines = <String>[];
    final lines = block.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.isEmpty || line.startsWith(':')) continue;
      final separator = line.indexOf(':');
      final field = separator == -1 ? line : line.substring(0, separator);
      final value = separator == -1
          ? ''
          : line.substring(separator + 1).trimLeft();
      switch (field) {
        case 'event':
          eventName = value;
        case 'data':
          dataLines.add(value);
        case 'id':
          eventId = value;
        default:
          break;
      }
    }
    if (eventName == null && dataLines.isEmpty && eventId == null) return null;
    return _SseEvent(name: eventName, data: dataLines.join('\n'), id: eventId);
  }

  void _handleJsonBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        _inboundController.add(decoded);
      } else if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map) {
            _inboundController.add(entry.cast<String, dynamic>());
          }
        }
      }
    } catch (e) {
      mcpLogger.warning('[MCP Client] Failed to parse JSON: $e');
    }
  }

  Future<void> _applyHeaders(HttpHeaders httpHeaders) async {
    for (final entry in headers.entries) {
      httpHeaders.set(entry.key, entry.value);
    }

    // Inject OAuth Bearer token when available.
    if (authProvider != null) {
      final tokens = await authProvider!.tokens();
      if (tokens != null) {
        httpHeaders.set('authorization', 'Bearer ${tokens.accessToken}');
      }
    }

    if (_sessionId != null) {
      httpHeaders.set('mcp-session-id', _sessionId!);
    }
    if (_protocolVersion != null) {
      httpHeaders.set('mcp-protocol-version', _protocolVersion!);
    }
  }

  void _captureSessionId(HttpClientResponse response) {
    final sessionId = response.headers.value('mcp-session-id');
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
    }
  }

  bool _isInitializedNotification(Map<String, dynamic> message) {
    return message['method'] == 'notifications/initialized';
  }

  static Future<void> _drain(HttpClientResponse response) =>
      response.drain<void>();
}

class _SseEvent {
  final String? name;
  final String data;
  final String? id;

  const _SseEvent({required this.name, required this.data, required this.id});
}

class _SseParseResult {
  final String remainingBuffer;
  final _SseEvent? event;

  const _SseParseResult({required this.remainingBuffer, required this.event});
}
