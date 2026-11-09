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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

import 'test_harness.dart';

Future<Map<String, dynamic>> _bodyFor({
  ToolChoice? toolChoice,
  List<ToolDefinition>? tools,
  Map<String, dynamic>? config,
}) async {
  final captured = <Map<String, dynamic>>[];
  final plugin = WirePlugin(captured);
  final action = plugin.resolve(.model, 'gemini-flash-latest') as Model;
  await action(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'What is the weather in Boston?')],
        ),
      ],
      tools: tools,
      toolChoice: toolChoice,
      config: config,
    ),
  );
  return captured.single;
}

final _weatherTool = ToolDefinition(
  name: 'getWeather',
  description: 'Get the weather for a location',
  inputSchema: {
    'type': 'object',
    'properties': {
      'location': {'type': 'string'},
    },
  },
);

void main() {
  group('toolConfig on the wire', () {
    test('maps toolChoice alongside function tools', () async {
      final body = await _bodyFor(toolChoice: .required, tools: [_weatherTool]);
      expect(body['toolConfig'], {
        'functionCallingConfig': {'mode': 'ANY'},
      });
    });

    test('omits toolChoice when there are no tools', () async {
      final body = await _bodyFor(toolChoice: .required);
      expect(body, isNot(contains('toolConfig')));
      expect(body, isNot(contains('tools')));
    });

    test('omits toolChoice when only built-in tools are enabled', () async {
      final body = await _bodyFor(
        toolChoice: .required,
        config: {'googleSearch': <String, dynamic>{}},
      );
      expect(body['tools'], hasLength(1));
      expect(body, isNot(contains('toolConfig')));
    });
  });
}
