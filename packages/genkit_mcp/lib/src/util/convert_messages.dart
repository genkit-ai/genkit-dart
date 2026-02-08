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

import 'dart:convert';

import 'package:genkit/genkit.dart';

int _toolUseCounter = 0;

Map<String, dynamic> toMcpPromptMessage(Message message) {
  final role = _toMcpRole(message.role);
  final contentBlocks = _toMcpContentBlocks(message.content);
  final content = contentBlocks.length == 1
      ? contentBlocks.first
      : contentBlocks;
  return {'role': role, 'content': content};
}

Map<String, dynamic> toMcpResourceContent(String uri, Part part) {
  final meta = _extractMcpMetaFromMetadata(part.metadata);
  final annotations = _extractMcpAnnotationsFromMetadata(part.metadata);
  if (part.isMedia) {
    final media = part.media!;
    final mediaContent = _toMcpMediaContent(media);
    final content = {
      'uri': uri,
      'mimeType': mediaContent['mimeType'],
      'blob': mediaContent['data'],
    };
    return _attachMcpDecorations(content, meta: meta, annotations: annotations);
  }
  if (part.isText) {
    final content = {'uri': uri, 'text': part.text};
    return _attachMcpDecorations(content, meta: meta, annotations: annotations);
  }
  throw GenkitException(
    '[MCP Server] Resource content supports text or media parts only.',
    status: StatusCodes.UNIMPLEMENTED,
  );
}

String _toMcpRole(Role role) {
  if (role == Role.user) return 'user';
  if (role == Role.model) return 'assistant';
  throw GenkitException(
    '[MCP Server] MCP prompt messages only support user or model roles.',
    status: StatusCodes.UNIMPLEMENTED,
  );
}

List<Map<String, dynamic>> _toMcpContentBlocks(List<Part> parts) {
  if (parts.isEmpty) {
    return [
      {'type': 'text', 'text': ''},
    ];
  }
  return parts.map(_toMcpContentBlock).toList();
}

Map<String, dynamic> _toMcpContentBlock(Part part) {
  final meta = _extractMcpMetaFromMetadata(part.metadata);
  final annotations = _extractMcpAnnotationsFromMetadata(part.metadata);
  if (part.isText) {
    return _attachMcpDecorations(
      {'type': 'text', 'text': part.text ?? ''},
      meta: meta,
      annotations: annotations,
    );
  }
  if (part.isMedia) {
    final media = part.media!;
    final mediaContent = _toMcpMediaContent(media);
    final mimeType = mediaContent['mimeType']!;
    final content = {
      'type': mimeType.startsWith('audio/') ? 'audio' : 'image',
      'mimeType': mimeType,
      'data': mediaContent['data'],
    };
    return _attachMcpDecorations(content, meta: meta, annotations: annotations);
  }
  if (part.isToolRequest) {
    final toolRequest = part.toolRequest!;
    final id = toolRequest.ref ?? _nextToolUseId(toolRequest.name);
    final content = {
      'type': 'tool_use',
      'id': id,
      'name': toolRequest.name,
      if (toolRequest.input != null) 'input': toolRequest.input,
    };
    return _attachMcpDecorations(content, meta: meta, annotations: annotations);
  }
  if (part.isToolResponse) {
    final toolResponse = part.toolResponse!;
    final toolUseId = toolResponse.ref ?? toolResponse.name;
    final contentBlocks = _toolResponseContent(toolResponse);
    final content = {
      'type': 'tool_result',
      'toolUseId': toolUseId,
      'content': contentBlocks,
      if (toolResponse.output is Map) 'structuredContent': toolResponse.output,
    };
    return _attachMcpDecorations(content, meta: meta, annotations: annotations);
  }
  if (part.isResource) {
    final resource = part.resource ?? {};
    final content = Map<String, dynamic>.from(resource);
    return _attachMcpDecorations(content, meta: meta, annotations: annotations);
  }
  final fallback = jsonEncode(part.toJson());
  return _attachMcpDecorations(
    {'type': 'text', 'text': fallback},
    meta: meta,
    annotations: annotations,
  );
}

Map<String, String> _toMcpMediaContent(Media media) {
  final url = media.url;
  if (!url.startsWith('data:')) {
    throw GenkitException(
      '[MCP Server] MCP only supports base64 data URLs for media.',
      status: StatusCodes.UNIMPLEMENTED,
    );
  }

  final commaIndex = url.indexOf(',');
  if (commaIndex <= 0) {
    throw GenkitException(
      '[MCP Server] Invalid data URL for media.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final header = url.substring('data:'.length, commaIndex);
  final mimeType = media.contentType ?? header.split(';').first;
  final data = url.substring(commaIndex + 1);
  return {'mimeType': mimeType, 'data': data};
}

List<Map<String, dynamic>> _toolResponseContent(ToolResponse response) {
  if (response.content is List) {
    final items = response.content as List;
    final blocks = items.whereType<Map>().map((e) {
      return e.cast<String, dynamic>();
    }).toList();
    if (blocks.isNotEmpty) return blocks;
  }
  final output = response.output;
  if (output == null) {
    return [
      {'type': 'text', 'text': ''},
    ];
  }
  final text = output is String ? output : jsonEncode(output);
  return [
    {'type': 'text', 'text': text},
  ];
}

String _nextToolUseId(String name) {
  _toolUseCounter += 1;
  return '$name-$_toolUseCounter';
}

Message fromMcpPromptMessage(Map<String, dynamic> message) {
  final role = message['role'];
  if (role is! String) {
    throw GenkitException(
      '[MCP Client] Prompt message role must be a string.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  final content = message['content'];
  if (content is List) {
    final parts = content
        .whereType<Map>()
        .map((entry) => _fromMcpContentBlock(entry.cast<String, dynamic>()))
        .toList();
    return Message(role: _fromMcpRole(role), content: parts);
  }
  if (content is Map) {
    return Message(
      role: _fromMcpRole(role),
      content: [_fromMcpContentBlock(content.cast<String, dynamic>())],
    );
  }
  throw GenkitException(
    '[MCP Client] Prompt message content must be an object or array.',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

Part fromMcpResourceContent(Map<String, dynamic> content) {
  final uri = content['uri']?.toString();
  final metadata = _metadataFromContent(content);
  if (content['text'] is String) {
    return TextPart(text: content['text'] as String, metadata: metadata);
  }
  if (content['blob'] is String) {
    final mimeType =
        content['mimeType']?.toString() ?? 'application/octet-stream';
    final data = content['blob'] as String;
    return MediaPart(
      media: Media(url: 'data:$mimeType;base64,$data', contentType: mimeType),
      metadata: metadata,
    );
  }
  if (uri != null) {
    return ResourcePart(resource: {'uri': uri}, metadata: metadata);
  }
  throw GenkitException(
    '[MCP Client] Resource contents only support text or blob fields.',
    status: StatusCodes.UNIMPLEMENTED,
  );
}

Part _fromMcpContentBlock(Map<String, dynamic> content) {
  final type = content['type']?.toString();
  final metadata = _metadataFromContent(content);
  switch (type) {
    case 'text':
      return TextPart(
        text: content['text']?.toString() ?? '',
        metadata: metadata,
      );
    case 'image':
    case 'audio':
      final data = content['data']?.toString() ?? '';
      final mimeType =
          content['mimeType']?.toString() ?? 'application/octet-stream';
      return MediaPart(
        media: Media(url: 'data:$mimeType;base64,$data', contentType: mimeType),
        metadata: metadata,
      );
    case 'resource':
      final resource = content['resource'];
      if (resource is Map) {
        return ResourcePart(
          resource: resource.cast<String, dynamic>(),
          metadata: metadata,
        );
      }
      return ResourcePart(resource: content, metadata: metadata);
    case 'resource_link':
      return ResourcePart(resource: content, metadata: metadata);
    case 'tool_use':
      return ToolRequestPart(
        toolRequest: ToolRequest(
          ref: content['id']?.toString(),
          name: content['name']?.toString() ?? 'unknown',
          input: content['input'] is Map
              ? (content['input'] as Map).cast<String, dynamic>()
              : null,
        ),
        metadata: metadata,
      );
    case 'tool_result':
      return ToolResponsePart(
        toolResponse: ToolResponse(
          ref: content['toolUseId']?.toString(),
          name: content['name']?.toString() ?? 'unknown',
          output: content['structuredContent'] ?? content['content'],
        ),
        metadata: metadata,
      );
    default:
      return CustomPart(custom: content, metadata: metadata);
  }
}

Map<String, dynamic> _metadataFromContent(Map<String, dynamic> content) {
  final uri = content['uri']?.toString();
  final mcp = <String, dynamic>{};
  if (content['_meta'] is Map) {
    mcp['_meta'] = (content['_meta'] as Map).cast<String, dynamic>();
  }
  if (content['annotations'] is Map) {
    mcp['annotations'] = (content['annotations'] as Map)
        .cast<String, dynamic>();
  }
  return {
    if (uri != null) 'resource': {'uri': uri},
    if (mcp.isNotEmpty) 'mcp': mcp,
  };
}

Map<String, dynamic> _attachMcpDecorations(
  Map<String, dynamic> content, {
  Map<String, dynamic>? meta,
  Map<String, dynamic>? annotations,
}) {
  if (meta != null) {
    content['_meta'] = meta;
  }
  if (annotations != null) {
    content['annotations'] = annotations;
  }
  return content;
}

Map<String, dynamic>? _extractMcpMetaFromMetadata(
  Map<String, dynamic>? metadata,
) {
  if (metadata == null) return null;
  final mcp = metadata['mcp'];
  if (mcp is Map && mcp['_meta'] is Map) {
    return (mcp['_meta'] as Map).cast<String, dynamic>();
  }
  return null;
}

Map<String, dynamic>? _extractMcpAnnotationsFromMetadata(
  Map<String, dynamic>? metadata,
) {
  if (metadata == null) return null;
  final mcp = metadata['mcp'];
  if (mcp is Map && mcp['annotations'] is Map) {
    return (mcp['annotations'] as Map).cast<String, dynamic>();
  }
  return null;
}

Role _fromMcpRole(String role) {
  switch (role) {
    case 'user':
      return Role.user;
    case 'assistant':
      return Role.model;
    case 'system':
      return Role.system;
    case 'tool':
      return Role.tool;
    default:
      throw GenkitException(
        '[MCP Client] Unsupported prompt message role "$role".',
        status: StatusCodes.UNIMPLEMENTED,
      );
  }
}
