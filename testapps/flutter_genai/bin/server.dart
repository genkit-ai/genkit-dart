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

import 'dart:io';

import 'package:flutter_genai/types.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final googleApiKey = Platform.environment['GEMINI_API_KEY'];
  final openAiApiKey = Platform.environment['OPENAI_API_KEY'];
  final anthropicApiKey = Platform.environment['ANTHROPIC_API_KEY'];

  final ai = Genkit(
    plugins: [
      googleAI(apiKey: googleApiKey ?? ''),
      openAI(apiKey: openAiApiKey ?? ''),
      anthropic(apiKey: anthropicApiKey ?? ''),
    ],
  );

  final serverFlow = ai.defineFlow(
    name: 'serverFlow',
    inputSchema: ServerFlowInput.$schema,
    outputSchema: .string(),
    fn: (ServerFlowInput input, _) async {
      final model = input.provider == 'google'
          ? googleAI.gemini('gemini-2.5-flash')
          : input.provider == 'openai'
          ? openAI.model('gpt-4o')
          : anthropic.model('claude-3-5-sonnet-latest');

      final response = await ai.generate(model: model, prompt: input.prompt);
      return response.text;
    },
  );

  final geminiModel = googleAI(apiKey: googleApiKey).model('gemini-2.5-flash');
  final openAiModel = openAI(apiKey: openAiApiKey).model('gpt-4o');
  final anthropicModel = anthropic(
    apiKey: anthropicApiKey,
  ).model('claude-3-5-sonnet-latest');

  final router = Router();

  router.post('/googleai/gemini-2.5-flash', shelfHandler(geminiModel));
  router.post('/openai/gpt-4o', shelfHandler(openAiModel));
  router.post(
    '/anthropic/claude-3-5-sonnet-latest',
    shelfHandler(anthropicModel),
  );
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
