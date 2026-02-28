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

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'aggregation.dart';
import 'api_client.dart';
import 'auth.dart';
import 'generated/generativelanguage.dart' as gcl;
import 'model.dart';

final _logger = Logger('genkit_google_genai');

final commonModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
);

@visibleForTesting
class GoogleGenAiPluginImpl extends GenkitPlugin {
  String? apiKey;
  String? projectId;
  String? location;
  http.Client? authClient;

  GoogleGenAiPluginImpl({
    this.apiKey,
    this.projectId,
    this.location,
    this.authClient,
  });

  bool get isVertex => projectId != null && location != null;

  Future<GenerativeLanguageBaseClient> _getApiClient([
    String? requestApiKey,
  ]) async {
    if (isVertex) {
      final client = await getVertexAuthClient(authClient);
      final baseUrl = location == 'global'
          ? 'https://aiplatform.googleapis.com/'
          : 'https://$location-aiplatform.googleapis.com/';
      final apiUrlPrefix =
          'v1beta1/projects/$projectId/locations/$location/publishers/google/';

      final headers = {
        'X-Goog-Api-Client':
            'genkit-dart/$genkitVersion gl-dart/${getPlatformLanguageVersion()}',
      };

      return GenerativeLanguageBaseClient(
        baseUrl: baseUrl,
        client: CustomClient(defaultHeaders: headers, inner: client),
        apiUrlPrefix: apiUrlPrefix,
      );
    } else {
      return GenerativeLanguageBaseClient(
        baseUrl: 'https://generativelanguage.googleapis.com/',
        client: httpClientFromApiKey(requestApiKey ?? apiKey),
      );
    }
  }

  @override
  String get name => isVertex ? 'vertexai' : 'googleai';

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    final service = await _getApiClient();
    try {
      if (isVertex) {
        final res = await service.listPublisherModels(projectId: projectId!);
        final publisherModels = (res['publisherModels'] as List?) ?? [];

        final models = publisherModels
            .where(
              (m) =>
                  (m as Map)['name'] != null &&
                  (m['name'] as String).contains('gemini-'),
            )
            .map((m) {
              final modelName = ((m as Map)['name'] as String).split('/').last;
              final isTts = modelName.contains('-tts');
              return modelMetadata(
                '$name/$modelName',
                customOptions: isTts
                    ? GeminiTtsOptions.$schema
                    : GeminiOptions.$schema,
                modelInfo: commonModelInfo,
              );
            })
            .toList();

        final embedders = publisherModels
            .where(
              (m) =>
                  (m as Map)['name'] != null &&
                  ((m['name'] as String).contains('text-embedding-') ||
                      (m['name'] as String).contains('embedding-')),
            )
            .map((m) {
              final modelName = ((m as Map)['name'] as String).split('/').last;
              return embedderMetadata('$name/$modelName');
            })
            .toList();

        return [...models, ...embedders];
      }

      final gcl.ListModelsResponse modelsResponse;
      try {
        modelsResponse = await service.listModels(pageSize: 1000);
      } catch (e, stack) {
        _logger.warning('Failed to list models: $e', e, stack);
        throw _handleException(e, stack);
      }
      final models = (modelsResponse.models ?? [])
          .where((model) {
            return model.name != null &&
                model.name!.startsWith('models/gemini-');
          })
          .map((model) {
            final isTts = model.name!.contains('-tts');
            return modelMetadata(
              '$name/${model.name!.split('/').last}',
              customOptions: isTts
                  ? GeminiTtsOptions.$schema
                  : GeminiOptions.$schema,
              modelInfo: commonModelInfo,
            );
          })
          .toList();
      final embedders = (modelsResponse.models ?? [])
          .where(
            (model) =>
                model.name != null &&
                (model.name!.startsWith('models/text-embedding-') ||
                    model.name!.startsWith('models/embedding-')),
          )
          .map((model) {
            return embedderMetadata('$name/${model.name!.split('/').last}');
          })
          .toList();
      return [...models, ...embedders];
    } catch (e, stack) {
      if (e is GenkitException) rethrow;
      _logger.warning('Failed to list models: $e', e, stack);
      throw _handleException(e, stack);
    } finally {
      service.client.close();
    }
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'embedder') {
      return _createEmbedder(name);
    }
    if (actionType == 'model') {
      if (name.contains('-tts')) {
        return _createModel(name, GeminiTtsOptions.$schema);
      }
      return _createModel(name, GeminiOptions.$schema);
    }
    return null;
  }

  Model _createModel(String modelName, SchemanticType customOptions) {
    return Model(
      name: '$name/$modelName',
      customOptions: customOptions,
      metadata: {'model': commonModelInfo.toJson()},
      fn: (req, ctx) async {
        gcl.GenerationConfig generationConfig;
        List<gcl.SafetySetting>? safetySettings;
        List<gcl.Tool>? tools;
        gcl.ToolConfig? toolConfig;
        String? apiKey;

        final isJsonMode =
            req!.output?.format == 'json' ||
            req.output?.contentType == 'application/json';

        if (customOptions == GeminiTtsOptions.$schema) {
          final options = req.config == null
              ? GeminiTtsOptions()
              : GeminiTtsOptions.$schema.parse(req.config!);
          apiKey = options.apiKey;
          generationConfig = toGeminiTtsSettings(
            options,
            req.output?.schema,
            isJsonMode,
          );
          safetySettings = toGeminiSafetySettings(options.safetySettings);
          tools = toGeminiTools(
            req.tools,
            codeExecution: options.codeExecution,
            googleSearch: options.googleSearch,
          );
          toolConfig = toGeminiToolConfig(options.functionCallingConfig);
        } else {
          final options = req.config == null
              ? GeminiOptions()
              : GeminiOptions.$schema.parse(req.config!);
          apiKey = options.apiKey;
          generationConfig = toGeminiSettings(
            options,
            req.output?.schema,
            isJsonMode,
          );
          safetySettings = toGeminiSafetySettings(options.safetySettings);
          tools = toGeminiTools(
            req.tools,
            codeExecution: options.codeExecution,
            googleSearch: options.googleSearch,
          );
          toolConfig = toGeminiToolConfig(options.functionCallingConfig);
        }

        final service = await _getApiClient(apiKey);

        try {
          final systemMessage = req.messages
              .where((m) => m.role == Role.system)
              .firstOrNull;
          final messages = req.messages
              .where((m) => m.role != Role.system)
              .toList();

          final generateRequest = gcl.GenerateContentRequest(
            contents: toGeminiContent(messages),
            tools: tools.isEmpty ? null : tools,
            toolConfig: toolConfig,
            generationConfig: generationConfig,
            safetySettings: safetySettings?.isEmpty ?? true
                ? null
                : safetySettings,
            systemInstruction: systemMessage == null
                ? null
                : gcl.Content(
                    parts: systemMessage.content.map(toGeminiPart).toList(),
                    role: 'system',
                  ),
          );

          if (ctx.streamingRequested) {
            final stream = service.streamGenerateContent(
              generateRequest,
              model: 'models/$modelName',
            );
            final chunks = <gcl.GenerateContentResponse>[];
            await for (final chunk in stream) {
              chunks.add(chunk);
              if (chunk.candidates?.isNotEmpty == true) {
                final (message, finishReason) = _fromGeminiCandidate(
                  chunk.candidates!.first,
                );
                ctx.sendChunk(
                  ModelResponseChunk(index: 0, content: message.content),
                );
              }
            }
            final aggregated = aggregateResponses(chunks);
            if (aggregated.candidates?.isEmpty ?? true) {
              final blockReason = aggregated.promptFeedback?.blockReason;
              throw Exception(
                'No candidates returned from generative stream. Block reason: $blockReason',
              );
            }
            final (message, finishReason) = _fromGeminiCandidate(
              aggregated.candidates!.first,
            );
            return ModelResponse(
              finishReason: finishReason,
              message: message,
              raw: aggregated as Map<String, dynamic>,
              usage: extractUsage(aggregated.usageMetadata),
            );
          } else {
            final response = await service.generateContent(
              generateRequest,
              model: 'models/$modelName',
            );
            if (response.candidates?.isEmpty ?? true) {
              final blockReason = response.promptFeedback?.blockReason;
              throw Exception(
                'No candidates returned from generateContent. Block reason: $blockReason',
              );
            }
            final (message, finishReason) = _fromGeminiCandidate(
              response.candidates!.first,
            );
            return ModelResponse(
              finishReason: finishReason,
              message: message,
              raw: response as Map<String, dynamic>?,
              usage: extractUsage(response.usageMetadata),
            );
          }
        } catch (e, stack) {
          throw _handleException(e, stack);
        } finally {
          service.client.close();
        }
      },
    );
  }

  Embedder _createEmbedder(String embedderName) {
    return Embedder(
      name: '$name/$embedderName',
      fn: (req, ctx) async {
        final service = await _getApiClient();
        try {
          final options = req?.options != null
              ? TextEmbedderOptions.fromJson(req!.options!)
              : null;

          if (isVertex) {
            final instances = req!.input.map((doc) {
              final text = doc.content
                  .where((p) => p.isText)
                  .map((p) => p.text)
                  .join('\n');
              return {'content': text};
            }).toList();

            final parameters = <String, dynamic>{};
            if (options?.outputDimensionality != null) {
              parameters['outputDimensionality'] =
                  options!.outputDimensionality;
            }
            if (options?.taskType != null) {
              parameters['taskType'] = options!.taskType;
            }

            final res = await service.predict({
              'instances': instances,
              if (parameters.isNotEmpty) 'parameters': parameters,
            }, model: 'models/$embedderName');

            final predictions = res['predictions'] as List;
            final embeddings = predictions.map((p) {
              final emb = (p as Map)['embeddings'] as Map;
              final vals = emb['values'] as List;
              return Embedding(
                embedding: vals.map((e) => (e as num).toDouble()).toList(),
              );
            }).toList();
            return EmbedResponse(embeddings: embeddings);
          }

          if (req!.input.length == 1) {
            final doc = req.input.first;
            final text = doc.content
                .where((p) => p.isText)
                .map((p) => p.text)
                .join('\n');
            final content = gcl.Content(parts: [gcl.Part(text: text)]);
            final res = await service.embedContent(
              gcl.EmbedContentRequest(
                content: content,
                outputDimensionality: options?.outputDimensionality,
                taskType: options?.taskType,
                title: options?.title,
              ),
              model: 'models/$embedderName',
            );
            return EmbedResponse(
              embeddings: [Embedding(embedding: res.embedding?.values ?? [])],
            );
          } else {
            final futures = req.input.map((doc) async {
              final text = doc.content
                  .map((p) => p.toJson()['text'] as String?)
                  .nonNulls
                  .join('\n');
              final content = gcl.Content(parts: [gcl.Part(text: text)]);
              final res = await service.embedContent(
                gcl.EmbedContentRequest(
                  content: content,
                  outputDimensionality: options?.outputDimensionality,
                  taskType: options?.taskType,
                  title: options?.title,
                ),
                model: 'models/$embedderName',
              );
              return Embedding(embedding: res.embedding?.values ?? []);
            });
            final embeddings = await Future.wait(futures);
            return EmbedResponse(embeddings: embeddings);
          }
        } catch (e, stack) {
          throw _handleException(e, stack);
        } finally {
          service.client.close();
        }
      },
    );
  }

  GenkitException _handleException(Object e, StackTrace stack) {
    if (e is GenkitException) return e;

    int? httpStatus;
    String? message;

    try {
      if ((e as dynamic).status != null) {
        httpStatus = (e as dynamic).status as int?;
      } else if ((e as dynamic).code != null) {
        httpStatus = (e as dynamic).code as int?;
      }
      if ((e as dynamic).message != null) {
        message = (e as dynamic).message as String?;
      }
    } catch (_) {}

    if (httpStatus != null) {
      return GenkitException(
        message ?? 'Google AI API Error: $httpStatus',
        status: StatusCodes.fromHttpStatus(httpStatus),
        underlyingException: e,
        stackTrace: stack,
      );
    }

    return GenkitException(
      'Google AI Error: $e',
      status: StatusCodes.INTERNAL,
      underlyingException: e,
      stackTrace: stack,
    );
  }
}

@visibleForTesting
gcl.GenerationConfig toGeminiSettings(
  GeminiOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode,
) {
  return gcl.GenerationConfig(
    candidateCount: options.candidateCount,
    stopSequences: options.stopSequences?.isEmpty ?? true
        ? null
        : options.stopSequences,
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType ?? ''),
    responseJsonSchema: outputSchema,
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseLogprobs: options.responseLogprobs,
    logprobs: options.logprobs,
    responseModalities: options.responseModalities?.isEmpty ?? true
        ? null
        : options.responseModalities!.map((m) => m.toUpperCase()).toList(),
    speechConfig: options.speechConfig != null
        ? gcl.SpeechConfig.fromJson(_toSpeechConfig(options.speechConfig)!)
        : null,
    thinkingConfig: options.thinkingConfig != null
        ? gcl.ThinkingConfig.fromJson(
            _toThinkingConfig(options.thinkingConfig)!,
          )
        : null,
  );
}

@visibleForTesting
gcl.GenerationConfig toGeminiTtsSettings(
  GeminiTtsOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode,
) {
  return gcl.GenerationConfig(
    candidateCount: options.candidateCount,
    stopSequences: options.stopSequences?.isEmpty ?? true
        ? null
        : options.stopSequences,
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType?.isEmpty ?? true
              ? null
              : options.responseMimeType),
    responseJsonSchema: outputSchema,
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseLogprobs: options.responseLogprobs,
    logprobs: options.logprobs,
    responseModalities: options.responseModalities?.isEmpty ?? true
        ? null
        : options.responseModalities!.map((m) => m.toUpperCase()).toList(),
    speechConfig: options.speechConfig != null
        ? gcl.SpeechConfig.fromJson(_toSpeechConfig(options.speechConfig)!)
        : null,
    thinkingConfig: options.thinkingConfig != null
        ? gcl.ThinkingConfig.fromJson(
            _toThinkingConfig(options.thinkingConfig)!,
          )
        : null,
  );
}

Map<String, dynamic>? _toSpeechConfig(SpeechConfig? config) {
  if (config == null) return null;
  return {
    if (config.voiceConfig != null)
      'voiceConfig': _toVoiceConfig(config.voiceConfig),
    if (config.multiSpeakerVoiceConfig != null)
      'multiSpeakerVoiceConfig': _toMultiSpeakerVoiceConfig(
        config.multiSpeakerVoiceConfig,
      ),
  };
}

Map<String, dynamic>? _toThinkingConfig(ThinkingConfig? config) {
  if (config == null) return null;
  return {
    if (config.includeThoughts != null)
      'includeThoughts': config.includeThoughts,
    if (config.thinkingBudget != null) 'thinkingBudget': config.thinkingBudget,
    if (config.thinkingLevel != null) 'thinkingLevel': config.thinkingLevel,
  };
}

Map<String, dynamic>? _toMultiSpeakerVoiceConfig(
  MultiSpeakerVoiceConfig? config,
) {
  if (config == null) return null;
  return {
    'speakerVoiceConfigs': config.speakerVoiceConfigs
        .map(_toSpeakerVoiceConfig)
        .toList(),
  };
}

Map<String, Object?> _toSpeakerVoiceConfig(SpeakerVoiceConfig config) {
  return {
    'speaker': config.speaker,
    'voiceConfig': _toVoiceConfig(config.voiceConfig),
  };
}

Map<String, Object?>? _toVoiceConfig(VoiceConfig? config) {
  if (config == null) return null;
  return {
    'prebuiltVoiceConfig': _toPrebuiltVoiceConfig(config.prebuiltVoiceConfig),
  };
}

Map<String, Object?>? _toPrebuiltVoiceConfig(PrebuiltVoiceConfig? config) {
  if (config == null) return null;
  return {'voiceName': config.voiceName};
}

@visibleForTesting
List<gcl.SafetySetting>? toGeminiSafetySettings(
  List<SafetySettings>? safetySettings,
) {
  return safetySettings
      ?.map(
        (s) => gcl.SafetySetting(
          category: s.category ?? 'HARM_CATEGORY_UNSPECIFIED',
          threshold: s.threshold ?? 'HARM_BLOCK_THRESHOLD_UNSPECIFIED',
        ),
      )
      .toList();
}

@visibleForTesting
List<gcl.Tool> toGeminiTools(
  List<ToolDefinition>? tools, {
  bool? codeExecution,
  GoogleSearch? googleSearch,
}) {
  return [
    ...(tools?.map(_toGeminiTool) ?? []),
    if (codeExecution == true) gcl.Tool(codeExecution: gcl.CodeExecution()),
    if (googleSearch != null) gcl.Tool(googleSearch: gcl.GoogleSearch()),
  ];
}

@visibleForTesting
gcl.ToolConfig? toGeminiToolConfig(
  FunctionCallingConfig? functionCallingConfig,
) {
  if (functionCallingConfig == null) return null;
  return gcl.ToolConfig(
    functionCallingConfig: gcl.FunctionCallingConfig(
      mode: functionCallingConfig.mode ?? 'MODE_UNSPECIFIED',
      allowedFunctionNames: functionCallingConfig.allowedFunctionNames ?? [],
    ),
  );
}

@visibleForTesting
List<gcl.Content> toGeminiContent(List<Message> messages) {
  return messages
      .map(
        (m) => gcl.Content(
          role: m.role.value,
          parts: m.content.map(toGeminiPart).toList(),
        ),
      )
      .toList();
}

(Message, FinishReason) _fromGeminiCandidate(gcl.Candidate candidate) {
  final finishReason = FinishReason(
    candidate.finishReason?.toLowerCase() ?? 'unspecified',
  );
  final message = Message(
    role: Role(candidate.content!.role!),
    content: candidate.content?.parts?.map(fromGeminiPart).toList() ?? [],
  );
  return (message, finishReason);
}

@visibleForTesting
gcl.Part toGeminiPart(Part p) {
  final thoughtSignature = p.metadata?['thoughtSignature'] != null
      ? p.metadata!['thoughtSignature'] as String
      : null;

  if (p.isReasoning) {
    return gcl.Part(
      text: p.reasoning,
      thought: true,
      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isText) {
    return gcl.Part(text: p.text, thoughtSignature: thoughtSignature);
  }
  if (p.isToolRequest) {
    return gcl.Part(
      functionCall: gcl.FunctionCall(
        id: p.toolRequest!.ref ?? '',
        name: p.toolRequest!.name,
        args: p.toolRequest!.input, // already a map
      ),
      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isToolResponse) {
    return gcl.Part(
      functionResponse: gcl.FunctionResponse(
        id: p.toolResponse!.ref ?? '',
        name: p.toolResponse!.name,
        response: {'output': p.toolResponse!.output},
      ),
      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isMedia) {
    final media = p.media;
    if (media!.url.startsWith('data:')) {
      final uri = Uri.parse(media.url);
      if (uri.data != null) {
        return gcl.Part.fromJson({
          'inlineData': {
            'mimeType': media.contentType ?? uri.data!.mimeType,
            'data': base64Encode(uri.data!.contentAsBytes()),
          },
          if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
        });
      }
    }
    return gcl.Part.fromJson({
      'fileData': {'mimeType': media.contentType ?? '', 'fileUri': media.url},
      if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
    });
  }
  if (p.isCustom && p.custom!['codeExecutionResult'] != null) {
    p as CustomPart;
    return gcl.Part(
      codeExecutionResult: gcl.CodeExecutionResult(
        outcome:
            (p.custom['codeExecutionResult'] as Map<String, dynamic>)['outcome']
                as String?,
        output:
            (p.custom['codeExecutionResult'] as Map<String, dynamic>)['output']
                as String?,
      ),
      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isCustom && p.custom!['executableCode'] != null) {
    p as CustomPart;
    return gcl.Part(
      executableCode: gcl.ExecutableCode(
        language:
            (p.custom['executableCode'] as Map<String, dynamic>)['language']
                as String?,
        code:
            (p.custom['executableCode'] as Map<String, dynamic>)['code']
                as String?,
      ),
      thoughtSignature: thoughtSignature,
    );
  }
  throw UnimplementedError('Unsupported part type: $p');
}

@visibleForTesting
Part fromGeminiPart(gcl.Part p) {
  final metadata = <String, dynamic>{
    if (p.thoughtSignature != null) 'thoughtSignature': p.thoughtSignature,
  };

  if (p.text != null) {
    if (p.thought == true) {
      return ReasoningPart(reasoning: p.text!, metadata: metadata);
    }
    return TextPart(text: p.text!, metadata: metadata);
  }
  if (p.functionCall != null) {
    return ToolRequestPart(
      toolRequest: ToolRequest(
        ref: p.functionCall!.id == '' ? null : p.functionCall!.id,
        name: p.functionCall!.name ?? '',
        input: p.functionCall!.args,
      ),
      metadata: metadata,
    );
  }
  if (p.codeExecutionResult != null) {
    return CustomPart(
      custom: {'codeExecutionResult': p.codeExecutionResult!.toJson()},
      metadata: metadata,
    );
  }
  if (p.executableCode != null) {
    return CustomPart(
      custom: {'executableCode': p.executableCode!.toJson()},
      metadata: metadata,
    );
  }
  // inlineData check
  final rawMap = p.toJson();
  if (rawMap['inlineData'] != null) {
    final mimeType = (rawMap['inlineData'] as Map)['mimeType'] as String?;
    final data = (rawMap['inlineData'] as Map)['data'] as String;
    return MediaPart(
      media: Media(url: 'data:$mimeType;base64,$data', contentType: mimeType),
      metadata: metadata,
    );
  }
  // fileData check
  if (rawMap['fileData'] != null) {
    final mimeType = (rawMap['fileData'] as Map)['mimeType'] as String?;
    final fileUri = (rawMap['fileData'] as Map)['fileUri'] as String;
    return MediaPart(
      media: Media(url: fileUri, contentType: mimeType),
      metadata: metadata,
    );
  }
  throw UnimplementedError('Unsupported part type: $p');
}

gcl.Tool _toGeminiTool(ToolDefinition tool) {
  return gcl.Tool(
    functionDeclarations: [
      gcl.FunctionDeclaration(
        name: tool.name,
        description: tool.description,
        parametersJsonSchema: tool.inputSchema,
      ),
    ],
  );
}

@visibleForTesting
GenerationUsage? extractUsage(gcl.UsageMetadata? metadata) {
  if (metadata == null) return null;
  return GenerationUsage(
    inputTokens: metadata.promptTokenCount?.toDouble(),
    outputTokens: metadata.candidatesTokenCount?.toDouble(),
    totalTokens: metadata.totalTokenCount?.toDouble(),
    thoughtsTokens: metadata.thoughtsTokenCount?.toDouble(),
    cachedContentTokens: metadata.cachedContentTokenCount?.toDouble(),
    custom: {'toolUsePromptTokenCount': metadata.toolUsePromptTokenCount},
  );
}

const _apiKeyEnvVars = ['GOOGLE_API_KEY', 'GEMINI_API_KEY'];

http.Client httpClientFromApiKey(String? apiKey) {
  apiKey ??= _apiKeyEnvVars.map(getConfigVar).nonNulls.firstOrNull;
  var headers = {
    'X-Goog-Api-Client':
        'genkit-dart/$genkitVersion gl-dart/${getPlatformLanguageVersion()}',
    if (apiKey != null) 'x-goog-api-key': apiKey,
  };
  if (apiKey == null) {
    throw GenkitException(
      'apiKey must be set to an API key',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  final baseClient = CustomClient(defaultHeaders: headers);
  return baseClient;
}

class CustomClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> defaultHeaders;

  CustomClient({required this.defaultHeaders, http.Client? inner})
    : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(defaultHeaders);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
