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

import 'dart:js_interop';
import 'package:genkit/genkit.dart';
import 'chrome_interop.dart';

class ChromeModel extends Model<LanguageModelOptions> {
  ChromeModel({
    super.name = 'chrome/gemini-nano',
    LanguageModelOptions? options,
  }) : super(
         metadata: {
           'model': ModelInfo(
             supports: {
               'multiturn': true,
               'media': false,
               'tools': false,
               'systemRole': true,
             },
           ).toJson(),
         },
         fn: (req, ctx) => _processRequest(req, ctx, options),
       );

  static Future<LanguageModelParams> getParams() {
    return _languageModel.params().toDart;
  }

  static Future<ModelResponse> _processRequest(
    ModelRequest? req,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    LanguageModelOptions? defaultOptions,
  ) async {
    if (req == null) {
      throw GenkitException(
        'Request is null',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final config = req.config ?? const {};
    final systemPrompt =
        config['systemPrompt'] as String? ?? defaultOptions?.systemPrompt;

    final initialPrompts = <LanguageModelInitialPrompt>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      initialPrompts.add(
        LanguageModelInitialPrompt(role: 'system', content: systemPrompt),
      );
    }

    // Add all messages except the last one to initialPrompts
    if (req.messages.isNotEmpty) {
      for (final m in req.messages.take(req.messages.length - 1)) {
        initialPrompts.add(
          LanguageModelInitialPrompt(
            role: m.role == Role.model ? 'assistant' : m.role.value,
            content: m.content.map((p) => p.text).join(' '),
          ),
        );
      }
    }

    final options = LanguageModelOptions(
      temperature: config['temperature'] as num? ?? defaultOptions?.temperature,
      topK: config['topK'] as num? ?? defaultOptions?.topK,
      initialPrompts: initialPrompts,
      expectedInputs:
          _parseExpectedInputs(config) ??
          defaultOptions?.expectedInputs?.toDart,
      expectedOutputs:
          _parseExpectedOutputs(config) ??
          defaultOptions?.expectedOutputs?.toDart,
    );

    // Availability check
    await _ensureAvailability(options);

    final session = await _languageModel.create(options).toDart;

    try {
      final prompt = req.messages.isEmpty
          ? ''
          : req.messages.last.content.map((p) => p.text).join(' ');

      String? lastResponseText;
      if (ctx.streamingRequested) {
        final stream = session.promptStreaming(prompt);
        final reader = stream.getReader();
        while (true) {
          final result = await reader.read().toDart;
          if (result.done.toDart) break;
          final chunkText = result.value?.toDart ?? '';
          ctx.sendChunk(
            ModelResponseChunk(index: 0, content: [TextPart(text: chunkText)]),
          );
          lastResponseText = (lastResponseText ?? '') + chunkText;
        }
      } else {
        lastResponseText = (await session.prompt(prompt).toDart).toDart;
      }

      // Collect usage stats
      // tokensSoFar and inputUsage are likely the same (renamed)
      final inputTokens = (session.inputUsage ?? session.tokensSoFar)
          ?.toDouble();
      // We don't have output tokens from the session directly usually
      // Quota is maxTokens or inputQuota
      // final totalTokens = session.maxTokens ?? session.inputQuota;

      return ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: lastResponseText ?? '')],
        ),
        usage: inputTokens != null
            ? GenerationUsage(
                inputTokens: inputTokens,
                outputTokens: 0, // Not available directly
                totalTokens: inputTokens,
              )
            : null,
      );
    } finally {
      session.destroy();
    }
  }
}

Future<void> _ensureAvailability([LanguageModelOptions? options]) async {
  final availability =
      (await _languageModel.availability(options).toDart).toDart;
  if (availability == 'no') {
    throw GenkitException(
      'Chrome AI is not available.',
      status: StatusCodes.UNAVAILABLE,
    );
  }
}

LanguageModelFactory get _languageModel {
  if (languageModelImpl == null) {
    throw GenkitException(
      '''
Chrome AI is not available (LanguageModel is undefined).
To enable local AI in Chrome (v128+):
1. Go to chrome://flags/
2. Enable "Prompt API for Gemini Nano"
3. Enable "Enables optimization guide on device" (choose "Enabled BypassPerfRequirement")
4. Relaunch Chrome
5. Go to chrome://components/ to download the model ("Optimization Guide On Device Model")''',
      status: StatusCodes.UNAVAILABLE,
    );
  }
  return languageModelImpl!;
}

List<T>? _parseExpected<T>({
  required Map<String, dynamic> config,
  required String key,
  required T Function({String type, JSArray<JSString>? languages}) constructor,
}) {
  final items = config[key];
  if (items is List) {
    return items.map((e) {
      if (e is Map) {
        return constructor(
          type: e['type'] as String? ?? 'text',
          languages: (e['languages'] as List?)
              ?.map((l) => (l as String).toJS)
              .toList()
              .toJS,
        );
      }
      throw ArgumentError('Invalid item in $key: $e');
    }).toList();
  }
  return null;
}

List<LanguageModelExpectedInput>? _parseExpectedInputs(
  Map<String, dynamic> config,
) {
  return _parseExpected(
    config: config,
    key: 'expectedInputs',
    constructor: ({String type = '', JSArray<JSString>? languages}) =>
        LanguageModelExpectedInput(type: type, languages: languages),
  );
}

List<LanguageModelExpectedOutput>? _parseExpectedOutputs(
  Map<String, dynamic> config,
) {
  return _parseExpected(
    config: config,
    key: 'expectedOutputs',
    constructor: ({String type = '', JSArray<JSString>? languages}) =>
        LanguageModelExpectedOutput(type: type, languages: languages),
  );
}
