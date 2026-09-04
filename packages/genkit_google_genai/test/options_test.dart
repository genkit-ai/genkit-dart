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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/common_plugin.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('toGeminiSettings', () {
    test('maps basic fields correctly', () {
      final options = GeminiOptions(
        temperature: 0.7,
        topP: 0.9,
        topK: 40,
        candidateCount: 2,
        maxOutputTokens: 100,
        stopSequences: ['stop'],
        responseMimeType: 'application/json',
      );

      final settings = toGeminiSettings(options, null, false);

      expect(settings.temperature, 0.7);
      expect(settings.topP, 0.9);
      expect(settings.topK, 40);
      expect(settings.candidateCount, 2);
      expect(settings.maxOutputTokens, 100);
      expect(settings.stopSequences, ['stop']);
      expect(settings.responseMimeType, 'application/json');
    });

    test('maps image config', () {
      final options = GeminiOptions(
        imageConfig: ImageConfig(aspectRatio: '3:4', imageSize: '2K'),
      );

      final settings = toGeminiSettings(options, null, false);

      expect(settings.imageConfig, isNotNull);
      expect(settings.imageConfig!.aspectRatio, '3:4');
      expect(settings.imageConfig!.imageSize, '2K');
    });

    test('maps thinking config', () {
      final options = GeminiOptions(
        thinkingConfig: ThinkingConfig(
          includeThoughts: true,
          thinkingBudget: 2048,
          thinkingLevel: 'HIGH',
        ),
      );

      final settings = toGeminiSettings(options, null, false);

      expect(settings.thinkingConfig, isNotNull);
      expect(settings.thinkingConfig!.includeThoughts, isTrue);
      expect(settings.thinkingConfig!.thinkingBudget, 2048);
      expect(settings.thinkingConfig!.thinkingLevel, 'HIGH');
    });

    test('maps response modalities', () {
      final options = GeminiOptions(
        responseModalities: ['TEXT', 'audio', 'IMAGE'],
      );

      final settings = toGeminiSettings(options, null, false);

      expect(settings.responseModalities, ['TEXT', 'AUDIO', 'IMAGE']);
    });
  });

  group('toGeminiSafetySettings', () {
    test('maps safety settings correctly', () {
      final options = GeminiOptions(
        safetySettings: [
          SafetySettings(
            category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
            threshold: 'BLOCK_ONLY_HIGH',
          ),
        ],
      );

      final settings = toGeminiSafetySettings(options.safetySettings);

      expect(settings, hasLength(1));
      expect(settings!.first.category, 'HARM_CATEGORY_DANGEROUS_CONTENT');
      expect(settings.first.threshold, 'BLOCK_ONLY_HIGH');
    });

    test('returns null for null input', () {
      expect(toGeminiSafetySettings(null), isNull);
    });

    test('returns empty list for empty input', () {
      expect(toGeminiSafetySettings([]), isEmpty);
    });

    test('drops an entry with unset category', () {
      final settings = toGeminiSafetySettings([
        SafetySettings(threshold: 'BLOCK_ONLY_HIGH'),
        SafetySettings(
          category: 'HARM_CATEGORY_HARASSMENT',
          threshold: 'BLOCK_LOW_AND_ABOVE',
        ),
      ]);

      expect(settings, hasLength(1));
      expect(settings!.first.category, 'HARM_CATEGORY_HARASSMENT');
    });

    test('drops an entry with explicit HARM_CATEGORY_UNSPECIFIED', () {
      final settings = toGeminiSafetySettings([
        SafetySettings(
          category: 'HARM_CATEGORY_UNSPECIFIED',
          threshold: 'BLOCK_ONLY_HIGH',
        ),
      ]);

      expect(settings, isEmpty);
    });

    test('drops an entry with neither category nor threshold', () {
      expect(toGeminiSafetySettings([SafetySettings()]), isEmpty);
    });

    test('omits threshold from the wire body when unset', () {
      final settings = toGeminiSafetySettings([
        SafetySettings(category: 'HARM_CATEGORY_HATE_SPEECH'),
      ]);

      expect(settings, hasLength(1));
      expect(settings!.first.toJson(), {
        'category': 'HARM_CATEGORY_HATE_SPEECH',
      });
    });

    test('warns once per dropped entry, kept entries stay silent', () {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);

      toGeminiSafetySettings([
        SafetySettings(threshold: 'BLOCK_ONLY_HIGH'),
        SafetySettings(
          category: 'HARM_CATEGORY_UNSPECIFIED',
          threshold: 'BLOCK_ONLY_HIGH',
        ),
        SafetySettings(
          category: 'HARM_CATEGORY_HARASSMENT',
          threshold: 'BLOCK_LOW_AND_ABOVE',
        ),
      ]);

      expect(records, hasLength(2));
      for (final record in records) {
        expect(record.level, Level.WARNING);
        expect(record.loggerName, 'genkit_google_genai');
        expect(record.message, contains('category'));
      }
    });
  });

  group('safety settings request body', () {
    test('omits safetySettings key when every entry is dropped', () async {
      Map<String, dynamic>? capturedBody;
      final plugin = StubClientPlugin((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final model = plugin.createModel(
        'gemini-2.5-flash',
        GeminiOptions.$schema,
      );
      await model.call(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hi')],
            ),
          ],
          config: {
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_UNSPECIFIED',
                'threshold': 'BLOCK_ONLY_HIGH',
              },
              {'threshold': 'BLOCK_ONLY_HIGH'},
            ],
          },
        ),
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody, isNot(contains('safetySettings')));
    });
  });

  group('toGeminiTools', () {
    test('maps code execution', () {
      final options = GeminiOptions(codeExecution: true);
      final tools = toGeminiTools(null, codeExecution: options.codeExecution);

      expect(tools, hasLength(1));
      expect(tools.first.codeExecution, isNotNull);
    });

    test('maps google search retrieval', () {
      final options = GeminiOptions(googleSearch: GoogleSearch());
      final tools = toGeminiTools(null, googleSearch: options.googleSearch);

      expect(tools, hasLength(1));
      expect(tools.first.googleSearch, isNotNull);
    });
  });

  group('toGeminiToolConfig', () {
    test('maps function calling config', () {
      final options = GeminiOptions(
        functionCallingConfig: FunctionCallingConfig(
          mode: 'ANY',
          allowedFunctionNames: ['foo'],
        ),
      );
      final config = toGeminiToolConfig(options.functionCallingConfig);

      expect(config?.functionCallingConfig?.mode, 'ANY');
      expect(config?.functionCallingConfig?.allowedFunctionNames, ['foo']);
    });
  });

  group('toGeminiTtsSettings', () {
    test('maps speech config correctly', () {
      final options = GeminiTtsOptions(
        speechConfig: SpeechConfig(
          voiceConfig: VoiceConfig(
            prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: 'Puck'),
          ),
        ),
      );

      final settings = toGeminiTtsSettings(options, null, false);

      expect(settings.speechConfig, isNotNull);
      expect(
        settings.speechConfig?.voiceConfig?.prebuiltVoiceConfig?.voiceName,
        'Puck',
      );
    });

    test('maps standard fields correctly', () {
      final options = GeminiTtsOptions(
        temperature: 0.5,
        responseMimeType: 'audio/mp3',
      );

      final settings = toGeminiTtsSettings(options, null, false);

      expect(settings.temperature, 0.5);
      expect(settings.responseMimeType, 'audio/mp3');
    });
  });
}

class StubClientPlugin extends GoogleGenAiPluginImpl {
  StubClientPlugin(this.handler);

  final Future<http.Response> Function(http.Request) handler;

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://test.invalid/',
      client: MockClient(handler),
    );
  }
}
