// Copyright 2026 Google LLC
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

// The Lyria music generation models on the Gemini API (googleAI): plain
// Interactions models (not streamed, not background).
//
// Mirrors js/plugins/google-genai/src/googleai/lyria.ts (Oct 27 2026). Keep
// the two in step: change JS first, then translate.
//
// Differences from JS (decided for Dart):
// - No config passthrough: only the LyriaOptions fields are read, so
//   unknown config keys never reach the server (JS sends them as request
//   fields).
// - A streamed request gets the final response without chunks (JS doesn't
//   stream these models either).

import 'package:genkit/plugin.dart';

import 'common_plugin.dart';
import 'interaction_converters.dart';
import 'interaction_types.dart';
import 'known_models.dart' show GeminiModelStage;
import 'model.dart';

/// The capability profile every Lyria model advertises (as in JS): one turn,
/// text and image input, music (and the lyrics or caption as text) out.
final lyriaSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': false,
  // Lyria takes images as input too.
  'media': true,
  'tools': false,
  'toolChoice': false,
  'systemRole': false,
  'output': List<String>.unmodifiable(['media', 'text']),
});

/// Whether [modelName] (bare, no plugin prefix) is a Lyria model.
bool isLyriaModelName(String modelName) => modelName.startsWith('lyria-');

/// Lyria models the googleAI plugin curates, kept in step with the JS
/// plugin's KNOWN_MODELS in googleai/lyria.ts. Other `lyria-*` names still
/// resolve, with the same capabilities.
enum KnownLyriaModel {
  lyria35('lyria-3.5', 'Lyria 3.5'),
  lyria3ClipPreview('lyria-3-clip-preview', 'Lyria 3 Clip Preview'),
  lyria3ProPreview('lyria-3-pro-preview', 'Lyria 3 Pro Preview');

  const KnownLyriaModel(this.id, this.label);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The capability metadata for this model.
  ModelInfo get info => ModelInfo(
    label: label,
    supports: lyriaSupports,
    stage: GeminiModelStage.stable.wireName,
  );
}

/// Curated Lyria metadata, keyed by bare model name.
final knownLyriaModels = Map<String, ModelInfo>.unmodifiable({
  for (final model in KnownLyriaModel.values) model.id: model.info,
});

/// The capability metadata for the Lyria model [modelName]: its curated
/// info, or the shared Lyria profile for an unlisted name.
ModelInfo lyriaModelInfo(String modelName) =>
    knownLyriaModels[modelName] ?? ModelInfo(supports: lyriaSupports);

/// Creates the Lyria model [modelName] for [plugin].
Model createLyriaModel(CommonGoogleGenPlugin plugin, String modelName) {
  return Model(
    name: '${plugin.name}/$modelName',
    customOptions: LyriaOptions.$schema,
    metadata: {'model': lyriaModelInfo(modelName).toJson()},
    fn: (req, ctx) async {
      final options = LyriaOptions.$schema.parse({...?req.config});
      final request = CreateInteractionRequest(
        model: modelName,
        input: toInteractionSteps(ensureToolIds(req.messages)),
        // Audio and the lyrics/caption text by default.
        responseFormat: toInteractionResponseFormat(
          modalities: options.responseModalities ?? const ['AUDIO', 'TEXT'],
        ),
      );

      final service = await plugin.getApiClient(options.apiKey);
      // Aborts the in-flight request on a plugin-owned client (see
      // generateWithInteractions).
      final disposeCancel = ctx.cancel?.onCancel(service.client.close);
      try {
        ctx.cancel?.throwIfCancelled();
        final interaction = await service.createInteraction(request);
        ctx.cancel?.throwIfCancelled();
        return fromInteractionSync(interaction);
      } catch (e, stack) {
        throw plugin.handleException(e, stack);
      } finally {
        disposeCancel?.call();
        service.client.close();
      }
    },
  );
}
