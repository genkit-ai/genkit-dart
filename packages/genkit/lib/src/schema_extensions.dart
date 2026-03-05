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

/// Extension methods for [Part].
extension PartExtension on Part {
  /// Whether this part is a text part.
  bool get isText => toJson().containsKey('text');
  /// The text part if it is one, otherwise null.
  TextPart? get textPart => isText ? TextPart.fromJson(toJson()) : null;
  /// The text content if it is a text part, otherwise null.
  String? get text => textPart?.text;

  /// Whether this part is a media part.
  bool get isMedia => toJson().containsKey('media');
  /// The media part if it is one, otherwise null.
  MediaPart? get mediaPart => isMedia ? MediaPart.fromJson(toJson()) : null;
  /// The media content if it is a media part, otherwise null.
  Media? get media => mediaPart?.media;

  /// Whether this part is a tool request.
  bool get isToolRequest => toJson().containsKey('toolRequest');
  /// The tool request part if it is one, otherwise null.
  ToolRequestPart? get toolRequestPart =>
      isToolRequest ? ToolRequestPart.fromJson(toJson()) : null;
  /// The tool request content if it is a tool request part, otherwise null.
  ToolRequest? get toolRequest => toolRequestPart?.toolRequest;

  /// Whether this part is a tool response.
  bool get isToolResponse => toJson().containsKey('toolResponse');
  /// The tool response part if it is one, otherwise null.
  ToolResponsePart? get toolResponsePart =>
      isToolResponse ? ToolResponsePart.fromJson(toJson()) : null;
  /// The tool response content if it is a tool response part, otherwise null.
  ToolResponse? get toolResponse => toolResponsePart?.toolResponse;

  /// Whether this part is a data part.
  bool get isData => toJson().containsKey('data');
  /// The data part if it is one, otherwise null.
  DataPart? get dataPart => isData ? DataPart.fromJson(toJson()) : null;
  /// The data content if it is a data part, otherwise null.
  Map<String, dynamic>? get data => dataPart?.data;

  /// Whether this part is a custom part.
  bool get isCustom => toJson().containsKey('custom');
  /// The custom part if it is one, otherwise null.
  CustomPart? get customPart => isCustom ? CustomPart.fromJson(toJson()) : null;
  /// The custom content if it is a custom part, otherwise null.
  Map<String, dynamic>? get custom => customPart?.custom;

  /// Whether this part is a reasoning part.
  bool get isReasoning => toJson().containsKey('reasoning');
  /// The reasoning part if it is one, otherwise null.
  ReasoningPart? get reasoningPart =>
      isReasoning ? ReasoningPart.fromJson(toJson()) : null;
  /// The reasoning content if it is a reasoning part, otherwise null.
  String? get reasoning => reasoningPart?.reasoning;

  /// Whether this part is a resource.
  bool get isResource => toJson().containsKey('resource');
  /// The resource part if it is one, otherwise null.
  ResourcePart? get resourcePart =>
      isResource ? ResourcePart.fromJson(toJson()) : null;
  /// The resource content if it is a resource part, otherwise null.
  Map<String, dynamic>? get resource => resourcePart?.resource;

  /// The metadata of the part.
  Map<String, dynamic>? get metadata =>
      toJson()['metadata'] as Map<String, dynamic>?;
}
