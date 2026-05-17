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

import 'package:genkit/plugin.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:genkit_google_genai/src/imagen.dart';
import 'package:test/test.dart';

void main() {
  group('Imagen', () {
    test('resolve returns Imagen model action', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('model', 'imagen-4.0-generate-001');

      expect(action, isNotNull);
      expect(action!.name, 'googleai/imagen-4.0-generate-001');
    });

    test('exposes image size in custom options metadata', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('model', 'imagen-4.0-generate-001');
      final model = action!.metadata['model'] as Map<String, dynamic>;
      final customOptions = model['customOptions'] as Map<String, dynamic>;
      final properties = customOptions['properties'] as Map<String, dynamic>;

      expect(properties, contains('imageSize'));
      expect(properties['imageSize'], containsPair('enum', ['1K', '2K']));
    });

    test('maps options to predict parameters', () {
      final options = ImagenOptions.fromJson({
        'outputGcsUri': 'gs://bucket/images',
        'numberOfImages': 2,
        'imageSize': '2K',
        'aspectRatio': '16:9',
        'guidanceScale': 7.5,
        'seed': 123,
        'safetyFilterLevel': 'BLOCK_ONLY_HIGH',
        'personGeneration': 'allow_adult',
        'includeSafetyAttributes': true,
        'includeRaiReason': true,
        'language': 'en',
        'outputMimeType': 'image/jpeg',
        'outputCompressionQuality': 90,
        'addWatermark': true,
        'labels': {'app': 'genkit'},
        'enhancePrompt': true,
        'negativePrompt': 'blurry',
      });

      final params = toImagenParameters(options);

      expect(params, {
        'sampleCount': 2,
        'outputGcsUri': 'gs://bucket/images',
        'imageSize': '2K',
        'aspectRatio': '16:9',
        'guidanceScale': 7.5,
        'seed': 123,
        'safetyFilterLevel': 'BLOCK_ONLY_HIGH',
        'personGeneration': 'allow_adult',
        'includeSafetyAttributes': true,
        'includeRaiReason': true,
        'language': 'en',
        'outputMimeType': 'image/jpeg',
        'outputCompressionQuality': 90,
        'addWatermark': true,
        'labels': {'app': 'genkit'},
        'enhancePrompt': true,
        'negativePrompt': 'blurry',
      });
    });

    test('defaults sample count to one', () {
      final params = toImagenParameters(ImagenOptions());

      expect(params, {'sampleCount': 1});
    });

    test('converts predictions to media parts', () {
      final part = fromImagenPrediction({
        'bytesBase64Encoded': 'abc123',
        'mimeType': 'image/jpeg',
      });

      expect(part.media.url, 'data:image/jpeg;base64,abc123');
      expect(part.media.contentType, 'image/jpeg');
    });

    test('extracts text from user messages only', () {
      final request = ModelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'system')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello ')],
          ),
          Message(
            role: Role.model,
            content: [TextPart(text: 'model')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'world')],
          ),
        ],
      );

      expect(extractImagenPrompt(request), 'hello world');
    });

    test('throws clear error for invalid prediction shape', () {
      expect(
        () => fromImagenPrediction('not-a-map'),
        throwsA(isA<GenkitException>()),
      );
    });
  });
}
