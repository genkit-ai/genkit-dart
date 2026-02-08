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
import 'server_transport.dart';

/// Streamable HTTP transport for MCP servers.
///
/// Implements the MCP Streamable HTTP transport specification (2025-11-25),
/// supporting both SSE streaming and JSON response modes.
///
/// **DNS Rebinding Protection:**
/// The MCP specification requires servers to validate the `Origin` header
/// on all incoming connections to prevent DNS rebinding attacks. To enable
/// this protection, configure [allowedOrigins] and/or [allowedHosts] when
/// calling [bind]. When configured, requests with invalid `Origin` or `Host`
/// headers will be rejected with HTTP 403. When not configured, no header
/// validation is performed (matching the default behaviour of the TypeScript
/// MCP SDK). For production deployments, you **should** set [allowedOrigins].
class StreamableHttpServerTransport implements McpServerTransport {
  final HttpServer _server;
  final String endpointPath;
  final String? Function()? sessionIdGenerator;
  final void Function(String sessionId)? onSessionInitialized;
  final bool enableJsonResponse;
  final List<String>? allowedHosts;
  final List<String>? allowedOrigins;

  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();
  final Map<Object, _StreamState> _requestStreams = {};
  _StreamState? _standaloneStream;
  String? _sessionId;
  bool _initialized = false;
  bool _closed = false;

  StreamableHttpServerTransport._(
    this._server, {
    required this.endpointPath,
    required this.sessionIdGenerator,
    required this.onSessionInitialized,
    required this.enableJsonResponse,
    required this.allowedHosts,
    required this.allowedOrigins,
  }) {
    _server.listen(_handleRequest, onError: _handleError);
  }

  /// Binds an HTTP server and returns a new transport instance.
  ///
  /// - [allowedOrigins]: When set, requests whose `Origin` header is present
  ///   but not in this list are rejected with HTTP 403. Recommended for
  ///   production deployments to prevent DNS rebinding attacks.
  /// - [allowedHosts]: When set, requests whose `Host` header does not match
  ///   any entry in this list are rejected with HTTP 403.
  static Future<StreamableHttpServerTransport> bind({
    required InternetAddress address,
    required int port,
    String endpointPath = '/mcp',
    String? Function()? sessionIdGenerator,
    void Function(String sessionId)? onSessionInitialized,
    bool enableJsonResponse = false,
    List<String>? allowedHosts,
    List<String>? allowedOrigins,
  }) async {
    final server = await HttpServer.bind(address, port);
    return StreamableHttpServerTransport._(
      server,
      endpointPath: endpointPath,
      sessionIdGenerator: sessionIdGenerator,
      onSessionInitialized: onSessionInitialized,
      enableJsonResponse: enableJsonResponse,
      allowedHosts: allowedHosts,
      allowedOrigins: allowedOrigins,
    );
  }

  int get port => _server.port;
  InternetAddress get address => _server.address;

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_closed) return;
    final id = message['id'];
    final stream = id == null ? null : _requestStreams[id];
    if (stream == null) {
      final standalone = _standaloneStream;
      if (standalone == null) return;
      await _writeSseEvent(standalone.response, message);
      return;
    }

    if (stream.jsonResponse) {
      if (id != null) {
        stream.responses[id] = message;
        if (stream.responses.length == stream.requestIds.length) {
          await _sendJsonResponses(stream);
          _cleanupStream(stream);
        }
      }
      return;
    }

    await _writeSseEvent(stream.response, message);
    if (_isResponseMessage(message) && id != null) {
      stream.completedIds.add(id);
      if (stream.completedIds.length == stream.requestIds.length) {
        await _closeResponse(stream.response);
        _cleanupStream(stream);
      }
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _inboundController.close();
    await _closeResponse(_standaloneStream?.response);
    for (final stream in _requestStreams.values.toList()) {
      await _closeResponse(stream.response);
    }
    _requestStreams.clear();
    _standaloneStream = null;
    await _server.close(force: true);
  }

  void _handleRequest(HttpRequest request) async {
    if (request.uri.path != endpointPath) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    if (!_validateHeaders(request)) return;

    switch (request.method) {
      case 'GET':
        await _handleGet(request);
        return;
      case 'POST':
        await _handlePost(request);
        return;
      case 'DELETE':
        await _handleDelete(request);
        return;
      default:
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
    }
  }

  Future<void> _handleGet(HttpRequest request) async {
    if (!_accepts(request, 'text/event-stream')) {
      await _writeJsonError(
        request.response,
        HttpStatus.notAcceptable,
        -32600,
        'Not Acceptable: Client must accept text/event-stream',
      );
      return;
    }

    if (!_validateSession(request, allowMissing: false)) return;
    if (!_validateProtocolVersion(request, allowMissing: true)) return;

    if (_standaloneStream != null) {
      final existing = _standaloneStream!;
      final alive = await _probeStandaloneStream(existing);
      if (alive) {
        await _writeJsonError(
          request.response,
          HttpStatus.conflict,
          -32600,
          'Conflict: Only one SSE stream is allowed per session.',
        );
        return;
      }
    }

    final response = request.response;
    response.bufferOutput = false;
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    response.headers.set('X-Accel-Buffering', 'no');
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'text/event-stream; charset=utf-8',
    );
    _applySessionHeader(response.headers);
    response.write(': stream open\n\n');
    await response.flush();

    final stream = _StreamState(response, jsonResponse: false);
    _standaloneStream = stream;
    response.done.whenComplete(() {
      if (_standaloneStream == stream) {
        _standaloneStream = null;
      }
    });
  }

  Future<void> _handlePost(HttpRequest request) async {
    if (!_accepts(request, 'application/json') ||
        !_accepts(request, 'text/event-stream')) {
      await _writeJsonError(
        request.response,
        HttpStatus.notAcceptable,
        -32600,
        'Not Acceptable: Client must accept application/json and text/event-stream',
      );
      return;
    }

    if (!_validateProtocolVersion(request, allowMissing: true)) return;

    final contentType = request.headers.contentType;
    if (contentType != null && contentType.mimeType != 'application/json') {
      await _writeJsonError(
        request.response,
        HttpStatus.unsupportedMediaType,
        -32600,
        'Unsupported Content-Type. Expected application/json.',
      );
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final parsed = await _parseMessages(body, request.response);
    if (parsed == null) return;
    final messages = parsed.messages;

    final isInitRequest = messages.any(_isInitializeRequest);
    if (isInitRequest) {
      if (_initialized && _sessionId != null) {
        await _writeJsonError(
          request.response,
          HttpStatus.badRequest,
          -32600,
          'Invalid Request: Server already initialized',
        );
        return;
      }
      if (messages.length > 1) {
        await _writeJsonError(
          request.response,
          HttpStatus.badRequest,
          -32600,
          'Invalid Request: Only one initialization request is allowed',
        );
        return;
      }
      _initialized = true;
      _sessionId = sessionIdGenerator?.call();
      if (_sessionId != null) {
        onSessionInitialized?.call(_sessionId!);
      }
    } else {
      if (!_validateSession(request, allowMissing: false)) return;
    }

    final hasRequests = messages.any(_isRequestMessage);
    if (!hasRequests) {
      for (final message in messages) {
        if (_isRequestOrNotification(message)) {
          _inboundController.add(message);
        }
      }
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
      return;
    }

    final response = request.response;
    if (!enableJsonResponse) {
      response.bufferOutput = false;
      response.statusCode = HttpStatus.ok;
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
      response.headers.set('X-Accel-Buffering', 'no');
      response.headers.set(
        HttpHeaders.contentTypeHeader,
        'text/event-stream; charset=utf-8',
      );
      _applySessionHeader(response.headers);
    }

    final stream = _StreamState(
      response,
      jsonResponse: enableJsonResponse,
      isBatch: parsed.isBatch,
      requestIds: messages
          .where(_isRequestMessage)
          .map((message) => message['id'])
          .whereType<Object>()
          .toList(),
    );
    if (stream.requestIds.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    for (final requestId in stream.requestIds) {
      _requestStreams[requestId] = stream;
    }

    response.done.whenComplete(() {
      _cleanupStream(stream);
    });

    for (final message in messages) {
      if (_isRequestOrNotification(message)) {
        _inboundController.add(message);
      }
    }
  }

  Future<void> _handleDelete(HttpRequest request) async {
    if (!_validateSession(request, allowMissing: false)) return;
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
    unawaited(close());
  }

  Future<_ParsedMessages?> _parseMessages(
    String body,
    HttpResponse response,
  ) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      await _writeJsonError(
        response,
        HttpStatus.badRequest,
        -32700,
        'Parse error: Invalid JSON',
      );
      return null;
    }
    if (decoded is List) {
      final messages = <Map<String, dynamic>>[];
      for (final entry in decoded) {
        if (entry is Map) {
          messages.add(entry.cast<String, dynamic>());
          continue;
        }
        await _writeJsonError(
          response,
          HttpStatus.badRequest,
          -32600,
          'Invalid Request: JSON-RPC batch entries must be objects',
        );
        return null;
      }
      return _ParsedMessages(messages, true);
    }
    if (decoded is Map) {
      return _ParsedMessages([decoded.cast<String, dynamic>()], false);
    }
    await _writeJsonError(
      response,
      HttpStatus.badRequest,
      -32600,
      'Invalid Request: JSON-RPC payload must be an object or array',
    );
    return null;
  }

  bool _validateHeaders(HttpRequest request) {
    if (allowedHosts != null && allowedHosts!.isNotEmpty) {
      final hostHeader = request.headers.value(HttpHeaders.hostHeader);
      if (hostHeader == null || !allowedHosts!.contains(hostHeader)) {
        unawaited(
          _writeJsonError(
            request.response,
            HttpStatus.forbidden,
            -32600,
            'Invalid Host header: $hostHeader',
          ),
        );
        return false;
      }
    }

    if (allowedOrigins != null && allowedOrigins!.isNotEmpty) {
      final originHeader = request.headers.value('origin');
      if (originHeader != null && !allowedOrigins!.contains(originHeader)) {
        unawaited(
          _writeJsonError(
            request.response,
            HttpStatus.forbidden,
            -32600,
            'Invalid Origin header: $originHeader',
          ),
        );
        return false;
      }
    }

    return true;
  }

  bool _validateSession(HttpRequest request, {required bool allowMissing}) {
    if (!_initialized) {
      unawaited(
        _writeJsonError(
          request.response,
          HttpStatus.badRequest,
          -32600,
          'Bad Request: Server not initialized',
        ),
      );
      return false;
    }
    if (_sessionId == null) return true;
    final requestSessionId = request.headers.value('mcp-session-id');
    if (requestSessionId == null && !allowMissing) {
      unawaited(
        _writeJsonError(
          request.response,
          HttpStatus.badRequest,
          -32600,
          'Bad Request: Missing MCP-Session-Id',
        ),
      );
      return false;
    }
    if (requestSessionId != null && requestSessionId != _sessionId) {
      unawaited(
        _writeJsonError(
          request.response,
          HttpStatus.notFound,
          -32600,
          'Session not found',
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateProtocolVersion(
    HttpRequest request, {
    required bool allowMissing,
  }) {
    final versionHeader = request.headers.value('mcp-protocol-version');
    if (versionHeader == null) {
      return allowMissing;
    }
    if (versionHeader != '2025-11-25') {
      unawaited(
        _writeJsonError(
          request.response,
          HttpStatus.badRequest,
          -32600,
          'Unsupported MCP-Protocol-Version: $versionHeader',
        ),
      );
      return false;
    }
    return true;
  }

  bool _accepts(HttpRequest request, String value) {
    final accept = request.headers.value(HttpHeaders.acceptHeader);
    if (accept == null) return false;
    return accept.contains(value);
  }

  bool _isRequestMessage(Map<String, dynamic> message) {
    return message['method'] is String && message.containsKey('id');
  }

  bool _isRequestOrNotification(Map<String, dynamic> message) {
    return message['method'] is String;
  }

  bool _isInitializeRequest(Map<String, dynamic> message) {
    return message['method'] == 'initialize';
  }

  bool _isResponseMessage(Map<String, dynamic> message) {
    return message.containsKey('result') || message.containsKey('error');
  }

  void _applySessionHeader(HttpHeaders headers) {
    if (_sessionId != null) {
      headers.set('mcp-session-id', _sessionId!);
    }
  }

  Future<void> _writeSseEvent(
    HttpResponse response,
    Map<String, dynamic> message,
  ) async {
    response.write('data: ${jsonEncode(message)}\n\n');
    await response.flush();
  }

  Future<void> _writeJsonError(
    HttpResponse response,
    int status,
    int code,
    String message,
  ) async {
    response.statusCode = status;
    response.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    response.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'error': {'code': code, 'message': message},
      }),
    );
    await response.close();
  }

  Future<void> _sendJsonResponses(_StreamState stream) async {
    final response = stream.response;
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    _applySessionHeader(response.headers);
    final responses = stream.requestIds
        .map((id) => stream.responses[id])
        .whereType<Map<String, dynamic>>()
        .toList();
    final payload = stream.isBatch
        ? responses
        : (responses.length == 1 ? responses.first : responses);
    response.write(jsonEncode(payload));
    await response.close();
  }

  Future<void> _closeResponse(HttpResponse? response) async {
    if (response == null) return;
    try {
      await response.close();
    } catch (e) {
      mcpLogger.warning('[MCP Server] Failed to close response: $e');
    }
  }

  void _cleanupStream(_StreamState stream) {
    for (final id in stream.requestIds) {
      _requestStreams.remove(id);
    }
    if (_standaloneStream == stream) {
      _standaloneStream = null;
    }
  }

  Future<bool> _probeStandaloneStream(_StreamState stream) async {
    try {
      stream.response.write(': ping\n\n');
      final flushed = await Future.any<bool>([
        stream.response.flush().then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 200), () => false),
      ]);
      if (!flushed) {
        throw TimeoutException('SSE probe timed out');
      }
      return true;
    } catch (_) {
      await _closeResponse(stream.response);
      _cleanupStream(stream);
      return false;
    }
  }

  void _handleError(Object error) {
    mcpLogger.warning('[MCP Server] HTTP transport error: $error');
  }
}

class _StreamState {
  final HttpResponse response;
  final List<Object> requestIds;
  final Set<Object> completedIds = {};
  final Map<Object, Map<String, dynamic>> responses = {};
  final bool jsonResponse;
  final bool isBatch;

  _StreamState(
    this.response, {
    required this.jsonResponse,
    this.isBatch = false,
    List<Object>? requestIds,
  }) : requestIds = requestIds ?? <Object>[];
}

class _ParsedMessages {
  final List<Map<String, dynamic>> messages;
  final bool isBatch;

  const _ParsedMessages(this.messages, this.isBatch);
}
