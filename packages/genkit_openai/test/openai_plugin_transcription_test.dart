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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/transcription.dart'
    show
        audioFilenameFor,
        declaresMediaInput,
        isTranscriptionModel,
        supportsTranslation,
        transcriptionModelInfo;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// One captured multipart upload.
class CapturedUpload {
  CapturedUpload({
    required this.path,
    required this.fields,
    required this.repeated,
    required this.filename,
    required this.fileBytes,
    required this.headers,
  });

  final String path;

  /// HTTP headers the plugin put on the upload.
  final Map<String, String> headers;

  /// Single-valued form fields.
  final Map<String, String> fields;

  /// Fields that appeared more than once, e.g. `timestamp_granularities[]`.
  final Map<String, List<String>> repeated;

  final String? filename;
  final List<int> fileBytes;
}

/// Parses a `multipart/form-data` body into its parts.
///
/// Hand-rolled because the plugin builds the upload itself rather than going
/// through the SDK, so the tests need to see exactly what went on the wire.
CapturedUpload parseMultipart(http.Request request) {
  final contentType = request.headers['content-type'] ?? '';
  final boundary = RegExp(r'boundary=(.*)$').firstMatch(contentType)!.group(1)!;
  final body = latin1.decode(request.bodyBytes);

  final fields = <String, String>{};
  final repeated = <String, List<String>>{};
  String? filename;
  var fileBytes = <int>[];

  for (final section in body.split('--$boundary')) {
    final split = section.indexOf('\r\n\r\n');
    if (split == -1) continue;
    final headers = section.substring(0, split);
    final nameMatch = RegExp('name="([^"]*)"').firstMatch(headers);
    if (nameMatch == null) continue;

    final name = nameMatch.group(1)!;
    final value = section
        .substring(split + 4)
        .replaceFirst(RegExp(r'\r\n$'), '');

    final fileMatch = RegExp('filename="([^"]*)"').firstMatch(headers);
    if (fileMatch != null) {
      filename = fileMatch.group(1);
      fileBytes = latin1.encode(value);
      continue;
    }

    if (fields.containsKey(name)) {
      repeated.putIfAbsent(name, () => [fields[name]!]).add(value);
    } else {
      fields[name] = value;
    }
  }

  return CapturedUpload(
    path: request.url.path,
    fields: fields,
    repeated: repeated,
    filename: filename,
    fileBytes: fileBytes,
    headers: request.headers,
  );
}

/// Serves canned transcription responses and captures each upload.
MockClient transcriptionWireClient(
  List<CapturedUpload> captured, {
  String body = '{"text":"The quick brown fox."}',
  int status = 200,
}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'gpt-4o',
              'object': 'model',
              'created': 0,
              'owned_by': 'openai',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith('/audio/transcriptions') ||
        request.url.path.endsWith('/audio/translations')) {
      captured.add(parseMultipart(request));
      return http.Response(body, status);
    }
    return http.Response('not found', 404);
  });
}

Genkit transcriptionGenkit(
  List<CapturedUpload> captured, {
  String body = '{"text":"The quick brown fox."}',
  int status = 200,
}) => Genkit(
  plugins: [
    openAI(
      apiKey: 'test-key',
      httpClient: transcriptionWireClient(captured, body: body, status: status),
    ),
  ],
);

/// A short audio payload as callers would supply it.
MediaPart audioPart({String contentType = 'audio/mpeg'}) => MediaPart(
  media: Media(
    contentType: contentType,
    url: 'data:$contentType;base64,${base64Encode([1, 2, 3, 4])}',
  ),
);

void main() {
  group('transcription model classification', () {
    test('recognizes speech-to-text models', () {
      expect(isTranscriptionModel('whisper-1'), isTrue);
      expect(isTranscriptionModel('gpt-4o-transcribe'), isTrue);
      expect(isTranscriptionModel('gpt-4o-mini-transcribe'), isTrue);
    });

    test('leaves other audio models alone', () {
      // All of these are also getModelType() == 'audio'.
      expect(isTranscriptionModel('tts-1'), isFalse);
      expect(isTranscriptionModel('gpt-4o-mini-tts'), isFalse);
      expect(isTranscriptionModel('gpt-4o-realtime-preview'), isFalse);
      expect(isTranscriptionModel('gpt-4o-audio-preview'), isFalse);
      expect(isTranscriptionModel('gpt-4o'), isFalse);
    });

    test('only whisper can translate', () {
      expect(supportsTranslation('whisper-1'), isTrue);
      expect(supportsTranslation('gpt-4o-transcribe'), isFalse);
    });

    test('declaresMediaInput reads the supports map', () {
      expect(declaresMediaInput(ModelInfo(supports: {'media': true})), isTrue);
      expect(
        declaresMediaInput(ModelInfo(supports: {'media': false})),
        isFalse,
      );
      expect(declaresMediaInput(ModelInfo()), isFalse);
      expect(declaresMediaInput(null), isFalse);
    });

    test('advertises media input and text output', () {
      final supports = transcriptionModelInfo('whisper-1').supports!;
      expect(supports['media'], isTrue);
      expect(supports['output'], ['text', 'json']);
      expect(supports['multiturn'], isFalse);
    });

    test('maps audio mime types to usable filenames', () {
      // OpenAI reads the codec off this filename, so a generic
      // type/subtype split would break x-m4a.
      expect(audioFilenameFor('audio/mpeg'), 'input.mp3');
      expect(audioFilenameFor('audio/wav'), 'input.wav');
      expect(audioFilenameFor('audio/x-m4a'), 'input.m4a');
      expect(audioFilenameFor('audio/webm'), 'input.webm');
      expect(audioFilenameFor('audio/flac'), 'input.flac');
      expect(audioFilenameFor('audio/unknown'), 'input');
    });
  });

  group('transcription wire-level request assembly', () {
    test('uploads the audio with model and response_format', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
      );

      expect(captured, hasLength(1));
      final upload = captured.single;
      expect(upload.path, endsWith('/audio/transcriptions'));
      expect(upload.fields['model'], 'whisper-1');
      expect(upload.fields['response_format'], 'json');
      expect(upload.filename, 'input.mp3');
      expect(upload.fileBytes, [1, 2, 3, 4]);
      // Nothing the caller did not ask for.
      expect(upload.fields.containsKey('language'), isFalse);
      expect(upload.fields.containsKey('temperature'), isFalse);
      expect(upload.fields.containsKey('prompt'), isFalse);

      await ai.shutdown();
    });

    test('forwards language, temperature and chunking strategy', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('gpt-4o-transcribe'),
        promptParts: [audioPart()],
        config: OpenAITranscriptionOptions(
          language: 'es',
          temperature: 0.2,
          chunkingStrategy: 'auto',
          include: ['logprobs'],
        ),
      );

      final upload = captured.single;
      expect(upload.fields['language'], 'es');
      expect(upload.fields['temperature'], '0.2');
      expect(upload.fields['chunking_strategy'], 'auto');
      expect(upload.fields['include[]'], 'logprobs');

      await ai.shutdown();
    });

    test('encodes an object chunking strategy as JSON', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('gpt-4o-transcribe'),
        promptParts: [audioPart()],
        config: OpenAITranscriptionOptions(
          chunkingStrategy: {'type': 'server_vad', 'threshold': 0.5},
        ),
      );

      expect(jsonDecode(captured.single.fields['chunking_strategy']!), {
        'type': 'server_vad',
        'threshold': 0.5,
      });

      await ai.shutdown();
    });

    test('sends repeated timestamp granularity fields', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
        config: OpenAITranscriptionOptions(
          responseFormat: 'verbose_json',
          timestampGranularities: ['word', 'segment'],
        ),
      );

      final upload = captured.single;
      expect(upload.repeated['timestamp_granularities[]'], ['word', 'segment']);

      await ai.shutdown();
    });

    test('sends multiple include values as repeated fields', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('gpt-4o-transcribe'),
        promptParts: [audioPart()],
        config: OpenAITranscriptionOptions(include: ['logprobs', 'usage']),
      );

      expect(captured.single.repeated['include[]'], ['logprobs', 'usage']);

      await ai.shutdown();
    });

    test('uses the message text as the decoding prompt', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [
          TextPart(text: 'Genkit, Dart, Firebase'),
          audioPart(),
        ],
      );

      expect(captured.single.fields['prompt'], 'Genkit, Dart, Firebase');

      await ai.shutdown();
    });

    test('an explicit prompt option wins over the message text', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [
          TextPart(text: 'ignored'),
          audioPart(),
        ],
        config: OpenAITranscriptionOptions(prompt: 'Genkit'),
      );

      expect(captured.single.fields['prompt'], 'Genkit');

      await ai.shutdown();
    });

    test('version overrides the model id', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
        config: OpenAITranscriptionOptions(version: 'whisper-2'),
      );

      expect(captured.single.fields['model'], 'whisper-2');

      await ai.shutdown();
    });
  });

  group('translation', () {
    test('translate routes whisper to the translations endpoint', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
        config: OpenAITranscriptionOptions(translate: true, language: 'es'),
      );

      final upload = captured.single;
      expect(upload.path, endsWith('/audio/translations'));
      expect(
        upload.fields.containsKey('language'),
        isFalse,
        reason: 'the translations endpoint rejects language',
      );

      await ai.shutdown();
    });

    test(
      'translate is ignored by models without a translations endpoint',
      () async {
        final captured = <CapturedUpload>[];
        final ai = transcriptionGenkit(captured);

        await ai.generate(
          model: openAI.transcriptionModel('gpt-4o-transcribe'),
          promptParts: [audioPart()],
          config: OpenAITranscriptionOptions(translate: true),
        );

        expect(captured.single.path, endsWith('/audio/transcriptions'));

        await ai.shutdown();
      },
    );
  });

  group('transcription request headers', () {
    test('authorization and custom headers reach the upload', () async {
      // Chat and TTS get header handling from the SDK; the multipart upload
      // is built by hand, so it needs its own coverage.
      final captured = <CapturedUpload>[];
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            headers: {'X-Custom-Header': 'value', 'X-Trace': 'abc'},
            httpClient: transcriptionWireClient(captured),
          ),
        ],
      );

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
      );

      final headers = captured.single.headers;
      expect(headers['authorization'], 'Bearer test-key');
      expect(headers['x-custom-header'], 'value');
      expect(headers['x-trace'], 'abc');

      await ai.shutdown();
    });

    test('an async apiKeyProvider is honored', () async {
      final captured = <CapturedUpload>[];
      final ai = Genkit(
        plugins: [
          openAI(
            apiKeyProvider: () async => 'provided-key',
            httpClient: transcriptionWireClient(captured),
          ),
        ],
      );

      await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
      );

      expect(captured.single.headers['authorization'], 'Bearer provided-key');

      await ai.shutdown();
    });

    test('a missing API key uploads nothing', () async {
      // The key is checked during plugin init, so this fails before the
      // transcription path runs. What matters here is that no audio leaves
      // the process.
      final captured = <CapturedUpload>[];
      final ai = Genkit(
        plugins: [openAI(httpClient: transcriptionWireClient(captured))],
      );

      await expectLater(
        ai.generate(
          model: openAI.transcriptionModel('whisper-1'),
          promptParts: [audioPart()],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.toString(),
            'message',
            contains('API key is required'),
          ),
        ),
      );
      expect(captured, isEmpty);

      await ai.shutdown();
    });
  });

  group('transcription response conversion', () {
    test('unwraps a json transcript', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      final response = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
      );

      expect(response.text, 'The quick brown fox.');
      expect(response.finishReason, FinishReason.stop);

      await ai.shutdown();
    });

    test('passes srt markup through verbatim', () async {
      // This is the case the SDK path could not serve at all: its create()
      // always JSON-decodes the body.
      const srt = '1\n00:00:00,000 --> 00:00:02,000\nThe quick brown fox.\n';
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured, body: srt);

      final response = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [audioPart()],
        config: OpenAITranscriptionOptions(responseFormat: 'srt'),
      );

      expect(captured.single.fields['response_format'], 'srt');
      expect(response.text, srt);

      await ai.shutdown();
    });

    test('surfaces API errors with a mapped status', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(
        captured,
        body: '{"error":{"message":"bad audio"}}',
        status: 400,
      );

      await expectLater(
        ai.generate(
          model: openAI.transcriptionModel('whisper-1'),
          promptParts: [audioPart()],
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );

      await ai.shutdown();
    });
  });

  group('transcription input validation', () {
    test('rejects a request with no audio', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await expectLater(
        ai.generate(
          model: openAI.transcriptionModel('whisper-1'),
          prompt: 'no audio here',
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
      expect(captured, isEmpty);

      await ai.shutdown();
    });

    test('rejects a non-data audio URL', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await expectLater(
        ai.generate(
          model: openAI.transcriptionModel('whisper-1'),
          promptParts: [
            MediaPart(
              media: Media(
                contentType: 'audio/mpeg',
                url: 'https://example.com/audio.mp3',
              ),
            ),
          ],
        ),
        throwsA(isA<GenkitException>()),
      );
      expect(captured, isEmpty);

      await ai.shutdown();
    });

    test('rejects a response format that cannot satisfy json output', () async {
      final captured = <CapturedUpload>[];
      final ai = transcriptionGenkit(captured);

      await expectLater(
        ai.generate(
          model: openAI.transcriptionModel('whisper-1'),
          promptParts: [audioPart()],
          config: OpenAITranscriptionOptions(responseFormat: 'srt'),
          outputFormat: 'json',
        ),
        throwsA(isA<GenkitException>()),
      );
      expect(captured, isEmpty);

      await ai.shutdown();
    });
  });

  group('transcription model registration', () {
    test('known transcription models are registered', () async {
      final ai = transcriptionGenkit([]);

      final actions = await ai.registry.listActions();
      final names = actions
          .where((a) => a.actionType == .model)
          .map((a) => a.name)
          .toSet();

      expect(
        names,
        containsAll([
          'openai/whisper-1',
          'openai/gpt-4o-transcribe',
          'openai/gpt-4o-mini-transcribe',
        ]),
      );

      await ai.shutdown();
    });

    test('registered models carry media-input metadata', () async {
      final ai = transcriptionGenkit([]);

      final action = await ai.registry.lookupAction(.model, 'openai/whisper-1');
      final info = (action!.metadata['model'] as Map).cast<String, dynamic>();
      final supports = (info['supports'] as Map).cast<String, dynamic>();
      expect(supports['media'], isTrue);
      expect(supports['output'], ['text', 'json']);

      await ai.shutdown();
    });

    test(
      'a custom model declaring media input is routed to transcription',
      () async {
        final captured = <CapturedUpload>[];
        final ai = Genkit(
          plugins: [
            openAI(
              name: 'earcorp',
              apiKey: 'test-key',
              baseUrl: 'https://api.earcorp.test/v1',
              httpClient: transcriptionWireClient(captured),
              models: [
                CustomModelDefinition(
                  name: 'earbox-1',
                  info: ModelInfo(supports: {'media': true}),
                ),
              ],
            ),
          ],
        );

        final response = await ai.generate(
          model: openAI.transcriptionModel('earbox-1', namespace: 'earcorp'),
          promptParts: [audioPart()],
        );

        expect(captured.single.path, endsWith('/audio/transcriptions'));
        expect(response.text, 'The quick brown fox.');

        await ai.shutdown();
      },
    );

    test('tts models still route to speech, not transcription', () async {
      final ai = transcriptionGenkit([]);

      final action = await ai.registry.lookupAction(.model, 'openai/tts-1');
      final info = (action!.metadata['model'] as Map).cast<String, dynamic>();
      final supports = (info['supports'] as Map).cast<String, dynamic>();
      expect(supports['output'], ['media']);
      expect(supports['media'], isFalse);

      await ai.shutdown();
    });
  });
}
