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
import 'package:schemantic/schemantic.dart';
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
      'gemini-nano-banana-2.1': GeminiModelFamily.image,
      'gemini-omni-1.1-flash': GeminiModelFamily.video,
      'gemini-omni-future': GeminiModelFamily.video,
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
    });

    test('each family has its own options type (as the JS schemas)', () {
      expect(GeminiModelFamily.text.customOptions, same(GeminiOptions.$schema));
      expect(
        GeminiModelFamily.image.customOptions,
        same(GeminiImageOptions.$schema),
      );
      expect(
        GeminiModelFamily.video.customOptions,
        same(GeminiVideoOptions.$schema),
      );
    });

    test('the Gemini option types share every GeminiOptions field', () {
      // The schema generator has no inheritance, so the shared fields are
      // repeated in each type; this keeps them from drifting apart.
      Set<String> fieldsOf(SchemanticType<dynamic> type) {
        final definition = type.schemaMetadata!.definition;
        return (definition['properties'] as Map).keys.cast<String>().toSet();
      }

      final shared = fieldsOf(GeminiOptions.$schema);
      expect(fieldsOf(GeminiTtsOptions.$schema), shared.union({'audioFormat'}));
      expect(
        fieldsOf(GeminiImageOptions.$schema),
        shared.union({'imageConfig'}),
      );
      expect(
        fieldsOf(GeminiVideoOptions.$schema),
        shared.union({'videoFormat', 'videoConfig'}),
      );
    });

    test('video carries the video profile (no tools, no constrained '
        'output, media out)', () {
      expect(GeminiModelFamily.video.supports, {
        'multiturn': true,
        'media': true,
        'tools': false,
        'toolChoice': false,
        'systemRole': true,
        'constrained': false,
        'output': ['media'],
      });
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

  group('GeminiModelStage', () {
    test('uses the Genkit stage names', () {
      expect(GeminiModelStage.values.map((s) => s.wireName), [
        'stable',
        'legacy',
        'deprecated',
      ]);
    });
  });

  group('KnownGeminiModel', () {
    for (final model in KnownGeminiModel.values) {
      test('${model.id} info carries its label, stage and profile', () {
        final info = model.info;
        expect(info.label, model.label);
        expect(info.stage, model.stage.wireName);
        expect(info.supports, model.supportsOverride ?? model.family.supports);
      });

      test('${model.id} family agrees with the classifier', () {
        expect(GeminiModelFamily.of(model.id), model.family);
      });

      test('${model.id} is hidden exactly when it is not stable', () {
        expect(model.hidden, model.stage != GeminiModelStage.stable);
      });
    }

    test('curates the Gemini API catalog by family', () {
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.family == GeminiModelFamily.text) model.id,
        },
        {
          'gemini-pro-latest',
          'gemini-flash-latest',
          'gemini-flash-lite-latest',
          'gemini-4-argon',
          'gemini-3.8-flash',
          'gemini-3.6-flash',
          'gemini-3.5-flash-lite',
          'gemini-3.1-flash-lite',
          'gemini-3.1-pro-preview-customtools',
          'gemini-3.1-pro-preview',
          'gemini-3-flash-preview',
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
          'gemini-3.5-flash',
        },
      );
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.family == GeminiModelFamily.image) model.id,
        },
        {
          'gemini-3.1-flash-lite-image',
          'gemini-nano-banana-2.1',
          'gemini-3-pro-image',
          'gemini-2.5-flash-image',
          'gemini-3.1-flash-image',
        },
      );
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.family == GeminiModelFamily.video) model.id,
        },
        {'gemini-omni-1.1-flash'},
      );
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.family == GeminiModelFamily.tts) model.id,
        },
        {
          'gemini-3.8-flash-tts',
          'gemini-3.8-flash-lite-tts',
          'gemini-2.5-flash-preview-tts',
          'gemini-2.5-pro-preview-tts',
          'gemini-3.1-flash-tts-preview',
        },
      );
    });

    test('hides the same models as the JS plugin, with the same stages', () {
      expect(
        {
          for (final model in KnownGeminiModel.values)
            if (model.hidden) model.id: model.stage,
        },
        {
          'gemini-2.5-pro': GeminiModelStage.legacy,
          'gemini-2.5-flash': GeminiModelStage.legacy,
          'gemini-2.5-flash-lite': GeminiModelStage.legacy,
          'gemini-2.5-flash-image': GeminiModelStage.legacy,
          'gemini-2.5-flash-preview-tts': GeminiModelStage.deprecated,
          'gemini-2.5-pro-preview-tts': GeminiModelStage.deprecated,
          'gemini-3.1-flash-tts-preview': GeminiModelStage.deprecated,
          'gemini-3.5-flash': GeminiModelStage.deprecated,
          'gemini-3.1-flash-image': GeminiModelStage.deprecated,
        },
      );
    });

    test('keeps every hidden model on generateContent', () {
      for (final model in KnownGeminiModel.values.where((m) => m.hidden)) {
        expect(model.interactions, isFalse, reason: model.id);
      }
    });

    test('Nano Banana 2.1 has no native constrained output (as in JS)', () {
      // With a schema it still returns only an image (checked live by JS).
      final supports = KnownGeminiModel.geminiNanoBanana21.info.supports!;
      expect(supports['constrained'], isFalse);
      expect(supports['tools'], isTrue);
    });

    test('leaves out a deprecated model that routes right when unlisted', () {
      // gemini-3.7-flash now serves gemini-3.8-flash and, unlisted, already
      // uses the Interactions API (as in JS), so an entry would change nothing.
      expect(knownGeminiModels, isNot(contains('gemini-3.7-flash')));
    });
  });

  group('knownGeminiInteractions', () {
    test('pins the same models to generateContent as the JS plugin', () {
      expect(
        {
          for (final MapEntry(:key, :value) in knownGeminiInteractions.entries)
            if (!value) key,
        },
        {
          'gemini-3.1-flash-lite',
          'gemini-3.1-pro-preview-customtools',
          'gemini-3.1-pro-preview',
          'gemini-3-flash-preview',
          'gemini-3-pro-image',
          'gemma-4-26b-a4b-it',
          'gemma-4-31b-it',
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
          'gemini-2.5-flash-image',
          'gemini-2.5-flash-preview-tts',
          'gemini-2.5-pro-preview-tts',
          'gemini-3.1-flash-tts-preview',
          'gemini-3.5-flash',
          'gemini-3.1-flash-image',
        },
      );
    });

    test('covers exactly the curated models', () {
      expect(
        knownGeminiInteractions.keys,
        unorderedEquals(knownGeminiModels.keys),
      );
    });

    test('is unmodifiable', () {
      expect(
        () => knownGeminiInteractions['gemini-3.8-flash'] = false,
        throwsUnsupportedError,
      );
    });
  });

  group('KnownGeminiEmbedder', () {
    test('curates the same embedders as the JS plugin', () {
      expect(knownGeminiEmbedders.keys, [
        'gemini-embedding-001',
        'gemini-embedding-2',
      ]);
      expect(knownGeminiEmbedders['gemini-embedding-2'], {
        'label': 'Gemini Embedding 2',
        'dimensions': 3072,
        'supports': {
          'input': ['text', 'image', 'video'],
        },
      });
      expect(
        (knownGeminiEmbedders['gemini-embedding-001']!['supports']
            as Map)['input'],
        ['text'],
      );
    });
  });

  group('knownGeminiModels', () {
    test('includes the curated Gemma models', () {
      // Pin the literal ids so a typo in an enum value fails the suite.
      expect(
        knownGeminiModels.keys,
        containsAll(['gemma-4-31b-it', 'gemma-4-26b-a4b-it']),
      );
    });

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
