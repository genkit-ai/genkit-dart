import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/generate.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/ai/tool.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/registry.dart';

export 'package:genkit/src/types.dart';
export 'package:genkit/src/schema_extensions.dart';

Future<ModelResponse> generate<C>({
  String? prompt,
  List<Message>? messages,
  required Model<C> model,
  C? config,
  List<Tool>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  GenerateOutput? output,
  Map<String, dynamic>? context,
  StreamingCallback<ModelResponseChunk>? onChunk,
}) async {
  final registry = Registry();
  registry.register(model);
  tools?.forEach((t) => registry.register(t));
  final generateAction = defineGenerateAction(registry);
  return generateHelper(
    generateAction,
    prompt: prompt,
    messages: messages,
    model: model,
    config: config,
    tools: tools?.map((t) => t.name).toList(),
    toolChoice: toolChoice,
    returnToolRequests: returnToolRequests,
    maxTurns: maxTurns,
    output: output,
    context: context,
    onChunk: onChunk,
  );
}

ActionStream<ModelResponseChunk, ModelResponse> generateStream<C>({
  required Model<C> model,
  String? prompt,
  List<Message>? messages,
  C? config,
  List<Tool>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  GenerateOutput? output,
  Map<String, dynamic>? context,
}) {
  final streamController = StreamController<ModelResponseChunk>();
  final actionStream = ActionStream<ModelResponseChunk, ModelResponse>(
    streamController.stream,
  );

  generate(
        prompt: prompt,
        messages: messages,
        model: model,
        config: config,
        tools: tools,
        toolChoice: toolChoice,
        returnToolRequests: returnToolRequests,
        maxTurns: maxTurns,
        output: output,
        context: context,
        onChunk: (chunk) {
          if (streamController.isClosed) return;
          streamController.add(chunk);
        },
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
