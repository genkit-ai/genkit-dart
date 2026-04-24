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

import 'package:genkit/plugin.dart';

import 'model.dart';

final imagenModelInfo = ModelInfo(
  supports: {
    'media': true,
    'multiturn': false,
    'tools': false,
    'toolChoice': false,
    'systemRole': false,
    'output': ['media'],
  },
);

bool isImagenModelName(String name) => name.startsWith('imagen-');

String extractPrompt(List<Message> messages) {
  return messages
      .where((m) => m.role == Role.user)
      .expand((m) => m.content)
      .where((p) => p.isText)
      .map((p) => p.text!)
      .join('\n');
}

/// Extracts a single input image from the last message for img2img.
///
/// Mirrors JS `extractImagenImage` (googleai/utils.ts): looks at the last
/// message's media parts, matching parts with no `metadata.type` or
/// `metadata.type == 'base'`, and returns the base64 payload of the first
/// match. Only `data:` URIs are supported (matches JS behaviour — the JS
/// impl splits the URL on `,` and takes the second segment, which yields
/// `undefined` for non-data URLs).
Map<String, dynamic>? extractImagenImage(List<Message> messages) {
  if (messages.isEmpty) return null;
  final last = messages.last;
  for (final p in last.content) {
    if (!p.isMedia) continue;
    final type = p.metadata?['type'] as String?;
    final matches = type == null || type == 'base';
    if (!matches) continue;
    final url = p.media!.url;
    if (!url.startsWith('data:')) continue;
    final commaIdx = url.indexOf(',');
    if (commaIdx < 0 || commaIdx == url.length - 1) continue;
    return {'bytesBase64Encoded': url.substring(commaIdx + 1)};
  }
  return null;
}

Map<String, dynamic> toImagenParameters(ImagenOptions options) {
  return {
    if (options.numberOfImages != null) 'sampleCount': options.numberOfImages,
    if (options.aspectRatio != null) 'aspectRatio': options.aspectRatio,
    if (options.personGeneration != null)
      'personGeneration': options.personGeneration,
  };
}

MediaPart? fromImagenPrediction(Map<String, dynamic> p) {
  final b64 = p['bytesBase64Encoded'] as String?;
  final mimeType = p['mimeType'] as String?;
  if (b64 == null || b64.isEmpty) return null;
  return MediaPart(
    media: Media(
      url: 'data:${mimeType ?? ''};base64,$b64',
      contentType: mimeType,
    ),
  );
}
