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
      if (part.isText) {
        buffer.write(part.text);
      }
    }
    return buffer.toString();
  }

  /// The media content of the message.
  Media? get media {
    for (final part in content) {
      if (part.isMedia) {
        return part.media;
      }
    }
    return null;
  }

  /// The tool requests in the response.
  List<ToolRequest> get toolRequests {
    return content
        .where((c) => c.isToolRequest)
        .map((c) => c.toolRequest!)
        .toList();
  }
}

extension ModelResponseExtension on ModelResponse {
  /// The text content of the response.
  String get text => message?.text ?? '';

  /// The media content of the response.
  Media? get media => message?.media;

  /// The tool requests in the response.
  List<ToolRequest> get toolRequests {
    return message?.content
            .where((c) => c.isToolRequest)
            .map((c) => c.toolRequest!)
            .toList() ??
        [];
  }
}

extension ModelResponseChunkExtension on ModelResponseChunk {
  /// The text content of the response chunk.
  String get text {
    final buffer = StringBuffer();
    for (final part in content) {
      if (part.isText) {
        buffer.write(part.text);
      }
    }
    return buffer.toString();
  }

  /// The media content of the response chunk.
  Media? get media {
    for (final part in content) {
      if (part.isMedia) {
        return part.media;
      }
    }
    return null;
  }
}

extension PartExtension on Part {
  bool get isText => toJson().containsKey('text');
  String? get text => isText ? (this as TextPart).text : null;

  bool get isMedia => toJson().containsKey('media');
  Media? get media => isMedia ? (this as MediaPart).media : null;

  bool get isToolRequest => toJson().containsKey('toolRequest');
  ToolRequest? get toolRequest =>
      isToolRequest ? (this as ToolRequestPart).toolRequest : null;

  bool get isToolResponse => toJson().containsKey('toolResponse');
  ToolResponse? get toolResponse =>
      isToolResponse ? (this as ToolResponsePart).toolResponse : null;

  bool get isData => toJson().containsKey('data');
  Map<String, dynamic>? get data => isData ? (this as DataPart).data : null;

  bool get isCustom => toJson().containsKey('custom');
  Map<String, dynamic>? get custom =>
      isCustom ? (this as CustomPart).custom : null;

  bool get isReasoning => toJson().containsKey('reasoning');
  String? get reasoning =>
      isReasoning ? (this as ReasoningPart).reasoning : null;

  bool get isResource => toJson().containsKey('resource');
  Map<String, dynamic>? get resource =>
      isResource ? (this as ResourcePart).resource : null;

  Map<String, dynamic>? get metadata =>
      toJson().containsKey('metadata') ? toJson()['metadata'] : null;
}
