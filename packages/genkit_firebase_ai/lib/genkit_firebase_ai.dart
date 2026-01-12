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

import 'package:meta/meta.dart';
import 'package:firebase_ai/firebase_ai.dart' as m;
import 'package:genkit/genkit.dart';

part 'genkit_firebase_ai.schema.g.dart';

@GenkitSchema()
abstract class GeminiOptionsSchema {
  int get maxOutputTokens;
  int get temperature;
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
    ];
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType != 'model') return null;
    return _createModel(name);
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
            maxOutputTokens: req.config?['maxOutputTokens'] as int?,
            temperature: (req.config?['temperature'] as num?)?.toDouble(),
          ),
        );

        final response = await model.generateContent(
          toGeminiContent(req.messages),
          tools: req.tools?.map(toGeminiTool).toList(),
        );

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
}

// ... class definitions ...

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
    // Firebase AI expects a FunctionResponse part.
    return m.FunctionResponse(
      p.toolResponse.name,
      {'result': p.toolResponse.output},
    );
  }
  // ToolRequest is usually handled by the model response, not sent by user.
  // But if we are sending history (context), we might need to send ToolRequests (function calls) made by assistant.
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
  throw UnimplementedError('Part type $p not supported yet in response');
}

@visibleForTesting
m.Tool toGeminiTool(ToolDefinition tool) {
  final schemaMap = tool.inputSchema as Map<String, dynamic>;
  final propertiesMap = schemaMap['properties'] as Map<String, dynamic>? ?? {};

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
