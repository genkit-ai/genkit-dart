// Copyright 2026 Google LLC
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

/// One Anthropic request, captured on the wire.
///
/// Shared by the wire suites: each asks the same question - what did the
/// plugin actually send - about a different part of the request.
library;

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Headers of the most recent captured request, alongside its decoded body.
Map<String, String> lastHeaders = const {};

/// A minimal well-formed Anthropic SSE stream, enough for the SDK accumulator.
String _sseStream(String model) {
  String event(String type, Map<String, dynamic> data) =>
      'event: $type\ndata: ${jsonEncode(data)}\n\n';

  return event('message_start', {
        'type': 'message_start',
        'message': {
          'id': 'msg_test',
          'type': 'message',
          'role': 'assistant',
          'model': model,
          'content': <dynamic>[],
          'stop_reason': null,
          'stop_sequence': null,
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        },
      }) +
      event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'text', 'text': ''},
      }) +
      event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'ok'},
      }) +
      event('content_block_stop', {'type': 'content_block_stop', 'index': 0}) +
      event('message_delta', {
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn', 'stop_sequence': null},
        'usage': {'output_tokens': 1},
      }) +
      event('message_stop', {'type': 'message_stop'});
}

Future<Map<String, dynamic>> requestOnTheWire({
  required String model,
  ThinkingConfig? thinking,
  AnthropicOutputConfig? outputConfig,
  List<Message>? messages,
  String? apiVersion,
  List<String>? betas,
  String? pluginApiVersion,
  Map<String, dynamic>? outputSchema,
  bool constrained = true,
  List<String>? tools,
  String? toolChoice,
  bool streaming = false,
}) async {
  Map<String, dynamic>? captured;
  final client = MockClient((request) async {
    if (request.url.path != '/v1/messages') {
      return http.Response('not found', 404);
    }
    lastHeaders = request.headers;
    captured = (jsonDecode(request.body) as Map).cast<String, dynamic>();

    if (streaming) {
      return http.Response(
        _sseStream(model),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    return http.Response(
      jsonEncode({
        'id': 'msg_test',
        'type': 'message',
        'role': 'assistant',
        'model': model,
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
        'stop_reason': 'end_turn',
        'stop_sequence': null,
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final plugin = AnthropicPluginImpl(
    apiKey: 'test-key',
    httpClient: client,
    apiVersion: pluginApiVersion,
  );
  addTearDown(plugin.close);
  final action = plugin.resolve(.model, model) as Model;

  await action(
    ModelRequest(
      messages:
          messages ??
          [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
      toolChoice: toolChoice,
      tools: tools == null
          ? null
          : [
              for (final name in tools)
                ToolDefinition(
                  name: name,
                  description: 'a tool',
                  inputSchema: {'type': 'object'},
                ),
            ],
      output: outputSchema == null
          ? null
          : OutputConfig(
              format: 'json',
              constrained: constrained,
              schema: outputSchema,
            ),
      config: AnthropicOptions(
        thinking: thinking,
        outputConfig: outputConfig,
        apiVersion: apiVersion,
        betas: betas,
      ).toJson(),
    ),
    onChunk: streaming ? (_) {} : null,
  );

  return captured!;
}
