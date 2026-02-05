import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart' as gcl;
import 'dart:io';

void main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) { print("NO API KEY"); return; }
  final service = gcl.ModelService.fromApiKey(apiKey);
  final res = await service.listModels(gcl.ListModelsRequest(pageSize: 100));
  print(res.models.map((m) => m.name).toList());
}
