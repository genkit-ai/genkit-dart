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

/// Adapts the existing Genkit transport extension point to `mcp_dart`.
///
/// Genkit transports are already active when returned by their factories, so
/// [start] only attaches the protocol callbacks.
class McpDartClientTransport implements mcp.Transport {
  final McpClientTransport delegate;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _closed = false;

  McpDartClientTransport(this.delegate);

  @override
  void Function()? onclose;

  @override
  void Function(Error error)? onerror;

  @override
  void Function(mcp.JsonRpcMessage message)? onmessage;

  @override
  String? get sessionId => null;

  @override
  Future<void> start() async {
    if (_subscription != null) {
      throw StateError('Transport already started.');
    }
    _subscription = delegate.inbound.listen(
      (message) {
        try {
          onmessage?.call(mcp.JsonRpcMessage.fromJson(message));
        } catch (error) {
          onerror?.call(error is Error ? error : StateError(error.toString()));
        }
      },
      onError: (Object error) {
        onerror?.call(error is Error ? error : StateError(error.toString()));
      },
      onDone: onclose,
    );
  }

  @override
  Future<void> send(mcp.JsonRpcMessage message, {int? relatedRequestId}) {
    return delegate.send(message.toJson());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    await delegate.close();
  }
}
