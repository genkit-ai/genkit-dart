import 'package:genkit_google_genai/src/plugin_impl.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleGenAiPluginImpl', () {
    test('resolve returns embedder action', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('embedder', 'text-embedding-004');
      expect(action, isNotNull);
      expect(action!.name, 'googleai/text-embedding-004');
    });

    test('resolve returns null for unknown action type', () {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('unknown', 'text-embedding-004');
      expect(action, isNull);
    });
  });
}
