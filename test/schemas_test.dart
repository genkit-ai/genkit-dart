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

    test('Message text getter with null content', () {
      final message = Message(
        role: Role.user,
        content: null,
      );
      expect(message.text, '');
    });

    test('GenerateResponse text getter', () {
      final response = GenerateResponse(
        message: Message(
          role: Role.model,
          content: [
            TextPart(text: 'Response text'),
          ],
        ),
      );
      expect(response.text, 'Response text');
    });

    test('GenerateResponse text getter with null message', () {
      final response = GenerateResponse(
        message: null,
      );
      expect(response.text, '');
    });

    test('GenerateResponseChunk text getter', () {
      final chunk = GenerateResponseChunk(
        content: [
          TextPart(text: 'Chunk text'),
        ],
      );
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
      expect(message.media, same(media));
    });

    test('Message media getter with no media part', () {
      final message = Message(
        role: Role.user,
        content: [
          TextPart(text: 'Hello, '),
        ],
      );
      expect(message.media, isNull);
    });

    test('Message media getter with null content', () {
      final message = Message(
        role: Role.user,
        content: null,
      );
      expect(message.media, isNull);
    });

    test('GenerateResponse media getter', () {
      final media = Media(url: 'http://example.com/image.png');
      final response = GenerateResponse(
        message: Message(
          role: Role.model,
          content: [
            // ignore: unnecessary_type_check
            MediaPart(media: media),
          ],
        ),
      );
      expect(response.media, same(media));
    });

    test('GenerateResponse media getter with null message', () {
      final response = GenerateResponse(
        message: null,
      );
      expect(response.media, isNull);
    });

    test('GenerateResponseChunk media getter', () {
      final media = Media(url: 'http://example.com/image.png');
      final chunk = GenerateResponseChunk(
        content: [
          // ignore: unnecessary_type_check
          MediaPart(media: media),
        ],
      );
      expect(chunk.media, same(media));
    });
  });

  group('Part Deserialization', () {
    test('deserializes TextPart', () {
      final json = {'text': 'hello'};
      final part = Part.fromJson(json);
      expect(part, isA<TextPart>());
      expect((part as TextPart).text, 'hello');
    });

    test('deserializes MediaPart', () {
      final json = {
        'media': {'url': 'http://example.com/image.png'}
      };
      final part = Part.fromJson(json);
      expect(part, isA<MediaPart>());
      expect(
        (part.toJson()['media'] as Map)['url'],
        'http://example.com/image.png',
      );
    });

    test('deserializes ToolRequestPart', () {
      final json = {
        'toolRequest': {'name': 'testTool'}
      };
      final part = Part.fromJson(json);
      expect(part, isA<ToolRequestPart>());
      expect((part.toJson()['toolRequest'] as Map)['name'], 'testTool');
    });

    test('deserializes ToolResponsePart', () {
      final json = {
        'toolResponse': {'name': 'testTool'}
      };
      final part = Part.fromJson(json);
      expect(part, isA<ToolResponsePart>());
      expect((part.toJson()['toolResponse'] as Map)['name'], 'testTool');
    });

    test('throws for unknown Part subtype', () {
      final json = {'unknown': 'subtype'};
      expect(() => Part.fromJson(json), throwsException);
    });
  });
}
