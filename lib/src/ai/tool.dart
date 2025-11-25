import 'package:genkit/src/core/action.dart';

class Tool<I, O> extends Action<I, O, dynamic> {
  Tool({
    required super.name,
    required super.description,
    required super.fn,
    super.inputType,
    super.outputType,
    super.metadata,
  }) : super(actionType: 'tool');
}
