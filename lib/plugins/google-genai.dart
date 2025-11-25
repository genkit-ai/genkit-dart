import 'dart:convert';
import 'dart:io';
import 'package:genkit/src/ai/model.dart';
import 'package:http/http.dart' as http;

import 'package:genkit/genkit.dart';
import 'package:genkit/src/core/plugin.dart';

GenkitPlugin googleAI() {
  return _GoogleGenAiPlugin();
}

class _GoogleGenAiPlugin extends GenkitPlugin {
  @override
  String get name => 'googleai';

  @override
  Future<List<ResolvableAction>> init() async {
    final model = Model(
      name: 'googleai/gemini-2.5-flash',
      fn: (req, ctx) async {
        final apiKey = Platform.environment['GEMINI_API_KEY'];
        if (apiKey == null) {
          throw Exception('GEMINI_API_KEY is not set');
        }
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
        );
        final response = await http.post(
          url,
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
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
    return [(action: model)];
  }
}
