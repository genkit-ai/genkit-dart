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

import 'package:firebase_ai/firebase_ai.dart' as m;
import 'package:genkit/genkit.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'src/aggregation.dart';

part 'genkit_firebase_ai.g.dart';

final _logger = Logger('genkit_firebase_ai');

@Schematic()
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

@Schematic()
abstract class $FunctionCallingConfig {
  @StringField(enumValues: ['MODE_UNSPECIFIED', 'AUTO', 'ANY', 'NONE'])
  String? get mode;
  List<String>? get allowedFunctionNames;
}

@Schematic()
abstract class $ThinkingConfig {
  int? get thinkingBudget;
  bool? get includeThoughts;
}

@Schematic()
abstract class $PrebuiltVoiceConfig {
  String? get voiceName;
}

@Schematic()
abstract class $VoiceConfig {
  $PrebuiltVoiceConfig? get prebuiltVoiceConfig;
}

@Schematic()
abstract class $SpeechConfig {
  $VoiceConfig? get voiceConfig;
}

@Schematic()
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

const FirebaseGenAiPluginHandle firebaseAI = FirebaseGenAiPluginHandle();

class FirebaseGenAiPluginHandle {
  const FirebaseGenAiPluginHandle();

  GenkitPlugin call() {
    return _FirebaseGenAiPlugin();
  }

  /// Ref to a model in the Firebase AI plugin.
  ///
  /// The [name] is the model name, e.g. 'gemini-2.5-flash'.
  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('firebaseai/$name', customOptions: GeminiOptions.$schema);
  }
}

class _FirebaseGenAiPlugin extends GenkitPlugin {
  @override
  String get name => 'firebaseai';

  _FirebaseGenAiPlugin();

  @override
  Future<List<Action>> init() async {
    return [
      _createModel('gemini-2.5-flash'),
      _createModel('gemini-2.5-pro'),
      _createBidiModel('gemini-2.5-flash-native-audio-preview-12-2025'),
    ];
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'model') return _createModel(name);
    if (actionType == 'bidi-model') return _createBidiModel(name);
    return null;
  }

  Model _createModel(String modelName) {
    return Model(
      name: 'firebaseai/$modelName',
      fn: (req, ctx) async {
        final isJsonMode =
            req!.output?.format == 'json' ||
            req.output?.contentType == 'application/json';

        final options = req.config == null
            ? GeminiOptions()
            : GeminiOptions.$schema.parse(req.config!);

        final instance = m.FirebaseAI.googleAI();
        final model = instance.generativeModel(
          model: modelName,
          generationConfig: toGeminiSettings(
            options,
            req.output?.schema,
            isJsonMode,
          ),
          tools: toGeminiTools(req.tools, codeExecution: options.codeExecution),
          toolConfig: toGeminiToolConfig(options.functionCallingConfig),
        );

        if (ctx.streamingRequested) {
          final stream = model.generateContentStream(
            toGeminiContent(req.messages),
          );
          final chunks = <m.GenerateContentResponse>[];
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
      fn: (stream, ctx) async {
        final configMap = ctx.init?.config;
        final tools = toGeminiTools(ctx.init?.tools);
        final systemMessage = ctx.init?.messages
            .where((m) => m.role == Role.system)
            .firstOrNull;
        final systemInstruction = systemMessage != null
            ? m.Content(
                'system',
                systemMessage.content.map(toGeminiPart).toList(),
              )
            : null;

        final liveConfig = m.LiveGenerationConfig(
          responseModalities: (configMap?['responseModalities'] as List?)?.map((
            e,
          ) {
            return m.ResponseModalities.values.byName(
              (e as String).toLowerCase(),
            );
          }).toList(),
          speechConfig: configMap?['speechConfig'] != null
              ? m.SpeechConfig(
                  voiceName:
                      (((configMap!['speechConfig'] as Map)['voiceConfig']
                                  as Map)['prebuiltVoiceConfig']
                              as Map)['voiceName']
                          as String,
                )
              : null,
          maxOutputTokens: configMap?['maxOutputTokens'] as int?,
          temperature: (configMap?['temperature'] as num?)?.toDouble(),
          topP: (configMap?['topP'] as num?)?.toDouble(),
          topK: configMap?['topK'] as int?,
          presencePenalty: (configMap?['presencePenalty'] as num?)?.toDouble(),
          frequencyPenalty: (configMap?['frequencyPenalty'] as num?)
              ?.toDouble(),
        );

        final instance = m.FirebaseAI.googleAI();
        final model = instance.liveGenerativeModel(
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
          await _sendToSession(session, msg);
        }

        final sub = ctx.inputStream!.listen(
          (chunk) async {
            for (final msg in chunk.messages) {
              await _sendToSession(session, msg);
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

  Future<void> _sendToSession(m.LiveSession session, Message msg) async {
    _logger.fine('Sending message: ${msg.role} parts: ${msg.content.length}');

    final contentParts = msg.content.map(toGeminiPart).toList();

    for (final part in contentParts) {
      try {
        if (part is m.InlineDataPart) {
          // TODO: Check mimeType for video vs audio
          await session.sendAudioRealtime(part);
        } else if (part is m.FunctionResponse) {
          await session.sendToolResponse([part]);
        } else {
          // Fallback for others
          await session.send(
            input: m.Content(msg.role.value, [part]),
            turnComplete: true,
          );
        }
      } catch (e) {
        _logger.severe('Error sending part: $part', e);
        rethrow;
      }
    }
  }
}

@visibleForTesting
Iterable<m.Content> toGeminiContent(List<Message> messages) {
  return messages.map(
    (msg) => m.Content(msg.role.value, msg.content.map(toGeminiPart).toList()),
  );
}

@visibleForTesting
m.Part toGeminiPart(Part p) {
  if (p.isText) {
    return m.TextPart(p.text!);
  }
  if (p.isMedia) {
    final media = p.media!;
    if (media.url.startsWith('data:')) {
      final uri = Uri.parse(media.url);
      if (uri.data != null) {
        return m.InlineDataPart(
          media.contentType ?? 'application/octet-stream',
          uri.data!.contentAsBytes(),
        );
      }
    }
    // Assume HTTP/S or other URLs are File URIs
    return m.FileData(
      media.contentType ?? 'application/octet-stream',
      media.url,
    );
  }
  if (p.isToolResponse) {
    final toolResponse = p.toolResponse!;
    return m.FunctionResponse(toolResponse.name, {
      'result': toolResponse.output,
    }, id: toolResponse.ref);
  }
  if (p.isToolRequest) {
    final toolRequest = p.toolRequest!;
    return m.FunctionCall(
      toolRequest.name,
      toolRequest.input ?? {},
      id: toolRequest.ref,
    );
  }
  throw UnimplementedError('Part type $p not supported yet');
}

@visibleForTesting
(Message, FinishReason) fromGeminiCandidate(m.Candidate candidate) {
  final finishReason = FinishReason(candidate.finishReason?.name ?? 'unknown');
  final message = Message(
    role: Role(candidate.content.role ?? 'model'),
    content: candidate.content.parts.map(fromGeminiPart).toList(),
  );
  return (message, finishReason);
}

@visibleForTesting
@visibleForTesting
Part fromGeminiPart(m.Part p) {
  if (p is m.TextPart) {
    return TextPart(text: p.text);
  }
  if (p is m.FunctionCall) {
    return ToolRequestPart(
      toolRequest: ToolRequest(name: p.name, input: p.args),
    );
  }
  if (p is m.InlineDataPart) {
    final base64 = base64Encode(p.bytes);
    return MediaPart(
      media: Media(
        url: 'data:${p.mimeType};base64,$base64',
        contentType: p.mimeType,
      ),
    );
  }
  throw UnimplementedError('Part type $p not supported yet in response');
}

ModelResponseChunk? _fromGeminiLiveEvent(m.LiveServerResponse event) {
  final liveParts = event.message is m.LiveServerContent
      ? (event.message as m.LiveServerContent).modelTurn?.parts
      : event.message is m.LiveServerToolCall
      ? (event.message as m.LiveServerToolCall).functionCalls as List<m.Part>
      : null;
  if (liveParts == null) return null;
  // We only care about content updates for now
  final parts = liveParts.map(fromGeminiPart).toList();

  return ModelResponseChunk(index: 0, content: parts);
}

@visibleForTesting
List<m.Tool>? toGeminiTools(
  List<ToolDefinition>? tools, {
  bool? codeExecution,
}) {
  if ((tools == null || tools.isEmpty) && codeExecution != true) return null;

  return [
    if (tools != null) ...(tools.map(_toGeminiTool)),
    if (codeExecution == true) m.Tool.codeExecution(),
  ];
}

m.Tool _toGeminiTool(ToolDefinition tool) {
  final rawSchema = tool.inputSchema;

  var flattened = <String, dynamic>{};
  if (rawSchema != null) {
    flattened = Schema.fromMap(rawSchema).flatten().value;
  }

  final propertiesMap = flattened['properties'] as Map<String, dynamic>? ?? {};
  final requiredList =
      (flattened['required'] as List<dynamic>?)?.cast<String>() ?? [];

  final parameters = propertiesMap.map((key, value) {
    return MapEntry(key, toGeminiSchema(value as Map<String, dynamic>));
  });

  final optionalParameters = propertiesMap.keys
      .where((k) => !requiredList.contains(k))
      .toList();

  return m.Tool.functionDeclarations([
    m.FunctionDeclaration(
      tool.name,
      tool.description,
      parameters: parameters,
      optionalParameters: optionalParameters,
    ),
  ]);
}

@visibleForTesting
m.Schema toGeminiSchema(Map<String, dynamic> json) {
  final flattened = Schema.fromMap(json).flatten().value;
  return _toGeminiSchemaInternal(flattened);
}

m.Schema _toGeminiSchemaInternal(Map<String, dynamic> json) {
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
      return m.Schema.string(description: description, nullable: nullable);
    case 'number':
      return m.Schema.number(description: description, nullable: nullable);
    case 'integer':
      return m.Schema.integer(description: description, nullable: nullable);
    case 'boolean':
      return m.Schema.boolean(description: description, nullable: nullable);
    case 'array':
      return m.Schema.array(
        description: description,
        nullable: nullable,
        items: json['items'] != null
            ? _toGeminiSchemaInternal(json['items'] as Map<String, dynamic>)
            : m.Schema.string(),
      );
    case 'object':
      if (json.containsKey('properties')) {
        final properties = (json['properties'] as Map<String, dynamic>?)?.map(
          (k, v) =>
              MapEntry(k, _toGeminiSchemaInternal(v as Map<String, dynamic>)),
        );
        return m.Schema.object(
          properties: properties ?? {},
          description: description,
          nullable: nullable,
        );
      } else {
        return m.Schema(
          m.SchemaType.object,
          description: description,
          nullable: nullable,
        );
      }
    default:
      return m.Schema.string(description: description, nullable: nullable);
  }
}

@visibleForTesting
m.GenerationConfig toGeminiSettings(
  GeminiOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode,
) {
  return m.GenerationConfig(
    candidateCount: options.candidateCount,
    stopSequences: options.stopSequences ?? [],
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType ?? ''),
    responseSchema: outputSchema != null
        ? toGeminiSchema(outputSchema)
        : (options.responseSchema != null
              ? toGeminiSchema(options.responseSchema!)
              : null),
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseModalities: options.responseModalities
        ?.map((e) => m.ResponseModalities.values.byName(e.toLowerCase()))
        .toList(),
    thinkingConfig: options.thinkingConfig == null
        ? null
        : m.ThinkingConfig(
            includeThoughts: options.thinkingConfig!.includeThoughts ?? false,
            thinkingBudget: options.thinkingConfig!.thinkingBudget,
          ),
  );
}

@visibleForTesting
m.ToolConfig? toGeminiToolConfig(FunctionCallingConfig? functionCallingConfig) {
  if (functionCallingConfig == null) return null;
  final modeStr = functionCallingConfig.mode;
  final m.FunctionCallingConfig mConfig;
  if (modeStr == null) {
    mConfig = m.FunctionCallingConfig.auto();
  } else {
    switch (modeStr.toUpperCase()) {
      case 'ANY':
        mConfig = m.FunctionCallingConfig.any(
          functionCallingConfig.allowedFunctionNames?.toSet() ?? {},
        );
        break;
      case 'NONE':
        mConfig = m.FunctionCallingConfig.none();
        break;
      case 'AUTO':
      default:
        mConfig = m.FunctionCallingConfig.auto();
        break;
    }
  }
  return m.ToolConfig(functionCallingConfig: mConfig);
}

@visibleForTesting
GenerationUsage? extractUsage(m.UsageMetadata? metadata) {
  if (metadata == null) return null;
  return GenerationUsage(
    inputTokens: metadata.promptTokenCount?.toDouble() ?? 0,
    outputTokens: metadata.candidatesTokenCount?.toDouble() ?? 0,
    totalTokens: metadata.totalTokenCount?.toDouble() ?? 0,
  );
}
