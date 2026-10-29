// Copyright 2026 Google LLC
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

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

import 'wire_harness.dart';

final _throwsInvalidArgument = throwsA(
  isA<GenkitException>().having(
    (e) => e.status,
    'status',
    StatusCode.invalidArgument,
  ),
);

Map<String, dynamic> _voice(String name) => {
  'prebuiltVoiceConfig': {'voiceName': name},
};

void main() {
  setUpAll(setUpFirebaseApp);

  Future<Map<String, dynamic>> sentConfig(Map<String, dynamic> config) async {
    final client = WireClient();
    await wireModel(client)(userRequest('hello', config: config));
    return client.requests.single.body['generationConfig']
        as Map<String, dynamic>;
  }

  Future<void> expectRejected(Map<String, dynamic> config) async {
    final client = WireClient();
    await expectLater(
      wireModel(client)(userRequest('hello', config: config)),
      _throwsInvalidArgument,
    );
    expect(client.requests, isEmpty);
  }

  group('speechConfig', () {
    test('sends a voice and language', () async {
      final config = await sentConfig({
        'speechConfig': {
          'voiceConfig': _voice('Kore'),
          'languageCode': 'en-US',
        },
      });

      // firebase_ai writes speech config in snake_case, which the API accepts.
      expect(config['speechConfig'], {
        'voice_config': {
          'prebuilt_voice_config': {'voice_name': 'Kore'},
        },
        'language_code': 'en-US',
      });
    });

    test('sends multiple speakers', () async {
      final config = await sentConfig({
        'speechConfig': {
          'multiSpeakerVoiceConfig': {
            'speakerVoiceConfigs': [
              {'speaker': 'Joe', 'voiceConfig': _voice('Kore')},
              {'speaker': 'Jane', 'voiceConfig': _voice('Puck')},
            ],
          },
        },
      });

      expect(config['speechConfig'], {
        'multi_speaker_voice_config': {
          'speaker_voice_configs': [
            {
              'speaker': 'Joe',
              'voice_config': {
                'prebuilt_voice_config': {'voice_name': 'Kore'},
              },
            },
            {
              'speaker': 'Jane',
              'voice_config': {
                'prebuilt_voice_config': {'voice_name': 'Puck'},
              },
            },
          ],
        },
      });
    });

    test('a voice and multiple speakers together throw invalidArgument and '
        'send nothing', () async {
      await expectRejected({
        'speechConfig': {
          'voiceConfig': _voice('Kore'),
          'multiSpeakerVoiceConfig': {
            'speakerVoiceConfigs': [
              {'speaker': 'Joe', 'voiceConfig': _voice('Puck')},
            ],
          },
        },
      });
    });

    test('an empty voiceConfig next to multiple speakers throws '
        'invalidArgument and sends nothing', () async {
      await expectRejected({
        'speechConfig': {
          'voiceConfig': <String, Object?>{},
          'multiSpeakerVoiceConfig': {
            'speakerVoiceConfigs': [
              {'speaker': 'Joe', 'voiceConfig': _voice('Puck')},
            ],
          },
        },
      });
    });

    test('no speakers throws invalidArgument and sends nothing', () async {
      await expectRejected({
        'speechConfig': {
          'multiSpeakerVoiceConfig': {'speakerVoiceConfigs': <Object>[]},
        },
      });
    });

    test('a speaker without a voice throws invalidArgument and sends '
        'nothing', () async {
      await expectRejected({
        'speechConfig': {
          'multiSpeakerVoiceConfig': {
            'speakerVoiceConfigs': [
              {'speaker': 'Joe'},
            ],
          },
        },
      });
    });
  });

  group('imageConfig', () {
    test('sends the aspect ratio and size', () async {
      final config = await sentConfig({
        'responseModalities': ['TEXT', 'IMAGE'],
        'imageConfig': {'aspectRatio': '16:9', 'imageSize': '2K'},
      });

      expect(config['imageConfig'], {'aspectRatio': '16:9', 'imageSize': '2K'});
    });

    test('an unknown aspect ratio throws invalidArgument and sends '
        'nothing', () async {
      await expectRejected({
        'imageConfig': {'aspectRatio': '7:5'},
      });
    });
  });

  group('mediaResolution', () {
    test('is sent in generationConfig', () async {
      final config = await sentConfig({
        'mediaResolution': 'MEDIA_RESOLUTION_LOW',
      });

      expect(config['mediaResolution'], 'MEDIA_RESOLUTION_LOW');
    });

    test('an unknown value throws invalidArgument and sends nothing', () async {
      await expectRejected({'mediaResolution': 'LOW'});
    });

    test('a non-string part mediaResolution throws invalidArgument and '
        'sends nothing', () async {
      final client = WireClient();

      await expectLater(
        wireModel(client)(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [
                  MediaPart(
                    media: Media(url: 'data:image/png;base64,iVBORw0KGgo='),
                    metadata: {'mediaResolution': 2},
                  ),
                ],
              ),
            ],
          ),
        ),
        _throwsInvalidArgument,
      );
      expect(client.requests, isEmpty);
    });

    test('a media part can set its own', () async {
      final client = WireClient();

      await wireModel(client)(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [
                MediaPart(
                  media: Media(url: 'data:image/png;base64,iVBORw0KGgo='),
                  metadata: {'mediaResolution': 'MEDIA_RESOLUTION_HIGH'},
                ),
              ],
            ),
          ],
        ),
      );

      final contents = client.requests.single.body['contents'] as List;
      final part = ((contents.single as Map)['parts'] as List).single as Map;
      expect(part['mediaResolution'], {'level': 'MEDIA_RESOLUTION_HIGH'});
      expect((part['inlineData'] as Map)['mimeType'], 'image/png');
    });
  });
}
