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

import 'package:firebase_ai/firebase_ai.dart' as fai;

// `firebase_ai` parses grounding and URL context metadata but neither exports
// their types nor gives them a `toJson`, so these rebuild the wire form from
// the candidate.

/// The wire JSON of [candidate]'s `groundingMetadata`, or null.
Map<String, Object?>? groundingMetadataJson(fai.Candidate candidate) {
  final m = candidate.groundingMetadata;
  if (m == null) return null;
  return {
    if (m.searchEntryPoint case final entryPoint?)
      'searchEntryPoint': {'renderedContent': entryPoint.renderedContent},
    'groundingChunks': [
      for (final chunk in m.groundingChunks)
        {
          if (chunk.web case final web?)
            'web': {
              'uri': ?web.uri,
              'title': ?web.title,
              'domain': ?web.domain,
            },
          if (chunk.maps case final maps?)
            'maps': {
              'uri': ?maps.uri,
              'title': ?maps.title,
              'placeId': ?maps.placeId,
            },
        },
    ],
    'groundingSupports': [
      for (final support in m.groundingSupports)
        {
          'segment': {
            'partIndex': support.segment.partIndex,
            'startIndex': support.segment.startIndex,
            'endIndex': support.segment.endIndex,
            'text': support.segment.text,
          },
          'groundingChunkIndices': support.groundingChunkIndices,
        },
    ],
    'webSearchQueries': m.webSearchQueries,
  };
}

/// The wire JSON of [candidate]'s `urlContextMetadata`, or null.
Map<String, Object?>? urlContextMetadataJson(fai.Candidate candidate) {
  final m = candidate.urlContextMetadata;
  if (m == null) return null;
  return {
    'urlMetadata': [
      for (final url in m.urlMetadata)
        {
          'retrievedUrl': ?url.retrievedUrl?.toString(),
          'urlRetrievalStatus': url.urlRetrievalStatus.toJson(),
        },
    ],
  };
}
