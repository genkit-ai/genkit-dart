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

const _genkitContextKey = #genkitContext;

typedef StreamingCallback<S> = void Function(S chunk);

typedef ActionFnArg<S, I, Init> = ({
  bool streamingRequested,
  StreamingCallback<S> sendChunk,
  Map<String, dynamic>? context,
  Stream<I>? inputStream,
  Init? init,
});

typedef ActionFn<I, O, S, Init> =
    Future<O> Function(I input, ActionFnArg<S, I, Init> context);

typedef BidiActionFn<I, O, S, Init> =
    Future<O> Function(Stream<I> inputStream, ActionFnArg<S, I, Init> context);

typedef InternalActionFn<I, O, S, Init> =
    Future<O> Function(I? input, ActionFnArg<S, I, Init> context);

class RunResult<O> {
  final O result;
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

class ActionMetadata<I, O, S, Init> {
  final String name;
  final String? description;
  final String actionType;
  final SchemanticType<I>? inputSchema;
  final SchemanticType<O>? outputSchema;
  final SchemanticType<S>? streamSchema;
  final SchemanticType<Init>? initSchema;
  final Map<String, dynamic> metadata;

  ActionMetadata({
    required this.name,
    this.actionType = 'custom', // Default or required?
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

class Action<I, O, S, Init> extends ActionMetadata<I, O, S, Init> {
  final InternalActionFn<I, O, S, Init> fn;

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

  @override
  String toString() {
    return 'Action(name: $name, actionType: $actionType)';
  }

  Future<O> call(
    I? input, {
    StreamingCallback<S>? onChunk,
    Map<String, dynamic>? context,
    Stream<I>? inputStream,
    Init? init,
  }) async {
    return (await run(input, onChunk: onChunk, context: context)).result;
  }

  Future<RunResult<O>> runRaw(
    dynamic input, {
    StreamingCallback<S>? onChunk,
    Map<String, dynamic>? context,
    Stream<I>? inputStream,
    dynamic init,
  }) async {
    return await run(
      inputSchema != null ? inputSchema!.parse(input) : input,
      onChunk: onChunk,
      context: context,
      inputStream: inputStream,
      init: initSchema != null ? initSchema!.parse(init) : init,
    );
  }

  Future<RunResult<O>> run(
    I? input, {
    StreamingCallback<S>? onChunk,
    Map<String, dynamic>? context,
    Stream<I>? inputStream,
    Init? init,
  }) async {
    if (inputStream == null) {
      final internalInputController = StreamController<I>();
      inputStream = internalInputController.stream;
      if (input != null) {
        internalInputController.add(input);
      }
      internalInputController.close();
    }

    final executionContext = context ?? Zone.current[_genkitContextKey];
    Future<RunResult<O>> runner() async {
      var traceId = '';
      var spanId = '';
      final result = await runInNewSpan(
        name,
        (telemetryContext) async {
          traceId = telemetryContext.traceId;
          spanId = telemetryContext.traceId;
          return await fn(input, (
            streamingRequested: onChunk != null,
            sendChunk: onChunk ?? (chunk) {},
            context: executionContext,
            inputStream: inputStream,
            init: init,
          ));
        },
        actionType: actionType,
        input: input,
      );
      return RunResult<O>(result: result, traceId: traceId, spanId: spanId);
    }

    if (context != null) {
      return runZoned(runner, zoneValues: {_genkitContextKey: context});
    } else {
      return runner();
    }
  }

  ActionStream<S, O> stream(
    I? input, {
    Map<String, dynamic>? context,
    Stream<I>? inputStream,
    Init? init,
  }) {
    final streamController = StreamController<S>();
    final actionStream = ActionStream<S, O>(streamController.stream);

    run(
          input,
          context: context,
          inputStream: inputStream,
          init: init,
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
        .catchError((e, s) {
          actionStream.setError(e, s);
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            streamController.close();
          }
        });

    return actionStream;
  }

  BidiActionStream<S, O, I> streamBidi({
    Stream<I>? inputStream,
    StreamingCallback<S>? onChunk,
    Map<String, dynamic>? context,
    Init? init,
  }) {
    StreamController<I>? internalInputController;
    if (inputStream == null) {
      internalInputController = StreamController<I>();
      inputStream = internalInputController.stream;
    }

    final streamController = StreamController<S>();
    final bidiStream = BidiActionStream<S, O, I>(
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
        )
        .then((result) {
          bidiStream.setResult(result.result);
          if (!streamController.isClosed) {
            streamController.close();
          }
        })
        .catchError((e, s) {
          bidiStream.setError(e, s);
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            streamController.close();
          }
        });

    return bidiStream;
  }
}

class ActionStream<S, F> extends StreamView<S> {
  bool _done = false;
  F? _result;
  Object? _streamError;
  StackTrace? _streamStackTrace;
  Completer<F>? _completer;

  Future<F> get onResult {
    if (_completer == null) {
      _completer = Completer<F>();
      if (_done) {
        if (_streamError != null) {
          _completer!.completeError(_streamError!, _streamStackTrace);
        } else {
          _completer!.complete(_result as F);
        }
      }
    }
    return _completer!.future;
  }

  F get result {
    if (!_done) {
      throw GenkitException('Stream not consumed yet');
    }
    if (_streamError != null) {
      // ignore: only_throw_errors
      throw _streamError!;
    }
    return _result as F;
  }

  void setResult(F result) {
    _done = true;
    _result = result;
    if (_completer?.isCompleted == false) {
      _completer!.complete(result);
    }
  }

  void setError(Object error, StackTrace st) {
    _done = true;
    _streamError = error;
    _streamStackTrace = st;
    if (_completer?.isCompleted == false) {
      _completer!.completeError(error, st);
    }
  }

  ActionStream(super.stream);
}

class BidiActionStream<S, F, I> extends ActionStream<S, F> {
  final StreamSink<I>? _inputSink;

  BidiActionStream(super.stream, this._inputSink);

  void send(I chunk) {
    if (_inputSink == null) {
      throw GenkitException('Cannot send to this stream (external input)');
    }
    _inputSink.add(chunk);
  }

  Future<void> close() async {
    await _inputSink?.close();
  }
}
