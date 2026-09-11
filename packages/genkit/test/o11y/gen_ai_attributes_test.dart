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

import 'package:genkit/src/o11y/genai/gen_ai_attributes.dart';
import 'package:test/test.dart';

void main() {
  group('splitModelName', () {
    test('splits a prefixed model name', () {
      final result = splitModelName('googleai/gemini-flash-latest');
      expect(result.prefix, 'googleai');
      expect(result.model, 'gemini-flash-latest');
    });

    test('keeps only the first slash as separator', () {
      final result = splitModelName('vertexai/publishers/google/models/x');
      expect(result.prefix, 'vertexai');
      expect(result.model, 'publishers/google/models/x');
    });

    test('returns null prefix when no slash', () {
      final result = splitModelName('some-model');
      expect(result.prefix, isNull);
      expect(result.model, 'some-model');
    });
  });

  group('deriveProviderName', () {
    test('maps known prefixes', () {
      expect(deriveProviderName('googleai'), 'gcp.gen_ai');
      expect(deriveProviderName('google-genai'), 'gcp.gen_ai');
      expect(deriveProviderName('vertexai'), 'gcp.vertex_ai');
      expect(deriveProviderName('openai'), 'openai');
      expect(deriveProviderName('anthropic'), 'anthropic');
    });

    test('is case insensitive', () {
      expect(deriveProviderName('GoogleAI'), 'gcp.gen_ai');
    });

    test('passes unknown prefixes through lowercased', () {
      expect(deriveProviderName('MyPlugin'), 'myplugin');
    });

    test('returns null for null or empty', () {
      expect(deriveProviderName(null), isNull);
      expect(deriveProviderName(''), isNull);
    });
  });

  group('mapFinishReason', () {
    test('maps direct values', () {
      expect(mapFinishReason('stop', failed: false), 'stop');
      expect(mapFinishReason('length', failed: false), 'length');
      expect(mapFinishReason('blocked', failed: false), 'content_filter');
    });

    test('maps interrupted to stop', () {
      expect(mapFinishReason('interrupted', failed: false), 'stop');
    });

    test('resolves ambiguous reasons by failure state', () {
      expect(mapFinishReason('other', failed: false), 'stop');
      expect(mapFinishReason('other', failed: true), 'error');
      expect(mapFinishReason('unknown', failed: true), 'error');
      expect(mapFinishReason(null, failed: true), 'error');
    });
  });

  group('deriveOutputType', () {
    test('detects json', () {
      expect(deriveOutputType(format: 'json'), 'json');
      expect(deriveOutputType(contentType: 'application/json'), 'json');
    });

    test('detects text', () {
      expect(deriveOutputType(format: 'text'), 'text');
      expect(deriveOutputType(contentType: 'text/plain'), 'text');
    });

    test('returns null when unknown', () {
      expect(deriveOutputType(), isNull);
      expect(deriveOutputType(format: 'media'), isNull);
    });
  });

  group('numeric coercion', () {
    test('asInt', () {
      expect(asInt(3), 3);
      expect(asInt(3.9), 3);
      expect(asInt('5'), 5);
      expect(asInt('x'), isNull);
      expect(asInt(null), isNull);
    });

    test('asDouble', () {
      expect(asDouble(3), 3.0);
      expect(asDouble(3.5), 3.5);
      expect(asDouble('5.5'), 5.5);
      expect(asDouble('x'), isNull);
      expect(asDouble(null), isNull);
    });

    test('asStringList', () {
      expect(asStringList(['a', 'b']), ['a', 'b']);
      expect(asStringList([1, 2]), ['1', '2']);
      expect(asStringList('a'), ['a']);
      expect(asStringList(null), isNull);
    });
  });
}
