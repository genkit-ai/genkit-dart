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

part 'genkit_firebase_ai.g.dart';

final _logger = Logger('genkit_firebase_ai');

@Schematic()
abstract class GeminiOptionsSchema {
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
  ThinkingConfigSchema? get thinkingConfig;
}

@Schematic()
abstract class ThinkingConfigSchema {
  int? get thinkingBudget;
  bool? get includeThoughts;
}

@Schematic()
abstract class PrebuiltVoiceConfigSchema {
  String? get voiceName;
}

@Schematic()
abstract class VoiceConfigSchema {
  PrebuiltVoiceConfigSchema? get prebuiltVoiceConfig;
}

@Schematic()
abstract class SpeechConfigSchema {
  VoiceConfigSchema? get voiceConfig;
}

@Schematic()
abstract class LiveGenerationConfigSchema {
  List<String>? get responseModalities;
  SpeechConfigSchema? get speechConfig;
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
    return modelRef('firebaseai/$name', customOptions: GeminiOptionsType);
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
        if (req == null) throw ArgumentError('Request cannot be null');
        final instance = m.FirebaseAI.googleAI();
        final model = instance.generativeModel(
          model: modelName,
          generationConfig: m.GenerationConfig(
            candidateCount: req.config?['candidateCount'] as int?,
            stopSequences: (req.config?['stopSequences'] as List?)
                ?.cast<String>(),
            maxOutputTokens: req.config?['maxOutputTokens'] as int?,
            temperature: (req.config?['temperature'] as num?)?.toDouble(),
            topP: (req.config?['topP'] as num?)?.toDouble(),
            topK: req.config?['topK'] as int?,
            presencePenalty: (req.config?['presencePenalty'] as num?)
                ?.toDouble(),
            frequencyPenalty: (req.config?['frequencyPenalty'] as num?)
                ?.toDouble(),
            responseModalities: (req.config?['responseModalities'] as List?)
                ?.map((e) => m.ResponseModalities.values.byName(e as String))
                .toList(),
            responseMimeType: req.config?['responseMimeType'] as String?,
            responseSchema: req.config?['responseSchema'] != null
                ? toGeminiSchema(
                    req.config!['responseSchema'] as Map<String, dynamic>,
                  )
                : null,
            responseJsonSchema:
                req.config?['responseJsonSchema'] as Map<String, dynamic>?,
            thinkingConfig: req.config?['thinkingConfig'] != null
                ? m.ThinkingConfig(
                    thinkingBudget:
                        (req.config!['thinkingConfig'] as Map)['thinkingBudget']
                            as int?,
                    includeThoughts:
                        (req.config!['thinkingConfig']
                                as Map)['includeThoughts']
                            as bool?,
                  )
                : null,
          ),
        );

        final response = await model.generateContent(
          toGeminiContent(req.messages),
          tools: req.tools?.map(toGeminiTool).toList(),
        );

        if (response.candidates.isEmpty) {
          // TODO: Consider inspecting response.promptFeedback for the block reason.
          throw GenkitException('Model returned no candidates.');
        }
        final (message, finishReason) = fromGeminiCandidate(
          response.candidates.first,
        );

        final raw = <String, dynamic>{
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

        return ModelResponse.from(
          finishReason: finishReason,
          message: message,
          raw: raw,
        );
      },
    );
  }

  BidiModel _createBidiModel(String modelName) {
    return BidiModel(
      name: 'firebaseai/$modelName',
      fn: (stream, ctx) async {
        final configMap = ctx.init?.config;
        final tools = ctx.init?.tools?.map(toGeminiTool).toList();
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

        return ModelResponse.from(finishReason: FinishReason.stop);
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
    p as TextPart;
    return m.TextPart(p.text);
  }
  if (p.isMedia) {
    p as MediaPart;
    final media = p.media;
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
    p as ToolResponsePart;
    return m.FunctionResponse(p.toolResponse.name, {
      'result': p.toolResponse.output,
    }, id: p.toolResponse.ref);
  }
  if (p.isToolRequest) {
    p as ToolRequestPart;
    return m.FunctionCall(
      p.toolRequest.name,
      p.toolRequest.input ?? {},
      id: p.toolRequest.ref,
    );
  }
  throw UnimplementedError('Part type $p not supported yet');
}

@visibleForTesting
(Message, FinishReason) fromGeminiCandidate(m.Candidate candidate) {
  final finishReason = FinishReason(candidate.finishReason?.name ?? 'unknown');
  final message = Message.from(
    role: Role(candidate.content.role ?? 'model'),
    content: candidate.content.parts.map(fromGeminiPart).toList(),
  );
  return (message, finishReason);
}

@visibleForTesting
@visibleForTesting
Part fromGeminiPart(m.Part p) {
  if (p is m.TextPart) {
    return TextPart.from(text: p.text);
  }
  if (p is m.FunctionCall) {
    return ToolRequestPart.from(
      toolRequest: ToolRequest.from(name: p.name, input: p.args),
    );
  }
  if (p is m.InlineDataPart) {
    final base64 = base64Encode(p.bytes);
    return MediaPart.from(
      media: Media.from(
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

  return ModelResponseChunk.from(index: 0, content: parts);
}

@visibleForTesting
m.Tool toGeminiTool(ToolDefinition tool) {
  final schemaMap = tool.inputSchema as Map<String, dynamic>?;
  final propertiesMap = schemaMap?['properties'] as Map<String, dynamic>? ?? {};

  final parameters = propertiesMap.map((key, value) {
    return MapEntry(key, toGeminiSchema(value as Map<String, dynamic>));
  });

  return m.Tool.functionDeclarations([
    m.FunctionDeclaration(tool.name, tool.description, parameters: parameters),
  ]);
}

@visibleForTesting
m.Schema toGeminiSchema(Map<String, dynamic> json) {
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
            ? toGeminiSchema(json['items'] as Map<String, dynamic>)
            : m.Schema.string(),
      );
    case 'object':
      final properties = (json['properties'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, toGeminiSchema(v as Map<String, dynamic>)),
      );
      return m.Schema.object(
        properties: properties ?? {},
        description: description,
        nullable: nullable,
      );
    default:
      return m.Schema.string(description: description, nullable: nullable);
  }
}
