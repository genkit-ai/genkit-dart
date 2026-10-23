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

// ignore_for_file: invalid_use_of_visible_for_testing_member

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
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'src/aggregation.dart';
import 'src/finish_reason.dart';

part 'genkit_firebase_ai.g.dart';

final _logger = Logger('genkit_firebase_ai');

/// Capabilities every model this plugin serves has.
///
/// The plugin serves Gemini through the Firebase AI SDK and resolves any model
/// name on demand, so there is no per-model catalog to key this off; these are
/// the Gemini family's capabilities, matching `genkit_google_genai`'s
/// `commonModelInfo`.
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

@Schema()
abstract class $GeminiOptions {
  List<String>? get stopSequences;
  int? get maxOutputTokens;
  double? get temperature;
  double? get topP;
  int? get topK;
  double? get presencePenalty;
  double? get frequencyPenalty;
  List<String>? get responseModalities;
  String? get responseMimeType;
  Map<String, dynamic>? get responseSchema;
  Map<String, dynamic>? get responseJsonSchema;
  $ThinkingConfig? get thinkingConfig;
  int? get candidateCount;
  bool? get codeExecution;
  $FunctionCallingConfig? get functionCallingConfig;
  bool? get responseLogprobs;
  int? get logprobs;
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
}

@Schema()
abstract class $LiveGenerationConfig {
  List<String>? get responseModalities;
  $SpeechConfig? get speechConfig;
  List<String>? get stopSequences;
  int? get maxOutputTokens;
  double? get temperature;
  double? get topP;
  int? get topK;
  double? get presencePenalty;
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
    // still resolves on demand (see [resolve]). The live (bidi) entry is the
    // native-audio model line, which has its own naming.
    return [
      _createModel('gemini-flash-latest'),
      _createModel('gemini-3.1-pro-preview'),
      _createBidiModel('gemini-2.5-flash-native-audio-preview-12-2025'),
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
      metadata: {'model': firebaseAiModelInfo.toJson()},
      fn: (req, ctx) async {
        final isJsonMode =
            req.output?.format == 'json' ||
            req.output?.contentType == 'application/json';

        final options = req.config == null
            ? GeminiOptions()
            : GeminiOptions.$schema.parse(req.config!);

        final model = _firebaseAI.generativeModel(
          model: modelName,
          generationConfig: toGeminiSettings(
            options,
            req.output?.schema,
            isJsonMode,
            constrained: req.output?.constrained ?? false,
          ),
          tools: toGeminiTools(req.tools, codeExecution: options.codeExecution),
          toolConfig: toGeminiToolConfig(
            options.functionCallingConfig,
            toolChoice: req.toolChoice,
            hasFunctionTools: req.tools?.isNotEmpty ?? false,
          ),
          httpClient: _httpClient,
        );

        if (ctx.streamingRequested) {
          final stream = model.generateContentStream(
            toGeminiContent(req.messages),
          );
          final chunks = <fai.GenerateContentResponse>[];
          await for (final chunk in stream) {
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
          final aggregated = aggregateResponses(chunks);
          final (message, finishReason) = fromGeminiCandidate(
            aggregated.candidates.first,
          );
          return ModelResponse(
            finishReason: finishReason,
            finishMessage: aggregated.candidates.first.finishMessage,
            custom: _finishCustom(aggregated.candidates.first),
            message: message,
            raw: {
              'candidates': aggregated.candidates
                  .map(
                    (c) => {
                      'content': c.content.parts.length,
                      'finishReason': c.finishReason?.name,
                    },
                  )
                  .toList(),
            },
            usage: extractUsage(aggregated.usageMetadata),
          );
        } else {
          final response = await model.generateContent(
            toGeminiContent(req.messages),
          );

          if (response.candidates.isEmpty) {
            // TODO: Consider inspecting response.promptFeedback for the block reason.
            throw GenkitException('Model returned no candidates.');
          }

          final (message, finishReason) = fromGeminiCandidate(
            response.candidates.first,
          );

          final raw = <String, dynamic>{
            // Recreate structure
            'candidates': response.candidates
                .map(
                  (c) => {
                    'content': c
                        .content
                        .parts
                        .length, // content.toJson() might not exist or be simple
                    'finishReason': c.finishReason?.name,
                  },
                )
                .toList(),
          };

          return ModelResponse(
            finishReason: finishReason,
            finishMessage: response.candidates.first.finishMessage,
            custom: _finishCustom(response.candidates.first),
            message: message,
            raw: raw,
            usage: extractUsage(response.usageMetadata),
          );
        }
      },
    );
  }

  BidiModel _createBidiModel(String modelName) {
    return BidiModel(
      name: 'firebaseai/$modelName',
      customOptions: LiveGenerationConfig.$schema,
      fn: (stream, ctx) async {
        final tools = toGeminiTools(ctx.init?.tools);
        final systemMessage = ctx.init?.messages
            .where((m) => m.role == Role.system)
            .firstOrNull;
        final systemInstruction = systemMessage != null
            ? fai.Content(
                'system',
                systemMessage.content.map(toGeminiPart).toList(),
              )
            : null;

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
        var session = await model.connect();
        _logger.info('Connected to model: $modelName');

        // Send initial history
        final initialMessages =
            ctx.init?.messages.where((m) => m.role != Role.system).toList() ??
            [];
        for (final msg in initialMessages) {
          await sendToLiveSession(session, msg);
        }

        final sub = stream.listen(
          (chunk) async {
            for (final msg in chunk.messages) {
              await sendToLiveSession(session, msg);
            }
          },
          onError: (e) {
            _logger.severe('InputStream error', e);
          },
          onDone: () {
            _logger.info('InputStream done');
            session.close();
          },
        );

        final receiveFuture = () async {
          try {
            await for (final event in session.receive()) {
              _logger.fine('Session receive loop: $event');
              final chunk = _fromGeminiLiveEvent(event);
              if (chunk != null) ctx.sendChunk(chunk);
            }
            _logger.fine('Session receive loop finished naturally');
          } catch (e, s) {
            _logger.warning('Error in Live session receive loop', e, s);
          }
        }();

        await receiveFuture;
        await sub.cancel();
        _logger.fine('Closing session');
        session.close();
        // Session closed in receiveFuture usually, but ensure it here?
        // Actually session.close() is called on inputStream done.
        // If receive loop finishes, we might want to stop input stream?
        // Usually Bidi sessions end when input ends OR model ends.

        return ModelResponse(finishReason: FinishReason.stop);
      },
    );
  }
}

/// Builds the Firebase AI Live config from a request's `config`, read through
/// [LiveGenerationConfig] so missing fields fall back to the SDK defaults.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] when a field
/// has the wrong type or an unknown value.
@visibleForTesting
fai.LiveGenerationConfig toLiveGenerationConfig(Map<String, dynamic>? config) {
  try {
    return _toLiveGenerationConfig(config);
  } catch (e) {
    throw GenkitException(
      'Invalid Live model config: $e',
      status: StatusCode.invalidArgument,
    );
  }
}

fai.LiveGenerationConfig _toLiveGenerationConfig(Map<String, dynamic>? config) {
  // The JSON round trip types nested maps written as Dart literals (e.g. an
  // empty `{}`) the way the generated getters expect.
  final options = config == null
      ? LiveGenerationConfig()
      : LiveGenerationConfig.$schema.parse(jsonDecode(jsonEncode(config)));
  if (options.stopSequences?.isNotEmpty ?? false) {
    _logger.warning(
      'stopSequences is not supported by Firebase AI Live models and is '
      'ignored.',
    );
  }
  final speechConfig = options.speechConfig;
  return fai.LiveGenerationConfig(
    responseModalities: options.responseModalities
        ?.map((e) => fai.ResponseModalities.values.byName(e.toLowerCase()))
        .toList(),
    speechConfig: speechConfig == null
        ? null
        : fai.SpeechConfig(
            voiceName: speechConfig.voiceConfig?.prebuiltVoiceConfig?.voiceName,
          ),
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
  );
}

/// Sends [msg] to a Live [session].
///
/// Only a user's media can be realtime input: audio always goes out as
/// realtime audio, and images or video as realtime video frames when the
/// message has nothing else to say. That is how the Live API takes camera
/// input, so a message with only an image is a frame and does not start a turn
/// on its own; send text with it to ask about it. Media sent alongside text,
/// and media in model messages (history), go inside the turn instead. All tool responses go
/// out together, and the remaining parts as one complete client turn, so the
/// model does not answer before the whole message is in.
@visibleForTesting
Future<void> sendToLiveSession(fai.LiveSession session, Message msg) async {
  _logger.fine('Sending message: ${msg.role} parts: ${msg.content.length}');

  final parts = msg.content.map(toGeminiPart).toList();
  final toolResponses = parts.whereType<fai.FunctionResponse>().toList();
  final otherParts = parts.where((p) => p is! fai.FunctionResponse).toList();
  final isUser = msg.role == Role.user;
  final framesOnly = otherParts.every(_isRealtimeMedia);
  final turnParts = <fai.Part>[];

  try {
    for (final part in otherParts) {
      switch (part) {
        case fai.InlineDataPart(:final mimeType)
            when isUser && mimeType.startsWith('audio/'):
          await session.sendAudioRealtime(part);
        case fai.InlineDataPart() when isUser && framesOnly:
          await session.sendVideoRealtime(part);
        default:
          turnParts.add(part);
      }
    }
    if (toolResponses.isNotEmpty) {
      await session.sendToolResponse(toolResponses);
    }
    if (turnParts.isNotEmpty) {
      await session.send(
        input: fai.Content(toGeminiRole(msg.role), turnParts),
        turnComplete: true,
      );
    }
  } catch (e) {
    _logger.severe('Error sending ${msg.role} message to the Live session', e);
    rethrow;
  }
}

/// Whether [part] is audio, image or video data that can go out as realtime
/// input.
bool _isRealtimeMedia(fai.Part part) =>
    part is fai.InlineDataPart &&
    (part.mimeType.startsWith('audio/') ||
        part.mimeType.startsWith('image/') ||
        part.mimeType.startsWith('video/'));

/// Maps a Genkit [Role] to the role string expected by the Gemini API.
///
/// Gemini's Content API only understands `user` and `model` roles. Tool
/// (function response) messages must be sent with the `user` role for
/// compatibility.
@visibleForTesting
String toGeminiRole(Role role) {
  if (role == Role.model) return 'model';
  // user, tool and anything else map to 'user'.
  return 'user';
}

@visibleForTesting
Iterable<fai.Content> toGeminiContent(List<Message> messages) {
  return messages.map(
    (msg) => fai.Content(
      toGeminiRole(msg.role),
      msg.content.map(toGeminiPart).toList(),
    ),
  );
}

/// The full media type of a data URL, keeping parameters such as the
/// `rate` in `audio/pcm;rate=24000` that [UriData.mimeType] drops.
String _dataUriMimeType(UriData data) => [
  data.mimeType,
  for (final MapEntry(:key, :value) in data.parameters.entries) '$key=$value',
].join(';');

@visibleForTesting
fai.Part toGeminiPart(Part p) {
  final isThought = p.metadata?['isThought'] == true;
  final thoughtSignature = p.metadata?['thoughtSignature'] as String?;

  // firebase_ai does not officially expose thoughtSignature in its public constructors
  // yet. It only exposes them via `.forTest` constructors meant for internal testing.
  // We use them here but defensively fallback to standard constructors if they
  // are ever removed or changed.
  if (p.isReasoning) {
    try {
      return fai.TextPart.forTest(
        p.reasoning!,
        isThought: true,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.TextPart(p.reasoning!, isThought: true);
    }
  }
  if (p.isText) {
    try {
      return fai.TextPart.forTest(
        p.text!,
        isThought: isThought,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.TextPart(p.text!, isThought: isThought);
    }
  }
  if (p.isMedia) {
    final media = p.media!;
    if (media.url.startsWith('data:')) {
      final uri = Uri.parse(media.url);
      if (uri.data != null) {
        final mimeType = media.contentType ?? _dataUriMimeType(uri.data!);
        try {
          return fai.InlineDataPart.forTest(
            mimeType,
            uri.data!.contentAsBytes(),
            isThought: isThought,
            thoughtSignature: thoughtSignature,
          );
        } catch (_) {
          return fai.InlineDataPart(
            mimeType,
            uri.data!.contentAsBytes(),
            isThought: isThought,
          );
        }
      }
    }
    // Assume HTTP/S or other URLs are File URIs
    try {
      return fai.FileData.forTest(
        media.contentType ?? 'application/octet-stream',
        media.url,
        isThought: isThought,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.FileData(
        media.contentType ?? 'application/octet-stream',
        media.url,
        isThought: isThought,
      );
    }
  }
  if (p.isToolResponse) {
    final toolResponse = p.toolResponse!;
    // Firebase AI function responses carry a structured map only, so multipart
    // tool content (images, media, etc.) cannot be represented here. Warn so
    // authors of multipart tools can discover the parts are dropped for this
    // provider rather than failing silently.
    if (toolResponse.content?.isNotEmpty ?? false) {
      _logger.warning(
        'Tool "${toolResponse.name}" returned multipart content, but Firebase '
        'AI function responses only support structured output. Dropping '
        '${toolResponse.content!.length} content part(s); only the structured '
        'output is sent.',
      );
    }
    return fai.FunctionResponse(
      toolResponse.name,
      {'result': toolResponse.output},
      id: toolResponse.ref,
      isThought: isThought,
    );
  }
  if (p.isToolRequest) {
    final toolRequest = p.toolRequest!;
    try {
      return fai.FunctionCall.forTest(
        toolRequest.name,
        toolRequest.input is Map
            ? (toolRequest.input as Map).cast<String, Object?>()
            : <String, Object?>{},
        id: toolRequest.ref,
        isThought: isThought,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.FunctionCall(
        toolRequest.name,
        toolRequest.input is Map
            ? (toolRequest.input as Map).cast<String, Object?>()
            : <String, Object?>{},
        id: toolRequest.ref,
        isThought: isThought,
      );
    }
  }
  throw UnimplementedError('Part type $p not supported yet');
}

@visibleForTesting
(Message, FinishReason) fromGeminiCandidate(fai.Candidate candidate) {
  final message = Message(
    role: Role(candidate.content.role ?? 'model'),
    content: candidate.content.parts.map(fromGeminiPart).toList(),
  );
  return (message, finishReasonFromWire(candidate.finishReason?.toJson()));
}

/// The `custom` map for a response, holding the finish reason as `firebase_ai`
/// parsed it, or null when it parsed none or [fai.FinishReason.unknown], whose
/// original wire value is lost.
Map<String, dynamic>? _finishCustom(fai.Candidate candidate) {
  final reason = candidate.finishReason;
  if (reason == null || reason == fai.FinishReason.unknown) return null;
  return {'finishReason': reason.toJson()};
}

@visibleForTesting
Part fromGeminiPart(fai.Part p) {
  final pJson = p.toJson() as Map<String, dynamic>;
  final thoughtSignature = pJson['thoughtSignature'] as String?;

  final metadata = <String, dynamic>{
    if (p.isThought == true) 'isThought': true,
    'thoughtSignature': ?thoughtSignature,
  };

  if (p is fai.TextPart) {
    if (p.isThought == true) {
      return ReasoningPart(reasoning: p.text, metadata: metadata);
    }
    return TextPart(text: p.text, metadata: metadata);
  }
  if (p is fai.FunctionCall) {
    return ToolRequestPart(
      toolRequest: ToolRequest(name: p.name, input: p.args, ref: p.id),
      metadata: metadata,
    );
  }
  if (p is fai.InlineDataPart) {
    final base64 = base64Encode(p.bytes);
    return MediaPart(
      media: Media(
        url: 'data:${p.mimeType};base64,$base64',
        contentType: p.mimeType,
      ),
      metadata: metadata,
    );
  }
  throw UnimplementedError('Part type $p not supported yet in response');
}

ModelResponseChunk? _fromGeminiLiveEvent(fai.LiveServerResponse event) {
  final liveParts = event.message is fai.LiveServerContent
      ? (event.message as fai.LiveServerContent).modelTurn?.parts
      : event.message is fai.LiveServerToolCall
      ? (event.message as fai.LiveServerToolCall).functionCalls
            as List<fai.Part>
      : null;
  if (liveParts == null) return null;
  // We only care about content updates for now
  final parts = liveParts.map(fromGeminiPart).toList();

  return ModelResponseChunk(index: 0, content: parts);
}

@visibleForTesting
List<fai.Tool>? toGeminiTools(
  List<ToolDefinition>? tools, {
  bool? codeExecution,
}) {
  if ((tools == null || tools.isEmpty) && codeExecution != true) return null;

  return [
    if (tools != null) ...(tools.map(_toGeminiTool)),
    if (codeExecution == true) fai.Tool.codeExecution(),
  ];
}

fai.Tool _toGeminiTool(ToolDefinition tool) {
  final rawSchema = tool.inputSchema;

  final flattened = rawSchema?.flatten() ?? <String, dynamic>{};

  final propertiesMap = flattened['properties'] as Map<String, dynamic>? ?? {};
  final requiredList =
      (flattened['required'] as List<dynamic>?)?.cast<String>() ?? [];

  final parameters = propertiesMap.map((key, value) {
    return MapEntry(key, toGeminiSchema(value as Map<String, dynamic>));
  });

  final optionalParameters = propertiesMap.keys
      .where((k) => !requiredList.contains(k))
      .toList();

  return fai.Tool.functionDeclarations([
    fai.FunctionDeclaration(
      tool.name,
      tool.description,
      parameters: parameters,
      optionalParameters: optionalParameters,
    ),
  ]);
}

@visibleForTesting
fai.Schema toGeminiSchema(Map<String, dynamic> json) =>
    _toGeminiSchemaInternal(json.flatten());

fai.Schema _toGeminiSchemaInternal(Map<String, dynamic> json) {
  final type = json['type']; // dynamic
  final description = json['description'] as String?;
  final nullable = json['nullable'] as bool? ?? false;
  // TODO: Handle enum

  // Simple type handling
  String? typeStr;
  if (type is String) {
    typeStr = type;
  }

  switch (typeStr) {
    case 'string':
      return fai.Schema.string(description: description, nullable: nullable);
    case 'number':
      return fai.Schema.number(description: description, nullable: nullable);
    case 'integer':
      return fai.Schema.integer(description: description, nullable: nullable);
    case 'boolean':
      return fai.Schema.boolean(description: description, nullable: nullable);
    case 'array':
      return fai.Schema.array(
        description: description,
        nullable: nullable,
        items: json['items'] != null
            ? _toGeminiSchemaInternal(json['items'] as Map<String, dynamic>)
            : fai.Schema.string(),
      );
    case 'object':
      if (json.containsKey('properties')) {
        final properties = (json['properties'] as Map<String, dynamic>?)?.map(
          (k, v) =>
              MapEntry(k, _toGeminiSchemaInternal(v as Map<String, dynamic>)),
        );
        return fai.Schema.object(
          properties: properties ?? {},
          description: description,
          nullable: nullable,
        );
      } else {
        return fai.Schema(
          fai.SchemaType.object,
          description: description,
          nullable: nullable,
        );
      }
    default:
      return fai.Schema.string(description: description, nullable: nullable);
  }
}

/// Maps Genkit's request onto Firebase AI's generation config.
///
/// [outputSchema] only becomes a native `responseSchema` on a constrained JSON
/// request, matching `genkit_google_genai`. A caller asking for a schema
/// without constraint wants it enforced by nothing rather than by Gemini
/// specifically - core does not inject textual instructions for it either
/// (`jsonFormatter` sets `defaultInstructions: false`), so honouring that
/// choice here means the model sees no description of the shape at all,
/// native or textual, unless the caller supplied their own. Gemini only honours
/// `responseSchema` alongside an `application/json` response mime type, so
/// the JSON-mode half of the condition is the provider's rule, not a
/// preference.
/// `options.responseSchema` is unaffected — that is an explicit config the
/// caller wrote, not an output-format inference.
@visibleForTesting
fai.GenerationConfig toGeminiSettings(
  GeminiOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode, {
  bool constrained = false,
}) {
  return fai.GenerationConfig(
    candidateCount: options.candidateCount,
    stopSequences: options.stopSequences ?? [],
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType?.isEmpty ?? true
              ? null
              : options.responseMimeType),
    responseSchema: constrained && isJsonMode && outputSchema != null
        ? toGeminiSchema(outputSchema)
        : (options.responseSchema != null
              ? toGeminiSchema(options.responseSchema!)
              : null),
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseModalities: options.responseModalities
        ?.map((e) => fai.ResponseModalities.values.byName(e.toLowerCase()))
        .toList(),
    thinkingConfig: options.thinkingConfig == null
        ? null
        // ignore: deprecated_member_use
        : fai.ThinkingConfig(
            includeThoughts: options.thinkingConfig!.includeThoughts ?? false,
            thinkingBudget: options.thinkingConfig!.thinkingBudget,
          ),
  );
}

/// Builds the Firebase AI `toolConfig` from the plugin-specific
/// [functionCallingConfig] or, when that is absent, the portable Genkit
/// [toolChoice] (`auto` / `required` / `none`). The plugin config wins because
/// it can also restrict the allowed function names. Unknown [toolChoice]
/// values are ignored.
///
/// [toolChoice] only applies when [hasFunctionTools] is true, i.e. the request
/// declares Genkit tools. Code execution doesn't count: a function-calling
/// mode with no function declarations is contradictory (`required` would
/// demand a call to nothing).
@visibleForTesting
fai.ToolConfig? toGeminiToolConfig(
  FunctionCallingConfig? functionCallingConfig, {
  ToolChoice? toolChoice,
  bool hasFunctionTools = false,
}) {
  if (functionCallingConfig == null) {
    if (!hasFunctionTools) return null;
    final fromChoice = switch (toolChoice?.value) {
      'auto' => fai.FunctionCallingConfig.auto(),
      'required' => fai.FunctionCallingConfig.any({}),
      'none' => fai.FunctionCallingConfig.none(),
      _ => null,
    };
    return fromChoice == null
        ? null
        : fai.ToolConfig(functionCallingConfig: fromChoice);
  }
  final mConfig = switch (functionCallingConfig.mode?.toUpperCase()) {
    'ANY' => fai.FunctionCallingConfig.any(
      functionCallingConfig.allowedFunctionNames?.toSet() ?? {},
    ),
    'NONE' => fai.FunctionCallingConfig.none(),
    _ => fai.FunctionCallingConfig.auto(),
  };
  return fai.ToolConfig(functionCallingConfig: mConfig);
}

@visibleForTesting
GenerationUsage? extractUsage(fai.UsageMetadata? metadata) {
  if (metadata == null) return null;
  return GenerationUsage(
    inputTokens: metadata.promptTokenCount ?? 0,
    outputTokens: metadata.candidatesTokenCount ?? 0,
    totalTokens: metadata.totalTokenCount ?? 0,
  );
}
