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

import 'package:genkit/genkit.dart';

void main() async {
  final ai = Genkit();

  final gemini = ai.defineRemoteModel(
    name: 'remote-gemini',
    url: 'http://localhost:8080/gemini-3.1',
    headers: (context) => {'Authorization': 'Bearer super-secret'},
  );

  final gpt = ai.defineRemoteModel(
    name: 'remote-gpt',
    url: 'http://localhost:8080/gpt-4o',
    headers: (context) => {'Authorization': 'Bearer super-secret'},
  );

  final myFlow = ai.defineFlow(
    name: 'remoteModelFlow',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (String input, _) async {
      print('Calling Gemini remote model...');
      final geminiRes = await ai.generate(model: gemini, prompt: input);
      print('Gemini Output: ${geminiRes.text}');

      print('Calling GPT-4o remote model...');
      final gptRes = await ai.generate(model: gpt, prompt: input);
      print('GPT-4o Output: ${gptRes.text}');

      return 'Success!\nGemini: ${geminiRes.text}\nGPT-4o: ${gptRes.text}';
    },
  );

  print('Executing flow...');
  final result = await myFlow('Why did the remote model cross the road?');
  print('Flow result:\n$result');
}
