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

import 'package:firebase_ai/firebase_ai.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

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
          url: 'https://example.com/image.png',
          contentType: 'image/png',
        ),
      );
      final geminiPart = toGeminiPart(part);
      expect(geminiPart, isA<m.FileData>());
      final fileData = geminiPart as m.FileData;
      expect(fileData.mimeType, 'image/png');
      expect(fileData.fileUri, 'https://example.com/image.png');
    });
  });
}
