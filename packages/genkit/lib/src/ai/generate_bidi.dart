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
import '../core/registry.dart';
import '../exception.dart';
import '../schema_extensions.dart';
import '../types.dart';
import 'generate.dart';
import 'generate_types.dart';
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
}) async {
  final model =
      await registry.lookupAction('bidi-model', modelName) as BidiModel?;
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
      final tool = await registry.lookupAction('tool', toolName) as Tool?;
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
        : (config as dynamic)?.toJson(),
    tools: toolDefs,
  );

  final session = model.streamBidi(init: initRequest);

  // ignore: close_sinks
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

            try {
              final output = await tool.runRaw(toolRequest.toolRequest.input);
              toolResponses.add(
                ToolResponsePart(
                  toolResponse: ToolResponse(
                    ref: toolRequest.toolRequest.ref,
                    name: toolRequest.toolRequest.name,
                    output: output.result,
                  ),
                ),
              );
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
