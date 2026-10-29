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

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

import 'wire_harness.dart';

const _groundingMetadata = {
  'searchEntryPoint': {'renderedContent': '<div>Search</div>'},
  'groundingChunks': [
    {
      'web': {
        'uri': 'https://example.com/a',
        'title': 'Example',
        'domain': 'example.com',
      },
    },
    {
      'maps': {
        'uri': 'https://maps.google.com/?cid=1',
        'title': 'Cafe',
        'placeId': 'places/abc',
      },
    },
  ],
  'groundingSupports': [
    {
      'segment': {
        'partIndex': 0,
        'startIndex': 0,
        'endIndex': 5,
        'text': 'Hello',
      },
      'groundingChunkIndices': [0, 1],
    },
  ],
  // firebase_ai matches this against List<String>, which decoded JSON never is,
  // so it always parses as empty.
  'webSearchQueries': ['weather today'],
};

const _urlContextMetadata = {
  'urlMetadata': [
    {
      'retrievedUrl': 'https://example.com/a',
      'urlRetrievalStatus': 'URL_RETRIEVAL_STATUS_SUCCESS',
    },
  ],
};

Map<String, dynamic> _grounded(String text, {String? finishReason = 'STOP'}) {
  final response = textResponse(text, finishReason: finishReason);
  final candidate = (response['candidates'] as List).single as Map;
  return {
    ...response,
    'candidates': [
      {
        ...candidate,
        'groundingMetadata': _groundingMetadata,
        'urlContextMetadata': _urlContextMetadata,
      },
    ],
  };
}

final _expectedGrounding = {
  ..._groundingMetadata,
  'webSearchQueries': <String>[],
};

void main() {
  setUpAll(setUpFirebaseApp);

  test('grounding options add their tools', () async {
    final client = WireClient();

    await wireModel(client)(
      userRequest(
        'hello',
        config: {
          'googleSearch': <String, Object?>{},
          'urlContext': <String, Object?>{},
          'googleMaps': <String, Object?>{},
        },
      ),
    );

    expect(client.requests.single.body['tools'], [
      {'googleSearch': <String, Object?>{}},
      {'urlContext': <String, Object?>{}},
      {'googleMaps': <String, Object?>{}},
    ]);
  });

  test('no grounding tools are sent by default', () async {
    final client = WireClient();

    await wireModel(client)(userRequest('hello'));

    expect(client.requests.single.body, isNot(contains('tools')));
  });

  test('retrievalConfig goes in toolConfig', () async {
    final client = WireClient();

    await wireModel(client)(
      userRequest(
        'cafes near me',
        config: {
          'googleMaps': <String, Object?>{},
          'retrievalConfig': {
            'latLng': {'latitude': 51.5, 'longitude': -0.12},
            'languageCode': 'en_GB',
          },
        },
      ),
    );

    expect(client.requests.single.body['toolConfig'], {
      'retrievalConfig': {
        'latLng': {'latitude': 51.5, 'longitude': -0.12},
        'languageCode': 'en_GB',
      },
    });
  });

  test('a latLng without a longitude throws invalidArgument and sends '
      'nothing', () async {
    final client = WireClient();

    await expectLater(
      wireModel(client)(
        userRequest(
          'hello',
          config: {
            'retrievalConfig': {
              'latLng': {'latitude': 51.5},
            },
          },
        ),
      ),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.invalidArgument,
        ),
      ),
    );
    expect(client.requests, isEmpty);
  });

  for (final MapEntry(key: name, value: config) in {
    'googleSearch: true': {'googleSearch': true},
    'a string retrievalConfig': {'retrievalConfig': 'London'},
  }.entries) {
    test('$name throws invalidArgument and sends nothing', () async {
      final client = WireClient();

      await expectLater(
        wireModel(client)(userRequest('hello', config: config)),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );
      expect(client.requests, isEmpty);
    });
  }

  for (final streaming in [false, true]) {
    test('grounding and URL context metadata reach custom and raw '
        '(streaming: $streaming)', () async {
      final client = WireClient(
        response: _grounded('Hello world'),
        // Gemini sends the metadata with the last chunk.
        streamChunks: [
          textResponse('Hello ', finishReason: null),
          _grounded('world'),
        ],
      );

      final response = await wireModel(client)(
        userRequest('hello'),
        onChunk: streaming ? (_) {} : null,
      );

      expect(response.custom?['groundingMetadata'], _expectedGrounding);
      expect(response.custom?['urlContextMetadata'], _urlContextMetadata);
      expect(response.custom?['finishReason'], 'STOP');
      final candidate = (response.raw!['candidates'] as List).single as Map;
      expect(candidate['groundingMetadata'], _expectedGrounding);
      expect(candidate['urlContextMetadata'], _urlContextMetadata);
    });
  }
}
