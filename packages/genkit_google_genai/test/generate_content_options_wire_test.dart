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

// The generateContent request for the options added with the Interactions
// work (built-in tools, retrievalConfig, imageConfig, the Interactions-only
// formats) and `store`. Mirrors the JS googleai gemini_test cases.

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/common.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_harness.dart';

// Models pinned to generateContent (other names use the Interactions API).
const _textModel = 'gemini-3.1-flash-lite';
const _imageModel = 'gemini-3.1-flash-image';
const _ttsModel = 'gemini-3.1-flash-tts-preview';

/// A plugin whose generateContent API has no `store` field, like the
/// vertexAI plugin's (Gemini Enterprise Agent Platform).
class _NoStorePlugin extends WirePlugin {
  _NoStorePlugin(super.captured, {super.store});

  @override
  bool get supportsGenerateContentStore => false;
}

/// Runs [model] once on [plugin] and returns the request body.
Future<Map<String, dynamic>> _bodyFor(
  WirePlugin plugin, {
  String model = _textModel,
  Map<String, dynamic>? config,
}) async {
  final action = plugin.resolve(.model, model) as Model;
  await action(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ],
      config: config,
    ),
  );
  return plugin.captured.last;
}

/// Captures log warnings for the rest of the test.
List<String> _captureWarnings() {
  final warnings = <String>[];
  final subscription = Logger.root.onRecord
      .where((r) => r.level == Level.WARNING)
      .listen((r) => warnings.add(r.message));
  addTearDown(subscription.cancel);
  return warnings;
}

void main() {
  setUp(resetDroppedConfigFieldWarnings);
  _toolOptionTests();
  _formatOptionTests();
  _storeTests();
}

void _toolOptionTests() {
  group('tool options', () {
    test('sends codeExecution, config tools, googleSearch and urlContext, '
        'in that order', () async {
      final body = await _bodyFor(
        WirePlugin([]),
        config: {
          'codeExecution': true,
          'tools': [
            {'googleMaps': <String, dynamic>{}},
          ],
          'googleSearch': <String, dynamic>{},
          'urlContext': <String, dynamic>{},
        },
      );
      expect(body['tools'], [
        {'codeExecution': <String, dynamic>{}},
        {'googleMaps': <String, dynamic>{}},
        {'googleSearch': <String, dynamic>{}},
        {'urlContext': <String, dynamic>{}},
      ]);
    });

    test('sends retrievalConfig in toolConfig', () async {
      final body = await _bodyFor(
        WirePlugin([]),
        config: {
          'tools': [
            {'googleMaps': <String, dynamic>{}},
          ],
          'retrievalConfig': {
            'latLng': {'latitude': 43.0896, 'longitude': -79.0849},
          },
        },
      );
      expect(body['tools'], [
        {'googleMaps': <String, dynamic>{}},
      ]);
      expect(body['toolConfig'], {
        'retrievalConfig': {
          'latLng': {'latitude': 43.0896, 'longitude': -79.0849},
        },
      });
      expect(body['generationConfig'], isNot(contains('retrievalConfig')));
    });

    test('retrievalConfig joins the function calling config', () async {
      final body = await _bodyFor(
        WirePlugin([]),
        config: {
          'functionCallingConfig': {'mode': 'AUTO'},
          'retrievalConfig': {'languageCode': 'en'},
        },
      );
      expect(body['toolConfig'], {
        'functionCallingConfig': {
          'mode': 'AUTO',
          'allowedFunctionNames': <String>[],
        },
        'retrievalConfig': {'languageCode': 'en'},
      });
    });
  });
}

void _formatOptionTests() {
  group('format options', () {
    test('sends imageConfig in generationConfig', () async {
      final body = await _bodyFor(
        WirePlugin([]),
        model: _imageModel,
        config: {
          'imageConfig': {'aspectRatio': '9:16', 'imageSize': '2K'},
        },
      );
      expect((body['generationConfig'] as Map)['imageConfig'], {
        'aspectRatio': '9:16',
        'imageSize': '2K',
      });
    });

    test('drops the Interactions-only formats with a warning, once per '
        'model and field', () async {
      final warnings = _captureWarnings();
      final plugin = WirePlugin([]);
      final config = {
        'audioFormat': {'mimeType': 'audio/wav'},
        'videoFormat': {'aspectRatio': '9:16'},
        'videoConfig': {'task': 'text_to_video'},
      };
      await _bodyFor(plugin, model: _ttsModel, config: config);
      final body = await _bodyFor(plugin, model: _ttsModel, config: config);

      final generationConfig = body['generationConfig'] as Map;
      for (final key in ['audioFormat', 'videoFormat', 'videoConfig']) {
        expect(generationConfig, isNot(contains(key)));
        expect(body, isNot(contains(key)));
      }
      String dropped(String field) =>
          "$field is not supported by '$_ttsModel' and was ignored.";
      expect(warnings, [
        dropped('audioFormat'),
        dropped('videoFormat'),
        dropped('videoConfig'),
      ]);
    });
  });
}

void _storeTests() {
  group('store', () {
    // On generateContent, `store` controls whether the server logs the
    // request for the project; it's sent as is when set.
    for (final store in [true, false]) {
      test('sends store: $store, without a warning', () async {
        final warnings = _captureWarnings();
        final body = await _bodyFor(WirePlugin([]), config: {'store': store});
        expect(body['store'], store);
        expect(warnings, isEmpty);
      });
    }

    test('does not send store when it is not set', () async {
      final body = await _bodyFor(WirePlugin([]));
      expect(body, isNot(contains('store')));
    });

    test('sends the plugin store option; the request config wins', () async {
      final plugin = WirePlugin([], store: false);
      expect((await _bodyFor(plugin))['store'], false);
      expect((await _bodyFor(plugin, config: {'store': true}))['store'], true);
    });

    test('warns about previousInteractionId, and does not send it', () async {
      final warnings = _captureWarnings();
      final body = await _bodyFor(
        WirePlugin([]),
        config: {'previousInteractionId': 'v1_x'},
      );
      expect(body, isNot(contains('previousInteractionId')));
      expect(body, isNot(contains('previous_interaction_id')));
      expect(warnings, [
        'previousInteractionId is not supported for this model and will be '
            'ignored.',
      ]);
    });

    group('without a store field (vertexAI)', () {
      String dropped(String model) =>
          "store is not supported by '$model' and was ignored.";

      test('store: true warns once per model and is not sent', () async {
        final warnings = _captureWarnings();
        final plugin = _NoStorePlugin([]);
        // false asks for nothing that can't happen: no warning.
        await _bodyFor(plugin, config: {'store': false});
        expect(warnings, isEmpty);

        await _bodyFor(plugin, config: {'store': true});
        final body = await _bodyFor(plugin, config: {'store': true});
        expect(body, isNot(contains('store')));
        expect(warnings, [dropped(_textModel)]);
      });

      test('the plugin store option: true warns, false does not', () async {
        final warnings = _captureWarnings();
        final body = await _bodyFor(_NoStorePlugin([], store: true));
        expect(body, isNot(contains('store')));
        expect(warnings, [dropped(_textModel)]);

        resetDroppedConfigFieldWarnings();
        warnings.clear();
        await _bodyFor(_NoStorePlugin([], store: false));
        // The request's false wins over the plugin's true.
        await _bodyFor(
          _NoStorePlugin([], store: true),
          config: {'store': false},
        );
        expect(warnings, isEmpty);
      });
    });
  });
}
