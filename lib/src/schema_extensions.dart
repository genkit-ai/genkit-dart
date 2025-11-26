import 'package:genkit/src/types.dart';

extension MessageExtension on Message {
  /// The text content of the message.
  String get text {
    final buffer = StringBuffer();
    for (final part in content) {
      if (part.toJson().containsKey('text') && part is TextPart) {
        buffer.write(part.text);
      }
    }
    return buffer.toString();
  }

  /// The media content of the message.
  Media? get media {
    for (final part in content) {
      if (part.toJson().containsKey('media') && part is MediaPart) {
        return part.media;
      }
    }
    return null;
  }
}

extension ModelResponseExtension on ModelResponse {
  /// The text content of the response.
  String get text => message?.text ?? '';

  /// The media content of the response.
  Media? get media => message?.media;

  /// The tool requests in the response.
  List<ToolRequest> get toolRequests {
    return (message)
            ?.content
            .where((c) => c.toJson().containsKey('toolRequest'))
            .map((c) => (c as ToolRequestPart).toolRequest)
            .toList() ??
        [];
  }
}

extension ModelResponseChunkExtension on ModelResponseChunk {
  /// The text content of the response chunk.
  String get text {
    final buffer = StringBuffer();
    for (final part in content as List) {
      if (part is TextPart) {
        buffer.write(part.text);
      }
    }
      return buffer.toString();
  }

  /// The media content of the response chunk.
  Media? get media {
    for (final part in content as List) {
      if (part is MediaPart) {
        return part.media;
      }
    }
      return null;
  }
}
