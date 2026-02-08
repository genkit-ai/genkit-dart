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

import 'server_transport.dart';

export 'server_transport.dart';

class StdioServerTransport implements McpServerTransport {
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();
  late final StreamSubscription<String> _subscription;

  StdioServerTransport() {
    _subscription = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _handleError, onDone: _handleDone);
  }

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    stdout.writeln(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _inboundController.close();
  }

  void _handleLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        _inboundController.add(decoded);
        return;
      }
    } catch (e) {
      stderr.writeln('[MCP Server] Failed to parse JSON: $e');
      return;
    }
    stderr.writeln('[MCP Server] Ignoring non-object message.');
  }

  void _handleError(Object error) {
    stderr.writeln('[MCP Server] Stdio read error: $error');
  }

  void _handleDone() {
    _inboundController.close();
  }
}
