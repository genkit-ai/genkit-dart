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

import 'package:schemantic/schemantic.dart';

import '../exception.dart';
import '../o11y/instrumentation.dart';
import 'cancellation.dart';

const _genkitContextKey = #genkitContext;

/// Well-known action type identifiers used as the `actionType` of an [Action]
/// and as the first segment of its registry key (`/$actionType/$name`).
///
/// This is a string-backed, open "enum" (following the same pattern as `Role`).
/// The known constants below give type-safe names and autocomplete, while
/// custom types remain expressible via the unnamed constructor, e.g.
/// `ActionType('my-custom-type')`.
extension type const ActionType(String value) {
  /// A model action.
  static const ActionType model = ActionType('model');

  /// A bidirectional (streaming) model action.
  static const ActionType bidiModel = ActionType('bidi-model');

  /// A flow action.
  static const ActionType flow = ActionType('flow');

  /// An embedder action.
  static const ActionType embedder = ActionType('embedder');

  /// An evaluator action.
  static const ActionType evaluator = ActionType('evaluator');

  /// A resource action.
  static const ActionType resource = ActionType('resource');

  /// An executable prompt action.
  static const ActionType executablePrompt = ActionType('executable-prompt');

  /// A prompt template action.
  static const ActionType promptTemplate = ActionType('promptTemplate');

  /// A dotprompt action.
  static const ActionType dotprompt = ActionType('dotprompt');

  /// An agent action.
  static const ActionType agent = ActionType('agent');

  /// An agent snapshot data action.
  static const ActionType agentSnapshot = ActionType('agent-snapshot');

  /// An agent abort action.
  static const ActionType agentAbort = ActionType('agent-abort');

  /// A dynamic action provider.
  static const ActionType dynamicActionProvider = ActionType(
    'dynamic-action-provider',
  );

  /// A utility action (e.g. the built-in `generate` action).
  static const ActionType util = ActionType('util');

  /// The default action type for actions that don't specify one.
  static const ActionType custom = ActionType('custom');

  /// The action type for tools.
  ///
  /// Its wire value is `tool.v2`: every Genkit Dart tool implements the
  /// multipart ("v2") tool contract (its function returns a `ToolResult` that
  /// serializes to `{output, content?, metadata?}`), so tools are registered
  /// and resolved under `tool.v2`. External consumers such as the Dev UI use
  /// this to render/run tools as multipart.
  static const ActionType tool = ActionType('tool.v2');
}

typedef StreamingCallback<Chunk> = void Function(Chunk chunk);

typedef TraceStartCallback =
    void Function({required String traceId, required String spanId});

typedef ActionFnArg<Chunk, Input, Init> = ({
  bool streamingRequested,
  StreamingCallback<Chunk> sendChunk,
  Map<String, dynamic>? context,
  Stream<Input>? inputStream,
  Init? init,

  /// A read-only cancellation token the action body should observe to abort
  /// cooperatively, or `null` when the caller wired up no cancellation. Observe
  /// it with null-aware calls, e.g. `ctx.cancel?.throwIfCancelled()`.
  CancellationToken? cancel,
});

typedef ActionFn<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Input input,
      ActionFnArg<Chunk, Input, Init> context,
    );

typedef BidiActionFn<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Stream<Input> inputStream,
      ActionFnArg<Chunk, Input, Init> context,
    );

typedef InternalActionFn<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Input? input,
      ActionFnArg<Chunk, Input, Init> context,
    );

class RunResult<Output> {
  final Output result;
  final String traceId;
  final String spanId;

  RunResult({
    required this.result,
    required this.traceId,
    required this.spanId,
  });

  Map<String, dynamic> toJson() {
    return {'result': result, 'traceId': traceId, 'spanId': spanId};
  }
}

class ActionMetadata<Input, Output, Chunk, Init> {
  final String name;
  final String? description;
  final ActionType actionType;
  final SchemanticType<Input>? inputSchema;
  final SchemanticType<Output>? outputSchema;
  final SchemanticType<Chunk>? streamSchema;
  final SchemanticType<Init>? initSchema;
  final Map<String, dynamic> metadata;

  ActionMetadata({
    required this.name,
    this.actionType = .custom,
    this.description,

    this.inputSchema,
    this.outputSchema,
    this.streamSchema,
    this.initSchema,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema?.jsonSchema,
      'outputSchema': outputSchema?.jsonSchema,
      'streamSchema': streamSchema?.jsonSchema,
      'initSchema': initSchema?.jsonSchema,
    };
  }
}

class Action<Input, Output, Chunk, Init>
    extends ActionMetadata<Input, Output, Chunk, Init> {
  final InternalActionFn<Input, Output, Chunk, Init> fn;

  Action({
    required super.name,
    required super.actionType,
    required this.fn,
    super.inputSchema,
    super.outputSchema,
    super.streamSchema,
    super.initSchema,
    super.description,
    super.metadata,
  });

  /// The output schema surfaced when building action manifests (Dev UI,
  /// reflection) and tool definitions.
  ///
  /// Defaults to [outputSchema]. Subclasses such as `Tool` override this to
  /// expose the user-declared output schema instead of an internal wrapper
  /// type (for example `ToolResult<Output>`).
  SchemanticType? get manifestOutputSchema => outputSchema;

  @override
  String toString() {
    return 'Action(name: $name, actionType: $actionType)';
  }

  Future<Output> call(
    Input? input, {
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
    Init? init,
    TraceStartCallback? onTraceStart,
    CancellationToken? cancel,
  }) async {
    return (await run(
      input,
      onChunk: onChunk,
      context: context,
      inputStream: inputStream,
      // Validate `init` against the schema, matching `runRaw`. The static type
      // only guarantees shape; value-level constraints (enum membership,
      // numeric ranges, required nested fields) still need the schema. Skip
      // when either the schema or the value is absent, mirroring `runRaw`.
      init: (initSchema != null && init != null)
          ? initSchema!.parse(init)
          : init,
      onTraceStart: onTraceStart,
      cancel: cancel,
    )).result;
  }

  Future<RunResult<Output>> runRaw(
    dynamic input, {
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
    dynamic init,
    TraceStartCallback? onTraceStart,
    CancellationToken? cancel,
  }) async {
    return await run(
      inputSchema != null ? inputSchema!.parse(input) : input as Input?,
      onChunk: onChunk,
      context: context,
      inputStream: inputStream,
      cancel: cancel,
      // Skip validation when no init was supplied. `init` is optional on the
      // first request (e.g. an agent's fresh session sends no init), so a null
      // value must pass through untouched rather than be validated against a
      // non-nullable init schema. Mirrors the Go core's `isNilValue(init)`
      // guard and JS's convention of only validating a present init.
      init: (initSchema != null && init != null)
          ? initSchema!.parse(init)
          : init as Init?,
      onTraceStart: onTraceStart,
    );
  }

  Future<RunResult<Output>> run(
    Input? input, {
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
    Init? init,
    TraceStartCallback? onTraceStart,
    CancellationToken? cancel,
  }) async {
    // Bail before doing any work if the caller's token is already cancelled.
    cancel?.throwIfCancelled();

    if (inputStream == null) {
      final internalInputController = StreamController<Input>();
      inputStream = internalInputController.stream;
      if (input != null) {
        internalInputController.add(input);
      }
      internalInputController.close();
    }

    final executionContext = context ?? Zone.current[_genkitContextKey];
    Future<RunResult<Output>> runner() async {
      var traceId = '';
      var spanId = '';
      final result = await runInNewSpan(
        name,
        (telemetryContext) async {
          traceId = telemetryContext.traceId;
          spanId = telemetryContext.spanId;
          if (onTraceStart != null) {
            onTraceStart(traceId: traceId, spanId: spanId);
          }
          return await fn(input, (
            streamingRequested: onChunk != null,
            sendChunk: onChunk ?? (chunk) {},
            context: executionContext,
            inputStream: inputStream,
            init: init,
            cancel: cancel,
          ));
        },
        actionType: actionType.value,
        input: input,
      );
      return RunResult<Output>(
        result: result,
        traceId: traceId,
        spanId: spanId,
      );
    }

    if (context != null) {
      return runZoned(runner, zoneValues: {_genkitContextKey: context});
    } else {
      return runner();
    }
  }

  ActionStream<Chunk, Output> stream(
    Input? input, {
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
    Init? init,
    CancellationToken? cancel,
  }) {
    final streamController = StreamController<Chunk>();
    final actionStream = ActionStream<Chunk, Output>(streamController.stream);

    run(
          input,
          context: context,
          inputStream: inputStream,
          init: init,
          cancel: cancel,
          onChunk: (chunk) {
            if (!streamController.isClosed) {
              streamController.add(chunk);
            }
          },
        )
        .then((result) {
          actionStream.setResult(result.result);
          if (!streamController.isClosed) {
            streamController.close();
          }
        })
        .catchError((Object e, StackTrace s) {
          actionStream.setError(e, s);
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            streamController.close();
          }
        });

    return actionStream;
  }

  BidiActionStream<Chunk, Output, Input> streamBidi({
    Stream<Input>? inputStream,
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Init? init,
    CancellationToken? cancel,
  }) {
    StreamController<Input>? internalInputController;
    if (inputStream == null) {
      internalInputController = StreamController<Input>();
      inputStream = internalInputController.stream;
    }

    final streamController = StreamController<Chunk>();
    final bidiStream = BidiActionStream<Chunk, Output, Input>(
      streamController.stream,
      internalInputController?.sink,
    );

    run(
          null, // Pass null for unary input
          onChunk: (chunk) {
            if (!streamController.isClosed) {
              streamController.add(chunk);
            }
            if (onChunk != null) {
              onChunk(chunk);
            }
          },
          context: context,
          inputStream: inputStream,
          init: init,
          cancel: cancel,
        )
        .then((result) {
          bidiStream.setResult(result.result);
          if (!streamController.isClosed) {
            streamController.close();
          }
        })
        .catchError((Object e, StackTrace s) {
          bidiStream.setError(e, s);
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            streamController.close();
          }
        });

    return bidiStream;
  }
}

/// A stream of chunks emitted by an action, which also resolves to a final response.
class ActionStream<Chunk, Response> extends StreamView<Chunk> {
  bool _done = false;
  Response? _result;
  Object? _streamError;
  StackTrace? _streamStackTrace;
  Completer<Response>? _completer;

  /// A future that resolves to the final response of the action once the stream is complete.
  Future<Response> get onResult {
    if (_completer == null) {
      _completer = Completer<Response>();
      if (_done) {
        if (_streamError != null) {
          _completer!.completeError(_streamError!, _streamStackTrace);
        } else {
          _completer!.complete(_result as Response);
        }
      }
    }
    return _completer!.future;
  }

  /// The final response of the action, throws an error if the stream has not completed yet.
  Response get result {
    if (!_done) {
      throw GenkitException('Stream not consumed yet');
    }
    if (_streamError != null) {
      // ignore: only_throw_errors
      throw _streamError!;
    }
    return _result as Response;
  }

  /// Sets the final result of the action stream and completes the future.
  void setResult(Response result) {
    _done = true;
    _result = result;
    if (_completer?.isCompleted == false) {
      _completer!.complete(result);
    }
  }

  /// Sets an error on the action stream and completes the future with an error.
  void setError(Object error, StackTrace st) {
    _done = true;
    _streamError = error;
    _streamStackTrace = st;
    if (_completer?.isCompleted == false) {
      _completer!.completeError(error, st);
    }
  }

  /// Creates a new [ActionStream] from a [Stream] of chunks.
  ActionStream(super.stream);
}

/// A bi-directional version of [ActionStream] that allows sending chunks back to the action.
class BidiActionStream<Chunk, Response, Request>
    extends ActionStream<Chunk, Response> {
  final StreamSink<Request>? _inputSink;
  bool _inputClosed = false;

  BidiActionStream(super.stream, this._inputSink);

  /// Whether the input side of this stream has been closed via [close].
  bool get isClosed => _inputClosed;

  /// Sends a chunk of data back to the action.
  ///
  /// No-op once the input side has been [close]d (e.g. after a cooperative
  /// cancel tears the session down): adding to a closed [StreamSink] throws a
  /// `StateError`, so a late send that races the close is silently dropped
  /// rather than crashing the caller.
  void send(Request chunk) {
    if (_inputSink == null) {
      throw GenkitException('Cannot send to this stream (external input)');
    }
    if (_inputClosed) return;
    _inputSink.add(chunk);
  }

  /// Closes the input sink.
  Future<void> close() async {
    _inputClosed = true;
    await _inputSink?.close();
  }
}
