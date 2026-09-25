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
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// TODO(#366): consolidate with the shared wire harness once it lands.
/// Captures every chat-completions request body the plugin puts on the wire
/// and serves canned OpenAI responses.
MockClient wireClient(List<Map<String, dynamic>> capturedBodies) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'gpt-4o',
              'object': 'model',
              'created': 0,
              'owned_by': 'openai',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith('/chat/completions')) {
      capturedBodies.add(
        (jsonDecode(request.body) as Map).cast<String, dynamic>(),
      );
      return http.Response(
        jsonEncode({
          'id': 'chatcmpl-test',
          'object': 'chat.completion',
          'created': 0,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  group('tool parameter schemas on the wire', () {
    test('a draft-07 recursive schema promotes too', () {
      // `flatten` resolves from `definitions` as well as `$defs`, so it throws
      // for either - and MCP servers and pydantic v1 emit the legacy spelling.
      final tool = GenkitConverter.toOpenAITool(
        ToolDefinition(
          name: 'walkTree',
          description: 'Walks a tree of nodes',
          inputSchema: {
            r'$ref': '#/definitions/Node',
            'definitions': {
              'Node': {
                'type': 'object',
                'properties': {
                  'child': {r'$ref': '#/definitions/Node'},
                },
              },
            },
          },
        ),
      );

      final parameters = tool.function.parameters!;
      expect(parameters['type'], 'object');
      expect(parameters.containsKey(r'$ref'), isFalse);
      expect(parameters['definitions'], isA<Map>());
    });

    test('a recursive non-object root is left alone', () {
      // Promoting would make the root an array, which `toOpenAITool` refuses
      // outright - turning a request that used to go out into a local failure
      // on every host.
      final authored = <String, dynamic>{
        r'$ref': r'#/$defs/Nodes',
        r'$defs': {
          'Nodes': {
            'type': 'array',
            'items': {r'$ref': r'#/$defs/Nodes'},
          },
        },
      };

      final tool = GenkitConverter.toOpenAITool(
        ToolDefinition(
          name: 'walkTree',
          description: 'Walks a forest',
          inputSchema: authored,
        ),
      );

      // Unchanged but for the `type: object` the guard prepends to a rootless
      // schema - the pre-existing behaviour, not a refusal.
      expect(
        tool.function.parameters,
        containsPair(r'$ref', authored[r'$ref']),
      );
    });

    test('a self-referential tool schema promotes its root def', () {
      // `flatten` cannot inline a type that contains itself and throws, which
      // used to fail the whole request locally - reported as an OpenAI API
      // error, with nothing having reached the host. Sending the authored
      // `{$ref, $defs}` shape does not work either: xAI answers "tool
      // parameter root must be an object type (root schema is a $ref)", and a
      // sibling `type: object` does not satisfy it. So the root definition is
      // promoted and `$defs` travels with it, leaving the internal refs - the
      // recursion itself - to resolve against it.
      final recursive = <String, dynamic>{
        r'$ref': r'#/$defs/Node',
        r'$defs': {
          'Node': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'child': {r'$ref': r'#/$defs/Node'},
            },
          },
        },
      };

      final tool = GenkitConverter.toOpenAITool(
        ToolDefinition(
          name: 'walkTree',
          description: 'Walks a tree of nodes',
          inputSchema: recursive,
        ),
      );

      final parameters = tool.function.parameters!;
      expect(parameters['type'], 'object');
      expect(parameters.containsKey(r'$ref'), isFalse);
      expect(parameters[r'$defs'], isA<Map>());
      // The recursion survives: the inner ref still points into $defs.
      final child = (parameters['properties'] as Map)['child'] as Map;
      expect(child[r'$ref'], r'#/$defs/Node');
    });

    test('schema-less tool goes out as an empty object schema', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );
      ai.defineTool(
        name: 'getWeather',
        description: 'Get the weather for a location',
        fn: (input, ctx) async => .response({'temperature': 72}),
      );

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'What is the weather in Boston?',
        toolNames: ['getWeather'],
      );

      final tools = (captured.single['tools'] as List)
          .cast<Map<String, dynamic>>();
      final function = (tools.single['function'] as Map)
          .cast<String, dynamic>();
      expect(function['parameters'], {'type': 'object', 'properties': {}});

      await ai.shutdown();
    });

    test(
      'tool with a primitive input schema fails before any request',
      () async {
        final captured = <Map<String, dynamic>>[];
        final ai = Genkit(
          plugins: [
            openAI(apiKey: 'test-key', httpClient: wireClient(captured)),
          ],
        );
        ai.defineTool<String, String>(
          name: 'echo',
          description: 'Echoes the input',
          inputSchema: .string(),
          outputSchema: .string(),
          fn: (input, ctx) async => .response(input),
        );

        // The primitive tool schema throws while building the request, before
        // any HTTP call. `generate` no longer rethrows: it resolves to a
        // `failed` response carrying the error, so assert on that (and that
        // nothing hit the wire).
        final res = await ai.generate(
          model: openAI.model('gpt-4o'),
          prompt: 'Echo hello.',
          toolNames: ['echo'],
        );
        expect(res.finishReason, FinishReason.failed);
        expect(res.error, isNotNull);
        expect(res.error!.status, StatusCodes.INVALID_ARGUMENT.name);
        expect(res.error!.message, allOf(contains('echo'), contains('object')));
        expect(captured, isEmpty);

        await ai.shutdown();
      },
    );
  });
}
