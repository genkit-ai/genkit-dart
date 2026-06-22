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

import 'package:genkit/genkit.dart';
import 'package:ollama_dart/ollama_dart.dart' as sdk;

/// Generic capability profile used when `/api/show` does not report a
/// `capabilities` array (older Ollama servers).
///
/// Conservatively assumes a chat model: multiturn + system role + tools, no
/// vision. Constrained output is enabled because Ollama applies `format` at the
/// server regardless of model.
ModelInfo genericModelInfo(String model) {
  return ModelInfo(
    label: model,
    supports: const {
      'multiturn': true,
      'systemRole': true,
      'tools': true,
      'media': false,
      'constrained': true,
    },
  );
}

/// Builds an accurate [ModelInfo] from an Ollama `/api/show` response.
///
/// Maps Ollama's `capabilities` array to Genkit's `supports` flags. Falls back
/// to [genericModelInfo] when capabilities are absent.
ModelInfo modelInfoFromShow(String model, sdk.ShowResponse show) {
  final capabilities = show.capabilities;
  if (capabilities == null || capabilities.isEmpty) {
    return genericModelInfo(model);
  }
  final caps = capabilities.map((c) => c.toLowerCase()).toSet();
  return ModelInfo(
    label: model,
    supports: {
      'multiturn': caps.contains('completion'),
      'systemRole': true,
      'tools': caps.contains('tools'),
      'media': caps.contains('vision'),
      // Ollama applies `format` constrained decoding for any completion model.
      'constrained': caps.contains('completion'),
    },
  );
}

/// Returns true when an Ollama `/api/show` response describes an embedding
/// model.
bool isEmbedderShow(sdk.ShowResponse show) {
  final caps = show.capabilities;
  return caps != null && caps.any((c) => c.toLowerCase() == 'embedding');
}

/// Extracts the embedding dimension from an Ollama `/api/show` response.
///
/// Ollama exposes this under a `model_info` key shaped like
/// `<architecture>.embedding_length` (e.g. `bert.embedding_length`). Returns
/// null when not reported.
int? embeddingDimensionsFromShow(sdk.ShowResponse show) {
  final info = show.modelInfo;
  if (info == null) return null;
  for (final entry in info.entries) {
    if (entry.key.endsWith('.embedding_length')) {
      final value = entry.value;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    }
  }
  return null;
}
