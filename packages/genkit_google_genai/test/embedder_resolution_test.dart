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

import 'package:genkit_google_genai/src/plugin_impl.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleGenAiPluginImpl', () {
    test('resolve returns embedder action', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('embedder', 'text-embedding-004');
      expect(action, isNotNull);
      expect(action!.name, 'googleai/text-embedding-004');
    });

    test('resolve returns null for unknown action type', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('unknown', 'text-embedding-004');
      expect(action, isNull);
    });
  });
}
