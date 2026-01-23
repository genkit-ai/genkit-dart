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
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_ai_testapp/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:logging/logging.dart';
import 'package:schemantic/schemantic.dart';

part 'main.g.dart';

@Schematic()
abstract class WeatherToolInputSchema {
  String get location;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep logging minimal
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
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
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
              },
              child: const Text('Text Chat (Standard)'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LiveChatScreen()),
                );
              },
              icon: const Icon(Icons.mic),
              label: const Text('Live Conversation (Bidi)'),
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
            padding: const EdgeInsets.all(16.0),
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
  final _audioQueue = AudioPlayerQueue();
  bool _isRecording = false;
  StreamSubscription? _audioSubscription;
  String _statusMessage = 'Initializing...';
  final _messages = <String>[];
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

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
    _initSession();
  }

  Future<void> _initSession() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() => _statusMessage = 'Microphone permission denied');
      return;
    }

    try {
      await _session?.close();
      _session = null;
      setState(() {
        _statusMessage = 'Connecting to Gemini Live...';
        _messages.clear();
      });

      final newSession = await _ai.generateBidi(
        model: 'firebaseai/gemini-2.5-flash-native-audio-preview-12-2025',
        config: LiveGenerationConfig.from(
          responseModalities: ['AUDIO'],
          speechConfig: SpeechConfig.from(
            voiceConfig: VoiceConfig.from(
              prebuiltVoiceConfig: PrebuiltVoiceConfig.from(
                voiceName: 'Algenib',
              ),
            ),
          ),
        ),
        system: 'Talk like pirate',
        tools: ['getWeather'],
      );
      newSession.send('Hello');

      _session = newSession;
      setState(() {
        _statusMessage = 'Connected!';
      });

      newSession.stream.listen(
        (chunk) async {
          if (_session != newSession) return;
          for (final part in chunk.content) {
            if (part.isText) {
              _addMessage('AI: ${(part as TextPart).text}');
            }
            if (part.isMedia) {
              final mediaPart = part as MediaPart;
              if (mediaPart.media.url.startsWith('data:')) {
                final data = Uri.parse(mediaPart.media.url).data;
                if (data != null) {
                  _audioQueue.enqueue(data.contentAsBytes());
                }
              }
            }
          }
        },
        onError: (e) {
          if (_session != newSession) return;
          setState(() => _statusMessage = 'Error: $e');
        },
        onDone: () {
          if (_session != newSession) return;
          setState(() {
            _statusMessage = 'Session closed.';
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Failed to connect: $e');
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_session == null) return;

    if (_isRecording) {
      await _recorder.stop();
      await _audioSubscription?.cancel();
      setState(() => _isRecording = false);
    } else {
      if (!await _recorder.hasPermission()) return;

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSubscription = stream.listen((data) {
        final base64Audio = base64Encode(data);
        _session!.send(
          ModelRequest.from(
            messages: [
              Message.from(
                role: Role.user,
                content: [
                  MediaPart.from(
                    media: Media.from(
                      url: 'data:audio/pcm;rate=16000;base64,$base64Audio',
                      contentType: 'audio/pcm;rate=16000',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      });

      setState(() => _isRecording = true);
      _addMessage('User: <Audio Input>');
    }
  }

  void _sendText() {
    final text = _textController.text;
    if (text.isEmpty || _session == null) return;

    _session!.send(text);
    _addMessage('User: $text');
    _textController.clear();
  }

  void _addMessage(String msg) {
    setState(() {
      _messages.add(msg);
    });
    // Auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioQueue.dispose();
    _session?.close();
    _audioSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Live')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _messages[i],
                  style: i.isEven
                      ? null
                      : const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          // Input Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 12),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textController,
                  builder: (context, value, child) {
                    final isTyping = value.text.isNotEmpty;
                    return GestureDetector(
                      onLongPressStart: isTyping
                          ? null
                          : (_) => _toggleRecording(),
                      onLongPressEnd: isTyping
                          ? null
                          : (_) => _toggleRecording(),
                      onTap: isTyping ? _sendText : _toggleRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isTyping
                              ? Theme.of(context).colorScheme.secondary
                              : (_isRecording
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isTyping
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.secondary
                                          : (_isRecording
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.error
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.primary))
                                      .withOpacity(0.4),
                              blurRadius: _isRecording ? 10 : 4,
                              spreadRadius: _isRecording ? 2 : 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          isTyping
                              ? Icons.send
                              : (_isRecording ? Icons.mic : Icons.mic_none),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Listening...',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}

class AudioPlayerQueue {
  final List<Uint8List> _queue = [];
  final List<int> _buffer = [];
  static const int _minBufferSize = 24000; // ~0.5 seconds at 24kHz
  Timer? _flushTimer;
  bool _isPlaying = false;
  final AudioPlayer _player = AudioPlayer();

  AudioPlayerQueue();

  void enqueue(Uint8List pcmData) {
    _buffer.addAll(pcmData);

    _flushTimer?.cancel();
    // Flush if buffer is large enough
    if (_buffer.length >= _minBufferSize) {
      _flush();
    } else {
      // Or flush if no new data arrives shortly (end of speech)
      _flushTimer = Timer(const Duration(milliseconds: 200), _flush);
    }
  }

  void _flush() {
    if (_buffer.isEmpty) return;
    final wavData = _createWav(Uint8List.fromList(_buffer));
    _buffer.clear();
    _queue.add(wavData);
    _playNext();
  }

  Future<void> _playNext() async {
    if (_isPlaying || _queue.isEmpty) return;
    _isPlaying = true;
    final data = _queue.removeAt(0);

    try {
      await _player.play(BytesSource(data));

      final completer = Completer();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      // Calculate duration plus a small buffer
      final durationSec = (data.length - 44) / 48000;
      final timeout = Duration(
        milliseconds: (durationSec * 1000).ceil() + 1000,
      );

      await completer.future.timeout(timeout, onTimeout: () {});
      await sub.cancel();
    } catch (e) {
      print('AudioQueue Error: $e');
    } finally {
      _isPlaying = false;
      _playNext();
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _player.dispose();
  }

  Uint8List _createWav(Uint8List pcmData) {
    const sampleRate = 24000;
    const numChannels = 1;
    const bitsPerSample = 16;

    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final head = Uint8List(44);
    final view = ByteData.view(head.buffer);

    _writeString(view, 0, 'RIFF');
    view.setUint32(4, fileSize, Endian.little);
    _writeString(view, 8, 'WAVE');

    _writeString(view, 12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);

    _writeString(view, 36, 'data');
    view.setUint32(40, dataSize, Endian.little);

    final wavFile = Uint8List(44 + dataSize);
    wavFile.setRange(0, 44, head);
    wavFile.setRange(44, 44 + dataSize, pcmData);
    return wavFile;
  }

  void _writeString(ByteData view, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      view.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
