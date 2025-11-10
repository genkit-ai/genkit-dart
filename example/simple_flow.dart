import 'package:genkit/genkit.dart';
import 'package:genkit/schema.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/core/action.dart';

void main() async {
  configureCollectorExporter();

  final ai = Genkit();

  ai.defineModel(
    name: 'echo',
    fn: (req, ctx) async {
      return ModelResponse.from(
        finishReason: FinishReason.stop,
        message: Message.from(
          role: Role.model,
          content: [
            TextPart.from(text: 'echo: ' + req.messages[0].content[0].text),
          ],
        ),
      );
    },
  );

  final child = ai.defineFlow(
    name: 'child',
    fn: (String name, context) async {
      return 'Hello, $name!';
    },
  );

  final generateAction = Action(
    actionType: 'util',
    name: 'generate',
    inputType: GenerateActionOptionsType,
    outputType: ModelResponseType,
    streamType: ModelResponseChunkType,
    fn: (options, context) async {
      final model = await ai.registry.get('model', options.model) as Model;
    
      return model(ModelRequest.from(messages: options.messages));
    },
  );

  ai.registry.register(generateAction);

  ai.defineFlow(
    name: 'parent',
    inputType: StringType,
    outputType: StringType,
    streamType: StringType,
    fn: (String name, context) async {
      if (context.streamingRequested) {
        for (var i = 0; i < 5; i++) {
          context.sendChunk('Thinking... $i');
          await Future.delayed(Duration(seconds: 1)); // Delays for 2 seconds
        }
      }
      return await child(name);
    },
  );
}
