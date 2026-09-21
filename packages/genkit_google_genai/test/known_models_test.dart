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
import 'package:genkit_google_genai/src/model.dart';
import 'package:test/test.dart';

const _multimodalProfile = {
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': true,
  'systemRole': true,
  'constrained': true,
};

const _ttsProfile = {
  'multiturn': false,
  'media': false,
  'tools': false,
  'toolChoice': false,
  'systemRole': false,
  'constrained': false,
  'output': ['media'],
};

void main() {
  group('GeminiModelFamily.of', () {
    const cases = {
      'gemini-2.5-pro': GeminiModelFamily.text,
      'gemini-3.1-pro-preview': GeminiModelFamily.text,
      'gemini-flash-latest': GeminiModelFamily.text,
      'gemma-3-27b-it': GeminiModelFamily.text,
      'gemma-4-31b-it': GeminiModelFamily.text,
      'gemini-2.5-flash-image': GeminiModelFamily.image,
      'gemini-3.1-flash-lite-image': GeminiModelFamily.image,
      'gemini-3-pro-image-preview': GeminiModelFamily.image,
      'gemini-2.5-flash-preview-tts': GeminiModelFamily.tts,
      'gemini-3.1-flash-tts-preview': GeminiModelFamily.tts,
      'gemini-2.5-flash-tts': GeminiModelFamily.tts,
    };

    for (final MapEntry(key: name, value: family) in cases.entries) {
      test('$name is ${family.name}', () {
        expect(GeminiModelFamily.of(name), family);
      });
    }

    test('-tts wins over -image', () {
      expect(GeminiModelFamily.of('gemini-x-image-tts'), GeminiModelFamily.tts);
      expect(GeminiModelFamily.of('gemini-x-tts-image'), GeminiModelFamily.tts);
    });

    test('a marker outside the gemini- namespace is text', () {
      expect(GeminiModelFamily.of('other-tts'), GeminiModelFamily.text);
      expect(GeminiModelFamily.of('other-image'), GeminiModelFamily.text);
    });
  });

  group('GeminiModelFamily', () {
    test('text and image share the multimodal profile', () {
      expect(GeminiModelFamily.text.supports, _multimodalProfile);
      expect(GeminiModelFamily.image.supports, _multimodalProfile);
      expect(GeminiModelFamily.text.customOptions, same(GeminiOptions.$schema));
      expect(
        GeminiModelFamily.image.customOptions,
        same(GeminiOptions.$schema),
      );
    });

    test('tts carries the TTS profile and options', () {
      expect(GeminiModelFamily.tts.supports, _ttsProfile);
      expect(
        GeminiModelFamily.tts.customOptions,
        same(GeminiTtsOptions.$schema),
      );
    });

    test('profiles are unmodifiable', () {
      expect(
        () => GeminiModelFamily.text.supports['multiturn'] = false,
        throwsUnsupportedError,
      );
      expect(
        () => geminiTtsSupports['multiturn'] = true,
        throwsUnsupportedError,
      );
      expect(
        () => (geminiTtsSupports['output'] as List).add('text'),
        throwsUnsupportedError,
      );
    });
  });

  group('KnownGeminiModel', () {
    for (final model in KnownGeminiModel.values) {
      test('${model.id} info carries its label, stage and family profile', () {
        final info = model.info;
        expect(info.label, model.label);
        expect(info.stage, model.stage);
        expect(info.supports, model.family.supports);
      });

      test('${model.id} family agrees with the classifier', () {
        expect(GeminiModelFamily.of(model.id), model.family);
      });
    }

    test('curates the JS/Go union by family', () {
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.family == GeminiModelFamily.text) model.id,
        },
        {
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
          'gemini-3.1-pro-preview',
          'gemini-3-flash-preview',
          'gemini-3.7-flash',
          'gemini-3.6-flash',
          'gemini-3.5-flash',
          'gemini-3.5-flash-lite',
          'gemini-3.1-flash-lite',
        },
      );
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.family == GeminiModelFamily.image) model.id,
        },
        {
          'gemini-2.5-flash-image',
          'gemini-3.1-flash-image',
          'gemini-3.1-flash-lite-image',
          'gemini-3-pro-image',
        },
      );
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.family == GeminiModelFamily.tts) model.id,
        },
        {
          'gemini-2.5-flash-preview-tts',
          'gemini-2.5-pro-preview-tts',
          'gemini-3.1-flash-tts-preview',
        },
      );
    });

    test('claims stable only for names a live probe has served', () {
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.stage == 'stable') model.id,
        },
        {
          'gemini-3.5-flash',
          'gemini-3.1-flash-lite',
          'gemini-3.1-flash-image',
          'gemini-3-pro-image',
        },
      );
      for (final model in KnownGeminiModel.values) {
        expect(model.stage, anyOf('stable', 'unstable'));
      }
    });
  });

  group('knownGeminiModels', () {
    test('is derived from the enums, keyed by bare model id', () {
      expect(
        knownGeminiModels.keys,
        unorderedEquals([
          for (final m in KnownGeminiModel.values) m.id,
          for (final m in KnownGemmaModel.values) m.id,
        ]),
      );
      for (final model in KnownGeminiModel.values) {
        expect(knownGeminiModels[model.id]!.label, model.label);
      }
      for (final model in KnownGemmaModel.values) {
        expect(knownGeminiModels[model.id]!.label, model.label);
      }
    });
  });
}
