import 'dart:convert';
import 'dart:io';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/core/action.dart';
import 'package:http/http.dart' as http;

import 'package:genkit/genkit.dart';
import 'package:genkit/src/core/plugin.dart';

part 'google_genai.schema.g.dart';

@GenkitSchema()
abstract class GeminiOptionsSchema {
  int get maxOutputTokens;
  int get temperature;
}

const GoogleGenAiPluginHandle googleAI = GoogleGenAiPluginHandle();

class GoogleGenAiPluginHandle {
  const GoogleGenAiPluginHandle();

  GenkitPlugin call() {
    return _GoogleGenAiPlugin();
  }

  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('googleai/$name', customOptions: GeminiOptionsType);
  }
}

class _GoogleGenAiPlugin extends GenkitPlugin {
  @override
  String get name => 'googleai';

  @override
  Future<List<Action>> init() async {
    return [
      createModel('gemini-2.5-flash'),
      createModel('gemini-2.5-pro'),
      createModel('gemini-3-pro-preview'),
    ];
  }

  @override
  Action? resolve(String actionType, String name) {
    return createModel(name);
  }
}

Model createModel(String modelName) {
  return Model(
    name: 'googleai/$modelName',
    fn: (req, ctx) async {
      final apiKey = Platform.environment['GEMINI_API_KEY'];
      if (apiKey == null) {
        throw Exception('GEMINI_API_KEY is not set');
      }
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent',
      );
      final response = await http.post(
        url,
        headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': req.messages.map((m) {
            return {
              'role': m.role.value,
              'parts': m.content.map((p) => p.toJson()).toList(),
            };
          }).toList(),
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to generate content: ${response.body}');
      }
      final responseJson = jsonDecode(response.body);
      final candidate = responseJson['candidates'][0];
      return ModelResponse.from(
        finishReason: FinishReason(candidate['finishReason']),
        message: Message.from(
          role: Role(candidate['content']['role']),
          content: (candidate['content']['parts'] as List<dynamic>)
              .map((p) => TextPart.from(text: p['text']))
              .toList(),
        ),
      );
    },
  );
}
