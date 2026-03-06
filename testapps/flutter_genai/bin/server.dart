import 'dart:io';

import 'package:flutter_genai/types.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final googleApiKey = Platform.environment['GEMINI_API_KEY'];
  final openAiApiKey = Platform.environment['OPENAI_API_KEY'];

  final ai = Genkit(
    plugins: [
      googleAI(apiKey: googleApiKey ?? ''),
      openAI(apiKey: openAiApiKey ?? ''),
    ],
  );

  final serverFlow = ai.defineFlow(
    name: 'serverFlow',
    inputSchema: ServerFlowInput.$schema,
    outputSchema: .string(),
    fn: (ServerFlowInput input, _) async {
      final model = input.provider == 'google'
          ? googleAI.gemini('gemini-2.5-flash')
          : openAI.model('gpt-4o');

      final response = await ai.generate(model: model, prompt: input.prompt);
      return response.text;
    },
  );

  final geminiModel = googleAI(apiKey: googleApiKey).model('gemini-2.5-flash');
  final openAiModel = openAI(apiKey: openAiApiKey).model('gpt-4o');

  final router = Router();

  router.post('/googleai/gemini-2.5-flash', shelfHandler(geminiModel));
  router.post('/openai/gpt-4o', shelfHandler(openAiModel));
  router.post('/serverFlow', shelfHandler(serverFlow));
  router.get('/health', (Request request) => Response.ok('OK'));

  Handler handler = router.call;
  handler = const Pipeline()
      .addMiddleware((innerHandler) {
        return (request) async {
          if (request.method == 'OPTIONS') {
            return Response.ok(
              '',
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
              },
            );
          }

          try {
            final response = await innerHandler(request);
            return response.change(
              headers: {
                'Access-Control-Allow-Origin': '*',
                ...response.headers,
              },
            );
          } catch (e) {
            rethrow;
          }
        };
      })
      .addHandler(handler);

  // ignore: avoid_print
  print('Starting flow server with shelfHandler on port 8080...');

  await io.serve(handler, 'localhost', 8080);
}
