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

import 'dart:async';
import 'dart:io';

import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'secret.dart';

FutureOr<Map<String, dynamic>> authContextProvider(Request request) {
  final authHeader = request.headers['authorization'];
  if (authHeader != 'Bearer $secret') {
    throw Exception('Unauthorized');
  }
  return {'auth': true};
}

void main() async {
  final geminiApi = googleAI(apiKey: Platform.environment['GEMINI_API_KEY']!);
  final geminiModel = geminiApi.model('gemini-3.1-pro-preview');

  final openAIApi = openAI(apiKey: Platform.environment['OPENAI_API_KEY']!);
  final gpt4oModel = openAIApi.model('gpt-4o');

  final router = Router();

  router.post(
    '/gemini-3.1',
    shelfHandler(geminiModel, contextProvider: authContextProvider),
  );
  router.post(
    '/gpt-4o',
    shelfHandler(gpt4oModel, contextProvider: authContextProvider),
  );

  final server = await io.serve(router.call, 'localhost', 8080);
  print('Server running on http://localhost:${server.port}');
}
