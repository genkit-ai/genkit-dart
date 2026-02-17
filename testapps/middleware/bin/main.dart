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
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_middleware/filesystem.dart';
import 'package:genkit_middleware/skills.dart';
import 'package:schemantic/schemantic.dart';

void main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('GEMINI_API_KEY environment variable is required.');
    print('Please set it in your environment or .env file');
    exit(1);
  }

  // Create plugin instances
  final middlewarePlugin = FilesystemPlugin();
  final skillsPlugin = SkillsPlugin();

  final ai = Genkit(
    plugins: [
      googleAI(apiKey: apiKey),
      middlewarePlugin,
      skillsPlugin,
    ],
  );

  ai.defineFlow(
    name: 'agenticFlow',
    inputSchema: stringSchema(
      defaultValue:
          'Create a new file "hello.dart" in the filesystem with a simple main function printing hello world. Use skills as needed.',
    ),
    outputSchema: stringSchema(),
    fn: (input, context) async {
      // Resolve paths relative to the script execution (assumed run from package root)
      final currentDir = Directory.current.path;
      // Assuming script is run from package root (testapps/middleware)
      final fsRoot = '$currentDir/fs_root';
      final skillsRoot = '$currentDir/skills';

      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: input,
        use: [
          filesystem(rootDirectory: fsRoot),
          skills(skillPaths: [skillsRoot]),
        ],
      );
      return response.text;
    },
  );
}
