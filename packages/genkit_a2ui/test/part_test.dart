// Copyright 2025 Google LLC
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
import 'package:genkit_a2ui/a2ui.dart';
import 'package:test/test.dart';

final sampleEnvelope = <String, dynamic>{
  'createSurface': {'surfaceId': 's1', 'catalogId': 'c1'},
};

void main() {
  group('a2uiPart', () {
    test('wraps envelopes in a data part tagged with the a2ui mime type', () {
      final part = a2uiPart([sampleEnvelope]);
      expect(part.data, {
        'envelopes': [sampleEnvelope],
      });
      expect(part.metadata?['mimeType'], a2uiMimeType);
    });
  });

  group('isA2uiPart', () {
    test('accepts a well-formed a2ui data part', () {
      expect(isA2uiPart(a2uiPart([sampleEnvelope])), isTrue);
    });

    test('rejects a plain text part', () {
      expect(isA2uiPart(TextPart(text: 'hi')), isFalse);
    });

    test('rejects a data part with a different mime type', () {
      expect(
        isA2uiPart(
          DataPart(
            data: {'envelopes': <dynamic>[]},
            metadata: {'mimeType': 'application/json'},
          ),
        ),
        isFalse,
      );
    });

    test('rejects a data part whose data.envelopes is not an array', () {
      expect(
        isA2uiPart(
          DataPart(
            data: {'envelopes': <String, dynamic>{}},
            metadata: {'mimeType': a2uiMimeType},
          ),
        ),
        isFalse,
      );
    });

    test('rejects a data part with no mime type metadata', () {
      expect(isA2uiPart(DataPart(data: {'envelopes': <dynamic>[]})), isFalse);
    });
  });

  group('a2uiEnvelopesFromParts', () {
    test('extracts envelopes from a single a2ui part', () {
      expect(
        a2uiEnvelopesFromParts([
          a2uiPart([sampleEnvelope]),
        ]),
        [sampleEnvelope],
      );
    });

    test('extracts envelopes from a message\'s content', () {
      final message = Message(
        role: Role.model,
        content: [
          TextPart(text: 'hi'),
          a2uiPart([sampleEnvelope]),
        ],
      );
      expect(a2uiEnvelopesFromParts(message.content), [sampleEnvelope]);
    });

    test('collects across multiple parts', () {
      final parts = <Part>[
        TextPart(text: 'hi'),
        a2uiPart([sampleEnvelope]),
        a2uiPart([sampleEnvelope]),
      ];
      expect(a2uiEnvelopesFromParts(parts), [sampleEnvelope, sampleEnvelope]);
    });

    test('returns [] for prose / non-a2ui content', () {
      expect(a2uiEnvelopesFromParts([TextPart(text: 'hi')]), isEmpty);
    });

    test('returns [] for empty content', () {
      expect(a2uiEnvelopesFromParts([]), isEmpty);
    });
  });
}
