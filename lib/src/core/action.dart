import 'dart:async';
import 'package:genkit/client.dart';
import 'package:genkit/schema.dart';
import 'package:genkit/src/o11y/instrumentation.dart';
import 'package:genkit/src/exception.dart';

const _genkitContextKey = #genkitContext;

typedef StreamingCallback<S> = void Function(S chunk);

typedef ActionFnArg<S> = ({
  bool streamingRequested,
  StreamingCallback<S> sendChunk,
  Map<String, dynamic>? context,
});

typedef ActionFn<I, O, S> = Future<O> Function(I input, ActionFnArg<S> context);

class ActionMetadata<I, O, S> {
  String name;
  String? description;
  String actionType;
  JsonExtensionType<I>? inputType;
  JsonExtensionType<O>? outputType;
  JsonExtensionType<S>? streamType;
  Map<String, dynamic> metadata;

  ActionMetadata({
    required this.actionType,
    required this.name,
    this.description,
    this.inputType,
    this.outputType,
    this.streamType,
    this.metadata = const {},
  }) {
    if (metadata.isEmpty) {
      metadata = {'description': description ?? name};
    }
  }
}

class Action<I, O, S> extends ActionMetadata<I, O, S> {
  ActionFn<I, O, S> fn;

  Action({
    required super.actionType,
    required super.name,
    super.description,
    super.inputType,
    super.outputType,
    super.streamType,
    super.metadata,
    required this.fn,
  });

  Future<O> call(
    I input, {
    StreamingCallback<S>? onChunk,
    Map<String, dynamic>? context,
  }) async {
    return (await run(input, onChunk: onChunk, context: context)).result;
  }

  Future<({O result, String traceId, String spanId})> run(
    I input, {
    StreamingCallback<S>? onChunk,
    Map<String, dynamic>? context,
  }) async {
    final executionContext = context ?? Zone.current[_genkitContextKey];
    Future<({O result, String traceId, String spanId})> runner() async {
      String traceId = '';
      String spanId = '';
      final result = await runInNewSpan(
        name,
        (telemetryContext) async {
          traceId = telemetryContext.traceId;
          spanId = telemetryContext.traceId;
          return await fn(input, (
            streamingRequested: onChunk != null,
            sendChunk: onChunk ?? (chunk) {},
            context: executionContext,
          ));
        },
        actionType: actionType,
        input: input,
      );
      return (result: result, traceId: traceId, spanId: spanId);
    }

    if (context != null) {
      return runZoned(runner, zoneValues: {_genkitContextKey: context});
    } else {
      return runner();
    }
  }

  ActionStream<S, O> stream(
    I input, {
    StreamingCallback<S>? onChunk,
    Map<String, dynamic>? context,
  }) {
    final streamController = StreamController<S>();
    final actionStream = ActionStream<S, O>(streamController.stream);

    call(
          input,
          onChunk: (S chunk) {
            if (streamController.isClosed) return;
            streamController.add(chunk);
            onChunk?.call(chunk);
          },
          context: context,
        )
        .then((result) {
          actionStream.setResult(result);
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
