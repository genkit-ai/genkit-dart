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
import 'package:test/test.dart';

void main() {
  group('OllamaChatOptions', () {
    test('parses common and Ollama-specific fields', () {
      final options = OllamaChatOptions.$schema.parse({
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.9,
        'maxOutputTokens': 256,
        'numCtx': 4096,
        'keepAlive': '5m',
        'stop': ['END'],
      });
      expect(options.temperature, 0.7);
      expect(options.topK, 40);
      expect(options.numCtx, 4096);
      expect(options.keepAlive, '5m');
      expect(options.stop, ['END']);
    });

    test('creates empty options', () {
      final options = OllamaChatOptions();
      expect(options.temperature, isNull);
      expect(options.numCtx, isNull);
    });
  });
}
