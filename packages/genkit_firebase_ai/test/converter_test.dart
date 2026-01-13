import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart' as m;
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toGeminiPart', () {
    test('converts text part', () {
      final part = TextPart.from(text: 'hello');
      final geminiPart = toGeminiPart(part);
      expect(geminiPart, isA<m.TextPart>());
      expect((geminiPart as m.TextPart).text, 'hello');
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
      expect(geminiPart, isA<m.InlineDataPart>());
      final inline = geminiPart as m.InlineDataPart;
      expect(inline.mimeType, 'text/plain');
      expect(utf8.decode(inline.bytes), 'Hello');
    });

    test('converts http/s media URL to FileData', () {
      final part = MediaPart.from(
        media: Media.from(
            url: 'https://example.com/image.png', contentType: 'image/png'),
      );
      final geminiPart = toGeminiPart(part);
      expect(geminiPart, isA<m.FileData>());
      final fileData = geminiPart as m.FileData;
      expect(fileData.mimeType, 'image/png');
      expect(fileData.fileUri, 'https://example.com/image.png');
    });
  });
}
