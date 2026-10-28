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
import 'package:genkit_vertexai/genkit_vertexai.dart';

import 'src/model.dart';

void main(List<String> args) async {
  final ai = Genkit(
    plugins: [
      vertexAI(
        projectId: Platform.environment['GCLOUD_PROJECT'],
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'global',
      ),
    ],
  );

  // --- Basic Generate Flow ---
  ai.defineFlow(
    name: 'basicGenerate',
    inputSchema: .string(defaultValue: 'Hello Genkit for Dart!'),
    outputSchema: .string(),
    fn: (input, context) async {
      final response = await ai.generate(
        // Called through the Interactions API (see the README's routing
        // section). The -latest aliases aren't served on this platform.
        model: vertexAI.gemini('gemini-3.8-flash'),
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
        model: vertexAI.gemini('gemini-3.1-flash-image'),
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
      final gemini = vertexAI(
        projectId: Platform.environment['GCLOUD_PROJECT'],
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'global',
      );
      final response = await lite.generate(
        model: gemini.model('gemini-3.8-flash'),
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

  ai.defineFlow(
    name: 'weatherFlow',
    inputSchema: .string(defaultValue: 'What is the weather like in Boston?'),
    outputSchema: .string(),
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: vertexAI.gemini('gemini-3-flash-preview'),
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
        model: vertexAI.gemini('gemini-3.8-flash'),
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
        model: vertexAI.gemini('gemini-3.8-flash'),
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
  // A public Cloud Storage sample (as in the JS testapp): the platform reads
  // gs:// URIs directly. It fetches http(s) URLs itself, and rejected the
  // samplelib.com video it used to read (URL_REJECTED, Oct 28).
  ai.defineFlow(
    name: 'multimodalVideo',
    inputSchema: .string(defaultValue: 'What happens in this video?'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
        prompt: prompt,
        messages: [
          Message(
            role: Role.user,
            content: [
              MediaPart(
                media: Media(
                  url: 'gs://cloud-samples-data/video/animals.mp4',
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
        model: vertexAI.gemini('gemini-3.8-flash'),
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
        model: vertexAI.gemini('gemini-3.1-pro-preview'),
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
    // Unlike googleAI, blocking thresholds work on vertexAI models called
    // through the Interactions API (they're sent as `safety_settings`).
    inputSchema: .string(defaultValue: 'Some potentially harmful content'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
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
        model: vertexAI.gemini('gemini-3.8-flash'),
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
        model: vertexAI.gemini('gemini-3.8-flash'),
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
        model: vertexAI.gemini('gemini-3.1-flash-tts-preview'),
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
        model: vertexAI.gemini('gemini-3.1-flash-tts-preview'),
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
  // Newer models (e.g. gemini-3.8-flash) are called through the Interactions
  // API; the flows below use features of that path.

  // Server-side conversation state: with store: true the interaction is kept
  // on the server, and the next request continues it (the plugin finds its
  // ID in the message metadata and sends only the new messages).
  ai.defineFlow(
    name: 'multiTurnPreviousInteraction',
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (_, _) async {
      final turn1 = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
        prompt: 'My secret code is BLUE-BANANA-42. Remember this secret code.',
        config: GeminiOptions(store: true),
      );
      final turn2 = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
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

  // A stateless (store: false) two-turn conversation with Google Search.
  // The platform rejects earlier search steps when they're sent back, so
  // the plugin leaves them out of turn 2's history (with a warning); the
  // model may search again. The text of turn 1 is still sent.
  ai.defineFlow(
    name: 'groundingMultiTurnStateless',
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (_, _) async {
      final turn1 = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
        prompt: 'Who won the most recent Formula 1 race?',
        config: GeminiOptions(googleSearch: GeminiGoogleSearch()),
      );
      final turn2 = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
        messages: turn1.messages,
        prompt: 'Which team does that driver race for?',
        config: GeminiOptions(googleSearch: GeminiGoogleSearch()),
      );
      return {'turn1': turn1.text, 'turn2': turn2.text};
    },
  );
  // --- Newer models ---

  // Gemini 4 Argon (Interactions API, like any model the plugin doesn't pin
  // to generateContent).
  ai.defineFlow(
    name: 'argonBasic',
    inputSchema: .string(
      defaultValue: 'You are a helpful AI assistant named Walt, say hello.',
    ),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: vertexAI.gemini('gemini-4-argon'),
        prompt: prompt,
      );
      return response.text;
    },
  );

  // Image generation with Nano Banana 2.1 (generateContent). It doesn't
  // support seed, topK, logprobs, temperature or topP.
  ai.defineFlow(
    name: 'imageGeneration',
    inputSchema: .string(
      defaultValue:
          'A cozy reading nook with a window seat on a rainy afternoon.',
    ),
    outputSchema: Media.$schema,
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: vertexAI.geminiImage('gemini-nano-banana-2.1'),
        prompt: prompt,
        config: GeminiImageOptions(
          imageConfig: GeminiImageConfig(aspectRatio: '9:16', imageSize: '1K'),
        ),
      );
      return response.media ?? (throw Exception('No image generated'));
    },
  );

  // Video generation with Gemini Omni (Interactions API, global location).
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
        model: vertexAI.geminiVideo('gemini-omni-1.1-flash-preview'),
        prompt: prompt,
        config: GeminiVideoOptions(
          videoFormat: GeminiVideoFormat(
            aspectRatio: '9:16',
            resolution: '360p',
          ),
        ),
      );
      return response.media ?? (throw Exception('No video generated'));
    },
  );

  // Music generation with Lyria 3 (Interactions API, global only). The
  // lyrics or a caption come back as text, next to the audio.
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
        model: vertexAI.lyria('lyria-3-clip-preview'),
        prompt: prompt,
        config: LyriaOptions(location: 'global'),
      );
      final media = response.media ?? (throw Exception('No music generated'));
      return {'text': response.text, 'media': media.toJson()};
    },
  );

  // --- Text-to-speech with the 3.8 TTS models (generateContent) ---

  // The text is read verbatim, so delivery goes in speechMetadata.style.
  ai.defineFlow(
    name: 'ttsVoiceAndStyle',
    inputSchema: .string(defaultValue: 'Have a wonderful day!'),
    outputSchema: Media.$schema,
    fn: (text, _) async {
      final response = await ai.generate(
        model: vertexAI.geminiTts('gemini-3.8-flash-lite-tts'),
        promptParts: [
          TextPart(
            text: text,
            metadata: {
              'speechMetadata': {'style': 'cheerful and friendly'},
            },
          ),
        ],
        config: GeminiTtsOptions(speechConfig: _voice('Kore')),
      );
      return response.media ?? (throw Exception('No audio generated'));
    },
  );

  // Two speakers: each turn is a separate text part naming its speaker.
  ai.defineFlow(
    name: 'ttsMultiSpeaker38',
    outputSchema: Media.$schema,
    fn: (_, _) async {
      final response = await ai.generate(
        model: vertexAI.geminiTts('gemini-3.8-flash-tts'),
        promptParts: [
          TextPart(
            text: "How's it going today, Jane?",
            metadata: {
              'speechMetadata': {'speaker': 'Joe', 'style': 'cheerful'},
            },
          ),
          TextPart(
            text: 'Not too bad, how about you? <laugh>',
            metadata: {
              'speechMetadata': {'speaker': 'Jane', 'style': 'relaxed'},
            },
          ),
        ],
        config: GeminiTtsOptions(
          speechConfig: GeminiSpeechConfig(
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
          ),
        ),
      );
      return response.media ?? (throw Exception('No audio generated'));
    },
  );

  // Streamed TTS: audio chunks arrive while the speech is generated; the
  // final response joins them into one part (raw PCM, audio/l16, by
  // default), wrapped in a WAV header here so it plays in the Dev UI.
  ai.defineFlow(
    name: 'ttsStreaming',
    outputSchema: .map(.string(), .dynamicSchema()),
    streamSchema: .string(),
    fn: (_, ctx) async {
      var chunkCount = 0;
      final response = await ai.generate(
        model: vertexAI.geminiTts('gemini-3.8-flash-lite-tts'),
        prompt:
            'Streaming lets an app start playing speech before the whole '
            'sentence has been generated.',
        config: GeminiTtsOptions(speechConfig: _voice('Kore')),
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

  // TTS output formats: audio/wav (default) is a complete WAV file;
  // audio/l16 is raw PCM (24 kHz); audio/mulaw and audio/alaw are telephony
  // formats (8 kHz). Only audio/wav plays in the Dev UI, so the others return
  // their size.
  ai.defineFlow(
    name: 'ttsAudioFormat',
    inputSchema: .string(defaultValue: 'audio/mulaw'),
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (mimeType, _) async {
      final response = await ai.generate(
        model: vertexAI.geminiTts('gemini-3.8-flash-lite-tts'),
        prompt: 'Thank you for calling. Please hold.',
        config: GeminiTtsOptions(
          speechConfig: _voice('Kore'),
          audioFormat: GeminiAudioFormat(mimeType: mimeType),
        ),
      );
      final media = response.media ?? (throw Exception('No audio generated'));
      final url = media.url;
      return {
        'contentType': media.contentType,
        'bytes': base64Decode(url.substring(url.indexOf(',') + 1)).length,
        if (mimeType == 'audio/wav') 'media': media.toJson(),
      };
    },
  );

  // --- vertexAI request options ---

  // Labels (cost tracking) and PayGo (headers) on a generateContent model
  // and an Interactions model.
  ai.defineFlow(
    name: 'labelsAndPayGo',
    inputSchema: .string(defaultValue: 'priority'),
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (payGo, _) async {
      final config = GeminiOptions(
        labels: {'team': 'genkit', 'flow': 'labels-and-paygo'},
        payGo: payGo, // priority, priority-only, flex or flex-only.
      );
      final generateContent = await ai.generate(
        model: vertexAI.gemini('gemini-3.1-flash-lite'),
        prompt: 'Say hello in one short sentence.',
        config: config,
      );
      final interactions = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
        prompt: 'Say hello in one short sentence.',
        config: config,
      );
      return {
        'generateContent': generateContent.text,
        'interactions': interactions.text,
      };
    },
  );

  // A per-request location: the plugin uses GCLOUD_LOCATION (default
  // global); this request goes to the `us` multi-region (3.8 Flash is served
  // on global, us and eu).
  ai.defineFlow(
    name: 'requestLocation',
    inputSchema: .string(defaultValue: 'us'),
    outputSchema: .string(),
    fn: (location, _) async {
      final response = await ai.generate(
        model: vertexAI.gemini('gemini-3.8-flash'),
        prompt: 'Say hello in one short sentence.',
        config: GeminiOptions(location: location),
      );
      return response.text;
    },
  );

  // Multimodal embedding through the `:embedContent` method
  // (gemini-embedding-2 and newer): text and an image in one document give
  // ONE embedding in a shared space. Compare embedMultimodalViaPredict.
  ai.defineFlow(
    name: 'embedMultimodalViaEmbedContent',
    outputSchema: .map(.string(), .dynamicSchema()),
    fn: (_, _) async {
      final photoUri = Platform.script.resolve('photo.jpg');
      final photoBase64 = base64Encode(
        await File(photoUri.toFilePath()).readAsBytes(),
      );
      final embeddings = await ai.embed(
        embedder: vertexAI.textEmbedding('gemini-embedding-2'),
        documents: [
          DocumentData(
            content: [
              TextPart(text: 'An old photo.'),
              MediaPart(
                media: Media(
                  url: 'data:image/jpeg;base64,$photoBase64',
                  contentType: 'image/jpeg',
                ),
              ),
            ],
          ),
        ],
        options: GoogleGenAiEmbedderOptions(outputDimensionality: 128),
      );
      return {
        'count': embeddings.length,
        'dimensions': embeddings.first.embedding.length,
      };
    },
  );

  ai.defineFlow(
    name: 'embedding',
    inputSchema: .string(defaultValue: 'Hello Genkit'),
    outputSchema: .list(.doubleSchema()),
    fn: (input, _) async {
      final embeddings = await ai.embed(
        embedder: vertexAI.textEmbedding('gemini-embedding-001'),
        documents: [
          DocumentData(content: [TextPart(text: input)]),
        ],
      );
      return embeddings.first.embedding;
    },
  );

  // --- Embedding With Options Flow ---
  // Per-request options are applied: a reduced output dimensionality and a task
  // type. The returned vector has 256 dimensions instead of the model default.
  ai.defineFlow(
    name: 'embeddingWithOptions',
    inputSchema: .string(defaultValue: 'Hello Genkit'),
    outputSchema: .integer(),
    fn: (input, _) async {
      final embeddings = await ai.embed(
        embedder: vertexAI.textEmbedding('gemini-embedding-001'),
        documents: [
          DocumentData(content: [TextPart(text: input)]),
        ],
        options: GoogleGenAiEmbedderOptions(
          outputDimensionality: 256,
          taskType: 'RETRIEVAL_DOCUMENT',
        ),
      );
      return embeddings.first.embedding.length;
    },
  );

  // --- Multimodal Embedding Flow (`:predict`) ---
  // `multimodalembedding` (the `:predict` method) returns one embedding *per
  // modality per document*, not one per document (compare
  // embedMultimodalViaEmbedContent). The input below is a single document
  // containing both the
  // `caption` (text) and the `imageUri` (image), so it produces TWO embeddings
  // and the flat result is not 1:1 with the input documents. Each embedding
  // carries metadata (`documentIndex`, `modality`, ...) that callers use to map
  // it back to its source. This flow returns that mapping so the shape is
  // visible: e.g. [{modality: text, ...}, {modality: image, ...}].
  // The default `imageUri` is a public Google sample (needs GCS read access);
  // inline `data:` image URIs work too.
  ai.defineFlow(
    name: 'embedMultimodalViaPredict',
    inputSchema: MultimodalEmbeddingInput.$schema,
    outputSchema: .list(.map(.string(), .dynamicSchema())),
    fn: (input, _) async {
      final uri = input.imageUri;
      final contentType = uri.endsWith('.png')
          ? 'image/png'
          : uri.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';

      final embeddings = await ai.embed(
        embedder: vertexAI.textEmbedding('multimodalembedding'),
        documents: [
          DocumentData(
            content: [
              TextPart(text: input.caption),
              MediaPart(
                media: Media(url: uri, contentType: contentType),
              ),
            ],
          ),
        ],
      );

      // Return each embedding's full metadata (documentIndex, modality,
      // partIndex/partIndices, segmentIndex, ...) plus its dimension count so
      // the per-modality mapping is visible end to end.
      return embeddings
          .map((e) => {...?e.metadata, 'dimensions': e.embedding.length})
          .toList();
    },
  );
}

GeminiSpeechConfig _voice(String voiceName) => GeminiSpeechConfig(
  voiceConfig: GeminiVoiceConfig(
    prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(voiceName: voiceName),
  ),
);

/// Wraps raw PCM audio (16-bit little-endian, mono) in a WAV header so it can
/// be played; WAV media is returned as is. The sample rate comes from the
/// content type (`rate=...`), else 24000 Hz (the Gemini TTS models' rate).
/// Same as `_pcmToWav` in bin/googleai.dart.
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
