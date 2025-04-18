import 'package:genkit/client.dart';

void main() async {
  var joke =
      await runFlow(url: 'http://localhost:5000/jokeHandler', input: "banana")
          as String;
  print('Joke: $joke');

  final (:stream, :response) = streamFlow<String, String>(
    url: 'http://localhost:5000/jokeHandler',
    input: "banana",
  );

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: $chunk');
  }
  print('\nStream finished.');
  // Wait for the final result after the stream is finished
  final finalResult = await response;
  print('Final Response: $finalResult');
}
