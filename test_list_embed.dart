import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart' as gcl;
import 'dart:io';

void main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('No GEMINI_API_KEY');
    return;
  }
  print('API Key: ${apiKey.substring(0, 5)}...${apiKey.substring(apiKey.length - 5)}');
  final service = gcl.ModelService.fromApiKey(apiKey);
  try {
    final res = await service.listModels(gcl.ListModelsRequest(pageSize: 100));
    print('Models count: ${res.models.length}');
    for (var m in res.models) {
      if (m.name.contains('embed')) {
        print(m.name);
      }
    }
  } catch (e) {
    print(e);
  }
}
