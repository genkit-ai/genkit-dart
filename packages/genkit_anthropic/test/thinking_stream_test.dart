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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Serves [events] as an SSE stream and returns the accumulated response.
///
/// The plugin never reads `SignatureDelta` itself — it leans on the SDK's
/// `MessageStreamAccumulator` to fold the delta into the thinking block before
/// `fromAnthropicMessage` runs. That is correct today, and invisible if a
/// future SDK bump changes it, so these assert the end of the stream rather
/// than any plugin code directly.
Future<ModelResponse> _streamed(List<Map<String, dynamic>> events) async {
  final client = MockClient.streaming((request, bodyStream) async {
    final body = events
        .map((e) => 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n')
        .join();
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
  final plugin = AnthropicPluginImpl(apiKey: 'test-key', httpClient: client);
  addTearDown(plugin.close);
  final action = plugin.resolve(.model, 'claude-sonnet-4-5') as Model;

  return await action(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
      ],
    ),
    onChunk: (_) {},
  );
}

Map<String, dynamic> _start() => {
  'type': 'message_start',
  'message': {
    'id': 'msg_1',
    'type': 'message',
    'role': 'assistant',
    'model': 'claude-sonnet-4-5',
    'content': <dynamic>[],
    'stop_reason': null,
    'stop_sequence': null,
    'usage': {'input_tokens': 1, 'output_tokens': 1},
  },
};

Map<String, dynamic> _stop() => {
  'type': 'message_delta',
  'delta': {'stop_reason': 'end_turn', 'stop_sequence': null},
  'usage': {'output_tokens': 2},
};

void main() {
  group('thinking blocks survive streaming', () {
    test('a signature delta reaches the final message metadata', () async {
      final response = await _streamed([
        _start(),
        {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {
            'type': 'thinking',
            'thinking': '',
            'signature': '',
          },
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'thinking_delta', 'thinking': 'Hmm'},
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'signature_delta', 'signature': 'sig_streamed'},
        },
        {'type': 'content_block_stop', 'index': 0},
        _stop(),
        {'type': 'message_stop'},
      ]);

      final reasoning = response.message!.content.first;
      expect(reasoning.reasoning, 'Hmm');
      expect(reasoning.metadata?['thoughtSignature'], 'sig_streamed');
    });

    test(
      'a redacted block reaches the final message as a CustomPart',
      () async {
        final response = await _streamed([
          _start(),
          {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {
              'type': 'redacted_thinking',
              'data': 'opaque_payload',
            },
          },
          {'type': 'content_block_stop', 'index': 0},
          _stop(),
          {'type': 'message_stop'},
        ]);

        final part = response.message!.content.first;
        expect(part.custom?['redactedThinking'], 'opaque_payload');
      },
    );
  });
}
