// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_ai_testapp/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

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
    return MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Genkit Firebase AI')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              child: const Text('Text Chat'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LiveChatScreen()),
                );
              },
              child: const Text('Live Conversation'),
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(title: const Text('Text Chat')),
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

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  late final Genkit _ai;
  GenerateBidiSession? _session;
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _isConnected = false;
  final _logs = <String>[];
  StreamSubscription? _audioSubscription;
  final _textController = TextEditingController();
  InputMode _inputMode = InputMode.text;

  @override
  void initState() {
    super.initState();
    _ai = Genkit(plugins: [firebaseAI()]);
    _initSession();
  }

  Future<void> _initSession() async {
    // Request permissions
    if (_inputMode == InputMode.audio) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _log('Microphone permission denied');
        return;
      }
    }

    try {
      await _session?.close();
      _session = null;
      setState(() {
        _isConnected = false;
      });

      _log('Connecting to Live Model (${_inputMode.name})...');
      final newSession = await _ai.generateBidi(
        model: 'firebaseai/gemini-2.5-flash-native-audio-preview-12-2025',
        config: {
          'responseModalities': [
            _inputMode == InputMode.audio ? 'AUDIO' : 'TEXT'
          ],
        },
      );
      _session = newSession;
      _log('Connected!');
      setState(() {
        _isConnected = true;
      });

      // Listen to responses
      newSession.stream.listen((chunk) async {
        if (_session != newSession) return;
        _log('Received chunk: ${chunk.content.length} parts');
        for (final part in chunk.content) {
          if (part.isText) {
            _log('AI: ${(part as TextPart).text}');
          }
          if (part.isMedia) {
            _log('AI: <Audio Data>');
          }
        }
      }, onError: (e) {
        if (_session != newSession) return;
        _log('Error from session: $e');
      }, onDone: () {
        if (_session != newSession) return;
        _log('Session closed');
        setState(() {
          _isConnected = false;
        });
      });
    } catch (e) {
      _log('Failed to connect: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_session == null) return;

    if (_isRecording) {
      await _recorder.stop(); // Stop local recording
      // Ideally we stream data.
      // `_recorder.startStream` gives us a stream of Uint8List.
      await _audioSubscription?.cancel();
      setState(() {
        _isRecording = false;
      });
      _log('Stopped recording');
    } else {
      // Start streaming
      if (!await _recorder.hasPermission()) return;

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSubscription = stream.listen((data) {
        // Send data to session as MediaPart with data URI
        final base64Audio = base64Encode(data);
        _session!.send(ModelRequest.from(
          messages: [
            Message.from(
              role: Role.user,
              content: [
                MediaPart.from(
                    media: Media.from(
                  url: 'data:audio/pcm;rate=16000;base64,$base64Audio',
                  contentType: 'audio/pcm;rate=16000',
                )),
              ],
            ),
          ],
        ));
      });

      setState(() {
        _isRecording = true;
      });
      _log('Started recording');
    }
  }

  void _sendText() {
    final text = _textController.text;
    if (text.isEmpty || _session == null) return;

    _session!.send(ModelRequest.from(
      messages: [
        Message.from(
          role: Role.user,
          content: [TextPart.from(text: text)],
        ),
      ],
    ));
    _log('Sent: $text');
    _textController.clear();
  }

  void _log(String msg) {
    setState(() {
      _logs.add(msg);
    });
    print(msg);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _session?.close();
    _audioSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Conversation')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (ctx, i) => Text(_logs[i]),
            ),
          ),
          const Divider(),
          // Mode Toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SegmentedButton<InputMode>(
              segments: const [
                ButtonSegment(
                  value: InputMode.audio,
                  label: Text('Audio'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: InputMode.text,
                  label: Text('Text'),
                  icon: Icon(Icons.keyboard),
                ),
              ],
              selected: {_inputMode},
              onSelectionChanged: (Set<InputMode> newSelection) {
                final newMode = newSelection.first;
                if (_inputMode != newMode) {
                  setState(() {
                    _inputMode = newMode;
                  });
                  _initSession();
                }
              },
            ),
          ),
          // Input Area
          if (_inputMode == InputMode.audio)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: GestureDetector(
                onLongPressStart: (_) => _toggleRecording(),
                onLongPressEnd: (_) => _toggleRecording(),
                onTap: () {
                  // Tap to toggle if long press is annoying in simulator
                  _toggleRecording();
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  child: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          if (_inputMode == InputMode.audio) ...[
            const SizedBox(height: 20),
            Text(_isConnected ? 'Tap/Hold to Speak' : 'Connecting...'),
          ],
        ],
      ),
    );
  }
}

// Helper for DataPart construction if needed
extension DataPartExtension on DataPart {
  // If DataPart doesn't have explicit bytes field, we might need a custom subclass or use 'custom' field?
  // `DataPart` is generated.
  // If I can't modify `DataPart`, I should use `CustomPart` or `MediaPart` with data URI.
  // Using MediaPart with data URI for audio is standard.
}

enum InputMode { audio, text }
