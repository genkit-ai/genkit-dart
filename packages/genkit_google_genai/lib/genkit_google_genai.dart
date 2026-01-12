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

import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as gcl;
import 'package:genkit/genkit.dart';
import 'package:google_cloud_protobuf/protobuf.dart' as pb;

part 'genkit_google_genai.schema.g.dart';

@GenkitSchema()
abstract class GeminiOptionsSchema {
  int get maxOutputTokens;
  int get temperature;
}

typedef GoogleGenAiPluginOptions = ();

const GoogleGenAiPluginHandle googleAI = GoogleGenAiPluginHandle();

class GoogleGenAiPluginHandle {
  const GoogleGenAiPluginHandle();

  GenkitPlugin call({String? apiKey}) {
    return _GoogleGenAiPlugin(apiKey: apiKey);
  }

  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('googleai/$name', customOptions: GeminiOptionsType);
  }
}

class _GoogleGenAiPlugin extends GenkitPlugin {
  @override
  String get name => 'googleai';

  String? apiKey;

  _GoogleGenAiPlugin({this.apiKey});

  @override
  Future<List<Action>> init() async {
    return [
      _createModel('gemini-1.5-flash-latest'),
      _createModel('gemini-1.5-pro-latest'),
    ];
  }

  @override
  Action? resolve(String actionType, String name) {
    return _createModel(name);
  }

  Model _createModel(String modelName) {
    return Model(
      name: 'googleai/$modelName',
      fn: (req, ctx) async {
        final service = gcl.GenerativeService.fromApiKey(apiKey);
        try {
          final response = await service.generateContent(
            gcl.GenerateContentRequest(
              model: 'models/$modelName',
              contents: _toGeminiContent(req!.messages),
              tools: req.tools?.map(_toGeminiTool).toList() ?? [],
            ),
          );
          final (message, finishReason) = _fromGeminiCandidate(
            response.candidates.first,
          );
          return ModelResponse.from(
            finishReason: finishReason,
            message: message,
            raw: jsonDecode(jsonEncode(response)),
          );
        } finally {
          service.close();
        }
      },
    );
  }
}

List<gcl.Content> _toGeminiContent(List<Message> messages) {
  return messages
      .map(
        (m) => gcl.Content(
          role: m.role.value,
          parts: m.content.map(_toGeminiPart).toList(),
        ),
      )
      .toList();
}

(Message, FinishReason) _fromGeminiCandidate(gcl.Candidate candidate) {
  final finishReason = FinishReason(candidate.finishReason.value);
  final message = Message.from(
    role: Role(candidate.content!.role),
    content: candidate.content?.parts.map(_fromGeminiPart).toList() ?? [],
  );
  return (message, finishReason);
}

gcl.Part _toGeminiPart(Part p) {
  if (p.isText) {
    p as TextPart;
    return gcl.Part(text: p.text);
  }
  if (p.isToolRequest) {
    p as ToolRequestPart;
    return gcl.Part(
      functionCall: gcl.FunctionCall(
        name: p.toolRequest.name,
        args: p.toolRequest.input == null
            ? null
            : pb.Struct.fromJson(p.toolRequest.input!),
      ),
    );
  }
  if (p.isToolResponse) {
    p as ToolResponsePart;
    return gcl.Part(
      functionResponse: gcl.FunctionResponse(
        name: p.toolResponse.name,
        response: pb.Struct.fromJson({'output': p.toolResponse.output}),
      ),
    );
  }
  throw UnimplementedError('Unsupported part type: $p');
}

Part _fromGeminiPart(gcl.Part p) {
  if (p.text != null) {
    return TextPart.from(text: p.text!);
  }
  if (p.functionCall != null) {
    return ToolRequestPart.from(
      toolRequest: ToolRequest.from(
        name: p.functionCall!.name,
        input: p.functionCall!.args?.toJson() as Map<String, dynamic>?,
      ),
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
        parametersJsonSchema: tool.inputSchema == null
            ? null
            : pb.Value.fromJson(tool.inputSchema as Map<String, dynamic>),
      ),
    ],
  );
}
