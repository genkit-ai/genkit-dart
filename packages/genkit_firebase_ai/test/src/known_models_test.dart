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

// ignore_for_file: experimental_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/experimental.dart';
import 'package:genkit/plugin.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:genkit_firebase_ai/src/known_models.dart';

Future<Map<String, Action>> registered(FirebaseAiProvider provider) async {
  final actions = await firebaseAI(provider: provider).init();
  return {for (final a in actions) a.name: a};
}

// Written out rather than read from the enum, so a wrong backend fails here.
const _servedOnBoth = [
  'gemini-4-argon',
  'gemini-3.8-flash',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
  'gemini-3.1-pro-preview',
  'gemini-nano-banana-2.1',
  'gemini-3.1-flash-image',
  'gemini-3.1-flash-lite-image',
  'gemini-3-pro-image',
  'gemini-3.8-flash-tts',
  'gemini-3.8-flash-lite-tts',
];

void main() {
  test('model ids are unique', () {
    final ids = KnownFirebaseAiModel.values.map((m) => m.id);
    expect(ids.toSet(), hasLength(ids.length));
  });

  for (final (provider, name, models, liveModels) in [
    (
      const FirebaseAiProvider.googleAI(),
      'the Gemini Developer API',
      [
        ..._servedOnBoth,
        'gemini-flash-latest',
        'gemini-3.7-flash',
        'gemini-3.6-flash',
      ],
      ['gemini-3.8-live'],
    ),
    (
      const FirebaseAiProvider.agentPlatform(),
      'Agent Platform',
      _servedOnBoth,
      ['gemini-3.8-live', 'gemini-live-2.5-flash-native-audio'],
    ),
  ]) {
    test('$name registers exactly the models it serves', () async {
      final actions = await registered(provider);

      expect(
        actions.keys,
        unorderedEquals([
          for (final m in [...models, ...liveModels]) 'firebaseai/$m',
        ]),
      );
      for (final m in models) {
        expect(actions['firebaseai/$m'], isA<Model>(), reason: m);
      }
      for (final m in liveModels) {
        expect(actions['firebaseai/$m'], isA<BidiModel>(), reason: m);
      }
    });
  }

  test('a model outside the catalog still resolves', () {
    final model = firebaseAI().resolve(.model, 'gemini-9-flash');

    expect(model, isA<Model>());
    expect(model!.name, 'firebaseai/gemini-9-flash');
  });

  Map<String, dynamic> modelMetadata(Action action) =>
      action.metadata['model'] as Map<String, dynamic>;

  test(
    'catalog models advertise their label, stage and capabilities',
    () async {
      final actions = await registered(const FirebaseAiProvider.googleAI());

      final flash = modelMetadata(actions['firebaseai/gemini-3.8-flash']!);
      expect(flash['label'], 'Gemini 3.8 Flash');
      expect(flash['stage'], 'stable');
      expect((flash['supports'] as Map)['tools'], isTrue);

      final preview = modelMetadata(
        actions['firebaseai/gemini-3.1-pro-preview']!,
      );
      expect(preview['stage'], 'unstable');

      final image = modelMetadata(
        actions['firebaseai/gemini-3.1-flash-image']!,
      );
      expect(image['supports'], containsPair('tools', false));
      expect(image['supports'], containsPair('output', ['text', 'media']));

      final tts = modelMetadata(actions['firebaseai/gemini-3.8-flash-tts']!);
      expect(tts['supports'], containsPair('output', ['media']));
      expect(tts['supports'], containsPair('multiturn', false));

      final live = modelMetadata(actions['firebaseai/gemini-3.8-live']!);
      expect(live['stage'], 'stable');
      expect(live['supports'], containsPair('constrained', false));
      // Audio only until output transcriptions are mapped (#597).
      expect(live['supports'], containsPair('output', ['media']));
    },
  );

  test('names outside the catalog get capabilities from their family', () {
    expect(modelInfoFor('gemini-9-flash').supports?['tools'], isTrue);
    expect(modelInfoFor('gemini-9-flash').label, isNull);
    expect(modelInfoFor('gemini-9-flash-image').supports?['output'], [
      'text',
      'media',
    ]);
    expect(modelInfoFor('gemini-nano-banana-9').supports?['output'], [
      'text',
      'media',
    ]);
    expect(modelInfoFor('gemini-9-flash-tts').supports?['output'], ['media']);
    // Only gemini- names carry a family marker.
    expect(modelInfoFor('gemma-3-27b-it-tts').supports?['tools'], isTrue);
    expect(
      modelInfoFor('gemini-9-flash', live: true).supports?['constrained'],
      isFalse,
    );
  });
}
