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

// The Antigravity agent on the Gemini API (googleAI): called through the
// Interactions API as an `agent` (not streamed, not background).
//
// Mirrors js/plugins/google-genai/src/googleai/antigravity.ts (Oct 27
// 2026). Keep the two in step: change JS first, then translate.
//
// Differences from JS (decided for Dart):
// - No config passthrough: only the AntigravityOptions fields are read, so
//   unknown config keys never reach the server (JS sends them as request
//   fields).
// - A streamed request gets the final response without chunks (JS doesn't
//   stream this agent either).

import 'package:genkit/plugin.dart';

import 'common_plugin.dart';
import 'interaction_converters.dart';
import 'interaction_types.dart';
import 'known_models.dart' show GeminiModelStage;
import 'model.dart';

/// The capability profile every Antigravity agent advertises (as in JS).
final antigravitySupports = Map<String, dynamic>.unmodifiable({
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': false,
  'systemRole': false,
  'output': List<String>.unmodifiable(['text']),
});

/// Whether [modelName] (bare, no plugin prefix) is an Antigravity agent.
bool isAntigravityModelName(String modelName) =>
    modelName.startsWith('antigravity-');

/// Antigravity agents the googleAI plugin curates, kept in step with the JS
/// plugin's KNOWN_MODELS in googleai/antigravity.ts. Other `antigravity-*`
/// names still resolve, with the same capabilities.
enum KnownAntigravityModel {
  antigravityPreview092026(
    'antigravity-preview-09-2026',
    'Antigravity Preview (09-2026)',
  );

  const KnownAntigravityModel(this.id, this.label);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The capability metadata for this agent.
  ModelInfo get info => ModelInfo(
    label: label,
    supports: antigravitySupports,
    stage: GeminiModelStage.stable.wireName,
  );
}

/// Curated Antigravity metadata, keyed by bare model name.
final knownAntigravityModels = Map<String, ModelInfo>.unmodifiable({
  for (final model in KnownAntigravityModel.values) model.id: model.info,
});

/// The capability metadata for the Antigravity agent [modelName]: its
/// curated info, or the shared Antigravity profile for an unlisted name.
ModelInfo antigravityModelInfo(String modelName) =>
    knownAntigravityModels[modelName] ??
    ModelInfo(supports: antigravitySupports);

/// Creates the Antigravity agent [modelName] for [plugin].
Model createAntigravityModel(CommonGoogleGenPlugin plugin, String modelName) {
  return Model(
    name: '${plugin.name}/$modelName',
    customOptions: AntigravityOptions.$schema,
    metadata: {'model': antigravityModelInfo(modelName).toJson()},
    fn: (req, ctx) async {
      final options = AntigravityOptions.$schema.parse({...?req.config});

      // Built-in tools from config.tools (e.g. {'type': 'google_search'}),
      // followed by the request's function tools.
      final tools = <InteractionTool>[
        ...?options.tools?.map(toInteractionConfigTool),
        ...?req.tools?.map(toInteractionTool),
      ];

      // Antigravity does not support system instructions, so they are sent
      // as user messages.
      final messages = [
        for (final m in req.messages)
          m.role == Role.system
              ? Message(
                  role: Role.user,
                  content: m.content,
                  metadata: m.metadata,
                )
              : m,
      ];

      // Unlike Gemini models, Antigravity doesn't default to `store: false`:
      // the agent doesn't work at all with `store: false` (the server
      // rejects it), so that default would break every Antigravity app.
      // `store` is only sent when set; an explicit `store: false` (request
      // config, or else the plugin option) is passed through as requested.
      final storeSetting =
          options.store ?? (plugin.store == false ? false : null);

      // Continue from the last model message: send its interaction ID and
      // only the messages after it, in the same environment (a new 'remote'
      // sandbox wouldn't have the previous turn's files). The agent also
      // rejects tool calls in `input`, so this is how a tool result is sent.
      // The message metadata doesn't record which model or agent created the
      // interaction, so a history that mixes stored Gemini turns and
      // Antigravity turns would continue the wrong interaction here (and the
      // Gemini path has the same issue in reverse).
      // TODO: record the creating model/agent in the metadata and check it
      // (same TODO in JS).
      var previousId = options.previousInteractionId;
      var newMessages = messages;
      var environment = options.environment;
      if (previousId == null || previousId.isEmpty) {
        for (var i = messages.length - 1; i >= 0; i--) {
          final metadata = messages[i].metadata;
          final prevId = metadata?['interactionId'];
          if (messages[i].role == Role.model &&
              prevId is String &&
              prevId.isNotEmpty) {
            previousId = prevId;
            newMessages = messages.sublist(i + 1);
            final prevEnvironment = metadata?['environmentId'];
            if ((environment == null || environment == 'remote') &&
                prevEnvironment is String &&
                prevEnvironment.isNotEmpty) {
              environment = prevEnvironment;
            }
            break;
          }
        }
      } else {
        // As for Gemini models: an explicit previousInteractionId wins, but
        // history up to the last model turn is already on the server.
        for (var i = messages.length - 1; i >= 0; i--) {
          if (messages[i].role == Role.model) {
            newMessages = messages.sublist(i + 1);
            break;
          }
        }
      }

      // Sent as agent_config.model; a top-level `model` would conflict with
      // `agent`.
      final agentModel = options.model;
      final request = CreateInteractionRequest(
        agent: modelName,
        input: toInteractionSteps(ensureToolIds(newMessages)),
        previousInteractionId: previousId,
        store: storeSetting,
        environment: environment,
        responseFormat: toInteractionResponseFormat(
          modalities: options.responseModalities,
        ),
        agentConfig: agentModel != null && agentModel.isNotEmpty
            ? AntigravityAgentConfig(model: agentModel)
            : null,
        tools: tools.isEmpty ? null : tools,
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
