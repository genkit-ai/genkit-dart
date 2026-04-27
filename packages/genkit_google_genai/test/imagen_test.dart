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

    test('maps options to predict parameters', () {
      final options = ImagenOptions.fromJson({
        'apiKey': 'secret',
        'numberOfImages': 2,
        'aspectRatio': '16:9',
        'personGeneration': 'allow_adult',
        'negativePrompt': 'blurry',
      });

      final params = toImagenParameters(options);

      expect(params, {
        'sampleCount': 2,
        'aspectRatio': '16:9',
        'personGeneration': 'allow_adult',
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

    test('extracts base64 image inputs', () {
      final request = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(text: 'edit this'),
              MediaPart(
                media: Media(
                  url: 'data:image/png;base64,abc123',
                  contentType: 'image/png',
                ),
              ),
            ],
          ),
        ],
      );

      expect(extractImagenImage(request), {'bytesBase64Encoded': 'abc123'});
    });
  });
}
