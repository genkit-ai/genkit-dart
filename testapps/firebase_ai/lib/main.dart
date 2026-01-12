import 'package:firebase_ai_testapp/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

part 'main.schema.g.dart';

@GenkitSchema()
abstract class WeatherToolInputSchema {
  String get location;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: ChatScreen());
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <String>[];
  late final Genkit _ai;

  @override
  void initState() {
    super.initState();
    _ai = Genkit(plugins: [firebaseAI()]);

    _ai.defineTool(
      name: 'getWeather',
      description: 'Get the weather for a location',
      inputType: WeatherToolInputType,
      fn: (input, context) async {
        if (input.location.toLowerCase().contains('boston')) {
          return 'The weather in Boston is 72 and sunny.';
        }
        return 'The weather in ${input.location} is 75 and cloudy.';
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    setState(() {
      _messages.add('User: $text');
      _controller.clear();
    });

    try {
      final response = await _ai.generate(
        model: firebaseAI.gemini('gemini-2.5-flash'),
        prompt: text,
        tools: ['getWeather'],
      );
      setState(() {
        _messages.add('AI: ${response.text}');
      });
    } catch (e) {
      setState(() {
        _messages.add('Error: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Genkit Firebase AI')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => ListTile(title: Text(_messages[i])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller)),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
