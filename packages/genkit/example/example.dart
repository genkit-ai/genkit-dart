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
// import plugin
// import 'package:genkit_google_genai/genkit_google_genai.dart';
// import 'package:genkit_anthropic/genkit_anthropic.dart';
// import 'package:genkit_openai/genkit_openai.dart';

void main() async {
  // Initialize Genkit
  final ai = Genkit(
    plugins: [
      // install plugin:
      //
      // googleAI(),
      // anthropic(),
      // openAI(),
    ],
  );

  // Define a simple flow
  final basicFlow = ai.defineFlow(
    name: 'basic',
    inputSchema: .string(defaultValue: 'World'),
    outputSchema: .string(),
    fn: (String subject, _) async {
      // call generate action:
      //
      // final response = await ai.generate(
      //   model: googleAI.gemini('gemini-flash-latest'),
      //   prompt: 'Say hello to $subject!',
      // );
      // return response.text;
      return 'hello $subject';
    },
  );

  // Run the flow directly
  final result = await basicFlow('World');
  print(result);
}
