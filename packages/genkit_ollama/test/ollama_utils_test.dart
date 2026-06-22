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

import 'package:genkit_ollama/genkit_ollama.dart';
import 'package:ollama_dart/ollama_dart.dart' as sdk;
import 'package:test/test.dart';

void main() {
  group('modelInfoFromShow', () {
    test('maps capabilities to supports flags', () {
      final info = modelInfoFromShow(
        'llama3.2',
        sdk.ShowResponse(capabilities: ['completion', 'tools']),
      );
      final supports = info.supports!;
      expect(supports['multiturn'], isTrue);
      expect(supports['tools'], isTrue);
      expect(supports['media'], isFalse);
      expect(supports['constrained'], isTrue);
    });

    test('flags vision models as media-capable', () {
      final info = modelInfoFromShow(
        'llava',
        sdk.ShowResponse(capabilities: ['completion', 'vision']),
      );
      expect(info.supports!['media'], isTrue);
    });

    test('falls back to a generic profile without capabilities', () {
      final info = modelInfoFromShow('mystery', sdk.ShowResponse());
      expect(info.supports!['tools'], isTrue);
      expect(info.supports!['media'], isFalse);
    });
  });

  group('isEmbedderShow', () {
    test('detects the embedding capability', () {
      expect(
        isEmbedderShow(sdk.ShowResponse(capabilities: ['embedding'])),
        isTrue,
      );
      expect(
        isEmbedderShow(sdk.ShowResponse(capabilities: ['completion'])),
        isFalse,
      );
    });

    test('returns false when capabilities are absent', () {
      expect(isEmbedderShow(sdk.ShowResponse()), isFalse);
    });
  });

  group('embeddingDimensionsFromShow', () {
    test('reads <arch>.embedding_length', () {
      final dims = embeddingDimensionsFromShow(
        sdk.ShowResponse(modelInfo: {'bert.embedding_length': 768}),
      );
      expect(dims, 768);
    });

    test('coerces num and string values to int', () {
      expect(
        embeddingDimensionsFromShow(
          sdk.ShowResponse(modelInfo: {'bert.embedding_length': 768.0}),
        ),
        768,
      );
      expect(
        embeddingDimensionsFromShow(
          sdk.ShowResponse(modelInfo: {'bert.embedding_length': '768'}),
        ),
        768,
      );
    });

    test('returns null when absent', () {
      expect(embeddingDimensionsFromShow(sdk.ShowResponse()), isNull);
    });
  });
}
