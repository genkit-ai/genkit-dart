import 'package:genkit/src/core/action.dart';

class Model<I, O, S> extends Action<I, O, S> {
  Model({
    required super.name,
    required super.fn,
    super.inputType,
    super.outputType,
    super.streamType,
  }) : super(actionType: 'flow');
}
