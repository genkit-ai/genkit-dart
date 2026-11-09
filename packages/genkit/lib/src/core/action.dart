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

import 'package:meta/meta.dart';
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

  /// An ad-hoc step inside a flow (e.g. `ai.run(name, fn)`).
  static const ActionType flowStep = ActionType('flowStep');

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

/// The per-invocation context handed to an action's implementation function.
///
/// A class rather than a record so fields can be added without breaking code
/// that constructs one (middleware that wraps `ctx` to intercept chunks, tests
/// that invoke an action function directly). Use [copyWith] to derive a
/// context that differs in one field:
///
/// ```dart
/// final wrapped = ctx.copyWith(sendChunk: (chunk) => ctx.sendChunk(tweak(chunk)));
/// return next(request, wrapped);
/// ```
final class ActionFnArg<Chunk, Input, Init> {
  /// Whether the caller is consuming streamed chunks. When `false`, chunks
  /// passed to [sendChunk] are dropped, so an action may skip producing them.
  final bool streamingRequested;

  /// Emits a streamed chunk to the caller.
  final StreamingCallback<Chunk> sendChunk;

  /// Request-scoped context (auth, headers, etc.) supplied by the caller.
  final Map<String, dynamic>? context;

  /// The input stream of a bidirectional action; `null` for unary actions.
  ///
  /// Experimental: bidirectional streaming is not covered by semver and may
  /// change in any minor release.
  final Stream<Input>? inputStream;

  /// The initialization payload of a bidirectional action or agent; `null`
  /// otherwise.
  ///
  /// Experimental: bidirectional streaming is not covered by semver and may
  /// change in any minor release.
  final Init? init;

  /// A read-only cancellation token the action body should observe to abort
  /// cooperatively, or `null` when the caller wired up no cancellation. Observe
  /// it with null-aware calls, e.g. `ctx.cancel?.throwIfCancelled()`.
  final CancellationToken? cancel;

  /// Creates an action context. [sendChunk] defaults to a no-op.
  ActionFnArg({
    this.streamingRequested = false,
    StreamingCallback<Chunk>? sendChunk,
    this.context,
    this.inputStream,
    this.init,
    this.cancel,
  }) : sendChunk = sendChunk ?? _dropChunk;

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields cannot be cleared this way (passing `null` keeps the
  /// current value); construct a new [ActionFnArg] for that.
  ActionFnArg<Chunk, Input, Init> copyWith({
    bool? streamingRequested,
    StreamingCallback<Chunk>? sendChunk,
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
    Init? init,
    CancellationToken? cancel,
  }) {
    return ActionFnArg(
      streamingRequested: streamingRequested ?? this.streamingRequested,
      sendChunk: sendChunk ?? this.sendChunk,
      context: context ?? this.context,
      inputStream: inputStream ?? this.inputStream,
      init: init ?? this.init,
      cancel: cancel ?? this.cancel,
    );
  }
}

void _dropChunk(Object? _) {}

typedef ActionFn<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Input input,
      ActionFnArg<Chunk, Input, Init> context,
    );

/// The implementation function of a bidirectional action.
///
/// Experimental: lives behind `package:genkit/experimental.dart`.
@experimental
typedef BidiActionFn<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Stream<Input> inputStream,
      ActionFnArg<Chunk, Input, Init> context,
    );

/// The low-level implementation function stored by [Action].
///
/// The input is nullable because [Action] also backs bidirectional actions
/// (which receive their input via `context.inputStream`) and actions whose
/// input is optional. Typed subclasses such as `Model`, `Embedder`,
/// `Evaluator`, `Flow` and `Tool` take a non-null [ActionFn] (or
/// [BidiActionFn]) instead and reject a null input before it reaches your
/// code.
typedef RawActionFn<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Input? input,
      ActionFnArg<Chunk, Input, Init> context,
    );

/// Adapts a non-null-input [ActionFn] to the [RawActionFn] that [Action]
/// stores, rejecting a null input with `INVALID_ARGUMENT`.
///
/// The check is `null is! Input`, so actions declared with a nullable,
/// `void` or `dynamic` input still receive `null`.
@internal
RawActionFn<Input, Output, Chunk, Init> requireInput<
  Input,
  Output,
  Chunk,
  Init
>(String kind, String name, ActionFn<Input, Output, Chunk, Init> fn) {
  return (input, ctx) {
    if (input == null && null is! Input) {
      throw GenkitException(
        '$kind "$name" requires a non-null input.',
        status: StatusCode.invalidArgument,
      );
    }
    return fn(input as Input, ctx);
  };
}

/// Adapts a [BidiActionFn] to the [RawActionFn] that [Action] stores. The
/// unary input is ignored; bidi actions read `context.inputStream`, which
/// `Action.run` always supplies.
@internal
RawActionFn<Input, Output, Chunk, Init> bidiInput<Input, Output, Chunk, Init>(
  String kind,
  String name,
  BidiActionFn<Input, Output, Chunk, Init> fn,
) {
  return (_, ctx) {
    final inputStream = ctx.inputStream;
    if (inputStream == null) {
      throw GenkitException(
        '$kind "$name" called without an input stream.',
        status: StatusCode.invalidArgument,
      );
    }
    return fn(inputStream, ctx);
  };
}

final class RunResult<Output> {
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

base class ActionMetadata<Input, Output, Chunk, Init> {
  final String name;
  final String? description;
  final ActionType actionType;
  final SchemanticType<Input>? inputSchema;
  final SchemanticType<Output>? outputSchema;
  final SchemanticType<Chunk>? streamSchema;
  final SchemanticType<Init>? initSchema;
  final Map<String, dynamic> metadata;

  /// The fully-qualified registry key (`/$actionType/$name`) or, for actions
  /// resolved through a dynamic action provider, the DAP key
  /// (`/dynamic-action-provider/<host>:<actionType>/<name>`).
  ///
  /// Null for locally-defined actions until stamped (a DAP stamps this onto the
  /// actions it resolves so their provenance survives into tool definitions and
  /// traces). Mirrors JS's `__action.key`.
  String? get key => _registryKey;

  /// Stamps [key] after construction.
  ///
  /// Only the dynamic action provider does this, for actions it resolves but
  /// did not construct; everything else passes `key` to the constructor. A key
  /// identifies the action in traces and tool definitions, so once set it can
  /// only be re-stamped with the same value.
  @internal
  set key(String? value) {
    final current = _registryKey;
    if (current != null && value != current) {
      throw StateError(
        'Action "$name" already has key "$current"; cannot change it to '
        '"$value".',
      );
    }
    _registryKey = value;
  }

  String? _registryKey;

  ActionMetadata({
    required this.name,
    this.actionType = .custom,
    this.description,
    String? key,

    this.inputSchema,
    this.outputSchema,
    this.streamSchema,
    this.initSchema,
    Map<String, dynamic>? metadata,
  }) : _registryKey = key,
       metadata = metadata ?? {};

  Map<String, dynamic> toJson() {
    // `jsonSchema` is a method, so it must be called; a bare tearoff would put a
    // Function into the map and break jsonEncode (e.g. when a DAP's
    // List<ActionMetadata> output is serialized into a trace). Use `useRefs`
    // ($ref + $defs) to match the reflection manifest and avoid the inline path,
    // which fails for some composite schemas (e.g. GenerateActionOptions).
    return {
      'name': name,
      if (key != null) 'key': key,
      'description': description,
      if (inputSchema != null)
        'inputSchema': inputSchema!.jsonSchema(useRefs: true),
      if (outputSchema != null)
        'outputSchema': outputSchema!.jsonSchema(useRefs: true),
      if (streamSchema != null)
        'streamSchema': streamSchema!.jsonSchema(useRefs: true),
      if (initSchema != null)
        'initSchema': initSchema!.jsonSchema(useRefs: true),
    };
  }
}

base class Action<Input, Output, Chunk, Init>
    extends ActionMetadata<Input, Output, Chunk, Init> {
  final RawActionFn<Input, Output, Chunk, Init> _fn;

  /// Creates a low-level action. Prefer the typed subclasses (`Model`,
  /// `Flow`, `Tool`, ...), which take a non-null-input function.
  Action({
    required super.name,
    required super.actionType,
    required this._fn,
    super.inputSchema,
    super.outputSchema,
    super.streamSchema,
    super.initSchema,
    super.description,
    super.metadata,
    super.key,
  });

  /// The output schema surfaced when building action manifests (Dev UI,
  /// reflection).
  ///
  /// Defaults to [outputSchema]. `Tool` overrides it to expose the declared
  /// output schema instead of its `ToolResult<Output>` wrapper.
  @internal
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
      // A null input skips parsing so typed actions reject it with a clear
      // INVALID_ARGUMENT (see requireInput) instead of a schema type error.
      // Mirrors the `init` handling below and genkit_shelf.
      (inputSchema != null && input != null)
          ? inputSchema!.parse(input)
          : input as Input?,
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

    final executionContext =
        context ?? Zone.current[_genkitContextKey] as Map<String, dynamic>?;
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
          _recordContextMetadata(executionContext);
          return await _fn(
            input,
            ActionFnArg(
              streamingRequested: onChunk != null,
              sendChunk: onChunk,
              context: executionContext,
              inputStream: inputStream,
              init: init,
              cancel: cancel,
            ),
          );
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

  /// Records the execution context on the current span, redacting sensitive
  /// top-level keys (`auth`, `secrets`). Serialization errors are swallowed so
  /// telemetry never crashes the action.
  void _recordContextMetadata(Object? context) {
    if (context is! Map) return;
    try {
      final traced = {...context};
      if (traced.containsKey('auth')) traced['auth'] = '<redacted>';
      if (traced.containsKey('secrets')) traced['secrets'] = '<redacted>';
      setCustomMetadataAttributes({'context': traced});
    } catch (_) {
      // Ignore telemetry serialization errors.
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

  /// Starts a bidirectional session with this action: send inputs with
  /// [BidiActionStream.send] while consuming output chunks.
  ///
  /// Experimental: bidirectional streaming is not covered by semver and may
  /// change in any minor release.
  @experimental
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
///
/// Listen to it for the chunks; read [onResult] (or [result], once the stream
/// is done) for the final response.
///
/// To create one outside this package (for example a fake `RemoteAction` in
/// tests), use [ActionStream.withResult]:
///
/// ```dart
/// final stream = ActionStream.withResult(
///   Stream.fromIterable(['Hel', 'lo']),
///   Future.value('Hello'),
/// );
/// ```
base class ActionStream<Chunk, Response> extends StreamView<Chunk> {
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
  ///
  /// Producer-side API for the code that created this stream; consumers must
  /// not call it.
  @internal
  void setResult(Response result) {
    _done = true;
    _result = result;
    if (_completer?.isCompleted == false) {
      _completer!.complete(result);
    }
  }

  /// Sets an error on the action stream and completes the future with an error.
  ///
  /// Producer-side API for the code that created this stream; consumers must
  /// not call it.
  @internal
  void setError(Object error, StackTrace st) {
    _done = true;
    _streamError = error;
    _streamStackTrace = st;
    if (_completer?.isCompleted == false) {
      _completer!.completeError(error, st);
    }
  }

  /// Creates an [ActionStream] over [stream] whose result is supplied later
  /// by the producer.
  ///
  /// Outside this package, prefer [ActionStream.withResult]: the producer-side
  /// setters are internal.
  ActionStream(super.stream);

  /// Creates an [ActionStream] that emits [stream] and completes [onResult]
  /// with [result] (or its error).
  ActionStream.withResult(super.stream, Future<Response> result) {
    result.then(setResult, onError: setError);
  }
}

/// A bi-directional version of [ActionStream] that allows sending chunks back to the action.
///
/// Experimental: lives behind `package:genkit/experimental.dart`.
@experimental
final class BidiActionStream<Chunk, Response, Request>
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
