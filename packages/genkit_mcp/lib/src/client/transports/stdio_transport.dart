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
import 'client_transport.dart';

class StdioClientTransport implements McpClientTransport {
  final Process _process;
  final StreamController<Map<String, dynamic>> _inboundController =
      StreamController.broadcast();
  late final StreamSubscription<String> _subscription;
  late final StreamSubscription<List<int>> _stderrSubscription;

  StdioClientTransport._(this._process) {
    _subscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _handleError, onDone: _handleDone);
    _stderrSubscription = _process.stderr.listen((data) {
      final message = utf8.decode(data).trimRight();
      if (message.isEmpty) return;
      stderr.writeln('[MCP Client] $message');
    });
  }

  static Future<StdioClientTransport> start({
    required String command,
    List<String> args = const [],
    Map<String, String>? environment,
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      command,
      args,
      environment: environment,
      workingDirectory: workingDirectory,
    );
    return StdioClientTransport._(process);
  }

  @override
  Stream<Map<String, dynamic>> get inbound => _inboundController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    _process.stdin.writeln(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    try {
      await _subscription.cancel();
      await _stderrSubscription.cancel();
      await _inboundController.close();
      await _process.stdin.close();
    } finally {
      _process.kill();
    }
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
      mcpLogger.warning('[MCP Client] Failed to parse JSON: $e');
      return;
    }
    mcpLogger.warning('[MCP Client] Ignoring non-object message.');
  }

  void _handleError(Object error) {
    mcpLogger.warning('[MCP Client] Stdio read error: $error');
  }

  void _handleDone() {
    _inboundController.close();
  }
}
