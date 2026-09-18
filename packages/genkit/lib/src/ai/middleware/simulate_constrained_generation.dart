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

import 'dart:convert';

import '../../core/action.dart';
import '../../schema_extensions.dart';
import '../../types.dart';
import '../generate_middleware.dart';

/// Renders [schema] as the instructions a model is given in place of native
/// constrained generation.
///
/// Deliberately not `jsonFormatter`'s wording: that formatter sets
/// `defaultInstructions: false`, so it never injects anything of its own and
/// this middleware is the whole mechanism. Keeping the string here means the
/// simulated path reads the same whatever format asked for a schema.
String simulatedConstrainedInstructions(Map<String, dynamic> schema) {
  final rendered = const JsonEncoder.withIndent('  ').convert(schema);
  return 'Output should be in JSON format and conform to the following '
      'schema:\n\n```\n$rendered\n```\n';
}

/// Simulates constrained generation for a model that cannot do it natively.
///
/// Injects the requested schema into the conversation as instructions, then
/// strips the output config the plugin would otherwise act on, so the request
/// reaching the model looks like an ordinary unconstrained one.
///
/// `schema` is cleared, not just `constrained`. Several plugins key off
/// `output.schema` alone and never read `output.constrained`, so leaving the
/// schema in place would send the native request this middleware exists to
/// avoid, on top of the injected instructions.
///
/// `format` and `contentType` are kept, which is where this parts company with
/// JS (`js/ai/src/model/middleware.ts` clears all four). Plugins read those two
/// to turn on native JSON mode — `genkit_google_genai` derives `isJsonMode`
/// from exactly them, and `genkit_openai` sends `json_object` off the same
/// signal — and that mode is orthogonal to schema constraint: it guarantees the
/// response parses, leaving the injected instructions to supply only the shape.
/// Clearing them would throw that away and make the simulated path parse worse
/// than it needs to. The instructions name JSON, which is the precondition
/// OpenAI puts on `json_object`.
///
/// Parsing is unaffected: `generate` parses the response against the format
/// it resolved before middleware ran, so the caller still gets typed output.
class SimulateConstrainedGenerationMiddleware extends GenerateMiddleware {
  /// The model's declared `supports.constrained`, checked against the request
  /// as it arrives here rather than as `generate` first built it — middleware
  /// ahead of this one can add tools or an output schema on the way down.
  final Object? constrained;

  SimulateConstrainedGenerationMiddleware({required this.constrained});

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
    if (!needsConstrainedSimulation(
      constrained,
      hasTools: request.tools?.isNotEmpty ?? false,
    )) {
      return next(request, ctx);
    }

    final instructions = simulatedConstrainedInstructions(schema);
    final messages = _withInstructions(request.messages, instructions);
    if (messages == null) {
      // Nowhere to put the instructions, so simulating would strip the schema
      // and replace it with nothing — the model would be left with no
      // description of the shape at all, which is worse than the native
      // request this exists to avoid. Pass it through untouched instead and
      // let the provider answer for a request the model did not claim to
      // support.
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

/// Returns [messages] with [instructions] appended to the last system or user
/// message, or unchanged when they are already present.
///
/// Deliberately not `injectInstructions`, which returns the list untouched
/// whenever *any* output-purpose part exists. That guard cannot tell the
/// instructions this middleware injected on an earlier turn from instructions
/// the caller wrote themselves: the first must not be duplicated, the second
/// does not describe the schema and must not suppress it. Matching on the
/// rendered text distinguishes them, so a caller's own `outputInstructions`
/// now sit alongside the schema rather than silently replacing it.
///
/// Returns null when there is no system or user message to append to, which
/// the caller reads as "cannot simulate".
List<Message>? _withInstructions(List<Message> messages, String instructions) {
  bool carriesInstructions(Message m) =>
      m.content.any((p) => p.isText && p.text == instructions);
  if (messages.any(carriesInstructions)) return messages;

  var targetIndex = messages.lastIndexWhere((m) => m.role == Role.system);
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

/// Whether a model declaring [constrained] under `supports` needs
/// [SimulateConstrainedGenerationMiddleware] for a request carrying [hasTools].
///
/// Mirrors JS (`js/ai/src/model.ts`), whose value space is `true`, `'all'`,
/// `'none'` and `'no-tools'`: an absent value means the model makes no claim,
/// which is read as no native support rather than as support. The
/// `'no-tools'` case describes models whose native constrained generation is
/// mutually exclusive with tool calling, so it simulates only when the request
/// actually carries tools.
///
/// Anything outside that space simulates. Only a recognised claim counts as
/// one, so a typo like `'noTools'` costs a longer prompt rather than the
/// provider rejection that reading it as support would earn.
bool needsConstrainedSimulation(Object? constrained, {required bool hasTools}) {
  return switch (constrained) {
    true || 'all' => false,
    'no-tools' => hasTools,
    _ => true,
  };
}
