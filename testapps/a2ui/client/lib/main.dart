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

/// A2UI sample Flutter client.
///
/// Talks to the Genkit A2UI agent (served by `../server`) with `remoteAgent`,
/// renders prose in a simple chat log, and renders each A2UI surface with the
/// `a2ui_flutter` renderer.
///
/// A2UI travels as spec-shaped `data` parts on the agent stream. This app does
/// not depend on `genkit_a2ui`: the two helpers in `a2ui_helpers.dart` (copied
/// from the genkit_a2ui README) read messages off each chunk and turn surface
/// actions into the next turn's input.
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:genkit/experimental_client.dart';

import 'a2ui_helpers.dart';
import 'catalog.dart';

/// The base URL of the agent server. Override with `--dart-define=AGENT_BASE_URL`.
const String _baseUrl = String.fromEnvironment(
  'AGENT_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

void main() {
  runApp(const A2uiApp());
}

class A2uiApp extends StatelessWidget {
  const A2uiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Genkit + A2UI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

/// One entry in the chat log: either prose text or a rendered surface.
sealed class _Entry {
  const _Entry();
}

class _TextEntry extends _Entry {
  _TextEntry(this.isUser, this.text);
  final bool isUser;
  String text;
}

class _SurfaceEntry extends _Entry {
  _SurfaceEntry(this.surfaceId);
  final String surfaceId;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final AgentApi _agent;
  late final AgentChat _chat;
  late final MessageProcessor<ComponentImplementation> _processor;

  final _entries = <_Entry>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _agent = remoteAgent(
      url: '$_baseUrl/api/uiAgent',
      getSnapshotUrl: '$_baseUrl/api/uiAgent/getSnapshot',
      abortUrl: '$_baseUrl/api/uiAgent/abort',
    );
    _chat = _agent.chat();
    _processor = MessageProcessor(
      catalogs: [weatherCatalog],
      // Deliver actions to `outboundListener` as typed, versioned messages.
      unifiedOutbound: true,
      outboundListener: _onRendererMessage,
      // Runtime errors (a failed function call, an unknown component type)
      // reach `onError`, not `outboundListener`.
      onError: (error) => debugPrint('A2UI renderer error: ${error.message}'),
    );

    // A new surface becomes a new entry in the chat log. A surface rendered
    // again under the same id (the agent deletes, then creates it) keeps its
    // entry, so it re-renders where it first appeared.
    _processor.model.onSurfaceCreated.subscribe((surface) {
      if (!mounted) return;
      final exists = _entries.whereType<_SurfaceEntry>().any(
        (e) => e.surfaceId == surface.id,
      );
      setState(() {
        if (!exists) _entries.add(_SurfaceEntry(surface.id));
      });
      if (!exists) _scrollToBottom();
    });
    _processor.model.onSurfaceDeleted.subscribe((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _processor.dispose();
    _agent.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _entries.add(_TextEntry(true, text));
      _busy = true;
    });
    _scrollToBottom();
    await _runTurn(_chat.sendStream(text: text));
  }

  /// Sends a rendered surface's action (e.g. a button press) back to the
  /// agent as the next turn.
  Future<void> _onRendererMessage(RendererToAgentMessage message) async {
    if (message is! ActionMessage) return;
    // Guard against re-entrancy: a button press mid-stream would otherwise
    // start a second concurrent turn, interleaving the streams and letting one
    // turn's completion flip `_busy` off while the other is still running.
    if (_busy) return;
    setState(() {
      _entries.add(_TextEntry(true, '> ${message.action.name}'));
      _busy = true;
    });
    _scrollToBottom();
    await _runTurn(_chat.sendStream(message: a2uiActionToMessage(message)));
  }

  /// Runs a single agent turn, streaming prose + surfaces into the log.
  Future<void> _runTurn(AgentTurn turn) async {
    _TextEntry? prose;
    try {
      await for (final chunk in turn.stream) {
        if (!mounted) return;
        if (chunk.text.isNotEmpty) {
          if (prose == null) {
            prose = _TextEntry(false, '');
            setState(() => _entries.add(prose!));
          }
          setState(() => prose!.text += chunk.text);
          _scrollToBottom();
        }
        for (final m in a2uiMessagesFrom(chunk.raw.modelChunk?.content)) {
          _handleMessage(m);
        }
      }
      await turn.response;
    } catch (err) {
      if (mounted) {
        setState(() => _entries.add(_TextEntry(false, 'Error: $err')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Applies one A2UI message. One message the renderer rejects (a newer
  /// protocol version, say) must not stop the rest of the turn.
  void _handleMessage(Map<String, dynamic> message) {
    try {
      _processor.processMessages([message]);
    } on Object catch (err) {
      debugPrint('Failed to apply A2UI message: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genkit + A2UI'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _SuggestionBar(onTap: _busy ? null : _send),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _entries.length,
              itemBuilder: (context, i) => _buildEntry(_entries[i]),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          _Composer(controller: _input, enabled: !_busy, onSend: _send),
        ],
      ),
    );
  }

  Widget _buildEntry(_Entry entry) {
    switch (entry) {
      case _TextEntry(:final isUser, :final text):
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text.trimRight()),
          ),
        );
      case _SurfaceEntry(:final surfaceId):
        final surface = _processor.model.getSurface(surfaceId);
        // Deleted: the entry keeps its place in the log in case the agent
        // renders the id again.
        if (surface == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          // A re-rendered surface is a new model, so key by it to start fresh.
          child: A2uiSurface(key: ObjectKey(surface), surface: surface),
        );
    }
  }
}

class _SuggestionBar extends StatelessWidget {
  const _SuggestionBar({required this.onTap});
  final void Function(String prompt)? onTap;

  static const _prompts = [
    "What's the weather in Tokyo?",
    'Show the weather in Tokyo with a gauge.',
    'Compare the weather in London, Paris and Rome.',
    'Give me a short signup form (name and email) with a submit button.',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final p in _prompts)
            ActionChip(
              label: Text(p, overflow: TextOverflow.ellipsis),
              onPressed: onTap == null ? null : () => onTap!(p),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String text) onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: const InputDecoration(
                  hintText: 'Ask for something visual…',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: enabled ? onSend : null,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: enabled ? () => onSend(controller.text) : null,
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
