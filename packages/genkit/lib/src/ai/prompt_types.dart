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

/// Utilities for converting between `dotprompt` types and Genkit types.
library;

import 'package:dotprompt/dotprompt.dart' as dp;

import '../types.dart' as genkit;

/// Converts a dotprompt [dp.Message] to a Genkit [genkit.Message].
genkit.Message dpMessageToGenkitMessage(dp.Message msg) {
  return genkit.Message(
    role: dpRoleToGenkitRole(msg.role),
    content: msg.content.map(dpPartToGenkitPart).toList(),
    metadata: msg.metadata,
  );
}

/// Converts a dotprompt [dp.Role] to a Genkit [genkit.Role].
genkit.Role dpRoleToGenkitRole(dp.Role role) {
  switch (role) {
    case dp.Role.user:
      return genkit.Role.user;
    case dp.Role.model:
      return genkit.Role.model;
    case dp.Role.system:
      return genkit.Role.system;
    case dp.Role.tool:
      return genkit.Role.tool;
  }
}

/// Converts a dotprompt [dp.Part] to a Genkit [genkit.Part].
genkit.Part dpPartToGenkitPart(dp.Part part) {
  return switch (part) {
    dp.TextPart(:final text) => genkit.TextPart(text: text),
    dp.MediaPart(:final media) => genkit.MediaPart(
        media: genkit.Media(
          contentType: media.contentType,
          url: media.url ?? media.data ?? '',
        ),
      ),
    dp.ToolRequestPart(:final toolRequest) => genkit.ToolRequestPart(
        toolRequest: genkit.ToolRequest(
          ref: toolRequest.ref,
          name: toolRequest.name,
          input: toolRequest.input,
        ),
      ),
    dp.ToolResponsePart(:final toolResponse) => genkit.ToolResponsePart(
        toolResponse: genkit.ToolResponse(
          ref: toolResponse.ref,
          name: toolResponse.name,
          output: toolResponse.output,
        ),
      ),
    dp.DataPart(:final data) => genkit.DataPart(data: data),
    // For PendingPart and MetadataPart, convert to DataPart with metadata
    dp.PendingPart() => genkit.DataPart(data: part.toJson()),
    dp.MetadataPart(:final metadata) => genkit.DataPart(data: metadata),
  };
}

/// Converts a Genkit [genkit.Message] to a dotprompt [dp.Message].
dp.Message genkitMessageToDpMessage(genkit.Message msg) {
  return dp.Message(
    role: genkitRoleToDpRole(msg.role),
    content: msg.content.map(genkitPartToDpPart).toList(),
    metadata: msg.metadata,
  );
}

/// Converts a Genkit [genkit.Role] to a dotprompt [dp.Role].
dp.Role genkitRoleToDpRole(genkit.Role role) {
  if (role == genkit.Role.user) return dp.Role.user;
  if (role == genkit.Role.model) return dp.Role.model;
  if (role == genkit.Role.system) return dp.Role.system;
  if (role == genkit.Role.tool) return dp.Role.tool;
  return dp.Role.user; // fallback
}

/// Converts a Genkit [genkit.Part] to a dotprompt [dp.Part].
dp.Part genkitPartToDpPart(genkit.Part part) {
  final json = part.toJson();
  if (json.containsKey('text')) {
    return dp.TextPart(text: json['text'] as String);
  }
  if (json.containsKey('media')) {
    final media = json['media'] as Map<String, dynamic>;
    return dp.MediaPart(
      media: dp.MediaContent(
        contentType: media['contentType'] as String? ?? '',
        url: media['url'] as String?,
      ),
    );
  }
  if (json.containsKey('toolRequest')) {
    final tr = json['toolRequest'] as Map<String, dynamic>;
    return dp.ToolRequestPart(
      toolRequest: dp.ToolRequest(
        name: tr['name'] as String,
        ref: tr['ref'] as String? ?? '',
        input: tr['input'] as Map<String, dynamic>?,
      ),
    );
  }
  if (json.containsKey('toolResponse')) {
    final tr = json['toolResponse'] as Map<String, dynamic>;
    return dp.ToolResponsePart(
      toolResponse: dp.ToolResponse(
        name: tr['name'] as String,
        ref: tr['ref'] as String? ?? '',
        output: tr['output'],
      ),
    );
  }
  // Fallback: text part
  return dp.TextPart(text: json.toString());
}
