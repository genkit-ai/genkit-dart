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

import 'package:genkit/client.dart';
import 'package:test/test.dart';

void main() {
  group('Schema Extensions', () {
    test('Message text getter', () {
      final message = Message(
        role: Role.user,
        content: [
          TextPart(text: 'Hello, '),
          TextPart(text: 'world!'),
          // ignore: unnecessary_type_check
          MediaPart(media: Media(url: 'http://example.com/image.png')),
        ],
      );
      expect(message.text, 'Hello, world!');
    });

    test('Message text getter with no text parts', () {
      final message = Message(
        role: Role.user,
        content: [
          // ignore: unnecessary_type_check
          MediaPart(media: Media(url: 'http://example.com/image.png')),
        ],
      );
      expect(message.text, '');
    });

    test('Message text getter with empty content', () {
      final message = Message(role: Role.user, content: []);
      expect(message.text, '');
    });

    test('GenerateResponse text getter', () {
      final response = ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'Response text')],
        ),
      );
      expect(response.text, 'Response text');
    });

    test('GenerateResponse text getter with null message', () {
      final response = ModelResponse(
        finishReason: FinishReason.stop,
        message: null,
      );
      expect(response.text, '');
    });

    test('GenerateResponseChunk text getter', () {
      final chunk = ModelResponseChunk(content: [TextPart(text: 'Chunk text')]);
      expect(chunk.text, 'Chunk text');
    });

    test('Message media getter', () {
      final media = Media(url: 'http://example.com/image.png');
      final message = Message(
        role: Role.user,
        content: [
          TextPart(text: 'Hello, '),
          // ignore: unnecessary_type_check
          MediaPart(media: media),
        ],
      );
      expect(message.media!.toJson(), same(media.toJson()));
    });

    test('Message media getter with no media part', () {
      final message = Message(
        role: Role.user,
        content: [TextPart(text: 'Hello, ')],
      );
      expect(message.media, isNull);
    });

    test('Message media getter with null content', () {
      final message = Message(role: Role.user, content: []);
      expect(message.media, isNull);
    });

    test('GenerateResponse media getter', () {
      final media = Media(url: 'http://example.com/image.png');
      final response = ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [
            // ignore: unnecessary_type_check
            MediaPart(media: media),
          ],
        ),
      );
      expect(response.media!.toJson(), same(media.toJson()));
    });

    test('GenerateResponse media getter with null message', () {
      final response = ModelResponse(
        finishReason: FinishReason.stop,
        message: null,
      );
      expect(response.media, isNull);
    });

    test('GenerateResponseChunk media getter', () {
      final media = Media(url: 'http://example.com/image.png');
      final chunk = ModelResponseChunk(
        content: [
          // ignore: unnecessary_type_check
          MediaPart(media: media),
        ],
      );
      expect(chunk.media!.toJson(), media.toJson());
    });
  });

  group('Part Deserialization', () {
    test('deserializes TextPart', () {
      final json = {'text': 'hello'};
      final part = Part.$schema.parse(json);
      expect(part.text, 'hello');
    });

    test('deserializes MediaPart', () {
      final json = {
        'media': {'url': 'http://example.com/image.png'},
      };
      final part = Part.$schema.parse(json);
      expect(part.media!.url, 'http://example.com/image.png');
    });

    test('deserializes ToolRequestPart', () {
      final json = {
        'toolRequest': {'name': 'testTool'},
      };
      final part = Part.$schema.parse(json);
      expect(part, isA<Part>());
      expect(part.isToolRequest, isTrue);
      expect(part.toolRequest!.name, 'testTool');
    });

    test('deserializes ToolResponsePart', () {
      final json = {
        'toolResponse': {'name': 'testTool'},
      };
      final part = Part.$schema.parse(json);
      expect(part, isA<Part>());
      expect(part.isToolResponse, isTrue);
      expect(part.toolResponse!.name, 'testTool');
    });
  });
}
