import 'package:genkit/genkit.dart';
import 'package:genkit/schema.dart';

void main() async {
  configureCollectorExporter();

  final ai = Genkit();

  final child = ai.defineFlow(
    name: 'child',
    fn: (String name, context) async {
      return 'Hello, $name!';
    },
  );

  ai.defineFlow(
    name: 'parent',
    inputType: StringType,
    outputType: StringType,
    streamType: StringType,
    fn: (String name, context) async {
      if (context.streamingRequested) {
        for (var i = 0; i < 5; i++) {
          context.sendChunk('Thinking... $i');
        }
      }
      return await child(name);
    },
  );
}
