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

import 'types.dart';

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
  TextPart? get textPart => isText ? TextPart(toJson()) : null;
  String? get text => isText ? TextPart(toJson()).text : null;

  bool get isMedia => toJson().containsKey('media');
  MediaPart? get mediaPart => isMedia ? MediaPart(toJson()) : null;
  Media? get media => isMedia ? MediaPart(toJson()).media : null;

  bool get isToolRequest => toJson().containsKey('toolRequest');
  ToolRequestPart? get toolRequestPart =>
      isToolRequest ? ToolRequestPart(toJson()) : null;
  ToolRequest? get toolRequest =>
      isToolRequest ? ToolRequestPart(toJson()).toolRequest : null;

  bool get isToolResponse => toJson().containsKey('toolResponse');
  ToolResponsePart? get toolResponsePart =>
      isToolResponse ? ToolResponsePart(toJson()) : null;
  ToolResponse? get toolResponse =>
      isToolResponse ? ToolResponsePart(toJson()).toolResponse : null;

  bool get isData => toJson().containsKey('data');
  DataPart? get dataPart => isData ? DataPart(toJson()) : null;
  Map<String, dynamic>? get data => isData ? DataPart(toJson()).data : null;

  bool get isCustom => toJson().containsKey('custom');
  CustomPart? get customPart => isCustom ? CustomPart(toJson()) : null;
  Map<String, dynamic>? get custom =>
      isCustom ? CustomPart(toJson()).custom : null;

  bool get isReasoning => toJson().containsKey('reasoning');
  ReasoningPart? get reasoningPart =>
      isReasoning ? ReasoningPart(toJson()) : null;
  String? get reasoning =>
      isReasoning ? ReasoningPart(toJson()).reasoning : null;

  bool get isResource => toJson().containsKey('resource');
  ResourcePart? get resourcePart => isResource ? ResourcePart(toJson()) : null;
  Map<String, dynamic>? get resource =>
      isResource ? ResourcePart(toJson()).resource : null;

  Map<String, dynamic>? get metadata =>
      toJson().containsKey('metadata') ? toJson()['metadata'] : null;
}
