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

import 'package:test/test.dart';

import 'wire_harness.dart';

void main() {
  group('tool_choice on the wire', () {
    Future<Object?> toolChoiceFor({
      String? toolChoice,
      String? forceTool,
    }) async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        tools: ['lookup', 'required'],
        toolChoice: toolChoice,
        forceTool: forceTool,
      );
      return body['tool_choice'];
    }

    test('auto maps to auto', () async {
      expect(await toolChoiceFor(toolChoice: 'auto'), {'type': 'auto'});
    });

    test('required maps to any, not to a tool named "required"', () async {
      expect(await toolChoiceFor(toolChoice: 'required'), {'type': 'any'});
    });

    test('none maps to none', () async {
      expect(await toolChoiceFor(toolChoice: 'none'), {'type': 'none'});
    });

    test('an unrecognized value is not treated as a tool name', () async {
      expect(await toolChoiceFor(toolChoice: 'lookup'), isNull);
    });

    test('forceTool forces the named tool', () async {
      expect(await toolChoiceFor(forceTool: 'lookup'), {
        'type': 'tool',
        'name': 'lookup',
      });
    });

    test('forceTool takes precedence over toolChoice', () async {
      expect(await toolChoiceFor(toolChoice: 'none', forceTool: 'lookup'), {
        'type': 'tool',
        'name': 'lookup',
      });
    });
  });
}
