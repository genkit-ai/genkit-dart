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
    for (final part in content) {
      if (part.toJson().containsKey('text') && part is TextPart) {
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
