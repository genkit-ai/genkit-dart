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
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit/lite.dart' as lite;
import 'package:genkit_google_genai/genkit_google_genai.dart';

import 'src/model.dart';

void main(List<String> args) async {
  final ai = Genkit(plugins: [googleAI()]);

  // --- Basic Generate Flow ---
  ai.defineFlow(
    name: 'basicGenerate',
    inputSchema: .string(defaultValue: 'Hello Genkit for Dart!'),
    outputSchema: .string(),
    fn: (input, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: input,
      );
      return response.text;
    },
  );

  // --- Image Generator Flow using Nano Banana ---
  ai.defineFlow(
    name: 'imageGenerator',
    inputSchema: .string(defaultValue: 'Colorize this photo'),
    outputSchema: Media.$schema,
    fn: (input, context) async {
      final photoUri = Platform.script.resolve('photo.jpg');
      final photoBytes = await File(photoUri.toFilePath()).readAsBytes();
      final photoBase64 = base64Encode(photoBytes);

      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash-image'),
        prompt: input,
        messages: [
          Message(
            role: Role.user,
            content: [
              MediaPart(
                media: Media(url: 'data:image/jpeg;base64,$photoBase64'),
              ),
            ],
          ),
        ],
      );
      if (response.media == null) {
        throw Exception('No media generated');
      }
      return response.media!;
    },
  );

  // --- Lite Generate Flow (Wrapped) ---
  ai.defineFlow(
    name: 'liteGenerate',
    inputSchema: .string(defaultValue: 'Hello Genkit for Dart!'),
    outputSchema: .string(),
    fn: (input, context) async {
      final gemini = googleAI();
      final response = await lite.generate(
        model: gemini.model('gemini-2.5-flash'),
        prompt: input,
      );
      return response.text;
    },
  );

  // --- Tool Calling Flow ---
  ai.defineTool(
    name: 'getWeather',
    description: 'Get the weather for a location',
    inputSchema: WeatherToolInput.$schema,
    fn: (input, context) async {
      if (input.location.toLowerCase().contains('boston')) {
        return 'The weather in Boston is 72 and sunny.';
      }
      return 'The weather in ${input.location} is 75 and cloudy.';
    },
  );

  ai.defineFlow(
    name: 'weatherFlow',
    inputSchema: .string(defaultValue: 'What is the weather like in Boston?'),
    outputSchema: .string(),
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3-flash-preview'),
        prompt: prompt,
        toolNames: ['getWeather'],
      );
      return response.text;
    },
  );

  // --- Structured Streaming Flow ---
  ai.defineFlow(
    name: 'structuredStreaming',
    inputSchema: .string(defaultValue: 'Gorble'),
    streamSchema: RpgCharacter.$schema,
    outputSchema: RpgCharacter.$schema,
    fn: (name, ctx) async {
      final stream = ai.generateStream(
        model: googleAI.gemini('gemini-2.5-flash'),
        config: GeminiOptions(temperature: 2.0),
        outputSchema: RpgCharacter.$schema,
        prompt: 'Generate an RPC character called $name',
      );

      await for (final chunk in stream) {
        if (ctx.streamingRequested) {
          ctx.sendChunk(chunk.output!);
        }
      }

      final response = await stream.onResult;
      return response.output!;
    },
  );

  // --- Character Profile Flow ---
  ai.defineFlow(
    name: 'characterProfile',
    inputSchema: .string(
      defaultValue: 'Generate a profile for a fictional character',
    ),
    outputSchema: CharacterProfile.$schema,
    streamSchema: CharacterProfile.$schema,
    fn: (prompt, ctx) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        outputSchema: CharacterProfile.$schema,
        prompt: prompt,
        onChunk: (chunk) {
          ctx.sendChunk(chunk.output!);
        },
      );
      return response.output!;
    },
  );

  // --- Multimodal Video Flow ---
  ai.defineFlow(
    name: 'multimodalVideo',
    inputSchema: .string(defaultValue: 'What happens in this video?'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: prompt,
        messages: [
          Message(
            role: Role.user,
            content: [
              MediaPart(
                media: Media(
                  url: 'https://download.samplelib.com/mp4/sample-5s.mp4',
                  contentType: 'video/mp4',
                ),
              ),
            ],
          ),
        ],
      );
      return response.text;
    },
  );

  // --- Multimodal Audio Flow ---
  ai.defineFlow(
    name: 'multimodalAudio',
    inputSchema: .string(defaultValue: 'Transcribe this audio'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: prompt,
        messages: [
          Message(
            role: Role.user,
            content: [
              MediaPart(
                media: Media(
                  url:
                      'https://www.mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Samples/Goldwave/addf8-Alaw-GW.wav',
                  contentType: 'audio/wav',
                ),
              ),
            ],
          ),
        ],
      );
      return response.text;
    },
  );

  // --- Thinking Flow ---
  ai.defineFlow(
    name: 'thinking',
    inputSchema: .string(
      defaultValue:
          'what is heavier, one kilo of steel or one kilo of feathers',
    ),
    outputSchema: Message.$schema,
    streamSchema: ModelResponseChunk.$schema,
    fn: (prompt, ctx) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-pro'),
        prompt: prompt,
        config: GeminiOptions(
          // Configured to return thoughts as ReasoningParts.
          thinkingConfig: ThinkingConfig(
            thinkingBudget: 2048,
            includeThoughts: true,
          ),
        ),
        onChunk: (chunk) => ctx.sendChunk(chunk),
      );
      return response.message!;
    },
  );

  // --- Safety Settings Flow ---
  ai.defineFlow(
    name: 'safetySettings',
    // Example of configuring safety settings.
    // Note: The model might not block the default content if it's not harmful enough.
    inputSchema: .string(defaultValue: 'Some potentially harmful content'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: prompt,
        config: GeminiOptions(
          safetySettings: [
            SafetySettings(
              category: 'HARM_CATEGORY_HATE_SPEECH',
              threshold: 'BLOCK_MEDIUM_AND_ABOVE',
            ),
          ],
        ),
      );
      return response.text;
    },
  );

  // --- Grounding Flow ---
  ai.defineFlow(
    name: 'grounding',
    inputSchema: .string(
      defaultValue: 'What are the top tech news stories this week?',
    ),
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: prompt,
        config: GeminiOptions(googleSearch: GoogleSearch()),
      );
      return response.raw!;
    },
  );

  // --- Code Execution Flow ---
  ai.defineFlow(
    name: 'codeExecution',
    inputSchema: .string(defaultValue: 'Calculate the 20th Fibonacci number'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-pro'),
        prompt: prompt,
        config: GeminiOptions(codeExecution: true),
      );
      return response.text;
    },
  );

  // --- TTS Flow ---
  ai.defineFlow(
    name: 'textToSpeech',
    inputSchema: .string(
      defaultValue: 'Say that Genkit is an amazing AI framework',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash-preview-tts'),
        prompt: prompt,
        config: GeminiTtsOptions(
          responseModalities: ['AUDIO'],
          speechConfig: SpeechConfig(
            voiceConfig: VoiceConfig(
              prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: 'Puck'),
            ),
          ),
        ),
      );
      if (response.media != null) {
        return response.media!;
      }
      throw Exception('No audio generated');
    },
  );

  // --- Multi Speaker TTS Flow ---
  ai.defineFlow(
    name: 'multiSpeaker',
    inputSchema: .string(
      defaultValue: '''
    Speaker A: Hello, how are you today?
    Speaker B: I am doing great, thanks for asking!
    ''',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash-preview-tts'),
        prompt: prompt,
        config: GeminiTtsOptions(
          responseModalities: ['AUDIO'],
          speechConfig: SpeechConfig(
            multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig(
              speakerVoiceConfigs: [
                SpeakerVoiceConfig(
                  speaker: 'Speaker A',
                  voiceConfig: VoiceConfig(
                    prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: 'Puck'),
                  ),
                ),
                SpeakerVoiceConfig(
                  speaker: 'Speaker B',
                  voiceConfig: VoiceConfig(
                    prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: 'Kore'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (response.media != null) {
        return response.media!;
      }
      throw Exception('No audio generated');
    },
  );

  ai.defineFlow(
    name: 'embedding',
    inputSchema: .string(defaultValue: 'Hello Genkit'),
    outputSchema: .list(.doubleSchema()),
    fn: (input, _) async {
      final embeddings = await ai.embedMany(
        embedder: googleAI.textEmbedding('text-embedding-004'),
        documents: [
          DocumentData(content: [TextPart(text: input)]),
        ],
      );
      return embeddings.first.embedding;
    },
  );
}
