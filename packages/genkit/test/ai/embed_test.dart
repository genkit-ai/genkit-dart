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

DocumentData _doc(String text) => DocumentData(content: [TextPart(text: text)]);

void main() {
  group('embed', () {
    late Genkit ai;
    late List<EmbedRequest> requests;
    final embedder = embedderRef('lengths');

    setUp(() {
      ai = Genkit(isDevEnv: false);
      requests = [];
      // Embeds each document as [text length].
      ai.defineEmbedder(
        name: 'lengths',
        fn: (req, ctx) async {
          requests.add(req);
          return EmbedResponse(
            embeddings: [
              for (final d in req.input)
                Embedding(
                  embedding: [
                    d.content.map((p) => p.text ?? '').join().length.toDouble(),
                  ],
                ),
            ],
          );
        },
      );
    });

    tearDown(() => ai.shutdown());

    test('embeds a single document', () async {
      final result = await ai.embed(embedder: embedder, document: _doc('abc'));

      expect(result.single.embedding, [3]);
      expect(requests.single.input, hasLength(1));
    });

    test('embeds many documents in one request, in order', () async {
      final result = await ai.embed(
        embedder: embedder,
        documents: [_doc('a'), _doc('abcd'), _doc('ab')],
      );

      expect(result.map((e) => e.embedding.single), [1, 4, 2]);
      expect(requests.single.input, hasLength(3));
    });

    test('passes options through', () async {
      await ai.embed(
        embedder: embedder,
        document: _doc('a'),
        options: {'dimensions': 8},
      );

      expect(requests.single.options, {'dimensions': 8});
    });

    test('rejects neither or both of document and documents', () async {
      await expectLater(ai.embed(embedder: embedder), throwsArgumentError);
      await expectLater(
        ai.embed(embedder: embedder, document: _doc('a'), documents: []),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });

    test('throws NOT_FOUND for an unknown embedder', () async {
      await expectLater(
        ai.embed(embedder: embedderRef('missing'), document: _doc('a')),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.NOT_FOUND,
          ),
        ),
      );
    });
  });
}
