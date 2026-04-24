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

import 'package:schemantic/schemantic.dart';

part 'model.g.dart';

@Schema()
abstract class $GeminiOptions {
  String? get apiKey;
  // TODO: Add apiVersion, baseUrl
  // String? get apiVersion;
  // String? get baseUrl;

  List<$SafetySettings>? get safetySettings;

  bool? get codeExecution;
  $FunctionCallingConfig? get functionCallingConfig;
  $ThinkingConfig? get thinkingConfig;
  List<String>? get responseModalities;

  // Retrieval
  $GoogleSearch? get googleSearch;
  $FileSearch? get fileSearch;
  // TODO: Add urlContext if needed, structure unclear from proto/zod vs usage

  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  int? get topK;
  int? get candidateCount;
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  String? get responseMimeType;
  bool? get responseLogprobs;
  int? get logprobs;
  double? get presencePenalty;
  double? get frequencyPenalty;
  int? get seed;

  $SpeechConfig? get speechConfig;
}

@Schema()
abstract class $ImagenOptions {
  String? get apiKey;

  @IntegerField(minimum: 1, maximum: 4)
  int? get numberOfImages;

  @StringField(
    enumValues: ['1:1', '9:16', '16:9', '3:4', '4:3'],
    description: 'Aspect ratio of the generated image.',
  )
  String? get aspectRatio;

  @StringField(
    enumValues: ['dont_allow', 'allow_adult', 'allow_all'],
    description: 'Controls generation of people.',
  )
  String? get personGeneration;
}

@Schema()
abstract class $SafetySettings {
  @StringField(
    enumValues: [
      'HARM_CATEGORY_UNSPECIFIED',
      'HARM_CATEGORY_HATE_SPEECH',
      'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'HARM_CATEGORY_HARASSMENT',
      'HARM_CATEGORY_DANGEROUS_CONTENT',
      'HARM_CATEGORY_CIVIC_INTEGRITY',
    ],
  )
  String? get category;

  @StringField(
    enumValues: [
      'BLOCK_LOW_AND_ABOVE',
      'BLOCK_MEDIUM_AND_ABOVE',
      'BLOCK_ONLY_HIGH',
      'BLOCK_NONE',
    ],
  )
  String? get threshold;
}

@Schema()
abstract class $ThinkingConfig {
  @Field(
    description:
        'Indicates whether to include thoughts in the response.'
        'If true, thoughts are returned only when available.',
  )
  bool? get includeThoughts;

  @IntegerField(
    minimum: 0,
    maximum: 24576,
    description:
        'The thinking budget parameter gives the model guidance on the '
        'number of thinking tokens it can use when generating a response. '
        'A greater number of tokens is typically associated with more detailed '
        'thinking, which is needed for solving more complex tasks. '
        'Setting the thinking budget to 0 disables thinking.',
  )
  int? get thinkingBudget;

  @StringField(
    enumValues: ['MINIMAL', 'LOW', 'MEDIUM', 'HIGH'],
    description:
        'For Gemini 3.0 - Indicates the thinking level. A higher level '
        'is associated with more detailed thinking, which is needed for solving '
        'more complex tasks.',
  )
  String? get thinkingLevel;
}

@Schema()
abstract class $FunctionCallingConfig {
  @StringField(enumValues: ['MODE_UNSPECIFIED', 'AUTO', 'ANY', 'NONE'])
  String? get mode;
  List<String>? get allowedFunctionNames;
}

@Schema()
abstract class $FileSearch {
  List<String>? get fileSearchStoreNames;
}

@Schema()
abstract class $GeminiTtsOptions {
  String? get apiKey;
  // TODO: Add apiVersion, baseUrl
  // String? get apiVersion;
  // String? get baseUrl;

  List<$SafetySettings>? get safetySettings;

  bool? get codeExecution;
  $FunctionCallingConfig? get functionCallingConfig;
  $ThinkingConfig? get thinkingConfig;
  List<String>? get responseModalities;

  // Retrieval
  $GoogleSearch? get googleSearch;
  $FileSearch? get fileSearch;
  // TODO: Add urlContext if needed, structure unclear from proto/zod vs usage

  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  int? get topK;
  int? get candidateCount;
  List<String>? get stopSequences;
  int? get maxOutputTokens;

  String? get responseMimeType;
  bool? get responseLogprobs;
  int? get logprobs;
  double? get presencePenalty;
  double? get frequencyPenalty;
  int? get seed;

  $SpeechConfig? get speechConfig;
}

@Schema(description: 'Speech generation config')
abstract class $SpeechConfig {
  $VoiceConfig? get voiceConfig;
  $MultiSpeakerVoiceConfig? get multiSpeakerVoiceConfig;
}

@Schema(description: 'Configuration for multi-speaker setup')
abstract class $MultiSpeakerVoiceConfig {
  @Field(description: 'Configuration for all the enabled speaker voices')
  List<$SpeakerVoiceConfig> get speakerVoiceConfigs;
}

@Schema(
  description: 'Configuration for a single speaker in a multi speaker setup',
)
abstract class $SpeakerVoiceConfig {
  @StringField(description: 'Name of the speaker to use')
  String get speaker;

  $VoiceConfig get voiceConfig;
}

@Schema(description: 'Configuration for the voice to use')
abstract class $VoiceConfig {
  $PrebuiltVoiceConfig? get prebuiltVoiceConfig;
}

@Schema(description: 'Configuration for the prebuilt speaker to use')
abstract class $PrebuiltVoiceConfig {
  @StringField(
    description:
        'Name of the preset voice to use. '
        'Known values: Zephyr, Puck, Charon, Kore, Fenrir, Leda, Orus, Aoede, '
        'Callirrhoe, Autonoe, Enceladus, Iapetus, Umbriel, Algieba, Despina, '
        'Erinome, Algenib, Rasalgethi, Laomedeia, Achernar, Alnilam, Schedar, '
        'Gacrux, Pulcherrima, Achird, Zubenelgenubi, Vindemiatrix, Sadachbia, '
        'Sadaltager, Sulafat',
  )
  String? get voiceName;
}

@Schema()
abstract class $GoogleSearch {
  // TODO: Add timeRangeFilter or other configurations if needed
}

@Schema()
abstract class $TextEmbedderOptions {
  @IntegerField(
    description:
        'Optional. reduced dimension for the output embedding. If set, excessive values in the output embedding are truncated from the end.',
  )
  int? get outputDimensionality;

  @StringField(
    description:
        'Optional. Optional task type for which the embedding will be used. Can only be set for models/text-embedding-004.',
    enumValues: [
      'TASK_TYPE_UNSPECIFIED',
      'RETRIEVAL_QUERY',
      'RETRIEVAL_DOCUMENT',
      'SEMANTIC_SIMILARITY',
      'CLASSIFICATION',
      'CLUSTERING',
      'QUESTION_ANSWERING',
      'FACT_VERIFICATION',
      'CODE_RETRIEVAL_QUERY',
    ],
  )
  String? get taskType;

  String? get title;
}
