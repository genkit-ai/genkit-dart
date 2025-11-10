import 'package:genkit/src/core/action.dart';

class Flow<I, O, S> extends Action<I, O, S> {
  Flow({
    required super.name,
    required super.fn,
    super.inputType,
    super.outputType,
    super.streamType,
    super.metadata,
  }) : super(actionType: 'flow');
}
