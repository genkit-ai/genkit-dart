import 'package:genkit/genkit.dart';
import 'package:genkit/src/o11y/otlp_http_exporter.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;

final ai = Genkit();

// Define a simple flow
final simpleFlow = ai.defineFlow(
  name: 'simpleFlow',
  fn: (String name, context) async {
    return await simpleFlow2.run(name);
  },
);
final simpleFlow2 = ai.defineFlow(
  name: 'simpleFlow2',
  fn: (String name, context) async {
    return 'Hello, $name!';
  },
);

void main() async {
  // Configure the OTLP HTTP Exporter
  final exporter = CollectorHttpExporter('http://localhost:4034/api/otlp');
  final processor = sdk.SimpleSpanProcessor(exporter);
  final provider = sdk.TracerProviderBase(
    processors: [processor],
  );
  api.registerGlobalTracerProvider(provider);

  // Initialize Genkit (this would typically be done once in your application)
  // For this example, we are not using a registry, but in a real app you would.
  print('Genkit initialized with OTLP HTTP Exporter.');

  // Run the flow
  print('Running simpleFlow...');
  final result = await simpleFlow.run('World');
  print('Flow result: $result');

  // Allow time for the exporter to send the data
  await Future.delayed(const Duration(seconds: 2));

  print('Example finished.');
  // In a real application, you would call provider.shutdown() on exit.
  provider.shutdown();
}
