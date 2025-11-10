import 'package:genkit/genkit.dart';

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
    fn: (String name, context) async {
      return await child(name);
    },
  );
}
