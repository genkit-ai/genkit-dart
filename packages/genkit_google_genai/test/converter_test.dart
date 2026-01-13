import 'dart:convert';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as gcl;
import 'package:test/test.dart';

void main() {
  group('toGeminiPart', () {
    test('converts text part', () {
      final part = TextPart.from(text: 'hello');
      final geminiPart = toGeminiPart(part);
      expect(geminiPart.text, 'hello');
    });

    test('converts media part with data URI', () {
      final data = 'SGVsbG8='; // "Hello" in base64
      final part = MediaPart.from(
        media: Media.from(
          url: 'data:text/plain;base64,$data',
          contentType: 'text/plain',
        ),
      );
      final geminiPart = toGeminiPart(part);
      expect(geminiPart.inlineData, isNotNull);
      expect(geminiPart.inlineData!.mimeType, 'text/plain');
      // Verify data is bytes
      expect(utf8.decode(geminiPart.inlineData!.data), 'Hello');
    });

    test('converts http/s media URL to FileData', () {
      final part = MediaPart.from(
        media: Media.from(
            url: 'https://example.com/image.png', contentType: 'image/png'),
      );
      final geminiPart = toGeminiPart(part);
      expect(geminiPart.fileData, isNotNull);
      expect(geminiPart.fileData!.mimeType, 'image/png');
      expect(geminiPart.fileData!.fileUri, 'https://example.com/image.png');
    });
  });
}
