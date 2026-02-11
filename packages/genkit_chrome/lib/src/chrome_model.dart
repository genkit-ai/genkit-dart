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
    // Availability check
    if (languageModel == null) {
      throw GenkitException(
        'Chrome AI is not available (LanguageModel is undefined).\n'
        'To enable local AI in Chrome (v128+):\n'
        '1. Go to chrome://flags/\n'
        '2. Enable "Prompt API for Gemini Nano"\n'
        '3. Enable "Enables optimization guide on device" (choose "Enabled BypassPerfRequirement")\n'
        '4. Relaunch Chrome\n'
        '5. Go to chrome://components/ to download the model ("Optimization Guide On Device Model")',
        status: StatusCodes.UNAVAILABLE,
      );
    }
    final availability = (await languageModel!.availability().toDart).toDart;
    if (availability == 'no') {
      throw GenkitException(
        'Chrome AI is not available.',
        status: StatusCodes.UNAVAILABLE,
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
    );

    final session = await languageModel!.create(options).toDart;

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
