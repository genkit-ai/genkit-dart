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

import 'package:genkit/src/ai/formatters/json.dart';
import 'package:genkit/src/ai/formatters/types.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:genkit/src/types.dart';

export 'package:genkit/src/ai/formatters/json.dart';
export 'package:genkit/src/ai/formatters/types.dart';

void configureFormats(Registry registry) {
  defineFormat(registry, jsonFormatter);
}

void defineFormat(Registry registry, Formatter formatter) {
  registry.registerValue('format', formatter.name, formatter);
}

Formatter? resolveFormat(
    Registry registry, GenerateActionOutputConfig? output) {
  if (output == null) return null;
  if (output.format != null) {
    return registry.lookupValue<Formatter>('format', output.format!);
  }
  if (output.jsonSchema != null) {
    return registry.lookupValue<Formatter>('format', 'json');
  }
  return null;
}

GenerateActionOptions applyFormat(
  GenerateActionOptions request,
  Formatter? formatter,
) {
  var outputConfig = request.output;
  if (outputConfig?.jsonSchema != null && outputConfig?.format == null) {
    outputConfig = GenerateActionOutputConfig.from(
      format: 'json',
      contentType: outputConfig?.contentType,
      instructions: outputConfig?.instructions,
      jsonSchema: outputConfig?.jsonSchema,
      constrained: outputConfig?.constrained,
    );
  }

  final instructions = resolveInstructions(
      formatter, outputConfig?.jsonSchema, outputConfig?.instructions);

  List<Message> messages = request.messages;

  if (formatter != null) {
    if (shouldInjectFormatInstructions(formatter.config, outputConfig)) {
      messages = injectInstructions(messages, instructions);
    }

    // Merge config
    outputConfig = GenerateActionOutputConfig.from(
      format: outputConfig?.format ?? formatter.config.format,
      contentType:
          outputConfig?.contentType ?? formatter.config.contentType,
      instructions:
          outputConfig?.instructions ?? formatter.config.instructions,
      jsonSchema: outputConfig?.jsonSchema ?? formatter.config.jsonSchema,
      constrained:
          outputConfig?.constrained ?? formatter.config.constrained,
    );
  }

  return GenerateActionOptions.from(
    messages: messages,
    model: request.model,
    config: request.config,
    tools: request.tools,
    toolChoice: request.toolChoice,
    output: outputConfig,
    docs: request.docs,
    resume: request.resume,
    returnToolRequests: request.returnToolRequests,
    maxTurns: request.maxTurns,
    stepName: request.stepName,
  );
}

String? resolveInstructions(Formatter? formatter,
    Map<String, dynamic>? schema, bool? instructionsOption) {
  if (instructionsOption == false) return null;
  if (formatter == null) return null;
  return formatter.handler(schema).instructions;
}

bool shouldInjectFormatInstructions(GenerateActionOutputConfig formatConfig,
    GenerateActionOutputConfig? requestConfig) {
  return formatConfig.instructions != false ||
      requestConfig?.instructions == true;
}

List<Message> injectInstructions(
    List<Message> messages, String? instructions) {
  if (instructions == null) return messages;

  bool hasOutputInstruction(Message m) {
    return m.content.any((p) {
      if (p is TextPart) {
        return p.metadata?['purpose'] == 'output' &&
            p.metadata?['pending'] != true;
      }
      return false;
    });
  }

  if (messages.any(hasOutputInstruction)) return messages;

  final newPart = TextPart.from(
    text: instructions,
    metadata: {'purpose': 'output'},
  );

  // Find last user message or system message
  int targetIndex = messages.lastIndexWhere((m) => m.role == Role.system);
  if (targetIndex < 0) {
    targetIndex = messages.lastIndexWhere((m) => m.role == Role.user);
  }

  if (targetIndex < 0) return messages;

  final targetMessage = messages[targetIndex];
  final newContent = List<Part>.from(targetMessage.content);

  final pendingIndex = newContent.indexWhere((p) =>
      p is TextPart &&
      p.metadata?['purpose'] == 'output' &&
      p.metadata?['pending'] == true);

  if (pendingIndex >= 0) {
    newContent[pendingIndex] = newPart;
  } else {
    newContent.add(newPart);
  }

  final newMessages = List<Message>.from(messages);
  newMessages[targetIndex] = Message.from(
    role: targetMessage.role,
    content: newContent,
    metadata: targetMessage.metadata,
  );

  return newMessages;
}
