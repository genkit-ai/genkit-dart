import 'genkit_schemas.dart';

extension MessageExtension on Message {
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
  String get text => message?.text ?? '';
  Media? get media => message?.media;
}

extension GenerateResponseChunkExtension on GenerateResponseChunk {
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
