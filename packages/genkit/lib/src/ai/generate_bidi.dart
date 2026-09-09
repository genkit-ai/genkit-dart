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

import 'dart:async';

import 'package:logging/logging.dart';

import '../core/action.dart';
import '../core/cancellation.dart';
import '../core/registry.dart';
import '../exception.dart';
import '../schema_extensions.dart';
import '../types.dart';
import 'generate.dart';
import 'generate_types.dart';
import 'interrupt.dart';
import 'model.dart';
import 'tool.dart';

final _logger = Logger('genkit');

class GenerateBidiSession {
  final BidiActionStream<ModelResponseChunk, ModelResponse, ModelRequest>
  _session;
  final Stream<GenerateResponseChunk> stream;

  GenerateBidiSession._(this._session, this.stream);

  void send(dynamic promptOrMessages) {
    if (promptOrMessages is String) {
      _session.send(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: promptOrMessages)],
            ),
          ],
        ),
      );
    } else if (promptOrMessages is List<Part>) {
      _session.send(
        ModelRequest(
          messages: [Message(role: Role.user, content: promptOrMessages)],
        ),
      );
    } else if (promptOrMessages is ModelRequest) {
      _session.send(promptOrMessages);
    } else {
      throw ArgumentError(
        'Invalid argument type. Expected String, List<Part>, or ModelRequest.',
      );
    }
  }

  Future<void> close() => _session.close();
}

Future<GenerateBidiSession> runGenerateBidi(
  Registry registry, {
  required String modelName,
  dynamic config,
  List<String>? tools,
  String? system,
  CancellationToken? cancel,
}) async {
  final model =
      await registry.lookupAction(.bidiModel, modelName) as BidiModel?;
  if (model == null) {
    throw GenkitException(
      'Bidi Model $modelName not found',
      status: StatusCodes.NOT_FOUND,
    );
  }

  var toolDefs = <ToolDefinition>[];
  var toolActions = <Tool>[];
  if (tools != null) {
    for (var toolName in tools) {
      final tool = await registry.lookupAction(.tool, toolName) as Tool?;

      if (tool != null) {
        toolActions.add(tool);
        toolDefs.add(toToolDefinition(tool));
      }
    }
  }

  final initRequest = ModelRequest(
    messages: [
      if (system != null)
        Message(
          role: Role.system,
          content: [TextPart(text: system)],
        ),
    ],
    config: config is Map
        ? config as Map<String, dynamic>
        : (config as dynamic)?.toJson() as Map<String, dynamic>?,
    tools: toolDefs,
  );

  final session = model.streamBidi(init: initRequest, cancel: cancel);
  // Close the input side of the session when cancellation is requested so no
  // further turns can be sent; the model's own `cancel` handling stops the
  // in-flight turn. Capture the disposer and drop it once the session settles
  // so a reused, long-lived `cancel` token doesn't leak this closure (and the
  // session it pins) across sessions.
  final unsubscribe = cancel?.onCancel(() => unawaited(session.close()));
  if (unsubscribe != null) {
    // `whenComplete` returns a *new* future that re-completes with the same
    // error; `ignore()` it so a session that settles with an error (e.g. a
    // transport failure) does not surface a duplicate unhandled async error via
    // this cleanup hook (the caller already sees it through `outputController`).
    session.onResult.whenComplete(unsubscribe).ignore();
  }

  final outputController = StreamController<GenerateResponseChunk>();
  final previousChunks = <ModelResponseChunk>[];

  void handleStream() async {
    try {
      await for (final chunk in session) {
        final wrapped = GenerateResponseChunk(
          chunk,
          previousChunks: previousChunks,
          output: parseChunkOutput(chunk, previousChunks, null),
        );
        previousChunks.add(chunk);
        if (!outputController.isClosed) {
          outputController.add(wrapped);
        }

        final toolRequests = chunk.content
            .where((p) => p.isToolRequest)
            .map((p) => ToolRequestPart.fromJson(p.toJson()))
            .toList();

        if (toolRequests.isNotEmpty) {
          _logger.fine('Processing ${toolRequests.length} tool requests');
          final toolResponses = <Part>[];
          for (final toolRequest in toolRequests) {
            final tool = toolActions.firstWhere(
              (t) => t.name == toolRequest.toolRequest.name,
              orElse: () => throw GenkitException(
                'Tool ${toolRequest.toolRequest.name} not found',
                status: StatusCodes.NOT_FOUND,
              ),
            );

            // Interrupts (human-in-the-loop) require handing control back to the
            // caller, which a live bidi session cannot do: the model is waiting
            // on a function response and there is no resume path. Both the
            // returned `.interrupt(...)` and the deprecated throwing
            // `ctx.interrupt(...)` forms must fail the session loudly rather
            // than answer the model, so this throw lives OUTSIDE the try/catch
            // below (which would otherwise turn it into an `Error: ...` tool
            // response and keep the session going).
            GenkitException bidiInterruptUnsupported() => GenkitException(
              'Tool "${toolRequest.toolRequest.name}" attempted to interrupt '
              'during a live (bidi) session. Interrupts are not supported by '
              'generateBidi; use a unary generate() call for human-in-the-loop '
              'tools.',
              status: StatusCodes.UNIMPLEMENTED,
            );

            final ToolResult result;
            try {
              result = (await tool.runRaw(
                toolRequest.toolRequest.input,
                cancel: cancel,
              )).result;
            } on ToolInterruptException {
              // Deprecated throwing interrupt form.
              throw bidiInterruptUnsupported();
            } on CancelledException {
              // A cooperative cancel tears the session down (the cancel hook
              // above calls `session.close()`). Propagate it rather than turn it
              // into a fabricated `Error: ...cancelled` tool answer that would
              // be sent back to the model on an already-closed input sink.
              rethrow;
            } catch (e) {
              toolResponses.add(
                ToolResponsePart(
                  toolResponse: ToolResponse(
                    ref: toolRequest.toolRequest.ref,
                    name: toolRequest.toolRequest.name,
                    output: 'Error: $e',
                  ),
                ),
              );
              continue;
            }

            switch (result) {
              case ToolInterruptResult():
                throw bidiInterruptUnsupported();
              case ToolResponseResult(
                :final output,
                :final parts,
                :final metadata,
              ):
                toolResponses.add(
                  ToolResponsePart(
                    toolResponse: ToolResponse(
                      ref: toolRequest.toolRequest.ref,
                      name: toolRequest.toolRequest.name,
                      output: output,
                      content: parts?.map((p) => p.toJson()).toList(),
                    ),
                    metadata: metadata,
                  ),
                );
            }
          }
          _logger.fine('toolResponses: $toolResponses');
          session.send(
            ModelRequest(
              messages: [Message(role: Role.tool, content: toolResponses)],
            ),
          );
        }
      }
      if (!outputController.isClosed) outputController.close();
    } catch (e, st) {
      if (!outputController.isClosed) {
        outputController.addError(e, st);
        outputController.close();
      }
    }
  }

  handleStream();

  return GenerateBidiSession._(session, outputController.stream);
}
