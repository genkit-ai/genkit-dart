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
import 'package:genkit_google_genai/src/gemma.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

Map<String, dynamic> _propertiesOf(SchemanticType type) {
  final schema = type.jsonSchema(useRefs: false);
  return (schema['properties'] as Map).cast<String, dynamic>();
}

Object _sampleFor(String property, Map<String, dynamic> propertySchema) {
  switch (propertySchema['type']) {
    case 'string':
      return 's';
    case 'number':
      return 0.5;
    case 'integer':
      return 1;
    case 'boolean':
      return true;
    case 'array':
      return <Object?>[];
    case 'object':
      return <String, Object?>{};
  }
  throw StateError('No sample value for $property: $propertySchema');
}

void main() {
  group('GemmaOptions schema', () {
    test('JSON schema caps temperature at 1.0', () {
      final temp =
          _propertiesOf(GemmaOptions.$schema)['temperature']
              as Map<String, dynamic>;
      expect(temp['maximum'], 1.0);
    });

    test('mirrors GeminiOptions property-for-property except the '
        'temperature cap', () {
      final geminiProps = _propertiesOf(GeminiOptions.$schema);
      final gemmaProps = _propertiesOf(GemmaOptions.$schema);
      expect(gemmaProps.keys.toSet(), geminiProps.keys.toSet());
      for (final key in geminiProps.keys) {
        if (key == 'temperature') continue;
        expect(gemmaProps[key], geminiProps[key], reason: key);
      }
      final expectedTemperature = Map<String, dynamic>.of(
        (geminiProps['temperature'] as Map).cast<String, dynamic>(),
      )..['maximum'] = 1.0;
      expect(gemmaProps['temperature'], expectedTemperature);
    });
  });

  group('gemmaToGeminiOptions', () {
    test('maps every GemmaOptions property', () {
      final gemmaProps = _propertiesOf(GemmaOptions.$schema);
      final sample = {
        for (final entry in gemmaProps.entries)
          entry.key: _sampleFor(
            entry.key,
            (entry.value as Map).cast<String, dynamic>(),
          ),
      };
      final mapped = gemmaToGeminiOptions(GemmaOptions.fromJson(sample));
      expect(mapped.toJson().keys.toSet(), sample.keys.toSet());
    });

    test('returns options backed by a map independent of the request '
        'config', () {
      final config = <String, dynamic>{'topK': 3};
      final mapped = gemmaToGeminiOptions(GemmaOptions.fromJson(config));

      mapped.topK = 99;

      expect(config['topK'], 3);
      expect(mapped.topK, 99);
    });

    test('passes temperature at the cap through', () {
      final mapped = gemmaToGeminiOptions(
        GemmaOptions.fromJson({'temperature': 1.0}),
      );
      expect(mapped.temperature, 1.0);
    });

    test('rejects temperature above 1.0 with INVALID_ARGUMENT', () {
      expect(
        () => gemmaToGeminiOptions(GemmaOptions.fromJson({'temperature': 1.5})),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });

    test('rejects negative temperature with INVALID_ARGUMENT', () {
      expect(
        () =>
            gemmaToGeminiOptions(GemmaOptions.fromJson({'temperature': -0.1})),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });
  });

  group('model family predicates', () {
    test('isGemma4ModelName', () {
      expect(isGemma4ModelName('gemma-4-26b-a4b-it'), isTrue);
      expect(isGemma4ModelName('gemma-4-31b-it'), isTrue);
      expect(isGemma4ModelName('gemma-3-1b-it'), isFalse);
      expect(isGemma4ModelName('gemma-3n-e4b-it'), isFalse);
      expect(isGemma4ModelName('gemini-2.5-pro'), isFalse);
      expect(isGemma4ModelName('text-embedding-004'), isFalse);
    });
  });

  group('stripReasoningParts', () {
    test('drops reasoning parts', () {
      final messages = [
        Message(
          role: Role.model,
          content: [
            ReasoningPart(reasoning: 'thinking...'),
            TextPart(text: 'answer'),
          ],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped, hasLength(1));
      expect(stripped.first.content, hasLength(1));
      expect(stripped.first.content.first.text, 'answer');
    });

    test('drops parts whose metadata carries thoughtSignature', () {
      final messages = [
        Message(
          role: Role.model,
          content: [
            TextPart(text: 'hidden', metadata: {'thoughtSignature': 'sig'}),
            TextPart(text: 'visible'),
          ],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped.first.content, hasLength(1));
      expect(stripped.first.content.first.text, 'visible');
    });

    test('drops messages that become empty', () {
      final messages = [
        Message(
          role: Role.model,
          content: [ReasoningPart(reasoning: 'only thought')],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped, hasLength(1));
      expect(stripped.first.role, Role.user);
    });

    test('leaves non-gemma-affected parts alone', () {
      final messages = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped, hasLength(1));
      expect(stripped.first.content.first.text, 'hello');
    });
  });

  group('plugin handle', () {
    test('googleAI.gemma returns a ModelRef with GemmaOptions schema', () {
      final ref = googleAI.gemma('gemma-4-26b-a4b-it');
      expect(ref.name, 'googleai/gemma-4-26b-a4b-it');
      expect(ref.customOptions, same(GemmaOptions.$schema));
    });
  });

  group('GoogleGenAiPluginImpl.resolve for gemma models', () {
    Map<String, dynamic>? supportsOf(String modelName) {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('model', modelName);
      expect(action, isNotNull);
      expect(action!.name, 'googleai/$modelName');
      final model = action.metadata['model'] as Map<String, dynamic>;
      return model['supports'] as Map<String, dynamic>?;
    }

    test('gemma 4 models advertise systemRole: true', () {
      for (final name in const ['gemma-4-26b-a4b-it', 'gemma-4-31b-it']) {
        expect(supportsOf(name)?['systemRole'], isTrue, reason: name);
      }
    });

    test('gemma 4 models advertise constrained: no-tools', () {
      expect(supportsOf('gemma-4-26b-a4b-it')?['constrained'], 'no-tools');
    });

    test('gemma 3 model names are not special-cased', () {
      final supports = supportsOf('gemma-3-4b-it');
      expect(supports?['systemRole'], isTrue);
      expect(supports?['constrained'], isTrue);
    });
  });
}
