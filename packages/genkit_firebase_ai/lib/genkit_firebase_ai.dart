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

// pana analyzes with its own options, so the root analysis_options.yaml
// ignore for this does not apply on pub.dev.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:firebase_core/firebase_core.dart' as fcore;
// Live (bidi) model support builds on Genkit's experimental surface. Like
// `package:genkit/experimental.dart`, `BidiModel` is NOT covered by
// semantic-versioning stability guarantees and may change in any MINOR release.
import 'package:genkit/experimental.dart' show BidiModel;
import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:schemantic/schemantic.dart';

import 'src/aggregation.dart';
import 'src/converters.dart';
import 'src/error_mapping.dart';
import 'src/known_models.dart';
import 'src/live.dart';

part 'genkit_firebase_ai.g.dart';

final _logger = Logger('genkit_firebase_ai');

/// The capabilities of a Gemini text model.
///
/// Each model now advertises its own label, stage and capabilities in its
/// `metadata['model']`, and image, TTS and Live models differ from these.
@Deprecated(
  "Read a model's capabilities from its metadata['model'] instead. Image, "
  'TTS and Live models differ from these.',
)
final firebaseAiModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
);

// firebase_ai 5 deprecates these for Gemini 3.x, but they still work on
// older models and are portable Genkit options, so they stay through 1.0
// (#596).
const _ignoredByGemini3 =
    'Gemini 3 and newer models ignore this and manage sampling themselves.';
const _rejectedByGemini3 =
    'Gemini 3 and newer models may reject requests that set this with a 400 '
    'error.';
const _notForGemini3 =
    'Not supported on Gemini 3 and newer models. Make parallel requests '
    'instead.';
// Live sends its config in the WebSocket setup message, so a rejected field
// closes the socket rather than returning a 400.
const _liveNotForGemini3 = 'Gemini 3 and newer models may not support this.';

@Schema()
abstract class $GeminiOptions {
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  /// Gemini 3 and newer models ignore this and manage sampling themselves.
  @Field(description: _ignoredByGemini3)
  double? get temperature;

  /// Gemini 3 and newer models ignore this and manage sampling themselves.
  @Field(description: _ignoredByGemini3)
  double? get topP;

  /// Gemini 3 and newer models ignore this and manage sampling themselves.
  @Field(description: _ignoredByGemini3)
  int? get topK;

  /// Gemini 3 and newer models may reject requests that set this with a 400
  /// error.
  @Field(description: _rejectedByGemini3)
  double? get presencePenalty;

  /// Gemini 3 and newer models may reject requests that set this with a 400
  /// error.
  @Field(description: _rejectedByGemini3)
  double? get frequencyPenalty;
  List<String>? get responseModalities;
  String? get responseMimeType;
  @Field(
    description:
        'OpenAPI-subset schema the response must conform to. Ignored when '
        'responseJsonSchema is set or the request has a constrained JSON '
        'output schema.',
  )
  Map<String, dynamic>? get responseSchema;
  @Field(
    description:
        'JSON Schema the response must conform to, sent to Gemini unchanged. '
        'Requires responseMimeType "application/json". Takes precedence over '
        'responseSchema when both are set. Ignored when the request has a '
        'constrained JSON output schema, which is sent instead.',
  )
  Map<String, dynamic>? get responseJsonSchema;
  $ThinkingConfig? get thinkingConfig;

  /// Not supported on Gemini 3 and newer models. Make parallel requests
  /// instead.
  @Field(description: _notForGemini3)
  int? get candidateCount;
  bool? get codeExecution;
  $FunctionCallingConfig? get functionCallingConfig;
  @Field(
    description:
        'Per-category thresholds for blocking harmful content. Each entry '
        'needs a category and a threshold.',
  )
  List<$GeminiSafetySettings>? get safetySettings;
  @Field(description: 'Grounds responses in Google Search results.')
  $GeminiGoogleSearch? get googleSearch;
  @Field(description: 'Lets the model read the URLs given in the prompt.')
  $GeminiUrlContext? get urlContext;
  @Field(
    description:
        'Grounds responses in Google Maps data. Pass the user location in '
        'retrievalConfig.',
  )
  $GeminiGoogleMaps? get googleMaps;
  @Field(description: 'Location and language for Google Maps grounding.')
  $GeminiRetrievalConfig? get retrievalConfig;
  @Field(description: 'Voice and language for text-to-speech models.')
  $SpeechConfig? get speechConfig;
  @Field(description: 'Aspect ratio and size for image generation models.')
  $GeminiImageConfig? get imageConfig;
  @StringField(
    enumValues: [
      'MEDIA_RESOLUTION_LOW',
      'MEDIA_RESOLUTION_MEDIUM',
      'MEDIA_RESOLUTION_HIGH',
    ],
    description:
        'Resolution for media inputs. A media part can set its own in '
        'metadata.mediaResolution, which also takes '
        'MEDIA_RESOLUTION_ULTRA_HIGH.',
  )
  String? get mediaResolution;
}

@Schema()
abstract class $GeminiImageConfig {
  @StringField(
    enumValues: [
      '1:1',
      '9:16',
      '16:9',
      '3:4',
      '4:3',
      '2:3',
      '3:2',
      '4:5',
      '5:4',
      '1:4',
      '4:1',
      '1:8',
      '8:1',
      '21:9',
    ],
  )
  String? get aspectRatio;

  @StringField(enumValues: ['512', '1K', '2K', '4K'])
  String? get imageSize;
}

@Schema()
abstract class $GeminiGoogleSearch {}

@Schema()
abstract class $GeminiUrlContext {}

@Schema()
abstract class $GeminiGoogleMaps {}

@Schema()
abstract class $GeminiRetrievalConfig {
  $GeminiLatLng? get latLng;
  String? get languageCode;
}

@Schema()
abstract class $GeminiLatLng {
  double? get latitude;
  double? get longitude;
}

@Schema()
abstract class $GeminiSafetySettings {
  @StringField(
    description:
        'The HARM_CATEGORY_IMAGE_* categories are Agent Platform only; the '
        'Gemini Developer API rejects them.',
    enumValues: [
      'HARM_CATEGORY_HARASSMENT',
      'HARM_CATEGORY_HATE_SPEECH',
      'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'HARM_CATEGORY_DANGEROUS_CONTENT',
      'HARM_CATEGORY_IMAGE_HATE',
      'HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT',
      'HARM_CATEGORY_IMAGE_HARASSMENT',
      'HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT',
    ],
  )
  String? get category;

  @StringField(
    enumValues: [
      'BLOCK_LOW_AND_ABOVE',
      'BLOCK_MEDIUM_AND_ABOVE',
      'BLOCK_ONLY_HIGH',
      'BLOCK_NONE',
      'OFF',
    ],
  )
  String? get threshold;

  @StringField(
    enumValues: ['SEVERITY', 'PROBABILITY'],
    description:
        'Whether the threshold applies to the probability or the severity '
        'score. Agent Platform only; the Gemini Developer API rejects it.',
  )
  String? get method;
}

@Schema()
abstract class $FunctionCallingConfig {
  @StringField(enumValues: ['MODE_UNSPECIFIED', 'AUTO', 'ANY', 'NONE'])
  String? get mode;
  List<String>? get allowedFunctionNames;
}

@Schema()
abstract class $ThinkingConfig {
  int? get thinkingBudget;
  bool? get includeThoughts;

  @StringField(
    enumValues: ['MINIMAL', 'LOW', 'MEDIUM', 'HIGH'],
    description:
        'Thinking level for Gemini 3 and newer models, which use it in place '
        'of thinkingBudget. Cannot be set together with thinkingBudget.',
  )
  String? get thinkingLevel;
}

@Schema()
abstract class $PrebuiltVoiceConfig {
  String? get voiceName;
}

@Schema()
abstract class $VoiceConfig {
  $PrebuiltVoiceConfig? get prebuiltVoiceConfig;
}

@Schema()
abstract class $SpeechConfig {
  $VoiceConfig? get voiceConfig;
  @Field(
    description:
        'Voices for a multi-speaker conversation, with exactly two '
        'speakers. Cannot be set together with voiceConfig.',
  )
  $MultiSpeakerVoiceConfig? get multiSpeakerVoiceConfig;
  @Field(description: 'BCP-47 language code, for example en-US.')
  String? get languageCode;
}

@Schema()
abstract class $MultiSpeakerVoiceConfig {
  List<$SpeakerVoiceConfig>? get speakerVoiceConfigs;
}

@Schema()
abstract class $SpeakerVoiceConfig {
  @Field(description: 'The speaker name used in the prompt.')
  String? get speaker;
  $VoiceConfig? get voiceConfig;
}

@Schema()
abstract class $LiveGenerationConfig {
  List<String>? get responseModalities;
  $SpeechConfig? get speechConfig;
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  /// Gemini 3 and newer models ignore this and manage sampling themselves.
  @Field(description: _ignoredByGemini3)
  double? get temperature;

  /// Gemini 3 and newer models ignore this and manage sampling themselves.
  @Field(description: _ignoredByGemini3)
  double? get topP;

  /// Gemini 3 and newer models ignore this and manage sampling themselves.
  @Field(description: _ignoredByGemini3)
  int? get topK;

  /// Gemini 3 and newer models may not support this.
  @Field(description: _liveNotForGemini3)
  double? get presencePenalty;

  /// Gemini 3 and newer models may not support this.
  @Field(description: _liveNotForGemini3)
  double? get frequencyPenalty;
}

/// The Gemini API backend that the Firebase AI plugin calls.
sealed class FirebaseAiProvider {
  const FirebaseAiProvider();

  /// The Gemini Developer API.
  const factory FirebaseAiProvider.googleAI() = _GoogleAIProvider;

  /// The Agent Platform Gemini API in [location].
  ///
  /// When [location] is omitted the Firebase AI SDK default, `global`, is used.
  /// Preview models are only available on `global`. Agent Platform Live models
  /// such as `gemini-live-2.5-flash-native-audio` are not available on
  /// `global`, so apps that use them, or that need data residency, must pass a
  /// regional location such as `'us-central1'`.
  const factory FirebaseAiProvider.agentPlatform({String? location}) =
      _AgentPlatformProvider;
}

class _GoogleAIProvider extends FirebaseAiProvider {
  const _GoogleAIProvider();
}

class _AgentPlatformProvider extends FirebaseAiProvider {
  final String? location;

  const _AgentPlatformProvider({this.location});
}

const FirebaseGenAiPluginHandle firebaseAI = FirebaseGenAiPluginHandle();

class FirebaseGenAiPluginHandle {
  const FirebaseGenAiPluginHandle();

  /// Creates the Firebase AI plugin.
  ///
  /// [httpClient] is used for every `generateContent` and
  /// `streamGenerateContent` request. Useful for proxies, instrumentation, or a
  /// mock transport in tests.
  /// Live (bidi) models connect over a WebSocket and do not use it. The caller
  /// owns it: the plugin never closes a client it was given, so close it
  /// yourself once you are done with the plugin. When omitted, the plugin
  /// creates one client on first use and shares it across requests.
  GenkitPlugin call({
    fcore.FirebaseApp? app,
    bool? useLimitedUseAppCheckTokens,
    FirebaseAiProvider provider = const FirebaseAiProvider.googleAI(),
    http.Client? httpClient,
  }) {
    return _FirebaseGenAiPlugin(
      app: app,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens,
      provider: provider,
      httpClient: httpClient,
    );
  }

  /// Ref to a model in the Firebase AI plugin.
  ///
  /// The [name] is the model name, e.g. 'gemini-flash-latest'.
  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('firebaseai/$name', customOptions: GeminiOptions.$schema);
  }
}

class _FirebaseGenAiPlugin extends GenkitPlugin {
  final fcore.FirebaseApp? app;
  final bool? useLimitedUseAppCheckTokens;
  final FirebaseAiProvider provider;
  final http.Client? httpClient;

  // firebase_ai 4.x builds an http.Client per GenerativeModel and never closes
  // it, and the plugin builds a model per request, so one client is shared to
  // keep connections reused. It is never closed: plugins have no dispose hook,
  // and Flutter apps can exit with an open connection pool.
  late final http.Client _httpClient = httpClient ?? http.Client();

  @override
  String get name => 'firebaseai';

  _FirebaseGenAiPlugin({
    this.app,
    this.useLimitedUseAppCheckTokens,
    this.provider = const FirebaseAiProvider.googleAI(),
    this.httpClient,
  });

  fai.FirebaseAI get _firebaseAI {
    return switch (provider) {
      _AgentPlatformProvider(:final location) => fai.FirebaseAI.agentPlatform(
        app: app,
        location: location,
        useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens,
      ),
      _GoogleAIProvider() => fai.FirebaseAI.googleAI(
        app: app,
        useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens,
      ),
    };
  }

  @override
  Future<List<Action>> init() async {
    // Pre-registered so they show up in the Developer UI; any other model name
    // still resolves on demand (see [resolve]).
    final agentPlatform = provider is _AgentPlatformProvider;
    return [
      for (final model in KnownFirebaseAiModel.values)
        if (model.servedOn(agentPlatform: agentPlatform))
          model.live ? _createBidiModel(model.id) : _createModel(model.id),
    ];
  }

  @override
  Action? resolve(ActionType actionType, String name) {
    if (actionType == .model) return _createModel(name);
    if (actionType == .bidiModel) return _createBidiModel(name);
    return null;
  }

  Model _createModel(String modelName) {
    return Model(
      name: 'firebaseai/$modelName',
      metadata: {'model': modelInfoFor(modelName).toJson()},
      customOptions: GeminiOptions.$schema,
      fn: (req, ctx) async {
        final isJsonMode =
            req.output?.format == 'json' ||
            req.output?.contentType == 'application/json';

        // The JSON round trip types nested maps written as Dart literals (e.g.
        // an empty `{}`) the way the generated getters expect.
        final options = req.config == null
            ? GeminiOptions()
            : readConfig(
                () => GeminiOptions.$schema.parse(
                  jsonDecode(jsonEncode(req.config)),
                ),
              );

        final nonSystem = req.messages
            .where((m) => m.role != Role.system)
            .toList();
        // Gemini rejects empty `contents`, so a system-only request keeps its
        // text as the user turn, as it did before systemInstruction was sent.
        final systemOnly = nonSystem.isEmpty;
        final contents = toGeminiContent(systemOnly ? req.messages : nonSystem);

        // Per request, because `IOClient` keeps its listeners on the trigger
        // until it completes, and a reused token's `whenCancelled` may never.
        final abort = Completer<void>();
        final disposeCancel = ctx.cancel?.onCancel(abort.complete);
        try {
          ctx.cancel?.throwIfCancelled();
          final transport = _StatusRecordingClient(
            _httpClient,
            abortTrigger: ctx.cancel == null ? null : abort.future,
          );
          final model = _firebaseAI.generativeModel(
            model: modelName,
            safetySettings: toGeminiSafetySettings(
              options,
              developerApi: provider is _GoogleAIProvider,
            ),
            generationConfig: toGeminiSettings(
              options,
              req.output?.schema,
              isJsonMode,
              constrained: req.output?.constrained ?? false,
            ),
            tools: readConfig(
              () => toGeminiTools(
                req.tools,
                codeExecution: options.codeExecution,
                googleSearch: options.googleSearch != null,
                urlContext: options.urlContext != null,
                googleMaps: options.googleMaps != null,
              ),
            ),
            toolConfig: readConfig(
              () => toGeminiToolConfig(
                options.functionCallingConfig,
                toolChoice: req.toolChoice,
                hasFunctionTools: req.tools?.isNotEmpty ?? false,
                retrievalConfig: options.retrievalConfig,
              ),
            ),
            systemInstruction: systemOnly
                ? null
                : toGeminiSystemInstruction(req.messages),
            httpClient: transport,
          );
          GenkitException mapError(Object e, StackTrace stack) {
            // An aborted request surfaces as a transport error; report the
            // cancellation instead.
            if ((e, ctx.cancel) case (
              http.RequestAbortedException(),
              final cancel?,
            )) {
              return CancelledException(reason: cancel.reason, token: cancel);
            }
            return toGenkitException(
              e,
              stack,
              httpStatus: transport.lastStatusCode,
              errorStatus: transport.lastError?.status,
              errorMessage: transport.lastError?.message,
            );
          }

          if (ctx.streamingRequested) {
            if ((options.candidateCount ?? 1) > 1) {
              // firebase_ai drops each candidate's `index`, so streamed chunks
              // could not be told apart and would be merged (#656).
              throw GenkitException(
                'Streaming with candidateCount > 1 is not supported. A '
                'non-streaming request returns only the first candidate in '
                'text and message; the rest are in raw.',
                status: StatusCode.invalidArgument,
              );
            }
            final stream = model
                .generateContentStream(contents)
                .handleError((Object e, StackTrace s) => throw mapError(e, s));
            final chunks = <fai.GenerateContentResponse>[];
            await for (final chunk in stream) {
              ctx.cancel?.throwIfCancelled();
              chunks.add(chunk);
              if (chunk.candidates.isNotEmpty) {
                final (message, finishReason) = fromGeminiCandidate(
                  chunk.candidates.first,
                );
                ctx.sendChunk(
                  ModelResponseChunk(index: 0, content: message.content),
                );
              }
            }
            ctx.cancel?.throwIfCancelled();
            final aggregated = aggregateResponses(chunks);
            if (aggregated.candidates.isEmpty) {
              throw noCandidatesException(aggregated.promptFeedback);
            }
            final (message, finishReason) = fromGeminiCandidate(
              aggregated.candidates.first,
            );
            return ModelResponse(
              finishReason: finishReason,
              finishMessage: aggregated.candidates.first.finishMessage,
              custom: candidateCustom(aggregated.candidates.first),
              message: message,
              raw: rawResponse(aggregated),
              usage: extractUsage(aggregated.usageMetadata),
            );
          } else {
            final fai.GenerateContentResponse response;
            try {
              response = await model.generateContent(contents);
            } catch (e, stack) {
              throw mapError(e, stack);
            }
            ctx.cancel?.throwIfCancelled();

            if (response.candidates.isEmpty) {
              throw noCandidatesException(response.promptFeedback);
            }

            final (message, finishReason) = fromGeminiCandidate(
              response.candidates.first,
            );

            return ModelResponse(
              finishReason: finishReason,
              finishMessage: response.candidates.first.finishMessage,
              custom: candidateCustom(response.candidates.first),
              message: message,
              raw: rawResponse(response),
              usage: extractUsage(response.usageMetadata),
            );
          }
        } finally {
          disposeCancel?.call();
        }
      },
    );
  }

  BidiModel _createBidiModel(String modelName) {
    return BidiModel(
      name: 'firebaseai/$modelName',
      metadata: {'model': modelInfoFor(modelName, live: true).toJson()},
      customOptions: LiveGenerationConfig.$schema,
      fn: (stream, ctx) async {
        final tools = toGeminiTools(ctx.init?.tools);
        final systemInstruction = toGeminiSystemInstruction(
          ctx.init?.messages ?? const [],
        );

        final liveConfig = toLiveGenerationConfig(ctx.init?.config);

        final model = _firebaseAI.liveGenerativeModel(
          model: modelName,
          liveGenerationConfig: liveConfig,
          tools: tools,
          systemInstruction: systemInstruction,
        );

        _logger.info(
          'Connecting to model: $modelName with config: $liveConfig',
        );
        if (liveConfig.responseModalities != null) {
          _logger.info(
            'Modalities: ${liveConfig.responseModalities!.map((e) => e.name).toList()}',
          );
        }
        final fai.LiveSession session;
        try {
          session = await model.connect();
        } catch (e, stack) {
          throw toGenkitException(e, stack);
        }
        _logger.info('Connected to model: $modelName');

        await runLiveSession(
          session,
          history:
              ctx.init?.messages.where((m) => m.role != Role.system) ??
              const [],
          input: stream,
          onChunk: ctx.sendChunk,
          cancel: ctx.cancel,
        );

        return ModelResponse(finishReason: FinishReason.stop);
      },
    );
  }
}

/// Records the HTTP status and the error body's gRPC status of the last
/// response, which `firebase_ai` drops from the exceptions it throws.
///
/// When [abortTrigger] completes, the in-flight request is aborted. That needs
/// a client that honours [http.Abortable], as `IOClient` and `BrowserClient`
/// do; with any other client, cancellation lands at the next checkpoint.
class _StatusRecordingClient extends http.BaseClient {
  _StatusRecordingClient(this._inner, {this.abortTrigger});

  final http.Client _inner;

  final Future<void>? abortTrigger;

  /// [request] as an [http.AbortableRequest] tied to [abortTrigger].
  /// `firebase_ai` sends plain [http.Request]s.
  http.BaseRequest _abortable(http.BaseRequest request) {
    if ((abortTrigger, request) case (
      final trigger?,
      final http.Request plain,
    ) when plain is! http.Abortable) {
      return http.AbortableRequest(
          plain.method,
          plain.url,
          abortTrigger: trigger,
        )
        ..headers.addAll(plain.headers)
        ..bodyBytes = plain.bodyBytes
        ..followRedirects = plain.followRedirects
        ..maxRedirects = plain.maxRedirects
        ..persistentConnection = plain.persistentConnection;
    }
    return request;
  }

  int? lastStatusCode;

  /// The `error` of a non-200 body or of an error chunk in an SSE stream.
  ({String? status, String? message})? lastError;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(_abortable(request));
    lastStatusCode = response.statusCode;
    lastError = null;
    if (response.statusCode != 200) {
      final body = await response.stream.toBytes();
      lastError = _errorOf(utf8.decode(body, allowMalformed: true));
      return _withBody(response, Stream.value(body), body.length);
    }
    if (request.url.queryParameters['alt'] != 'sse') return response;

    final lines = const LineSplitter().startChunkedConversion(
      _CallbackSink((line) {
        if (lastError == null &&
            line.startsWith('data: ') &&
            line.contains('"error"')) {
          lastError = _errorOf(line.substring('data: '.length));
        }
      }),
    );
    final sniffer = const Utf8Decoder(
      allowMalformed: true,
    ).startChunkedConversion(lines);
    // The sniffer sees each chunk before firebase_ai does, so the status is
    // recorded by the time firebase_ai throws on the error chunk.
    final stream = response.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (bytes, sink) {
          sniffer.add(bytes);
          sink.add(bytes);
        },
        handleDone: (sink) {
          sniffer.close();
          sink.close();
        },
      ),
    );
    return _withBody(response, stream, response.contentLength);
  }
}

http.StreamedResponse _withBody(
  http.StreamedResponse response,
  Stream<List<int>> body,
  int? contentLength,
) => http.StreamedResponse(
  body,
  response.statusCode,
  contentLength: contentLength,
  request: response.request,
  headers: response.headers,
  isRedirect: response.isRedirect,
  persistentConnection: response.persistentConnection,
  reasonPhrase: response.reasonPhrase,
);

class _CallbackSink implements Sink<String> {
  _CallbackSink(this._onData);

  final void Function(String) _onData;

  @override
  void add(String data) => _onData(data);

  @override
  void close() {}
}

({String? status, String? message})? _errorOf(String json) {
  try {
    if (jsonDecode(json) case {'error': final Map<String, dynamic> error}) {
      return (
        status: error['status'] as String?,
        message: error['message'] as String?,
      );
    }
  } on FormatException {
    return null;
  }
  return null;
}
