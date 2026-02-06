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

typedef StreamingCallback<Chunk> = void Function(Chunk chunk);

class FunctionContext<Chunk, Input, Init> {
  final bool streamingRequested;
  final StreamingCallback<Chunk> sendChunk;
  final Map<String, dynamic>? context;
  final Stream<Input>? inputStream;
  final Init? init;

  const FunctionContext({
    required this.streamingRequested,
    required this.sendChunk,
    this.context,
    this.inputStream,
    this.init,
  });
}

typedef ActionFunction<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Input input,
      FunctionContext<Chunk, Input, Init> context,
    );

typedef BidiActionFunction<Input, Output, Chunk, Init> =
    Future<Output> Function(
      Stream<Input> inputStream,
      FunctionContext<Chunk, Input, Init> context,
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
    this.actionType = ActionType.custom, // Default or required?
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

class ActionType {
  final String value;

  static const ActionType embedder = ActionType._('embedder');
  static const ActionType flow = ActionType._('flow');
  static const ActionType model = ActionType._('model');
  static const ActionType tool = ActionType._('tool');
  static const ActionType custom = ActionType._('custom');
  static const ActionType unknown = ActionType._('unknown');
  static const ActionType bidiModel = ActionType._('bidi-model');
  static const ActionType util = ActionType._('util');
  static const ActionType format = ActionType._('format');
  static const ActionType middleware = ActionType._('middleware');

  const ActionType._(this.value);

  const ActionType.fromString(this.value);
}

class Action<Input, Output, Chunk, Init>
    extends ActionMetadata<Input, Output, Chunk, Init> {
  final Future<Output> Function(
    Input? input,
    FunctionContext<Chunk, Input, Init> context,
  )
  fn;

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
    return 'Action(name: $name, actionType: ${actionType.value})';
  }

  Future<Output> call(
    Input? input, {
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
    Init? init,
  }) async {
    return (await run(input, onChunk: onChunk, context: context)).result;
  }

  Future<RunResult<Output>> runRaw(
    dynamic input, {
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
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

  Future<RunResult<Output>> run(
    Input? input, {
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Stream<Input>? inputStream,
    Init? init,
  }) async {
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
          spanId = telemetryContext.traceId;
          return await fn(
            input,
            FunctionContext(
              streamingRequested: onChunk != null,
              sendChunk: onChunk ?? (chunk) {},
              context: executionContext,
              inputStream: inputStream,
              init: init,
            ),
          );
        },
        actionType: actionType,
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
  }) {
    final streamController = StreamController<Chunk>();
    final actionStream = ActionStream<Chunk, Output>(streamController.stream);

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

  BidiActionStream<Chunk, Output, Input> streamBidi({
    Stream<Input>? inputStream,
    StreamingCallback<Chunk>? onChunk,
    Map<String, dynamic>? context,
    Init? init,
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

class ActionStream<Chunk, Response> extends StreamView<Chunk> {
  bool _done = false;
  Response? _result;
  Object? _streamError;
  StackTrace? _streamStackTrace;
  Completer<Response>? _completer;

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

  void setResult(Response result) {
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

class BidiActionStream<Chunk, Response, Request>
    extends ActionStream<Chunk, Response> {
  final StreamSink<Request>? _inputSink;

  BidiActionStream(super.stream, this._inputSink);

  void send(Request chunk) {
    if (_inputSink == null) {
      throw GenkitException('Cannot send to this stream (external input)');
    }
    _inputSink.add(chunk);
  }

  Future<void> close() async {
    await _inputSink?.close();
  }
}
