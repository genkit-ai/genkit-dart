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

import 'package:mcp_dart/mcp_dart.dart' as mcp;

import 'client_transport.dart';

/// Backwards-compatible Streamable HTTP client transport.
///
/// Prefer configuring `McpServerConfig.url` in new code. This wrapper delegates
/// protocol handling to `mcp_dart` so existing callers receive the same MCP
/// version headers, request cancellation, reconnection, and session behavior as
/// the native transport.
@Deprecated('Use McpServerConfig(url: ...) instead.')
class StreamableHttpClientTransport
    implements McpClientTransport, McpDartClientTransport {
  final Uri url;
  final Map<String, String> headers;
  final Duration? timeout;
  final mcp.StreamableHttpClientTransport _transport;
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();

  bool _started = false;
  bool _delegated = false;
  bool _closed = false;

  StreamableHttpClientTransport._({
    required this.url,
    required this.headers,
    required this.timeout,
    required mcp.StreamableHttpClientTransport transport,
  }) : _transport = transport {
    _transport.onmessage = (message) {
      if (!_inboundController.isClosed) {
        _inboundController.add(message.toJson());
      }
    };
    _transport.onerror = (error) {
      if (!_inboundController.isClosed) {
        _inboundController.addError(error);
      }
    };
    _transport.onclose = () {
      _closed = true;
      unawaited(_closeInbound());
    };
  }

  static Future<StreamableHttpClientTransport> connect({
    required Uri url,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final requestHeaders = <String, dynamic>{...?headers};
    return StreamableHttpClientTransport._(
      url: url,
      headers: headers ?? const {},
      timeout: timeout,
      transport: mcp.StreamableHttpClientTransport(
        url,
        opts: mcp.StreamableHttpClientTransportOptions(
          requestInit: {
            if (requestHeaders.isNotEmpty) 'headers': requestHeaders,
          },
        ),
      ),
    );
  }

  /// Retained for source compatibility with the previous transport.
  void setProtocolVersion(String version) {
    _transport.protocolVersion = version;
  }

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_closed) return;
    if (_delegated) {
      throw StateError(
        'This transport is already owned by an MCP client connection.',
      );
    }
    await _ensureStarted();
    final operation = _transport.send(mcp.JsonRpcMessage.fromJson(message));
    if (timeout == null) {
      await operation;
    } else {
      await operation.timeout(timeout!);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _transport.close();
    await _closeInbound();
  }

  @override
  mcp.Transport get mcpDartTransport {
    if (_started) {
      throw StateError(
        'A manually started transport cannot be attached to an MCP client.',
      );
    }
    _delegated = true;
    return _transport;
  }

  @override
  Duration? get requestTimeout => timeout;

  Future<void> _ensureStarted() async {
    if (_started) return;
    _started = true;
    await _transport.start();
  }

  Future<void> _closeInbound() async {
    if (!_inboundController.isClosed) {
      await _inboundController.close();
    }
  }
}
