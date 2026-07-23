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
/// Talks to the Genkit A2UI agent (served by `bin/server.dart`) with
/// `remoteAgent` from `package:genkit/client.dart`, renders prose in a simple
/// chat log, and renders each A2UI surface with the `genui` renderer.
///
/// A2UI travels as `data` parts on the agent stream; we pull them off each chunk
/// with `a2uiEnvelopes` (from `package:genkit_a2ui/client.dart`), convert each
/// envelope to a genui `A2uiMessage`, and feed it to a `SurfaceController`.
/// Surface actions (e.g. button presses) are sent back to the agent as the next
/// turn.
library;

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:genkit/client.dart';
import 'package:genkit_a2ui/client.dart';
// `basicCatalogId` is defined by both genkit_a2ui and genui (with different
// values); we want the plugin's id, so hide genui's.
import 'package:genui/genui.dart' hide basicCatalogId;

/// The base URL of the agent server. Override with `--dart-define=AGENT_BASE_URL`.
const String _baseUrl = String.fromEnvironment(
  'AGENT_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// The genui basic catalog, re-tagged with the catalog id the `genkit_a2ui`
/// plugin's bundled basic catalog advertises, so surfaces created by the agent
/// resolve to real widgets (genui otherwise registers an empty stub for an
/// unknown catalog id).
final Catalog _catalog = BasicCatalogItems.asCatalog().copyWith(
  catalogId: basicCatalogId,
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
  late final SurfaceController _surfaceController;

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
    _surfaceController = SurfaceController(catalogs: [_catalog]);

    // A new surface becomes a new entry in the chat log.
    _surfaceController.surfaceUpdates.listen((update) {
      if (update is SurfaceAdded) {
        final exists = _entries.whereType<_SurfaceEntry>().any(
          (e) => e.surfaceId == update.surfaceId,
        );
        if (!exists) {
          setState(() => _entries.add(_SurfaceEntry(update.surfaceId)));
          _scrollToBottom();
        }
      }
    });

    // A surface action (e.g. button press) becomes the next agent turn.
    _surfaceController.onSubmit.listen(_onSurfaceSubmit);
  }

  @override
  void dispose() {
    _surfaceController.dispose();
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

  /// Sends a rendered surface's action back to the agent as the next turn.
  Future<void> _onSurfaceSubmit(dynamic message) async {
    final action = _actionFromSubmit(message);
    if (action == null) return;
    setState(() {
      _entries.add(_TextEntry(true, '▶ ${action.name}'));
      _busy = true;
    });
    _scrollToBottom();
    await _runTurn(_chat.sendStream(message: actionToMessage(action)));
  }

  /// Runs a single agent turn, streaming prose + surfaces into the log.
  Future<void> _runTurn(AgentTurn turn) async {
    _TextEntry? prose;
    try {
      await for (final chunk in turn.stream) {
        if (chunk.text.isNotEmpty) {
          if (prose == null) {
            prose = _TextEntry(false, '');
            setState(() => _entries.add(prose!));
          }
          setState(() => prose!.text += chunk.text);
          _scrollToBottom();
        }
        for (final envelope in a2uiEnvelopes(chunk.raw.modelChunk)) {
          _handleEnvelope(envelope);
        }
      }
      await turn.response;
    } catch (err) {
      setState(() => _entries.add(_TextEntry(false, 'Error: $err')));
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Converts one A2UI envelope map into a genui message and applies it.
  void _handleEnvelope(Map<String, dynamic> envelope) {
    try {
      _sanitizeEnvelope(envelope);
      _surfaceController.handleMessage(core.A2uiMessage.fromJson(envelope));
    } catch (err) {
      debugPrint('Failed to apply A2UI envelope: $err');
    }
  }

  /// Works around a genui layout limitation: a `Row` with `align: "stretch"`
  /// maps to `CrossAxisAlignment.stretch`, which demands a bounded height. But
  /// surfaces render inside a scrolling `ListView` (unbounded height), and
  /// genui lays out `Column` children with unbounded vertical constraints, so a
  /// stretch `Row` nested in a `Column` throws "BoxConstraints forces an
  /// infinite height" (e.g. the equal-height cards in a 3-city comparison).
  ///
  /// Drop `align: "stretch"` from `Row` components so they size to their content
  /// instead of crashing. (`Column` stretch is horizontal, bounded by the
  /// ListView width, so it is left untouched.)
  void _sanitizeEnvelope(Map<String, dynamic> envelope) {
    final update = envelope['updateComponents'];
    if (update is! Map) return;
    final components = update['components'];
    if (components is! List) return;
    for (final c in components) {
      if (c is Map && c['component'] == 'Row' && c['align'] == 'stretch') {
        c.remove('align');
      }
    }
  }

  /// Extracts an [A2uiClientAction] from a genui `onSubmit` ChatMessage.
  ///
  /// genui reports surface interactions as a `UiInteractionPart` whose payload
  /// is a JSON string `{ "version": "v0.9", "action": { name, surfaceId,
  /// widgetId, context } }`.
  A2uiClientAction? _actionFromSubmit(dynamic message) {
    for (final part in (message as ChatMessage).parts) {
      final interaction = part.asUiInteractionPart?.interaction;
      if (interaction == null) continue;
      final decoded = jsonDecode(interaction);
      final action = (decoded is Map) ? decoded['action'] : null;
      if (action is Map) {
        final map = action.cast<String, dynamic>();
        return A2uiClientAction(
          name: (map['name'] as String?) ?? 'action',
          surfaceId: (map['surfaceId'] as String?) ?? '',
          sourceComponentId: (map['widgetId'] as String?) ?? '',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          context:
              (map['context'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
      }
    }
    return null;
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
            child: Text(text),
          ),
        );
      case _SurfaceEntry(:final surfaceId):
        // `IntrinsicHeight` gives the surface subtree a bounded (natural) height.
        // Surfaces are rendered inside a scrolling `ListView`, so their height is
        // otherwise unbounded; a genui `Row` with `align: "stretch"` (e.g. the
        // equal-height cards in a comparison) needs a bounded cross-axis extent
        // to stretch into, and would otherwise throw "forces an infinite height".
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: IntrinsicHeight(
            child: Surface(
              surfaceContext: _surfaceController.contextFor(surfaceId),
            ),
          ),
        );
    }
  }
}

class _SuggestionBar extends StatelessWidget {
  const _SuggestionBar({required this.onTap});
  final void Function(String prompt)? onTap;

  static const _prompts = [
    "What's the weather in Tokyo?",
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
