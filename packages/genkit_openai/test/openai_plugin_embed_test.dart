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
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Captures every embeddings request the plugin puts on the wire and answers
/// with a vector per input, so tests can assert on the JSON actually sent.
MockClient embeddingClient(
  List<Map<String, dynamic>> capturedBodies, {
  int dimensions = 4,
  bool reverseOrder = false,
  int? returnCount,
  int statusCode = 200,
  Object? errorBody,
}) {
  return MockClient((request) async {
    if (!request.url.path.endsWith('/embeddings')) {
      return http.Response('not found', 404);
    }
    final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
    capturedBodies.add(body);

    if (statusCode != 200) {
      return http.Response(
        jsonEncode(errorBody ?? {'error': 'nope'}),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    }

    final inputs = (body['input'] as List).length;
    final count = returnCount ?? inputs;
    final data = [
      for (var i = 0; i < count; i++)
        {
          'object': 'embedding',
          'index': i,
          'embedding': [
            for (var d = 0; d < (body['dimensions'] as int? ?? dimensions); d++)
              i + d / 10,
          ],
        },
    ];

    return http.Response(
      jsonEncode({
        'object': 'list',
        'model': body['model'],
        'data': reverseOrder ? data.reversed.toList() : data,
        'usage': {'prompt_tokens': 1, 'total_tokens': 1},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

DocumentData doc(String text) => DocumentData(content: [TextPart(text: text)]);

Future<List<Embedding>> embedWith(
  http.Client client, {
  String embedderName = 'text-embedding-3-small',
  required List<DocumentData> documents,
  OpenAIEmbedderOptions? options,
}) async {
  final ai = Genkit(
    plugins: [openAI(apiKey: 'test-key', httpClient: client)],
  );
  addTearDown(ai.shutdown);
  return ai.embedMany(
    embedder: openAI.embedder(embedderName),
    documents: documents,
    options: options,
  );
}

void main() {
  group('wire-level request assembly', () {
    test('sends every document as one input array', () async {
      final captured = <Map<String, dynamic>>[];
      final embeddings = await embedWith(
        embeddingClient(captured),
        documents: [doc('first'), doc('second')],
      );

      expect(captured, hasLength(1));
      expect(captured.single['model'], 'text-embedding-3-small');
      expect(captured.single['input'], ['first', 'second']);
      expect(embeddings, hasLength(2));
      expect(embeddings.first.embedding, hasLength(4));
    });

    test('joins a document\'s text parts with newlines', () async {
      final captured = <Map<String, dynamic>>[];
      await embedWith(
        embeddingClient(captured),
        documents: [
          DocumentData(
            content: [
              TextPart(text: 'one'),
              TextPart(text: 'two'),
            ],
          ),
        ],
      );

      expect(captured.single['input'], ['one\ntwo']);
    });

    test('drops media parts, which OpenAI cannot embed', () async {
      final captured = <Map<String, dynamic>>[];
      await embedWith(
        embeddingClient(captured),
        documents: [
          DocumentData(
            content: [
              TextPart(text: 'a caption'),
              MediaPart(media: Media(url: 'data:image/png;base64,AAA')),
            ],
          ),
        ],
      );

      expect(captured.single['input'], ['a caption']);
    });

    test('sends dimensions and user when asked', () async {
      final captured = <Map<String, dynamic>>[];
      await embedWith(
        embeddingClient(captured),
        documents: [doc('hello')],
        options: OpenAIEmbedderOptions(dimensions: 256, user: 'user-1'),
      );

      expect(captured.single['dimensions'], 256);
      expect(captured.single['user'], 'user-1');
    });

    test('omits both when they are not set', () async {
      final captured = <Map<String, dynamic>>[];
      await embedWith(embeddingClient(captured), documents: [doc('hello')]);

      expect(captured.single, isNot(contains('dimensions')));
      expect(captured.single, isNot(contains('user')));
    });

    test('an empty document list costs no request', () async {
      final captured = <Map<String, dynamic>>[];
      final embeddings = await embedWith(
        embeddingClient(captured),
        documents: const [],
      );

      expect(captured, isEmpty);
      expect(embeddings, isEmpty);
    });
  });

  group('batching', () {
    test('splits a corpus larger than one request allows', () async {
      final captured = <Map<String, dynamic>>[];
      final documents = [for (var i = 0; i < 2500; i++) doc('doc $i')];

      final embeddings = await embedWith(
        embeddingClient(captured),
        documents: documents,
      );

      expect(captured, hasLength(2));
      expect(captured[0]['input'] as List, hasLength(2048));
      expect(captured[1]['input'] as List, hasLength(452));
      expect((captured[1]['input'] as List).first, 'doc 2048');
      expect(embeddings, hasLength(2500));
    });

    test('one batch below the limit stays one request', () async {
      final captured = <Map<String, dynamic>>[];
      await embedWith(
        embeddingClient(captured),
        documents: [for (var i = 0; i < 2048; i++) doc('doc $i')],
      );

      expect(captured, hasLength(1));
    });
  });

  group('response handling', () {
    test('orders vectors by the index OpenAI stamps on them', () async {
      final embeddings = await embedWith(
        embeddingClient([], reverseOrder: true),
        documents: [doc('first'), doc('second'), doc('third')],
      );

      // The fake builds vector i as [i, i + 0.1, ...], so a mis-ordered
      // response would put 2.0 first.
      expect(embeddings.map((e) => e.embedding.first), [0.0, 1.0, 2.0]);
    });

    test('a short response is an error, not a silent misalignment', () async {
      await expectLater(
        embedWith(
          embeddingClient([], returnCount: 1),
          documents: [doc('first'), doc('second')],
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INTERNAL)
              .having((e) => e.message, 'message', contains('2 input')),
        ),
      );
    });

    test('a failure keeps the stack trace of its origin', () async {
      // The count-mismatch check throws from embed.dart; a plain `throw` at
      // the plugin's catch site would restamp the trace there.
      try {
        await embedWith(
          embeddingClient([], returnCount: 1),
          documents: [doc('first'), doc('second')],
        );
        fail('expected a GenkitException');
      } on GenkitException catch (_, stackTrace) {
        expect(stackTrace.toString(), contains('embed.dart'));
      }
    });

    test('an API error keeps its HTTP status', () async {
      await expectLater(
        embedWith(
          embeddingClient([], statusCode: 401),
          documents: [doc('hello')],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.UNAUTHENTICATED,
          ),
        ),
      );
    });
  });

  group('input validation', () {
    test('a document with no text names its index', () async {
      final captured = <Map<String, dynamic>>[];

      await expectLater(
        embedWith(
          embeddingClient(captured),
          documents: [
            doc('fine'),
            DocumentData(
              content: [
                MediaPart(media: Media(url: 'data:image/png;base64,A')),
              ],
            ),
          ],
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having((e) => e.message, 'message', contains('index 1')),
        ),
      );
      expect(captured, isEmpty, reason: 'rejected before any request');
    });

    test('dimensions on a model that cannot shorten is rejected', () async {
      final captured = <Map<String, dynamic>>[];

      await expectLater(
        embedWith(
          embeddingClient(captured),
          embedderName: 'text-embedding-ada-002',
          documents: [doc('hello')],
          options: OpenAIEmbedderOptions(dimensions: 256),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having((e) => e.message, 'message', contains('1536')),
        ),
      );
      expect(captured, isEmpty);
    });

    test('dimensions larger than the model returns is rejected', () async {
      await expectLater(
        embedWith(
          embeddingClient([]),
          documents: [doc('hello')],
          options: OpenAIEmbedderOptions(dimensions: 4096),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });

    test('a compat host judges its own limits', () async {
      // The catalog describes OpenAI's models. A host serving one of those
      // names need not share its limits, so the request goes through and the
      // backend answers for itself.
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            baseUrl: 'https://api.deepinfra.com/v1/openai',
            httpClient: embeddingClient(captured),
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.embed(
        embedder: openAI.embedder('text-embedding-ada-002'),
        document: doc('hello'),
        options: OpenAIEmbedderOptions(dimensions: 256),
      );

      expect(captured.single['dimensions'], 256);
    });

    test('an uncurated embedder is left to OpenAI to judge', () async {
      final captured = <Map<String, dynamic>>[];
      await embedWith(
        embeddingClient(captured),
        embedderName: 'text-embedding-4-turbo',
        documents: [doc('hello')],
        options: OpenAIEmbedderOptions(dimensions: 99999),
      );

      expect(captured.single['dimensions'], 99999);
    });
  });

  group('resolve', () {
    test('a curated embedder resolves with its catalog metadata', () {
      final plugin = OpenAIPlugin(apiKey: 'test-key');
      final action = plugin.resolve(.embedder, 'text-embedding-3-large');

      expect(action, isA<Embedder>());
      final info = (action!.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['label'], 'OpenAI text-embedding-3-large');
      expect(info['dimensions'], 3072);
    });

    test('an uncurated embedder resolves without a size claim', () {
      final plugin = OpenAIPlugin(apiKey: 'test-key');
      final action = plugin.resolve(.embedder, 'text-embedding-4-turbo')!;

      final info = (action.metadata['model'] as Map).cast<String, dynamic>();
      expect(info.containsKey('dimensions'), isFalse);
      // Embedder falls back to the action name for the label.
      expect(info['label'], 'openai/text-embedding-4-turbo');
    });

    test('catalog metadata is not mutable through the action', () {
      final plugin = OpenAIPlugin(apiKey: 'test-key');
      final action = plugin.resolve(.embedder, 'text-embedding-3-small')!;
      final info = (action.metadata['model'] as Map).cast<String, dynamic>();

      // The action's own map is a copy - core writes the label and options
      // schema into it - but the catalog entry it was built from is shared
      // with every other resolution, so it must not be reachable for writing.
      expect(
        () => (info['supports'] as Map)['input'] = ['image'],
        throwsUnsupportedError,
      );
    });

    test('a custom namespace is honoured by the ref and the action', () {
      final plugin = OpenAIPlugin(name: 'deepinfra', apiKey: 'test-key');
      final action = plugin.resolve(.embedder, 'text-embedding-3-small')!;

      expect(action.name, 'deepinfra/text-embedding-3-small');
      expect(
        openAI.embedder('text-embedding-3-small', namespace: 'deepinfra').name,
        action.name,
      );
    });
  });
}
