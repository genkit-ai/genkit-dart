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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:genkit_google_genai/src/imagen.dart';
import 'package:test/test.dart';

void main() {
  group('isImagenModelName', () {
    test('matches imagen prefix', () {
      expect(isImagenModelName('imagen-4.0-generate-001'), isTrue);
      expect(isImagenModelName('imagen-4.0-fast-generate-001'), isTrue);
      expect(isImagenModelName('imagen-4.0-ultra-generate-001'), isTrue);
    });

    test('does not match other families', () {
      expect(isImagenModelName('gemini-2.5-pro'), isFalse);
      expect(isImagenModelName('gemma-3-1b-it'), isFalse);
      expect(isImagenModelName('text-embedding-004'), isFalse);
    });
  });

  group('extractPrompt', () {
    test('joins text parts across user messages with newlines', () {
      final messages = [
        Message(
          role: Role.user,
          content: [
            TextPart(text: 'hello'),
            TextPart(text: 'world'),
          ],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: 'again')],
        ),
      ];
      expect(extractPrompt(messages), 'hello\nworld\nagain');
    });

    test('ignores media parts and model-role messages', () {
      final messages = [
        Message(
          role: Role.model,
          content: [TextPart(text: 'should be ignored')],
        ),
        Message(
          role: Role.user,
          content: [
            TextPart(text: 'draw this:'),
            MediaPart(media: Media(url: 'data:image/png;base64,AAA')),
          ],
        ),
      ];
      expect(extractPrompt(messages), 'draw this:');
    });
  });

  group('extractImagenImage', () {
    test('returns null when there are no messages', () {
      expect(extractImagenImage(const []), isNull);
    });

    test('returns null when last message has no media', () {
      final messages = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
      ];
      expect(extractImagenImage(messages), isNull);
    });

    test('returns base64 payload from a data URI with no metadata', () {
      final messages = [
        Message(
          role: Role.user,
          content: [MediaPart(media: Media(url: 'data:image/png;base64,ABC'))],
        ),
      ];
      expect(extractImagenImage(messages), {'bytesBase64Encoded': 'ABC'});
    });

    test('matches metadata.type == "base"', () {
      final messages = [
        Message(
          role: Role.user,
          content: [
            MediaPart(
              media: Media(url: 'data:image/png;base64,ABC'),
              metadata: {'type': 'base'},
            ),
          ],
        ),
      ];
      expect(extractImagenImage(messages), {'bytesBase64Encoded': 'ABC'});
    });

    test('skips media with a non-"base" metadata.type', () {
      final messages = [
        Message(
          role: Role.user,
          content: [
            MediaPart(
              media: Media(url: 'data:image/png;base64,ABC'),
              metadata: {'type': 'mask'},
            ),
          ],
        ),
      ];
      expect(extractImagenImage(messages), isNull);
    });

    test('returns null for a plain https URL (non-data URI)', () {
      final messages = [
        Message(
          role: Role.user,
          content: [MediaPart(media: Media(url: 'https://example.com/x.png'))],
        ),
      ];
      expect(extractImagenImage(messages), isNull);
    });

    test('only looks at the last message', () {
      final messages = [
        Message(
          role: Role.user,
          content: [MediaPart(media: Media(url: 'data:image/png;base64,OLD'))],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: 'new turn')],
        ),
      ];
      expect(extractImagenImage(messages), isNull);
    });
  });

  group('toImagenParameters', () {
    test('empty options yields empty map', () {
      expect(toImagenParameters(ImagenOptions()), <String, dynamic>{});
    });

    test('maps numberOfImages to sampleCount', () {
      final params = toImagenParameters(
        ImagenOptions(
          numberOfImages: 2,
          aspectRatio: '16:9',
          personGeneration: 'allow_adult',
        ),
      );
      expect(params, {
        'sampleCount': 2,
        'aspectRatio': '16:9',
        'personGeneration': 'allow_adult',
      });
    });

    test('never emits apiKey', () {
      final params = toImagenParameters(ImagenOptions(apiKey: 'secret'));
      expect(params.containsKey('apiKey'), isFalse);
    });
  });

  group('fromImagenPrediction', () {
    test('builds a MediaPart with a data URI', () {
      final part = fromImagenPrediction({
        'bytesBase64Encoded': 'abc',
        'mimeType': 'image/png',
      });
      expect(part, isNotNull);
      expect(part!.media.url, 'data:image/png;base64,abc');
      expect(part.media.contentType, 'image/png');
    });

    test('returns null when bytesBase64Encoded is missing', () {
      expect(fromImagenPrediction({'mimeType': 'image/png'}), isNull);
    });

    test('returns null when bytesBase64Encoded is empty', () {
      expect(
        fromImagenPrediction({'bytesBase64Encoded': '', 'mimeType': 'x'}),
        isNull,
      );
    });
  });

  group('plugin handle', () {
    test('googleAI.imagen returns a ModelRef with ImagenOptions schema', () {
      final ref = googleAI.imagen('imagen-4.0-generate-001');
      expect(ref.name, 'googleai/imagen-4.0-generate-001');
      expect(ref.customOptions, same(ImagenOptions.$schema));
    });
  });

  group('GoogleGenAiPluginImpl.resolve for imagen models', () {
    test('returns a Model with imagen supports metadata', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('model', 'imagen-4.0-fast-generate-001');
      expect(action, isNotNull);
      expect(action!.name, 'googleai/imagen-4.0-fast-generate-001');

      final model = action.metadata['model'] as Map<String, dynamic>;
      final supports = model['supports'] as Map<String, dynamic>;
      expect(supports['media'], isTrue);
      expect(supports['multiturn'], isFalse);
      expect(supports['tools'], isFalse);
      expect(supports['toolChoice'], isFalse);
      expect(supports['systemRole'], isFalse);
      expect(supports['output'], ['media']);
    });

    test('non-imagen names still reach the gemini/embedder path', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('model', 'gemini-2.5-pro');
      expect(action, isNotNull);
      expect(action!.name, 'googleai/gemini-2.5-pro');
    });
  });

  group('ImagenOptions schema', () {
    test('round-trips all fields', () {
      final opts = ImagenOptions.$schema.parse({
        'numberOfImages': 2,
        'aspectRatio': '16:9',
        'personGeneration': 'allow_adult',
      });
      expect(opts.numberOfImages, 2);
      expect(opts.aspectRatio, '16:9');
      expect(opts.personGeneration, 'allow_adult');
    });
  });
}
