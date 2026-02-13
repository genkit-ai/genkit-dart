import 'dart:io';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_middleware/filesystem.dart';
import 'package:genkit_middleware/skills.dart';
import 'package:schemantic/schemantic.dart';

void main() async {
  configureCollectorExporter();

  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('GEMINI_API_KEY environment variable is required.');
    print('Please set it in your environment or .env file');
    exit(1);
  }

  // Create plugin instances
  final middlewarePlugin = FilesystemPlugin();
  final skillsPlugin = SkillsPlugin();

  final ai = Genkit(plugins: [googleAI(apiKey: apiKey), middlewarePlugin, skillsPlugin]);

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
