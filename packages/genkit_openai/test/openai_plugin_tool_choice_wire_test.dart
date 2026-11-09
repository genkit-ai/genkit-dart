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
import 'package:genkit_openai/genkit_openai.dart';
import 'package:test/test.dart';

import 'wire_client.dart';

void main() {
  group('tool_choice on the wire', () {
    Future<Map<String, dynamic>> bodyFor({
      ToolChoice? toolChoice,
      bool withTools = true,
    }) async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        isDevEnv: false,
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );
      addTearDown(ai.shutdown);
      ai.defineTool(
        name: 'getWeather',
        description: 'Get the weather for a location',
        fn: (input, ctx) async => .response({'temperature': 72}),
      );

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'What is the weather in Boston?',
        toolNames: withTools ? ['getWeather'] : null,
        toolChoice: toolChoice,
      );
      return captured.single;
    }

    test('maps auto, required and none one to one', () async {
      expect((await bodyFor(toolChoice: .auto))['tool_choice'], 'auto');
      expect((await bodyFor(toolChoice: .required))['tool_choice'], 'required');
      expect((await bodyFor(toolChoice: .none))['tool_choice'], 'none');
    });

    test('is omitted when unset or unrecognized', () async {
      expect(await bodyFor(), isNot(contains('tool_choice')));
      expect(
        await bodyFor(toolChoice: ToolChoice('getWeather')),
        isNot(contains('tool_choice')),
      );
    });

    test('is omitted when there are no tools', () async {
      expect(
        await bodyFor(toolChoice: .required, withTools: false),
        isNot(contains('tool_choice')),
      );
    });
  });
}
