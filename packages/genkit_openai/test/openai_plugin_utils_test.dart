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

import 'package:genkit_openai/genkit_openai.dart';
import 'package:test/test.dart';

void main() {
  group('Model Info Helpers', () {
    test('defaultModelInfo sets correct supports', () {
      final info = defaultModelInfo('gpt-4o');
      expect(info.supports?['multiturn'], true);
      expect(info.supports?['tools'], true);
      expect(info.supports?['systemRole'], true);
      expect(info.supports?['media'], true);
    });

    test('oSeriesModelInfo sets correct supports', () {
      final info = oSeriesModelInfo('o1');
      expect(info.supports?['multiturn'], true);
      expect(info.supports?['tools'], false);
      expect(info.supports?['systemRole'], false);
      expect(info.supports?['media'], true);
    });

    test('modelInfoFor uses family-specific capability profile', () {
      final defaultInfo = modelInfoFor('gpt-4o');
      expect(defaultInfo.supports?['tools'], true);
      expect(defaultInfo.supports?['systemRole'], true);

      final oSeriesInfo = modelInfoFor('o3-mini');
      expect(oSeriesInfo.supports?['tools'], false);
      expect(oSeriesInfo.supports?['systemRole'], false);
      expect(oSeriesInfo.supports?['media'], true);
    });

    test('supportsVision identifies vision models', () {
      // Vision models
      expect(supportsVision('gpt-4o'), true);
      expect(supportsVision('gpt-4o-mini'), true);
      expect(supportsVision('gpt-4o-2024-05-13'), true);
      expect(supportsVision('gpt-4-turbo'), true);
      expect(supportsVision('gpt-4-1106-preview'), true);
      expect(supportsVision('gpt-4-0125-preview'), true);
      expect(supportsVision('gpt-4-vision'), true);
      expect(supportsVision('gpt-4-vision-preview'), true);
      expect(supportsVision('o1'), true);
      expect(supportsVision('o1-preview'), true);
      expect(supportsVision('o3'), true);
      expect(supportsVision('o3-mini'), true);
      expect(supportsVision('gpt-5o'), true);
      expect(supportsVision('gpt-5.1o'), true);
      expect(supportsVision('gpt-6o-mini'), true);
      expect(supportsVision('chatgpt-4o-latest'), true);

      // Non-vision models
      expect(supportsVision('gpt-3.5-turbo'), false);
      expect(supportsVision('gpt-4'), false);
      expect(supportsVision('text-embedding-3-small'), false);
    });

    test('supportsTools identifies models with function calling support', () {
      // Tool models
      expect(supportsTools('gpt-4'), true);
      expect(supportsTools('gpt-4o'), true);
      expect(supportsTools('gpt-4o-mini'), true);
      expect(supportsTools('gpt-4-turbo'), true);
      expect(supportsTools('gpt-3.5-turbo'), true);
      expect(supportsTools('gpt-5'), true);
      expect(supportsTools('gpt-5.1'), true);

      // Non-tool models
      expect(supportsTools('chatgpt-4o-latest'), false);
      expect(supportsTools('chatgpt-5-latest'), false);
      expect(supportsTools('gpt-3.5-turbo-instruct'), false);
      expect(supportsTools('davinci-002'), false);
      expect(supportsTools('babbage-002'), false);
      expect(supportsTools('text-embedding-3-small'), false);
      expect(supportsTools('text-embedding-3-large'), false);
      expect(supportsTools('tts-1'), false);
      expect(supportsTools('tts-1-hd'), false);
      expect(supportsTools('whisper-1'), false);
      expect(supportsTools('dall-e-3'), false);
      expect(supportsTools('dall-e-2'), false);
      expect(supportsTools('omni-moderation-latest'), false);
      expect(supportsTools('sora-2'), false);
    });
  });

  group('getModelType', () {
    test('classifies chat models', () {
      expect(getModelType('gpt-4o'), 'chat');
      expect(getModelType('chatgpt-4o-latest'), 'chat');
    });

    test('classifies non-chat models', () {
      expect(getModelType('dall-e-3'), 'image');
      expect(getModelType('sora-2'), 'video');
      expect(getModelType('whisper-1'), 'audio');
    });

    test('returns unknown for unrecognized models', () {
      expect(getModelType('my-custom-model'), 'unknown');
    });
  });
}
