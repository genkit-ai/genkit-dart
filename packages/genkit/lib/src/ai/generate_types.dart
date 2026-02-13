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

import '../extract.dart';
import '../schema_extensions.dart';
import '../types.dart';

/// A chunk of a response from a generate action.
class GenerateResponseChunk<O> extends ModelResponseChunk {
  final ModelResponseChunk _chunk;
  final List<ModelResponseChunk> previousChunks;
  final O? output;

  GenerateResponseChunk(
    this._chunk, {
    this.previousChunks = const [],
    this.output,
  }) : super(
         index: _chunk.index,
         role: _chunk.role,
         content: _chunk.content,
         custom: _chunk.custom,
       );

  // Derived properties
  String get text =>
      content.where((p) => p.isText).map((p) => p.text!).join('');

  String get accumulatedText {
    final prev = previousChunks.map((c) => c.text).join('');
    return prev + text;
  }

  /// Tries to parse the output as JSON.
  ///
  /// This will be populated if the output format is JSON, or if the output is
  /// arbitrarily parsed as JSON.
  O? get jsonOutput {
    if (output != null) return output;
    return extractJson(accumulatedText) as O?;
  }

  ModelResponseChunk get rawChunk => _chunk;
}

/// A response to an interrupted tool request.
class InterruptResponse {
  final ToolRequestPart _part;
  final dynamic output;

  InterruptResponse(this._part, this.output);

  String? get ref => _part.toolRequest.ref;
  String get name => _part.toolRequest.name;
  ToolRequestPart get toolRequestPart => _part;

  Map<String, dynamic> toJson() => {
    'name': _part.toolRequest.name,
    'ref': _part.toolRequest.ref,
    'output': output,
  };
}

/// A response from a generate action.
class GenerateResponseHelper<O> extends GenerateResponse {
  final ModelResponse _response;
  final ModelRequest? _request;
  final O? output;

  GenerateResponseHelper(this._response, {ModelRequest? request, this.output})
    : _request = request,
      super(
        message: _response.message,
        finishReason: _response.finishReason,
        finishMessage: _response.finishMessage,
        latencyMs: _response.latencyMs,
        usage: _response.usage,
        custom: _response.custom,
        raw: _response.raw,
        request: _response.request, // This uses ModelResponse.request
        operation: _response.operation,
        candidates: [
          Candidate(
            index: 0,
            message: _response.message!,
            finishReason: _response.finishReason,
            finishMessage: _response.finishMessage,
            usage: _response.usage,
            custom: _response.custom,
          ),
        ],
      );

  /// The full history of the conversation, including the request messages and
  /// the final model response.
  ///
  /// This is useful for continuing the conversation in multi-turn scenarios.
  List<Message> get messages => [
    ...(_request?.messages ?? _response.request?.messages ?? []),
    _response.message!,
  ];

  ModelResponse get modelResponse => _response;

  /// The text content of the response.
  String get text => _response.text;

  /// The media content of the response.
  Media? get media => _response.media;

  /// The tool requests in the response.
  List<ToolRequest> get toolRequests => _response.toolRequests;

  /// The list of tool requests that triggered an interrupt.
  ///
  /// These parts contain metadata with the interrupt payload.
  List<ToolRequestPart> get interrupts {
    return _response.message?.content
            .where(
              (p) =>
                  p.isToolRequest &&
                  (p.metadata?.containsKey('interrupt') ?? false),
            )
            .map((p) => p.toolRequestPart!)
            .toList() ??
        [];
  }

  /// Tries to parse the output as JSON.
  ///
  /// This will be populated if the output format is JSON, or if the output is
  /// arbitrarily parsed as JSON.
  O? get jsonOutput {
    if (output != null) return output;
    return extractJson(text) as O?;
  }

  ModelResponse get rawResponse => _response;
}
