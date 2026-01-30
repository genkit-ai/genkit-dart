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

import 'dart:convert';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:test/test.dart';

void main() {
  group('toGeminiPart', () {
    test('converts text part', () {
      final part = TextPart(text: 'hello');
      final geminiPart = toGeminiPart(part);
      expect(geminiPart.text, 'hello');
    });

    test('converts media part with data URI', () {
      final data = 'SGVsbG8='; // "Hello" in base64
      final part = MediaPart(
        media: Media(
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
      final part = MediaPart(
        media: Media(
          url: 'https://example.com/image.png',
          contentType: 'image/png',
        ),
      );
      final geminiPart = toGeminiPart(part);
      expect(geminiPart.fileData, isNotNull);
      expect(geminiPart.fileData!.mimeType, 'image/png');
      expect(geminiPart.fileData!.fileUri, 'https://example.com/image.png');
    });
  });
}
