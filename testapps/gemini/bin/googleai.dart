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
import 'dart:typed_data';

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
        model: googleAI.gemini('gemini-flash-latest'),
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
        model: googleAI.geminiImage('gemini-nano-banana-2.1'),
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
        model: gemini.model('gemini-flash-latest'),
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
        return .response('The weather in Boston is 72 and sunny.');
      }
      return .response('The weather in ${input.location} is 75 and cloudy.');
    },
  );

  // A primitive input schema works too; the description tells the model what
  // the value means.
  ai.defineTool(
    name: 'getTime',
    description: 'Get the current time in a city',
    inputSchema: .string(description: 'City name, e.g. "Boston"'),
    fn: (city, _) async => .response('It is 3pm in $city.'),
  );

  ai.defineFlow(
    name: 'weatherFlow',
    inputSchema: .string(
      defaultValue: 'What is the weather and local time in Boston?',
    ),
    outputSchema: .string(),
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        prompt: prompt,
        toolNames: ['getWeather', 'getTime'],
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
        model: googleAI.gemini('gemini-flash-latest'),
        config: GeminiOptions(temperature: 2.0),
        outputSchema: RpgCharacter.$schema,
        prompt: 'Generate an RPC character called $name',
      );

      await for (final chunk in stream) {
        // `output` is null while the JSON streamed so far can't be parsed
        // yet, or for chunks without JSON text (e.g. thoughts or tool
        // calls), so skip those.
        final output = chunk.output;
        if (ctx.streamingRequested && output != null) {
          ctx.sendChunk(output);
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
        model: googleAI.gemini('gemini-flash-latest'),
        outputSchema: CharacterProfile.$schema,
        prompt: prompt,
        onChunk: ctx.streamingRequested
            ? (GenerateResponseChunk<CharacterProfile?> chunk) {
                // Null until enough JSON has arrived to parse.
                final output = chunk.output;
                if (output != null) ctx.sendChunk(output);
              }
            : null,
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
        model: googleAI.gemini('gemini-flash-latest'),
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
        model: googleAI.gemini('gemini-flash-latest'),
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
        model: googleAI.gemini('gemini-3.1-pro-preview'),
        prompt: prompt,
        config: GeminiOptions(
          // Configured to return thoughts as ReasoningParts.
          thinkingConfig: GeminiThinkingConfig(
            thinkingBudget: 2048,
            includeThoughts: true,
          ),
        ),
        onChunk: (chunk) => ctx.sendChunk(chunk.modelChunk),
      );
      return response.message!;
    },
  );

  // --- Safety Settings Flow ---
  ai.defineFlow(
    name: 'safetySettings',
    // Example of configuring safety settings.
    // Note: The model might not block the default content if it's not harmful enough.
    // Blocking thresholds need a model called through generateContent: models
    // called through the Interactions API (e.g. gemini-flash-latest) only
    // accept BLOCK_NONE and throw INVALID_ARGUMENT for stricter thresholds.
    inputSchema: .string(defaultValue: 'Some potentially harmful content'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3.1-flash-lite'),
        prompt: prompt,
        config: GeminiOptions(
          safetySettings: [
            GeminiSafetySettings(
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
        model: googleAI.gemini('gemini-flash-latest'),
        prompt: prompt,
        config: GeminiOptions(googleSearch: GeminiGoogleSearch()),
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
        model: googleAI.gemini('gemini-pro-latest'),
        prompt: prompt,
        config: GeminiOptions(codeExecution: true),
      );
      return response.text;
    },
  );

  // --- TTS Flow ---
  // The 3.8 TTS models are called through the Interactions API and return a
  // complete WAV file (audio/wav), ready to play or save.
  ai.defineFlow(
    name: 'textToSpeech',
    inputSchema: .string(
      defaultValue: 'Say that Genkit is an amazing AI framework',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.geminiTts('gemini-3.8-flash-tts'),
        prompt: prompt,
        config: GeminiTtsOptions(
          responseModalities: ['AUDIO'],
          speechConfig: GeminiSpeechConfig(
            voiceConfig: GeminiVoiceConfig(
              prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(voiceName: 'Puck'),
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
        // 3.1 TTS (called through generateContent) takes the speakers from
        // the transcript. For the 3.8 TTS models (Interactions API), see
        // ttsInteractionsMultiSpeaker: each turn names its speaker.
        model: googleAI.geminiTts('gemini-3.1-flash-tts-preview'),
        prompt: prompt,
        config: GeminiTtsOptions(
          responseModalities: ['AUDIO'],
          speechConfig: GeminiSpeechConfig(
            multiSpeakerVoiceConfig: GeminiMultiSpeakerVoiceConfig(
              speakerVoiceConfigs: [
                GeminiSpeakerVoiceConfig(
                  speaker: 'Speaker A',
                  voiceConfig: GeminiVoiceConfig(
                    prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(
                      voiceName: 'Puck',
                    ),
                  ),
                ),
                GeminiSpeakerVoiceConfig(
                  speaker: 'Speaker B',
                  voiceConfig: GeminiVoiceConfig(
                    prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(
                      voiceName: 'Kore',
                    ),
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

  // --- Interactions API flows ---
  // Newer models (and the -latest aliases) are called through the
  // Interactions API; the flows below use features only that API has.

  // Server-side conversation state: with store: true the interaction is kept
  // on the server, and the next request continues it (the plugin finds its
  // ID in the message metadata and sends only the new messages).
  ai.defineFlow(
    name: 'multiTurnPreviousInteraction',
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (_, _) async {
      final turn1 = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        prompt: 'My secret code is BLUE-BANANA-42. Remember this secret code.',
        config: GeminiOptions(store: true),
      );
      final turn2 = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        messages: turn1.messages,
        prompt: 'What was my secret code?',
        config: GeminiOptions(store: true),
      );
      return {
        'turn1Answer': turn1.text,
        'turn2Answer': turn2.text,
        'turn1InteractionId': turn1.message?.metadata?['interactionId'],
        'turn2InteractionId': turn2.message?.metadata?['interactionId'],
      };
    },
  );

  // Flex tier: lower cost, variable latency.
  ai.defineFlow(
    name: 'flexTier',
    inputSchema: .string(
      defaultValue: 'You are a helpful AI assistant named Walt, say hello',
    ),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-flash-lite-latest'),
        prompt: prompt,
        config: GeminiOptions(serviceTier: 'flex'), // or standard, priority
      );
      return response.text;
    },
  );

  // Thinking levels (Interactions models have no thinking budget).
  ai.defineFlow(
    name: 'thinkingLevel',
    inputSchema: .string(defaultValue: 'LOW'),
    outputSchema: Message.$schema,
    fn: (level, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3.8-flash'),
        prompt:
            'Alice, Bob, and Carol each live in a different house on the '
            'same street: red, green, and blue. The person who lives in the '
            'red house owns a cat. Bob does not live in the green house. '
            'Carol owns a dog. The green house is to the left of the red '
            'house. Alice does not own a cat. The person in the blue house '
            'owns a fish. Who lives in each house, and what pet do they own?',
        config: GeminiOptions(
          thinkingConfig: GeminiThinkingConfig(
            thinkingLevel: level,
            includeThoughts: true,
          ),
        ),
      );
      return response.message!;
    },
  );

  // Turn-level speech style, set in the part metadata; requires a voice.
  ai.defineFlow(
    name: 'ttsInteractionsVoiceAndStyle',
    inputSchema: .string(defaultValue: 'Have a wonderful day!'),
    outputSchema: Media.$schema,
    fn: (text, _) async {
      final response = await ai.generate(
        model: googleAI.geminiTts('gemini-3.8-flash-lite-tts'),
        promptParts: [
          TextPart(
            text: text,
            metadata: {
              'speechMetadata': {'style': 'cheerful and friendly'},
            },
          ),
        ],
        config: GeminiTtsOptions(speechConfig: _voice('Puck')),
      );
      return response.media ?? (throw Exception('No audio generated'));
    },
  );

  // Multi-speaker TTS through the Interactions API: each turn is a separate
  // text part that names one of the configured speakers.
  ai.defineFlow(
    name: 'ttsInteractionsMultiSpeaker',
    outputSchema: Media.$schema,
    fn: (_, _) async {
      final response = await ai.generate(
        model: googleAI.geminiTts('gemini-3.8-flash-lite-tts'),
        promptParts: _joeAndJane(janeStyle: 'calm'),
        config: GeminiTtsOptions(speechConfig: _joeAndJaneVoices),
      );
      return response.media ?? (throw Exception('No audio generated'));
    },
  );

  // Streamed TTS: raw PCM (audio/l16) chunks arrive while the speech is
  // generated, so a client can start playing right away; the final response
  // joins them into one audio/l16 part, wrapped in a WAV header here so it
  // can be played.
  ai.defineFlow(
    name: 'ttsStreaming',
    outputSchema: .map(.string(), .dynamicSchema()),
    streamSchema: .string(),
    fn: (_, ctx) async {
      var chunkCount = 0;
      final response = await ai.generate(
        model: googleAI.geminiTts('gemini-3.8-flash-lite-tts'),
        promptParts: _joeAndJane(),
        config: GeminiTtsOptions(speechConfig: _joeAndJaneVoices),
        onChunk: (chunk) {
          // A real client would play chunk.media here; report progress only.
          chunkCount++;
          ctx.sendChunk('chunk $chunkCount: ${chunk.media?.contentType}');
        },
      );
      final media = response.media ?? (throw Exception('No audio generated'));
      return {
        'chunkCount': chunkCount,
        'streamedContentType': media.contentType,
        'media': _pcmToWav(media).toJson(),
      };
    },
  );

  // --- Built-in tools ---

  // Google Maps: a `tools` map plus the user's location in retrievalConfig.
  // On Interactions models the location is set on the google_maps tool.
  ai.defineFlow(
    name: 'mapsGrounding',
    inputSchema: .string(defaultValue: 'Describe some sights near me'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        prompt: prompt,
        config: GeminiOptions(
          tools: [
            {
              'googleMaps': {'enableWidget': true},
            },
          ],
          retrievalConfig: GeminiRetrievalConfig(
            latLng: GeminiLatLng(latitude: 43.0896, longitude: -79.0849),
          ),
        ),
      );
      return response.text;
    },
  );

  // The same on a model pinned to generateContent (toolConfig.retrievalConfig).
  ai.defineFlow(
    name: 'mapsGroundingGenerateContent',
    inputSchema: .string(defaultValue: 'Describe some sights near me'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3.1-pro-preview'),
        prompt: prompt,
        config: GeminiOptions(
          tools: [
            {'googleMaps': <String, dynamic>{}},
          ],
          retrievalConfig: GeminiRetrievalConfig(
            latLng: GeminiLatLng(latitude: 43.0896, longitude: -79.0849),
          ),
        ),
      );
      return response.text;
    },
  );

  ai.defineFlow(
    name: 'urlContext',
    inputSchema: .string(
      defaultValue:
          'Compare the ingredients and cooking times from the recipes at '
          'https://www.foodnetwork.com/recipes/ina-garten/perfect-roast-chicken-recipe-1940592 '
          'and https://www.allrecipes.com/recipe/70679/simple-whole-roasted-chicken/',
    ),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        prompt: prompt,
        config: GeminiOptions(urlContext: GeminiUrlContext()),
      );
      return response.text;
    },
  );

  // --- Image generation settings ---

  // Interactions model: imageConfig goes in the response_format image entry.
  ai.defineFlow(
    name: 'imageConfig',
    inputSchema: .string(
      defaultValue: 'A picture of a sunset in the mountains by a lake',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.geminiImage('gemini-nano-banana-2.1'),
        prompt: prompt,
        config: GeminiImageOptions(
          imageConfig: GeminiImageConfig(aspectRatio: '9:16', imageSize: '1K'),
        ),
      );
      return response.media ?? (throw Exception('No image generated'));
    },
  );

  // generateContent model: imageConfig goes in generationConfig.
  ai.defineFlow(
    name: 'imageConfigGenerateContent',
    inputSchema: .string(
      defaultValue: 'A picture of a sunset in the mountains by a lake',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.geminiImage('gemini-3-pro-image'),
        prompt: prompt,
        config: GeminiImageOptions(
          imageConfig: GeminiImageConfig(aspectRatio: '3:4', imageSize: '1K'),
        ),
      );
      return response.media ?? (throw Exception('No image generated'));
    },
  );

  // --- TTS audio format ---

  // Streamed with audioFormat audio/wav: the final response is one playable
  // WAV file (no wrapping needed).
  ai.defineFlow(
    name: 'ttsStreamingWav',
    outputSchema: .map(.string(), .dynamicSchema()),
    streamSchema: .string(),
    fn: (_, ctx) async {
      var chunkCount = 0;
      final response = await ai.generate(
        model: googleAI.geminiTts('gemini-3.8-flash-lite-tts'),
        prompt: 'Have a wonderful day!',
        config: GeminiTtsOptions(
          speechConfig: _voice('Kore'),
          audioFormat: GeminiAudioFormat(mimeType: 'audio/wav'),
        ),
        onChunk: (chunk) {
          chunkCount++;
          ctx.sendChunk('chunk $chunkCount: ${chunk.media?.contentType}');
        },
      );
      final media = response.media ?? (throw Exception('No audio generated'));
      return {'chunkCount': chunkCount, 'media': media.toJson()};
    },
  );

  // --- Video generation (Gemini Omni) ---

  // ai.generate() returns the video directly, as an inline MP4 (a data URL)
  // that plays in the Dev UI. 360p keeps it fast.
  ai.defineFlow(
    name: 'omniTextToVideo',
    inputSchema: .string(
      defaultValue:
          'A paper boat floating down a rain-filled gutter, continuous '
          'shot, with the sound of rain.',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.geminiVideo('gemini-omni-1.1-flash'),
        prompt: prompt,
        config: GeminiVideoOptions(
          videoFormat: GeminiVideoFormat(
            aspectRatio: '9:16',
            resolution: '360p',
          ),
          // Optional: the model infers the task from the prompt if not set.
          videoConfig: GeminiVideoConfig(task: 'text_to_video'),
        ),
      );
      return response.media ?? (throw Exception('No video generated'));
    },
  );

  // --- Music generation (Lyria) ---

  ai.defineFlow(
    name: 'lyriaClip',
    inputSchema: .string(
      defaultValue:
          'Create a 30-second cheerful acoustic folk song with guitar and '
          'harmonica.',
    ),
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.lyria('lyria-3-clip-preview'),
        prompt: prompt,
      );
      final media = response.media ?? (throw Exception('No music generated'));
      // The lyrics or a caption come back as text, next to the audio.
      return {'text': response.text, 'media': media.toJson()};
    },
  );

  ai.defineFlow(
    name: 'lyriaInstrumental',
    inputSchema: .string(
      defaultValue:
          'A bright chiptune melody in C Major, retro 8-bit video game style. '
          'Instrumental only, no vocals.',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.lyria('lyria-3-clip-preview'),
        prompt: prompt,
        config: LyriaOptions(responseModalities: ['AUDIO']),
      );
      return response.media ?? (throw Exception('No music generated'));
    },
  );

  // --- Antigravity agent ---

  ai.defineFlow(
    name: 'antigravity',
    inputSchema: .string(
      defaultValue: 'Read Hacker News, summarize the top 10 stories.',
    ),
    outputSchema: Message.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.antigravity('antigravity-preview-09-2026'),
        prompt: prompt,
        // Without tools, the agent uses all its default tools.
        config: AntigravityOptions(environment: 'remote'),
      );
      return response.message!;
    },
  );

  // Two turns: the second continues the stored interaction, in the same
  // sandbox, because it passes the first response's messages.
  ai.defineFlow(
    name: 'antigravityMultiTurn',
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (_, _) async {
      final turn1 = await ai.generate(
        model: googleAI.antigravity('antigravity-preview-09-2026'),
        prompt: 'Create a simple python script to print hello world.',
        config: AntigravityOptions(environment: 'remote'),
      );
      final turn2 = await ai.generate(
        model: googleAI.antigravity('antigravity-preview-09-2026'),
        messages: turn1.messages,
        prompt: 'Now modify the script to print it backwards and run it.',
      );
      return {
        'turn1': turn1.text,
        'turn1Metadata': turn1.message?.metadata,
        'turn2': turn2.text,
      };
    },
  );

  // Antigravity calling one of your own tools, on a chosen Gemini model.
  ai.defineFlow(
    name: 'antigravityFunctionTools',
    inputSchema: .string(
      defaultValue:
          'Use the getWeather tool to get the weather in Tokyo, then tell me '
          'in one sentence.',
    ),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: googleAI.antigravity('antigravity-preview-09-2026'),
        prompt: prompt,
        toolNames: ['getWeather'],
        config: AntigravityOptions(
          environment: 'remote',
          model: 'gemini-3.5-flash-lite',
        ),
      );
      return response.text;
    },
  );

  ai.defineFlow(
    name: 'embedding',
    inputSchema: .string(defaultValue: 'Hello Genkit'),
    outputSchema: .list(.doubleSchema()),
    fn: (input, _) async {
      final embeddings = await ai.embed(
        embedder: googleAI.textEmbedding('gemini-embedding-001'),
        documents: [
          DocumentData(content: [TextPart(text: input)]),
        ],
      );
      return embeddings.first.embedding;
    },
  );
}

GeminiSpeechConfig _voice(String voiceName) => GeminiSpeechConfig(
  voiceConfig: GeminiVoiceConfig(
    prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(voiceName: voiceName),
  ),
);

final _joeAndJaneVoices = GeminiSpeechConfig(
  multiSpeakerVoiceConfig: GeminiMultiSpeakerVoiceConfig(
    speakerVoiceConfigs: [
      GeminiSpeakerVoiceConfig(
        speaker: 'Joe',
        voiceConfig: _voice('Puck').voiceConfig!,
      ),
      GeminiSpeakerVoiceConfig(
        speaker: 'Jane',
        voiceConfig: _voice('Kore').voiceConfig!,
      ),
    ],
  ),
);

/// Wraps raw PCM audio (16-bit little-endian, mono) in a WAV header so it can
/// be played; WAV media is returned as is. The sample rate comes from the
/// content type (`rate=...`), else 24000 Hz (the Gemini TTS models' rate).
/// Like `pcmMediaToWav` in packages/genkit_google_genai/example.
Media _pcmToWav(Media media) {
  final contentType = media.contentType ?? '';
  if (contentType.toLowerCase().startsWith('audio/wav')) return media;

  final pcm = base64Decode(media.url.substring(media.url.indexOf(',') + 1));
  final rate = RegExp(r'rate=(\d+)').firstMatch(contentType);
  final sampleRate = rate == null ? 24000 : int.parse(rate.group(1)!);

  final header = ByteData(44);
  void ascii4(int offset, String s) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii4(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii4(8, 'WAVE');
  ascii4(12, 'fmt ');
  header
    ..setUint32(16, 16, Endian.little) // fmt chunk size for PCM
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little) // bytes per second
    ..setUint16(32, 2, Endian.little) // bytes per sample
    ..setUint16(34, 16, Endian.little); // bits per sample
  ascii4(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  final wav = Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  return Media(
    url: 'data:audio/wav;base64,${base64Encode(wav)}',
    contentType: 'audio/wav',
  );
}

List<Part> _joeAndJane({String? janeStyle}) => [
  TextPart(
    text: "How's it going today, Jane?",
    metadata: {
      'speechMetadata': {'speaker': 'Joe'},
    },
  ),
  TextPart(
    text: 'Not too bad, how about you?',
    metadata: {
      'speechMetadata': {'speaker': 'Jane', 'style': ?janeStyle},
    },
  ),
];
