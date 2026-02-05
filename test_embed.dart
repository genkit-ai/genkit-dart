import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart' as gcl;
import 'dart:io';

void main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('No GEMINI_API_KEY');
    return;
  }
  final service = gcl.GenerativeService.fromApiKey(apiKey);
  final req = gcl.EmbedContentRequest(model: 'models/text-embedding-004', content: gcl.Content(parts: [gcl.Part(text: 'Hello world')]));
  final res = await service.embedContent(req);
  print(res.embedding?.values);
}
