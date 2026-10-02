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

import '../schema_extensions.dart';
import '../types.dart';

/// A chunk of a response from a generate action: the model's chunk plus the
/// partially parsed [output] and the chunks streamed before it.
///
/// A read-only view over [modelChunk], deliberately not a [ModelResponseChunk]
/// subtype: the wire type has setters, and writing through them would not
/// update this view's derived getters. Use [modelChunk] where a
/// [ModelResponseChunk] is expected (e.g. a flow's `streamSchema`).
final class GenerateResponseChunk<Output> {
  final ModelResponseChunk _chunk;

  /// The chunks streamed before this one, in order.
  final List<ModelResponseChunk> previousChunks;

  /// The output parsed from everything streamed so far, or null while it is
  /// not yet parseable.
  final Output? output;

  GenerateResponseChunk(
    this._chunk, {
    this.previousChunks = const [],
    this.output,
  });

  /// The underlying wire chunk, as emitted by the model.
  ModelResponseChunk get modelChunk => _chunk;

  /// The parts in this chunk.
  List<Part> get content => _chunk.content;

  /// The role of the message this chunk belongs to.
  Role? get role => _chunk.role;

  /// The index of the message this chunk belongs to, when the model streams
  /// more than one message.
  int? get index => _chunk.index;

  /// Provider-specific data attached to the chunk.
  Map<String, dynamic>? get custom => _chunk.custom;

  /// The text in this chunk.
  String get text => _chunk.text;

  /// The media in this chunk, if any.
  Media? get media => _chunk.media;

  /// The text of all chunks so far, including this one.
  String get accumulatedText {
    final buffer = StringBuffer();
    for (final chunk in previousChunks) {
      buffer.write(chunk.text);
    }
    buffer.write(text);
    return buffer.toString();
  }

  /// The wire JSON of [modelChunk], so a chunk can be encoded directly (e.g.
  /// `jsonEncode(chunk)` in untyped flows and the Dev UI stream).
  /// [previousChunks] and [output] are not included.
  ///
  /// Read-only forwarding is safe: the view holds no copy that could go stale.
  Map<String, dynamic> toJson() => _chunk.toJson();

  @override
  String toString() => 'GenerateResponseChunk(${_chunk.toJson()})';
}

/// A response to an interrupted tool request.
final class InterruptResponse {
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

/// The result of `generate`: the final model response plus the parsed
/// [output], the full conversation [messages], and the originating request.
///
/// A read-only view over [modelResponse], deliberately not a wire-type
/// subtype: the wire types have setters, and writing through them would not
/// update this view's derived getters. Use [modelResponse] where a
/// [ModelResponse] is expected.
final class GenerateResult<Output> {
  final ModelResponse _response;
  final ModelRequest? _request;

  /// The structured output, parsed with the output schema when one was given.
  final Output? output;

  /// The original thrown error a failed response resolved from, for callers
  /// that want to inspect the raw exception (e.g. `cause is SocketException`).
  /// The serializable view lives on [error]; `cause` is in-process only and
  /// does NOT survive the reflection/HTTP boundary (like [modelRequest]).
  final Object? cause;

  GenerateResult(this._response, {this._request, this.output, this.cause});

  /// The underlying wire response, as returned by the model.
  ModelResponse get modelResponse => _response;

  /// The request sent to the model on the final turn, when known.
  ModelRequest? get modelRequest => _request;

  /// The model's reply, or null when the turn produced none (e.g. aborted).
  Message? get message => _response.message;

  /// Why the model stopped generating.
  FinishReason get finishReason => _response.finishReason;

  /// A human-readable explanation of [finishReason], if the model gave one.
  String? get finishMessage => _response.finishMessage;

  /// The structured error of a failed response (`finishReason: failed`);
  /// null on success.
  RuntimeError? get error => _response.error;

  /// Token and media usage reported by the model.
  GenerationUsage? get usage => _response.usage;

  /// How long the model call took, in milliseconds.
  double? get latencyMs => _response.latencyMs;

  /// Provider-specific data attached to the response.
  Map<String, dynamic>? get custom => _response.custom;

  /// The provider's raw response payload, if the plugin attached it.
  Map<String, dynamic>? get raw => _response.raw;

  /// The long-running operation started by the model, if any.
  Operation? get operation => _response.operation;

  /// The full history of the conversation, including the request messages and
  /// the final model response.
  ///
  /// This is useful for continuing the conversation in multi-turn scenarios.
  /// When the response has no message (e.g. an aborted turn), only the request
  /// history is returned, so callers can attempt to resume from the last good
  /// state.
  List<Message> get messages => [
    ...(_request?.messages ?? _response.request?.messages ?? []),
    if (_response.message != null) _response.message!,
  ];

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

  /// The wire JSON of [modelResponse], valid against `GenerateResponse` (minus
  /// the legacy `candidates`), so a result can be returned from an untyped
  /// flow or passed to `jsonEncode`. [output], [modelRequest] and [cause] are
  /// not included.
  ///
  /// Read-only forwarding is safe: the view holds no copy that could go stale.
  Map<String, dynamic> toJson() => _response.toJson();

  @override
  String toString() => 'GenerateResult(${_response.toJson()})';
}
