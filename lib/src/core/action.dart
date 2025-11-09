import 'dart:async';
import 'package:genkit/client.dart';
import 'package:genkit/schema.dart';
import 'package:genkit/src/o11y/instrumentation.dart';

typedef StreamingCallback<S> = void Function(S chunk);

typedef ActionFnArg<S> = ({
  bool streamingRequested,
  StreamingCallback<S> sendChunk,
  Map<String, dynamic>? context,
});

typedef ActionRunOptions<S> = ({
  StreamingCallback<S>? onChunk,
  Map<String, dynamic>? context,
});

typedef ActionFn<I, O, S> = Future<O> Function(I input, ActionFnArg<S> context);

class Action<I, O, S> {
  String name;
  String actionType;
  JsonExtensionType<I>? inputType;
  JsonExtensionType<O>? outputType;
  JsonExtensionType<S>? streamType;
  ActionFn<I, O, S> fn;

  Future<O> run(I input, ActionRunOptions<S>? options) {
    return runInNewSpan(
      name,
      (telemetryContext) {
        return fn(input, (
          // TODO: try to check if sentinel onChunk callback is used.
          streamingRequested: options?.onChunk != null,
          sendChunk: options?.onChunk ?? (chunk) {},
          // TODO: fallback to context from Async Context
          context: options?.context ?? {},
        ));
      },
      actionType: actionType,
      input: input,
    );
  }

  ActionStream<S, O> stream(I input, ActionRunOptions<S>? options) {
    final streamController = StreamController<S>();
    final actionStream = ActionStream<S, O>(streamController.stream);

    final runOptions = (
      onChunk: (S chunk) {
        if (streamController.isClosed) return;
        streamController.add(chunk);
        options?.onChunk?.call(chunk);
      },
      context: options?.context,
    );

    run(input, runOptions).then((result) {
      actionStream.setResult(result);
      if (!streamController.isClosed) {
        streamController.close();
      }
    }).catchError((e, s) {
      actionStream.setError(e, s);
      if (!streamController.isClosed) {
        streamController.addError(e, s);
        streamController.close();
      }
    });

    return actionStream;
  }

  Action({
    required this.actionType,
    required this.name,
    required this.fn,
    this.inputType,
    this.outputType,
    this.streamType,
  });
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
