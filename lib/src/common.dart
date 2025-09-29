import 'genkit_schemas.dart';

extension MessageExtension on Message {
  /// The text content of the message.
  String get text {
    if (content == null) {
      return '';
    }
    final buffer = StringBuffer();
    for (final part in content!) {
      if (part is TextPart && part.text != null) {
        buffer.write(part.text);
      }
    }
    return buffer.toString();
  }

  /// The media content of the message.
  Media? get media {
    if (content == null) {
      return null;
    }
    for (final part in content!) {
      if (part is MediaPart) {
        return part.media;
      }
    }
    return null;
  }
}

extension GenerateResponseExtension on GenerateResponse {
  /// The text content of the response.
  String get text => message?.text ?? '';

  /// The media content of the response.
  Media? get media => message?.media;
}

extension GenerateResponseChunkExtension on GenerateResponseChunk {
  /// The text content of the response chunk.
  String get text {
    if (content == null) {
      return '';
    }
    final buffer = StringBuffer();
    for (final part in content!) {
      if (part is TextPart && part.text != null) {
        buffer.write(part.text);
      }
    }
    return buffer.toString();
  }

  /// The media content of the response chunk.
  Media? get media {
    if (content == null) {
      return null;
    }
    for (final part in content!) {
      if (part is MediaPart) {
        return part.media;
      }
    }
    return null;
  }
}
