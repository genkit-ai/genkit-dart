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

/// A custom JSON transport for a Genkit MCP client.
///
/// The client owns the transport lifecycle and calls [close] when the MCP
/// connection closes.
abstract class McpClientTransport {
  /// A stream of inbound JSON-RPC messages from the server.
  Stream<Map<String, dynamic>> get inbound;

  /// Sends a JSON-RPC message to the server.
  Future<void> send(Map<String, dynamic> message);

  /// Closes the transport and releases any held resources.
  Future<void> close();
}
