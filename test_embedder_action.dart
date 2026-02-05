import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'dart:io';

void main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('No GEMINI_API_KEY');
    return;
  }
  
  final plugin = googleAI(apiKey: apiKey);
  final actions = await plugin.list();
  
  for (var action in actions) {
    if (action.actionType == 'embedder') {
      print('Embedder found: \${action.name}');
    }
  }
  
  final embedder = plugin.resolve('embedder', 'text-embedding-004');
  if (embedder != null) {
    print('Embedder resolved: \${embedder.name}');
  } else {
    print('Failed to resolve embedder');
  }
}
