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
import 'generated/generativelanguage.dart' as gcl;
import 'model.dart';

final logger = Logger('genkit_google_genai');

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

final commonGemmaModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': 'no-tools',
  },
);

final gemma3ModelInfo = ModelInfo(
  supports: {
    ...?commonGemmaModelInfo.supports,
    'systemRole': false,
  },
);

bool isGemmaModelName(String name) => name.startsWith('gemma-');

bool isGemma3ModelName(String name) =>
    name.startsWith('gemma-3-') || name.startsWith('gemma-3n-');

abstract class CommonGoogleGenPlugin extends GenkitPlugin {
  Future<GenerativeLanguageBaseClient> getApiClient([String? requestApiKey]);

  Model createModel(
    String modelName,
    SchemanticType customOptions, {
    ModelInfo? modelInfo,
  }) {
    final isGemma = isGemmaModelName(modelName);
    return Model(
      name: '$name/$modelName',
      customOptions: customOptions,
      metadata: {'model': (modelInfo ?? commonModelInfo).toJson()},
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
          final GeminiOptions options;
          if (isGemma) {
            final gemmaOptions = req.config == null
                ? GemmaOptions()
                : GemmaOptions.$schema.parse(req.config!);
            options = _gemmaToGeminiOptions(gemmaOptions);
          } else {
            options = req.config == null
                ? GeminiOptions()
                : GeminiOptions.$schema.parse(req.config!);
          }
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

        final service = await getApiClient(apiKey);

        try {
          final systemMessage = req.messages
              .where((m) => m.role == Role.system)
              .firstOrNull;
          final nonSystemMessages = req.messages
              .where((m) => m.role != Role.system)
              .toList();
          final messages = isGemma
              ? stripReasoningParts(nonSystemMessages)
              : nonSystemMessages;

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
                final (message, finishReason) = fromGeminiCandidate(
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
            final (message, finishReason) = fromGeminiCandidate(
              aggregated.candidates!.first,
            );
            return ModelResponse(
              finishReason: finishReason,
              message: message,
              raw: aggregated.toJson(),
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
            final (message, finishReason) = fromGeminiCandidate(
              response.candidates!.first,
            );
            return ModelResponse(
              finishReason: finishReason,
              message: message,
              raw: response?.toJson(),
              usage: extractUsage(response.usageMetadata),
            );
          }
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          service.client.close();
        }
      },
    );
  }

  Embedder createEmbedder(String embedderName);

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'embedder') {
      return createEmbedder(name);
    }
    if (actionType == 'model') {
      if (isGemmaModelName(name)) {
        return createModel(
          name,
          GemmaOptions.$schema,
          modelInfo: isGemma3ModelName(name)
              ? gemma3ModelInfo
              : commonGemmaModelInfo,
        );
      }
      if (name.contains('-tts')) {
        return createModel(name, GeminiTtsOptions.$schema);
      }
      return createModel(name, GeminiOptions.$schema);
    }
    return null;
  }

  GenkitException handleException(Object e, StackTrace stack) {
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

(Message, FinishReason) fromGeminiCandidate(gcl.Candidate candidate) {
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
      allowedFunctionNames:
          functionCallingConfig.allowedFunctionNames
              ?.map(_toGeminiToolName)
              .toList() ??
          [],
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

@visibleForTesting
List<Message> stripReasoningParts(List<Message> messages) {
  return messages
      .map(
        (m) => Message(
          role: m.role,
          content: m.content
              .where(
                (p) =>
                    !p.isReasoning && p.metadata?['thoughtSignature'] == null,
              )
              .toList(),
          metadata: m.metadata,
        ),
      )
      .where((m) => m.content.isNotEmpty)
      .toList();
}

GeminiOptions _gemmaToGeminiOptions(GemmaOptions o) {
  return GeminiOptions(
    apiKey: o.apiKey,
    safetySettings: o.safetySettings,
    codeExecution: o.codeExecution,
    functionCallingConfig: o.functionCallingConfig,
    thinkingConfig: o.thinkingConfig,
    responseModalities: o.responseModalities,
    googleSearch: o.googleSearch,
    fileSearch: o.fileSearch,
    temperature: o.temperature,
    topP: o.topP,
    topK: o.topK,
    candidateCount: o.candidateCount,
    stopSequences: o.stopSequences,
    maxOutputTokens: o.maxOutputTokens,
    responseMimeType: o.responseMimeType,
    responseLogprobs: o.responseLogprobs,
    logprobs: o.logprobs,
    presencePenalty: o.presencePenalty,
    frequencyPenalty: o.frequencyPenalty,
    seed: o.seed,
    speechConfig: o.speechConfig,
  );
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
        name: _toGeminiToolName(p.toolRequest!.name),
        args: p.toolRequest!.input, // already a map
      ),
      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isToolResponse) {
    return gcl.Part(
      functionResponse: gcl.FunctionResponse(
        id: p.toolResponse!.ref ?? '',
        name: _toGeminiToolName(p.toolResponse!.name),
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
          'thoughtSignature': ?thoughtSignature,
        });
      }
    }
    return gcl.Part.fromJson({
      'fileData': {'mimeType': media.contentType ?? '', 'fileUri': media.url},
      'thoughtSignature': ?thoughtSignature,
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
        name: _fromGeminiToolName(p.functionCall!.name ?? ''),
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
  if (p.inlineData != null) {
    final mimeType = p.inlineData!.mimeType;
    final data = p.inlineData!.data;
    if (data != null) {
      return MediaPart(
        media: Media(url: 'data:$mimeType;base64,$data', contentType: mimeType),
        metadata: metadata,
      );
    }
  }
  if (p.fileData != null) {
    final mimeType = p.fileData!.mimeType;
    final fileUri = p.fileData!.fileUri;
    if (fileUri != null) {
      return MediaPart(
        media: Media(url: fileUri, contentType: mimeType),
        metadata: metadata,
      );
    }
  }
  throw UnimplementedError('Unsupported part type: ${p.toJson()}');
}

String _toGeminiToolName(String name) => name.replaceAll('/', '__');

String _fromGeminiToolName(String name) => name.replaceAll('__', '/');

gcl.Tool _toGeminiTool(ToolDefinition tool) {
  return gcl.Tool(
    functionDeclarations: [
      gcl.FunctionDeclaration(
        name: _toGeminiToolName(tool.name),
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
    custom: {
      if (metadata.toolUsePromptTokenCount != null)
        'toolUsePromptTokenCount': metadata.toolUsePromptTokenCount,
    },
  );
}

const _apiKeyEnvVars = ['GOOGLE_API_KEY', 'GEMINI_API_KEY'];

http.Client httpClientFromApiKey(String? apiKey) {
  apiKey ??= _apiKeyEnvVars.map(getConfigVar).nonNulls.firstOrNull;
  var headers = {
    'X-Goog-Api-Client':
        'genkit-dart/$genkitVersion gl-dart/${getPlatformLanguageVersion()}',
    'x-goog-api-key': ?apiKey,
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
