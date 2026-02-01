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

import 'package:genkit/genkit.dart';
import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as gcl;
import 'package:google_cloud_protobuf/protobuf.dart' as pb;
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'aggregation.dart';
import 'model.dart';

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

  GoogleGenAiPluginImpl({this.apiKey});

  @override
  String get name => 'googleai';

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    final service = gcl.ModelService.fromApiKey(apiKey);
    try {
      final gcl.ListModelsResponse modelsResponse;
      try {
        modelsResponse = await service.listModels(
          gcl.ListModelsRequest(pageSize: 1000),
        );
      } catch (e, stack) {
        throw _handleException(e, stack);
      }
      final models = modelsResponse.models
          .where((model) {
            return model.name.startsWith('models/gemini-');
          })
          .map((model) {
            final isTts = model.name.contains('-tts');
            return modelMetadata(
              'googleai/${model.name.split('/').last}',
              customOptions: isTts
                  ? GeminiTtsOptions.$schema
                  : GeminiOptions.$schema,
              modelInfo: commonModelInfo,
            );
          })
          .toList();
      return models;
    } finally {
      service.close();
    }
  }

  @override
  Action? resolve(String actionType, String name) {
    if (name.contains('-tts')) {
      return _createModel(name, GeminiTtsOptions.$schema);
    }
    return _createModel(name, GeminiOptions.$schema);
  }

  Model _createModel(String modelName, SchemanticType customOptions) {
    return Model(
      name: 'googleai/$modelName',
      customOptions: customOptions,
      metadata: {'model': commonModelInfo.toJson()},
      fn: (req, ctx) async {
        final gcl.GenerationConfig generationConfig;
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
            googleSearchRetrieval: options.googleSearchRetrieval,
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
            googleSearchRetrieval: options.googleSearchRetrieval,
          );
          toolConfig = toGeminiToolConfig(options.functionCallingConfig);
        }

        final service = gcl.GenerativeService.fromApiKey(
          apiKey ?? this.apiKey,
          // TODO: baseUrl is not supported in the current version of the library
          // baseUrl: options.baseUrl,
        );

        try {
          final systemMessage = req.messages
              .where((m) => m.role == Role.system)
              .firstOrNull;
          final messages = req.messages
              .where((m) => m.role != Role.system)
              .toList();

          final generateRequest = gcl.GenerateContentRequest(
            model: 'models/$modelName',
            contents: toGeminiContent(messages),
            tools: tools,
            toolConfig: toolConfig,
            generationConfig: generationConfig,
            safetySettings: safetySettings ?? [],
            systemInstruction: systemMessage == null
                ? null
                : gcl.Content(
                    parts: systemMessage.content.map(toGeminiPart).toList(),
                  ),
          );

          if (ctx.streamingRequested) {
            final stream = service.streamGenerateContent(generateRequest);
            final chunks = <gcl.GenerateContentResponse>[];
            await for (final chunk in stream) {
              chunks.add(chunk);
              if (chunk.candidates.isNotEmpty) {
                final (message, finishReason) = _fromGeminiCandidate(
                  chunk.candidates.first,
                );
                ctx.sendChunk(
                  ModelResponseChunk(index: 0, content: message.content),
                );
              }
            }
            final aggregated = aggregateResponses(chunks);
            final (message, finishReason) = _fromGeminiCandidate(
              aggregated.candidates.first,
            );
            return ModelResponse(
              finishReason: finishReason,
              message: message,
              raw: aggregated.toJson() as Map<String, dynamic>,
            );
          } else {
            final response = await service.generateContent(generateRequest);
            final (message, finishReason) = _fromGeminiCandidate(
              response.candidates.first,
            );
            return ModelResponse(
              finishReason: finishReason,
              message: message,
              raw: jsonDecode(jsonEncode(response)),
            );
          }
        } catch (e, stack) {
          throw _handleException(e, stack);
        } finally {
          service.close();
        }
      },
    );
  }

  GenkitException _handleException(Object e, StackTrace stack) {
    if (e is GenkitException) return e;

    // Check for common HTTP status codes if the exception has them
    // googleapis definitions often have 'status' or 'code'
    int? httpStatus;
    String? message;

    // Dynamic access to avoid hard dependency on specific exception types
    // if they are not exported or vary.
    try {
      if ((e as dynamic).status != null) {
        httpStatus = (e as dynamic).status as int?;
      } else if ((e as dynamic).code != null) {
        httpStatus =
            (e as dynamic).code as int?; // Sometimes 'code' is the status
      }
      if ((e as dynamic).message != null) {
        message = (e as dynamic).message as String?;
      }
    } catch (_) {
      // Ignore reflection errors
    }

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
    stopSequences: options.stopSequences ?? [],
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType ?? ''),
    responseJsonSchema: switch (outputSchema) {
      null => null,
      Map<String, Object?> $1 => pb.Value.fromJson($1),
    },
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseLogprobs: options.responseLogprobs,
    logprobs: options.logprobs,
    enableEnhancedCivicAnswers: null, // Not yet available in options
    responseModalities:
        options.responseModalities
            ?.map(
              (m) => switch (m.toUpperCase()) {
                'TEXT' => gcl.GenerationConfig_Modality.text,
                'IMAGE' => gcl.GenerationConfig_Modality.image,
                'AUDIO' => gcl.GenerationConfig_Modality.audio,
                _ => gcl.GenerationConfig_Modality.modalityUnspecified,
              },
            )
            .toList() ??
        [],
    speechConfig: null, // Not yet available in options
    thinkingConfig: options.thinkingConfig == null
        ? null
        : gcl.ThinkingConfig(
            includeThoughts: options.thinkingConfig!.includeThoughts ?? false,
            thinkingBudget: options.thinkingConfig!.thinkingBudget,
          ),
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
    stopSequences: options.stopSequences ?? [],
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType ?? ''),
    responseJsonSchema: switch (outputSchema) {
      null => null,
      Map<String, Object?> $1 => pb.Value.fromJson($1),
    },
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseLogprobs: options.responseLogprobs,
    logprobs: options.logprobs,
    enableEnhancedCivicAnswers: null,
    responseModalities:
        options.responseModalities
            ?.map(
              (m) => switch (m.toUpperCase()) {
                'TEXT' => gcl.GenerationConfig_Modality.text,
                'IMAGE' => gcl.GenerationConfig_Modality.image,
                'AUDIO' => gcl.GenerationConfig_Modality.audio,
                _ => gcl.GenerationConfig_Modality.modalityUnspecified,
              },
            )
            .toList() ??
        [],
    speechConfig: _toSpeechConfig(options.speechConfig),
    thinkingConfig: options.thinkingConfig == null
        ? null
        : gcl.ThinkingConfig(
            includeThoughts: options.thinkingConfig!.includeThoughts ?? false,
            thinkingBudget: options.thinkingConfig!.thinkingBudget,
          ),
  );
}

gcl.SpeechConfig? _toSpeechConfig(SpeechConfig? config) {
  if (config == null) return null;
  return gcl.SpeechConfig(voiceConfig: _toVoiceConfig(config.voiceConfig));
}

gcl.VoiceConfig? _toVoiceConfig(VoiceConfig? config) {
  if (config == null) return null;
  return gcl.VoiceConfig(
    prebuiltVoiceConfig: _toPrebuiltVoiceConfig(config.prebuiltVoiceConfig),
  );
}

gcl.PrebuiltVoiceConfig? _toPrebuiltVoiceConfig(PrebuiltVoiceConfig? config) {
  if (config == null) return null;
  return gcl.PrebuiltVoiceConfig(voiceName: config.voiceName);
}

@visibleForTesting
List<gcl.SafetySetting>? toGeminiSafetySettings(
  List<SafetySettings>? safetySettings,
) {
  return safetySettings
      ?.map(
        (s) => gcl.SafetySetting(
          category: switch (s.category) {
            null => gcl.HarmCategory.harmCategoryUnspecified,
            String c => gcl.HarmCategory.fromJson(c),
          },
          threshold: switch (s.threshold) {
            null =>
              gcl
                  .SafetySetting_HarmBlockThreshold
                  .harmBlockThresholdUnspecified,
            String t => gcl.SafetySetting_HarmBlockThreshold.fromJson(t),
          },
        ),
      )
      .toList();
}

@visibleForTesting
List<gcl.Tool> toGeminiTools(
  List<ToolDefinition>? tools, {
  bool? codeExecution,
  GoogleSearchRetrieval? googleSearchRetrieval,
}) {
  return [
    ...(tools?.map(_toGeminiTool) ?? []),
    if (codeExecution == true) gcl.Tool(codeExecution: gcl.CodeExecution()),
    if (googleSearchRetrieval != null)
      gcl.Tool(
        googleSearchRetrieval: gcl.GoogleSearchRetrieval(
          dynamicRetrievalConfig: gcl.DynamicRetrievalConfig(
            mode: switch (googleSearchRetrieval.mode) {
              null => gcl.DynamicRetrievalConfig_Mode.modeUnspecified,
              String m => gcl.DynamicRetrievalConfig_Mode.fromJson(m),
            },
            dynamicThreshold: googleSearchRetrieval.dynamicThreshold,
          ),
        ),
      ),
  ];
}

@visibleForTesting
gcl.ToolConfig? toGeminiToolConfig(
  FunctionCallingConfig? functionCallingConfig,
) {
  if (functionCallingConfig == null) return null;
  return gcl.ToolConfig(
    functionCallingConfig: gcl.FunctionCallingConfig(
      mode: switch (functionCallingConfig.mode) {
        null => gcl.FunctionCallingConfig_Mode.modeUnspecified,
        String m => gcl.FunctionCallingConfig_Mode.fromJson(m),
      },
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
  final finishReason = FinishReason(candidate.finishReason.value.toLowerCase());
  final message = Message(
    role: Role(candidate.content!.role),
    content: candidate.content?.parts.map(fromGeminiPart).toList() ?? [],
  );
  return (message, finishReason);
}

@visibleForTesting
gcl.Part toGeminiPart(Part p) {
  if (p.isText) {
    return gcl.Part(text: p.text);
  }
  if (p.isToolRequest) {
    return gcl.Part(
      functionCall: gcl.FunctionCall(
        name: p.toolRequest!.name,
        args: p.toolRequest!.input == null
            ? null
            : pb.Struct.fromJson(p.toolRequest!.input!),
      ),
    );
  }
  if (p.isToolResponse) {
    return gcl.Part(
      functionResponse: gcl.FunctionResponse(
        name: p.toolResponse!.name,
        response: pb.Struct.fromJson({'output': p.toolResponse!.output}),
      ),
    );
  }
  if (p.isMedia) {
    final media = p.media;
    if (media!.url.startsWith('data:')) {
      final uri = Uri.parse(media.url);
      if (uri.data != null) {
        return gcl.Part(
          inlineData: gcl.Blob(
            mimeType: media.contentType ?? 'application/octet-stream',
            data: uri.data!.contentAsBytes(),
          ),
        );
      }
    }
    // Assume HTTP/S or other URLs are File URIs
    return gcl.Part(
      fileData: gcl.FileData(
        mimeType: media.contentType ?? 'application/octet-stream',
        fileUri: media.url,
      ),
    );
  }
  if (p.isCustom && p.custom!['codeExecutionResult'] != null) {
    p as CustomPart;
    return gcl.Part(
      codeExecutionResult: gcl.CodeExecutionResult.fromJson(
        p.custom['codeExecutionResult'],
      ),
    );
  }
  if (p.isCustom && p.custom!['executableCode'] != null) {
    p as CustomPart;
    return gcl.Part(
      executableCode: gcl.ExecutableCode.fromJson(p.custom['executableCode']),
    );
  }
  throw UnimplementedError('Unsupported part type: $p');
}

@visibleForTesting
Part fromGeminiPart(gcl.Part p) {
  if (p.text != null) {
    return TextPart(text: p.text!);
  }
  if (p.functionCall != null) {
    return ToolRequestPart(
      toolRequest: ToolRequest(
        name: p.functionCall!.name,
        input: p.functionCall!.args?.toJson() as Map<String, dynamic>?,
      ),
    );
  }
  if (p.codeExecutionResult != null) {
    return CustomPart(
      custom: {
        'codeExecutionResult':
            p.codeExecutionResult!.toJson() as Map<String, dynamic>,
      },
    );
  }
  if (p.executableCode != null) {
    return CustomPart(
      custom: {
        'executableCode': p.executableCode!.toJson() as Map<String, dynamic>,
      },
    );
  }
  if (p.inlineData != null) {
    return MediaPart(
      media: Media(
        url:
            'data:${p.inlineData!.mimeType};base64,${base64Encode(p.inlineData!.data)}',
        contentType: p.inlineData!.mimeType,
      ),
    );
  }
  throw UnimplementedError('Unsupported part type: ${p.toJson()}');
}

gcl.Tool _toGeminiTool(ToolDefinition tool) {
  return gcl.Tool(
    functionDeclarations: [
      gcl.FunctionDeclaration(
        name: tool.name,
        description: tool.description,
        parametersJsonSchema: tool.inputSchema == null
            ? null
            : pb.Value.fromJson(tool.inputSchema),
      ),
    ],
  );
}
