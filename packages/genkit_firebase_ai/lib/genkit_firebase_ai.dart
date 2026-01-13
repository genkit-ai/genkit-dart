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
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:firebase_ai/firebase_ai.dart' as m;
import 'package:genkit/genkit.dart';
import 'package:logging/logging.dart';

part 'genkit_firebase_ai.schema.g.dart';

final _logger = Logger('genkit_firebase_ai');

@GenkitSchema()
abstract class GeminiOptionsSchema {
  int? get candidateCount;
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

@GenkitSchema()
abstract class ThinkingConfigSchema {
  int? get thinkingBudget;
  bool? get includeThoughts;
}

@GenkitSchema()
abstract class LiveGenerationConfigSchema {
  List<String>? get responseModalities;
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
            stopSequences:
                (req.config?['stopSequences'] as List?)?.cast<String>(),
            maxOutputTokens: req.config?['maxOutputTokens'] as int?,
            temperature: (req.config?['temperature'] as num?)?.toDouble(),
            topP: (req.config?['topP'] as num?)?.toDouble(),
            topK: req.config?['topK'] as int?,
            presencePenalty:
                (req.config?['presencePenalty'] as num?)?.toDouble(),
            frequencyPenalty:
                (req.config?['frequencyPenalty'] as num?)?.toDouble(),
            responseModalities: (req.config?['responseModalities'] as List?)
                ?.map((e) => m.ResponseModalities.values.byName(e as String))
                .toList(),
            responseMimeType: req.config?['responseMimeType'] as String?,
            responseSchema: req.config?['responseSchema'] != null
                ? toGeminiSchema(
                    req.config!['responseSchema'] as Map<String, dynamic>)
                : null,
            responseJsonSchema:
                req.config?['responseJsonSchema'] as Map<String, dynamic>?,
            thinkingConfig: req.config?['thinkingConfig'] != null
                ? m.ThinkingConfig(
                    thinkingBudget: (req.config!['thinkingConfig']
                        as Map)['thinkingBudget'] as int?,
                    includeThoughts: (req.config!['thinkingConfig']
                        as Map)['includeThoughts'] as bool?,
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
              .map((c) => {
                    'content': c.content.parts
                        .length, // content.toJson() might not exist or be simple
                    'finishReason': c.finishReason?.name
                  })
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
        final liveConfig = m.LiveGenerationConfig(
          responseModalities:
              (configMap?['responseModalities'] as List?)?.map((e) {
            return m.ResponseModalities.values
                .byName((e as String).toLowerCase());
          }).toList(),
        );

        final instance = m.FirebaseAI.googleAI();
        final model = instance.liveGenerativeModel(
          model: modelName,
          liveGenerationConfig: liveConfig,
        );

        final session = await model.connect();

        final sub = ctx.inputStream!.listen((chunk) {
          for (final msg in chunk.messages) {
            print('Sending message: $msg');
            final contentParts = msg.content
                .map((p) {
                  if (p.isMedia) {
                    final media = (p as MediaPart).media;
                    if (media.url.startsWith('data:')) {
                      final uri = Uri.parse(media.url);
                      // Handle data URI
                      if (uri.data != null) {
                        return m.InlineDataPart(
                          media.contentType ?? 'application/octet-stream',
                          uri.data!.contentAsBytes(),
                        );
                      }
                    }
                  }
                  if (p.isData) {
                    final dataPart = p as DataPart;
                    if (dataPart.data != null &&
                        dataPart.data!.containsKey('mimeType') &&
                        dataPart.data!.containsKey('bytes')) {
                      return m.InlineDataPart(
                        dataPart.data!['mimeType'] as String,
                        dataPart.data!['bytes'] as Uint8List,
                      );
                    }
                  }
                  try {
                    return toGeminiPart(p);
                  } catch (e) {
                    _logger.warning('Skipping unsupported part: $p', e);
                    return null;
                  }
                })
                .whereType<m.Part>()
                .toList();

            if (contentParts.isNotEmpty) {
              session.send(input: m.Content(msg.role.value, contentParts));
            }
          }
        });

        final receiveFuture = () async {
          try {
            await for (final event in session.receive()) {
              print('Received event: $event');
              final chunk = _fromGeminiLiveEvent(event);
              if (chunk != null) ctx.sendChunk(chunk);
            }
          } catch (e, s) {
            _logger.warning('Error in Live session receive loop', e, s);
          }
        }();

        await receiveFuture;
        await sub.cancel();
        await session.close();

        return ModelResponse.from(finishReason: FinishReason.stop);
      },
    );
  }
}

@visibleForTesting
Iterable<m.Content> toGeminiContent(List<Message> messages) {
  return messages.map(
    (msg) => m.Content(
      msg.role.value,
      msg.content.map(toGeminiPart).toList(),
    ),
  );
}

@visibleForTesting
m.Part toGeminiPart(Part p) {
  if (p.isText) {
    p as TextPart;
    return m.TextPart(p.text);
  }
  if (p.isToolResponse) {
    p as ToolResponsePart;
    return m.FunctionResponse(
      p.toolResponse.name,
      {'result': p.toolResponse.output},
    );
  }
  if (p.isToolRequest) {
    p as ToolRequestPart;
    return m.FunctionCall(
      p.toolRequest.name,
      p.toolRequest.input ?? {},
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
      toolRequest: ToolRequest.from(
        name: p.name,
        input: p.args,
      ),
    );
  }
  if (p is m.InlineDataPart) {
    final base64 = base64Encode(p.bytes);
    return MediaPart.from(
        media: Media.from(
      url: 'data:${p.mimeType};base64,$base64',
      contentType: p.mimeType,
    ));
  }
  throw UnimplementedError('Part type $p not supported yet in response');
}

ModelResponseChunk? _fromGeminiLiveEvent(dynamic event) {
  // Assuming event is m.GenerateContentResponse
  if (event is m.GenerateContentResponse) {
    if (event.candidates.isEmpty) return null;
    final candidate = event.candidates.first;
    // We only care about content updates for now
    final parts = candidate.content.parts.map(fromGeminiPart).toList();
    if (parts.isEmpty && candidate.finishReason == null) return null;

    final finishReason = candidate.finishReason != null
        ? FinishReason(candidate.finishReason!.name)
        : null;

    return ModelResponseChunk.from(
      index: 0,
      content: parts,
      custom:
          finishReason != null ? {'finishReason': finishReason.value} : null,
    );
  }
  return null;
}

@visibleForTesting
m.Tool toGeminiTool(ToolDefinition tool) {
  final schemaMap = tool.inputSchema as Map<String, dynamic>?;
  final propertiesMap = schemaMap?['properties'] as Map<String, dynamic>? ?? {};

  final parameters = propertiesMap.map((key, value) {
    return MapEntry(key, toGeminiSchema(value as Map<String, dynamic>));
  });

  return m.Tool.functionDeclarations([
    m.FunctionDeclaration(
      tool.name,
      tool.description,
      parameters: parameters,
    ),
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
