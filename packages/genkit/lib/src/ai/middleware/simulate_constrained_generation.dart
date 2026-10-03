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

import '../../core/action.dart';
import '../../schema_extensions.dart';
import '../../types.dart';
import '../formatters/json.dart';
import '../generate_middleware.dart';

/// Name under which [SimulateConstrainedGenerationMiddleware] is registered.
const _name = 'simulateConstrainedGeneration';

/// Lets [simulateConstrainedGeneration] refs resolve. Core registers it on
/// every `Genkit` instance, so callers never add it themselves.
final simulateConstrainedGenerationDef = generateMiddleware<void>(
  name: _name,
  create: (_, _) => SimulateConstrainedGenerationMiddleware(),
);

/// Puts a requested output schema in the prompt instead of sending it to the
/// model as a native constraint.
///
/// For a model or provider without native constrained generation:
///
/// ```dart
/// final response = await ai.generate(
///   model: someModel,
///   prompt: 'Describe a cat',
///   outputSchema: Cat.$schema,
///   use: [simulateConstrainedGeneration()],
/// );
/// ```
///
/// Opt-in: core never adds it, whatever the model declares under
/// `supports.constrained`. See [SimulateConstrainedGenerationMiddleware] for
/// exactly what it changes.
GenerateMiddlewareRef<void> simulateConstrainedGeneration() =>
    middlewareRef(name: _name);

/// Rewrites a constrained request into an unconstrained one that carries the
/// schema as prompt instructions.
///
/// Acts only on a request with `output.constrained == true` and a schema:
///
/// - appends [jsonSchemaInstructions] to the first system message, or to the
///   last user message when there is none;
/// - clears `output.schema` and sets `output.constrained` to false, so the
///   plugin sends no native constraint. `schema` matters as much as the flag:
///   several plugins send a native schema whenever `output.schema` is set;
/// - keeps `output.format` and `output.contentType`, unlike JS. Plugins read
///   that pair to turn on native JSON mode, which guarantees the response
///   parses and is independent of schema constraint.
///
/// Parsing is unaffected: `generate` parses the response with the format it
/// resolved before middleware ran, so the caller still gets typed output.
///
/// A caller's own `outputInstructions` do not suppress the schema, and
/// `outputNoInstructions` is not honoured: that flag is dropped before the
/// model request this middleware sees is built. Leave the middleware out if
/// the prompt should not carry the schema.
final class SimulateConstrainedGenerationMiddleware extends GenerateMiddleware {
  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) {
    final output = request.output;
    final schema = output?.schema;
    if (output?.constrained != true || schema == null) {
      return next(request, ctx);
    }

    final instructions = jsonSchemaInstructions(schema);
    final messages = _withInstructions(request.messages, instructions);
    if (messages == null) {
      // Nowhere to put the instructions. Stripping the schema anyway would
      // leave the model with no description of the shape at all, so the
      // request goes through untouched.
      return next(request, ctx);
    }

    return next(
      ModelRequest(
        messages: messages,
        config: request.config,
        tools: request.tools,
        toolChoice: request.toolChoice,
        docs: request.docs,
        output: OutputConfig(
          constrained: false,
          format: output?.format,
          contentType: output?.contentType,
        ),
      ),
      ctx,
    );
  }
}

/// Returns [messages] with [instructions] appended to the first system
/// message, or the last user message when there is none; unchanged when they
/// are already there, and null when there is nowhere to put them.
///
/// Deliberately not `injectInstructions`, which does nothing once *any*
/// output-purpose part exists. That guard cannot tell instructions from an
/// earlier turn (must not be duplicated) from the caller's own
/// `outputInstructions` (must not suppress the schema). Matching on the
/// rendered text does.
List<Message>? _withInstructions(List<Message> messages, String instructions) {
  // System and user only: a model or tool turn can echo the rendered schema
  // without it having come from here, and matching that would skip injection
  // while still stripping the schema.
  bool carriesInstructions(Message m) =>
      (m.role == Role.system || m.role == Role.user) &&
      m.content.any((p) => p.isText && p.text == instructions);
  if (messages.any(carriesInstructions)) return messages;

  // The first system message, as JS does: a provider that folds system
  // messages into one field may keep only the first.
  var targetIndex = messages.indexWhere((m) => m.role == Role.system);
  if (targetIndex < 0) {
    targetIndex = messages.lastIndexWhere((m) => m.role == Role.user);
  }
  if (targetIndex < 0) return null;

  final target = messages[targetIndex];
  return [
    ...messages.sublist(0, targetIndex),
    Message(
      role: target.role,
      content: [
        ...target.content,
        TextPart(text: instructions, metadata: {'purpose': 'output'}),
      ],
      metadata: target.metadata,
    ),
    ...messages.sublist(targetIndex + 1),
  ];
}
