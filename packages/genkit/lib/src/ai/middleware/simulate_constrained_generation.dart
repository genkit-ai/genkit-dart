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
import '../../types.dart';
import '../formatters/formatters.dart';
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
/// Parsing is unaffected: `generate` parses the response against the format
/// it resolved before middleware ran, so the caller still gets typed output.
class SimulateConstrainedGenerationMiddleware extends GenerateMiddleware {
  SimulateConstrainedGenerationMiddleware();

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

    // `injectInstructions` is a no-op when the conversation already carries an
    // output instruction part, so a resumed turn does not accumulate copies.
    final messages = injectInstructions(
      request.messages,
      simulatedConstrainedInstructions(schema),
    );

    return next(
      ModelRequest(
        messages: messages,
        config: request.config,
        tools: request.tools,
        toolChoice: request.toolChoice,
        docs: request.docs,
        output: OutputConfig(constrained: false),
      ),
      ctx,
    );
  }
}

/// Whether a model declaring [constrained] under `supports` needs
/// [SimulateConstrainedGenerationMiddleware] for a request carrying [hasTools].
///
/// Mirrors JS (`js/ai/src/model.ts`): an absent value means the model makes no
/// claim, which is read as no native support rather than as support. The
/// `'no-tools'` case describes models whose native constrained generation is
/// mutually exclusive with tool calling, so it simulates only when the request
/// actually carries tools.
bool needsConstrainedSimulation(Object? constrained, {required bool hasTools}) {
  return switch (constrained) {
    null || false || 'none' => true,
    'no-tools' => hasTools,
    _ => false,
  };
}
