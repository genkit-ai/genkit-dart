import 'package:genkit/client.dart';
import 'package:test/test.dart';

void main() {
  group('Schema Extensions', () {
    test('Message text getter', () {
      final message = Message.from(
        role: Role.user,
        content: [
          TextPart.from(text: 'Hello, '),
          TextPart.from(text: 'world!'),
          // ignore: unnecessary_type_check
          MediaPart.from(
            media: Media.from(url: 'http://example.com/image.png'),
          ),
        ],
      );
      expect(message.text, 'Hello, world!');
    });

    test('Message text getter with no text parts', () {
      final message = Message.from(
        role: Role.user,
        content: [
          // ignore: unnecessary_type_check
          MediaPart.from(
            media: Media.from(url: 'http://example.com/image.png'),
          ),
        ],
      );
      expect(message.text, '');
    });

    test('Message text getter with empty content', () {
      final message = Message.from(role: Role.user, content: []);
      expect(message.text, '');
    });

    test('GenerateResponse text getter', () {
      final response = ModelResponse.from(
        finishReason: FinishReason.stop,
        message: Message.from(
          role: Role.model,
          content: [TextPart.from(text: 'Response text')],
        ),
      );
      expect(response.text, 'Response text');
    });

    test('GenerateResponse text getter with null message', () {
      final response = ModelResponse.from(
        finishReason: FinishReason.stop,
        message: null,
      );
      expect(response.text, '');
    });

    test('GenerateResponseChunk text getter', () {
      final chunk = ModelResponseChunk.from(
        content: [TextPart.from(text: 'Chunk text')],
      );
      expect(chunk.text, 'Chunk text');
    });

    test('Message media getter', () {
      final media = Media.from(url: 'http://example.com/image.png');
      final message = Message.from(
        role: Role.user,
        content: [
          TextPart.from(text: 'Hello, '),
          // ignore: unnecessary_type_check
          MediaPart.from(media: media),
        ],
      );
      expect(message.media, same(media));
    });

    test('Message media getter with no media part', () {
      final message = Message.from(
        role: Role.user,
        content: [TextPart.from(text: 'Hello, ')],
      );
      expect(message.media, isNull);
    });

    test('Message media getter with null content', () {
      final message = Message.from(role: Role.user, content: []);
      expect(message.media, isNull);
    });

    test('GenerateResponse media getter', () {
      final media = Media.from(url: 'http://example.com/image.png');
      final response = ModelResponse.from(
        finishReason: FinishReason.stop,
        message: Message.from(
          role: Role.model,
          content: [
            // ignore: unnecessary_type_check
            MediaPart.from(media: media),
          ],
        ),
      );
      expect(response.media, same(media));
    });

    test('GenerateResponse media getter with null message', () {
      final response = ModelResponse.from(
        finishReason: FinishReason.stop,
        message: null,
      );
      expect(response.media, isNull);
    });

    test('GenerateResponseChunk media getter', () {
      final media = Media.from(url: 'http://example.com/image.png');
      final chunk = ModelResponseChunk.from(
        content: [
          // ignore: unnecessary_type_check
          MediaPart.from(media: media),
        ],
      );
      expect(chunk.media, same(media));
    });
  });

  group('Part Deserialization', () {
    test('deserializes TextPart', () {
      final json = {'text': 'hello'};
      final part = PartType.parse(json);
      expect(part, isA<TextPart>());
      expect((part as TextPart).text, 'hello');
    });

    test('deserializes MediaPart', () {
      final json = {
        'media': {'url': 'http://example.com/image.png'},
      };
      final part = PartType.parse(json);
      expect(part, isA<MediaPart>());
      expect((part as MediaPart).media.url, 'http://example.com/image.png');
    });

    test('deserializes ToolRequestPart', () {
      final json = {
        'toolRequest': {'name': 'testTool'},
      };
      final part = PartType.parse(json);
      expect(part, isA<ToolRequestPart>());
      expect((part as ToolRequestPart).toolRequest.name, 'testTool');
    });

    test('deserializes ToolResponsePart', () {
      final json = {
        'toolResponse': {'name': 'testTool'},
      };
      final part = PartType.parse(json);
      expect(part, isA<ToolResponsePart>());
      expect((part as ToolResponsePart).toolResponse.name, 'testTool');
    });

    test('throws for unknown Part subtype', () {
      final json = {'unknown': 'subtype'};
      expect(() => PartType.parse(json), throwsException);
    });
  });
}
