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
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

ToolRequestPart _echoCall(Object? input) => ToolRequestPart(
  toolRequest: ToolRequest(name: 'echo', ref: 'r1', input: input),
);

/// A provider stand-in that only understands object parameters, so it emits
/// object-shaped calls.
ModelResponse _provider(ModelRequest request, List<ModelRequest> log) {
  log.add(request);
  if (request.messages.last.role == Role.tool) {
    return ModelResponse(
      finishReason: .stop,
      message: Message(
        role: .model,
        content: [TextPart(text: 'ok')],
      ),
    );
  }
  return ModelResponse(
    finishReason: .stop,
    message: Message(
      role: .model,
      content: [
        _echoCall({'input': 'hi'}),
      ],
    ),
  );
}

List<Object?> _toolInputs(Iterable<Message> messages) => [
  for (final part in messages.expand((m) => m.content))
    if (part.isToolRequest) part.toolRequestPart!.toolRequest.input,
];

/// Records the raw JSON bodies the remote model client sends.
final class _RecordingClient extends http.BaseClient {
  final bodies = <Map<String, dynamic>>[];
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request) {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

void main() {
  // The remote model is a proxy: it forwards the declared schema and bare
  // values, and the serving model does the wrapping.
  group('remote model with a primitive tool input', () {
    late HttpServer server;
    late Genkit serverAi;
    late Genkit clientAi;
    late List<ModelRequest> providerSaw;
    late _RecordingClient httpClient;

    setUp(() async {
      providerSaw = [];
      httpClient = _RecordingClient();
      serverAi = Genkit(isDevEnv: false);
      final model = serverAi.defineModel(
        name: 'provider',
        fn: (request, ctx) async {
          final response = _provider(request, providerSaw);
          final message = response.message!;
          ctx.sendChunk(ModelResponseChunk(content: message.content));
          return response;
        },
      );
      server = await (GenkitRouter()..addAction(model)).serve(port: 0);
      clientAi = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      httpClient.close();
      await server.close(force: true);
      await serverAi.shutdown();
      await clientAi.shutdown();
    });

    for (final streaming in [false, true]) {
      test('round-trips (streaming: $streaming)', () async {
        Object? toolGot;
        final echo = clientAi.defineTool(
          name: 'echo',
          description: 'Echo a string back.',
          inputSchema: .string(),
          fn: (input, _) async {
            toolGot = input;
            return .response('echo: $input');
          },
        );
        final chunkInputs = <Object?>[];

        final response = await clientAi.generate(
          model: clientAi.defineRemoteModel(
            name: 'remote',
            url: 'http://localhost:${server.port}/provider',
            httpClient: httpClient,
          ),
          prompt: 'go',
          tools: [echo],
          onChunk: streaming
              ? (chunk) => chunkInputs.addAll([
                  for (final part in chunk.content)
                    if (part.isToolRequest)
                      part.toolRequestPart!.toolRequest.input,
                ])
              : null,
        );

        expect(response.text, 'ok');
        expect(toolGot, 'hi');
        expect(_toolInputs(response.messages), ['hi']);
        if (streaming) expect(chunkInputs, contains('hi'));

        // On the HTTP wire: the declared schema and the bare value.
        final wire = [
          for (final body in httpClient.bodies)
            ModelRequest.fromJson(body['data'] as Map<String, dynamic>),
        ];
        expect(wire.first.tools!.single.inputSchema!['type'], 'string');
        expect(_toolInputs(wire.last.messages), ['hi']);

        // The serving model wraps for its provider.
        final schema = providerSaw.first.tools!.single.inputSchema!;
        expect(schema['properties'], {
          'input': {'type': 'string'},
        });
        expect(_toolInputs(providerSaw.last.messages), [
          {'input': 'hi'},
        ]);
      });
    }
  });

  test('a server that does not wrap gets the request unchanged', () async {
    // A plain flow over `ModelRequest`: no `Model` wrapper, like a server
    // that predates primitive tool input support.
    final serverAi = Genkit(isDevEnv: false);
    final providerSaw = <ModelRequest>[];
    final flow = serverAi.defineFlow(
      name: 'provider',
      inputSchema: ModelRequest.$schema,
      outputSchema: ModelResponse.$schema,
      fn: (request, _) async => _provider(request, providerSaw),
    );
    final server = await (GenkitRouter()..addAction(flow)).serve(port: 0);
    final clientAi = Genkit(isDevEnv: false);
    addTearDown(() async {
      await server.close(force: true);
      await serverAi.shutdown();
      await clientAi.shutdown();
    });

    final echo = clientAi.defineTool(
      name: 'echo',
      description: 'Echo a string back.',
      inputSchema: .string(),
      fn: (input, _) async => .response('echo: $input'),
    );
    final response = await clientAi.generate(
      model: clientAi.defineRemoteModel(
        name: 'remote',
        url: 'http://localhost:${server.port}/provider',
      ),
      prompt: 'go',
      tools: [echo],
    );

    expect(providerSaw.first.tools!.single.inputSchema!['type'], 'string');
    // The object-shaped call reaches a `.string()` tool: the #560 failure.
    expect(response.finishReason, FinishReason.failed);
  });
}
