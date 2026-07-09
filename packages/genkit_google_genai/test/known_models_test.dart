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

import 'package:genkit_google_genai/src/known_models.dart';
import 'package:test/test.dart';

void main() {
  group('KnownGeminiModel', () {
    test('info carries the label, stable stage, and multimodal supports', () {
      for (final model in KnownGeminiModel.values) {
        final info = model.info;
        expect(info.label, model.label);
        expect(info.stage, 'stable');
        expect(info.supports, {
          'multiturn': true,
          'media': true,
          'tools': true,
          'toolChoice': true,
          'systemRole': true,
          'constrained': true,
        });
      }
    });

    test('supports map is unmodifiable', () {
      expect(
        () =>
            KnownGeminiModel.gemini35Flash.info.supports!['multiturn'] = false,
        throwsUnsupportedError,
      );
    });
  });

  group('knownGeminiModels', () {
    test('exposes the curated bare model names', () {
      // Pin the literal ids so a typo in an enum value fails the suite (the
      // derivation test below draws both sides from the enum, so it can't).
      expect(
        knownGeminiModels.keys,
        containsAll([
          'gemini-3.5-flash',
          'gemini-3.1-flash-lite',
          'gemini-3.1-flash-image',
          'gemini-3-pro-image',
        ]),
      );
    });

    test('is derived from the enum, keyed by bare model id', () {
      expect(
        knownGeminiModels.keys,
        unorderedEquals([for (final m in KnownGeminiModel.values) m.id]),
      );
      for (final model in KnownGeminiModel.values) {
        expect(knownGeminiModels[model.id]!.label, model.label);
      }
    });
  });
}
