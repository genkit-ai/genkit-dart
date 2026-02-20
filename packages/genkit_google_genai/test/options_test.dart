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

import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/plugin_impl.dart';
import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as gcl;
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

    test('maps thinking config', () {
      final options = GeminiOptions(
        thinkingConfig: ThinkingConfig(
          includeThoughts: true,
          thinkingBudget: 2048,
        ),
      );

      final settings = toGeminiSettings(options, null, false);

      expect(settings.thinkingConfig?.includeThoughts, isTrue);
      expect(settings.thinkingConfig?.thinkingBudget, 2048);
    });

    test('maps response modalities', () {
      final options = GeminiOptions(
        responseModalities: ['TEXT', 'audio', 'IMAGE'],
      );

      final settings = toGeminiSettings(options, null, false);

      expect(settings.responseModalities, [
        gcl.GenerationConfig_Modality.text,
        gcl.GenerationConfig_Modality.audio,
        gcl.GenerationConfig_Modality.image,
      ]);
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
      expect(
        settings!.first.category,
        gcl.HarmCategory.harmCategoryDangerousContent,
      );
      expect(
        settings.first.threshold,
        gcl.SafetySetting_HarmBlockThreshold.blockOnlyHigh,
      );
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

      expect(
        config?.functionCallingConfig?.mode,
        gcl.FunctionCallingConfig_Mode.any,
      );
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
