import 'package:genkit/schema.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/flow.dart';
import 'package:genkit/src/core/registry.dart';

class Genkit {
  Registry registry = Registry();

  Genkit();

  Flow<I, O, S> defineFlow<I, O, S>({
    required String name,
    required ActionFn<I, O, S> fn,
    JsonExtensionType<I>? inputType,
    JsonExtensionType<O>? outputType,
    JsonExtensionType<S>? streamType,
  }) {
    final flow = Flow(
      name: name,
      fn: fn,
      inputType: inputType,
      outputType: outputType,
      streamType: streamType,
    );
    registry.register(flow);
    return flow;
  }
}
