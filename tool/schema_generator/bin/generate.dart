import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:schema_generator/src/class_generator.dart';

void main() async {
  final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/firebase/genkit/refs/heads/main/genkit-tools/genkit-schema.json'));

  if (response.statusCode == 200) {
    final schema = json.decode(response.body) as Map<String, dynamic>;
    final definitions = schema['\$defs'] as Map<String, dynamic>;

    final allowlist = [
      'Candidate',
      'Message',
      'ToolDefinition',
      'Part',
      'TextPart',
      'MediaPart',
      'ToolRequestPart',
      'ToolResponsePart',
      'DataPart',
      'CustomPart',
      'ReasoningPart',
      'ResourcePart',
      'Media',
      'ToolRequest',
      'ToolResponse',
      'GenerateRequest',
      'GenerateResponse',
      'GenerateResponseChunk',
      'GenerationUsage',
      'Operation',
      'OutputConfig',
      'FinishReason',
      'Role',
      'DocumentData',
    ];

    final classGenerator = ClassGenerator(definitions);
    final generatedClasses = classGenerator.generate(allowlist.toSet());

    final outputFile = File('lib/src/genkit_schemas.dart');
    await outputFile.writeAsString(generatedClasses);
    print('Successfully generated lib/src/genkit_schemas.dart');
  } else {
    throw Exception('Failed to fetch schema');
  }
}
