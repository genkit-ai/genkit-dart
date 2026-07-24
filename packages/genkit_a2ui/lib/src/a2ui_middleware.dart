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

/// The `a2ui()` generate middleware - the whole server-side integration.
///
/// Register [A2uiPlugin] in `Genkit(plugins: [...])`, then add [a2ui] to an
/// agent's (or a one-shot `generate`'s) `use` list and the agent gains the
/// ability to render A2UI surfaces. The middleware:
///
/// 1. Injects the catalog's capabilities into the system prompt so the model
///    knows what UI it may render.
/// 2. Intercepts the model's output (both the streamed chunks and the final
///    message), extracts any `a2ui` fenced blocks, validates them against the
///    catalog, and rewrites them into the canonical a2ui data part.
///
/// Implemented via the `model` hook, so it wraps each raw model call in the
/// agent's tool loop.
library;

import 'dart:convert';
import 'dart:math';

import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

import 'catalog.dart';
import 'loader.dart';
import 'parser.dart';
import 'part.dart';
import 'types.dart';

part 'a2ui_middleware.g.dart';

/// Configuration for the [a2ui] middleware.
@Schema()
abstract class $A2uiOptions {
  /// The id of the catalog describing what the agent may render. Defaults to
  /// `'basic'` (the bundled basic catalog). Register additional catalogs with
  /// `loadCatalog(registry, id: ..., catalog: ...)` and reference them by id.
  String? get catalog;

  /// Where to inject the catalog's capabilities. `'system'` (default) appends
  /// A2UI instructions to the system prompt; `'none'` injects nothing (useful
  /// if you supply your own instructions).
  String? get instructions;

  /// Validate emitted envelopes against the catalog. `'warn'` (default) logs a
  /// warning and drops the offending block/envelope, keeping the rest of the
  /// turn alive; `'strict'` throws on malformed JSON or unknown components
  /// (best during development); `'off'` passes them through unchecked.
  String? get validate;

  /// Surface id policy. Provide a fixed id to reuse for every surface. Defaults
  /// to a fresh UUID per surface.
  String? get surfaceId;

  /// Protocol version stamped on emitted envelopes. Defaults to `'v0.9'`.
  String? get version;
}

/// The Genkit plugin that registers the [a2ui] middleware. Add it to
/// `Genkit(plugins: [A2uiPlugin()])`.
class A2uiPlugin extends GenkitPlugin {
  @override
  String get name => 'a2ui';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<A2uiOptions>(
      name: 'a2ui',
      configSchema: A2uiOptions.$schema,
      create: (config, ctx) => A2uiMiddleware(ctx.ai.registry, config),
    ),
  ];
}

/// Creates a reference to the A2UI middleware for use in a `use: [...]` list.
///
/// Requires [A2uiPlugin] to be registered in `Genkit(plugins: [...])`.
GenerateMiddlewareRef<A2uiOptions> a2ui({
  String? catalog,
  String? instructions,
  String? validate,
  String? surfaceId,
  String? version,
}) {
  return middlewareRef(
    name: 'a2ui',
    config: A2uiOptions(
      catalog: catalog,
      instructions: instructions,
      validate: validate,
      surfaceId: surfaceId,
      version: version,
    ),
  );
}

/// Resolves the `validate` option into a mode. Defaults to
/// [A2uiValidateMode.warn] when unset (a malformed block is dropped rather than
/// killing the whole turn); use `'strict'` during development to surface errors.
A2uiValidateMode _parseValidateMode(String? value) {
  switch (value) {
    case 'strict':
      return A2uiValidateMode.strict;
    case 'off':
      return A2uiValidateMode.off;
    case 'warn':
    case null:
      return A2uiValidateMode.warn;
    default:
      throw ArgumentError('a2ui(): invalid validate mode "$value".');
  }
}

/// Resolves the `instructions` option, defaulting to `'system'`. Throws on any
/// value other than `'system'` or `'none'`.
String _parseInstructions(String? value) {
  switch (value) {
    case 'system':
    case null:
      return 'system';
    case 'none':
      return 'none';
    default:
      throw ArgumentError('a2ui(): invalid instructions mode "$value".');
  }
}

final _rng = Random();

/// Generates a random v4 UUID string.
String _uuidV4() {
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The A2UI model middleware.
///
/// Injects catalog capabilities into the prompt and rewrites emitted `a2ui`
/// blocks (streamed and final) into a2ui data parts.
class A2uiMiddleware extends GenerateMiddleware {
  final Registry _registry;
  final String _catalogId;
  final String _instructions;
  final A2uiValidateMode _validate;
  final String _version;
  final String? _fixedSurfaceId;

  /// Creates an [A2uiMiddleware].
  A2uiMiddleware(this._registry, [A2uiOptions? config])
    : _catalogId = config?.catalog ?? defaultCatalogId,
      _instructions = _parseInstructions(config?.instructions),
      _validate = _parseValidateMode(config?.validate),
      _version = config?.version ?? a2uiVersion,
      _fixedSurfaceId = config?.surfaceId;

  String _nextSurfaceId() => _fixedSurfaceId ?? _uuidV4();

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) async {
    // Resolve the catalog by id from the registry (falls back to the bundled
    // basic catalog for the default id).
    final catalog = resolveCatalog(_registry, _catalogId);

    // Share surface ids between the streamed parse and the final-message parse
    // of this single turn, so the same surface gets the same id in both.
    final surfaceIds = _ReplayableSurfaceIds(_nextSurfaceId);

    // 0) Sanitize any inbound a2ui data parts (e.g. a surface action sent back
    //    as the next turn, or replayed history) into model-readable text, so
    //    the underlying model's converter never sees the a2ui mime type.
    final sanitized = _sanitizeInboundA2ui(request);

    // 1) Inject catalog instructions into the system prompt.
    final newRequest = _instructions == 'none'
        ? sanitized
        : _injectInstructions(sanitized, catalog);

    // 2) Wrap the streaming callback so streamed text is split into prose
    //    deltas + whole a2ui parts as blocks complete.
    var wrappedCtx = ctx;
    if (ctx.streamingRequested) {
      final streamParser = A2uiStreamParser(
        catalog: catalog,
        validate: _validate,
        version: _version,
        surfaceId: surfaceIds.next,
      );
      wrappedCtx = (
        streamingRequested: ctx.streamingRequested,
        sendChunk: (chunk) {
          final transformed = _transformChunk(chunk, streamParser);
          if (transformed != null) ctx.sendChunk(transformed);
        },
        context: ctx.context,
        inputStream: ctx.inputStream,
        init: null,
      );
    }

    // 3) Run downstream model, then transform the final message. The final
    //    parse replays the same surface ids the stream minted.
    final response = await next(newRequest, wrappedCtx);
    surfaceIds.reset();
    return _transformResponse(response, catalog, surfaceIds.replayNext);
  }

  /// Appends A2UI instructions to (or creates) the system message.
  ModelRequest _injectInstructions(ModelRequest req, A2uiCatalog catalog) {
    final text = renderCatalogInstructions(catalog);
    final messages = List<Message>.from(req.messages);
    final sysIdx = messages.indexWhere((m) => m.role == Role.system);
    if (sysIdx >= 0) {
      final sys = messages[sysIdx];
      messages[sysIdx] = Message(
        role: sys.role,
        content: [
          ...sys.content,
          TextPart(text: '\n\n$text'),
        ],
        metadata: sys.metadata,
      );
    } else {
      messages.insert(
        0,
        Message(
          role: Role.system,
          content: [TextPart(text: text)],
        ),
      );
    }
    return ModelRequest(
      messages: messages,
      config: req.config,
      tools: req.tools,
      toolChoice: req.toolChoice,
      output: req.output,
      docs: req.docs,
    );
  }

  /// Transforms a single streamed chunk; returns null if nothing to emit.
  ModelResponseChunk? _transformChunk(
    ModelResponseChunk chunk,
    A2uiStreamParser parser,
  ) {
    if (chunk.content.isEmpty) return chunk;
    final newContent = <Part>[];
    for (final part in chunk.content) {
      final text = part.text;
      if (part.isText && text != null && text != '') {
        final result = parser.push(text);
        newContent.addAll(_partsFromSegments(result.segments));
      } else {
        newContent.add(part);
      }
    }
    if (newContent.isEmpty) return null;
    return ModelResponseChunk(
      role: chunk.role,
      index: chunk.index,
      content: newContent,
      custom: chunk.custom,
      aggregated: chunk.aggregated,
    );
  }

  /// Transforms the final response message: prose text + a2ui parts.
  ModelResponse _transformResponse(
    ModelResponse response,
    A2uiCatalog catalog,
    String Function() surfaceId,
  ) {
    final message = response.message;
    if (message == null) return response;

    final parser = A2uiStreamParser(
      catalog: catalog,
      validate: _validate,
      version: _version,
      surfaceId: surfaceId,
    );
    final newContent = <Part>[];
    // Push every text part through the parser first so a block spanning
    // multiple text parts stays intact, then flush once at the end to drain
    // any trailing block. Ordering (prose before/after a block) is preserved.
    for (final part in message.content) {
      if (part.isText) {
        final pushed = parser.push(part.text ?? '');
        newContent.addAll(_partsFromSegments(pushed.segments));
      } else {
        newContent.add(part);
      }
    }
    final flushed = parser.flush();
    newContent.addAll(_partsFromSegments(flushed.segments));

    return ModelResponse(
      message: Message(
        role: message.role,
        content: newContent,
        metadata: message.metadata,
      ),
      finishReason: response.finishReason,
      finishMessage: response.finishMessage,
      latencyMs: response.latencyMs,
      usage: response.usage,
      custom: response.custom,
      raw: response.raw,
      request: response.request,
      operation: response.operation,
    );
  }

  /// Converts inbound a2ui data parts in the request into model-readable text.
  ModelRequest _sanitizeInboundA2ui(ModelRequest req) {
    var changed = false;
    final messages = req.messages.map((message) {
      var msgChanged = false;
      final content = <Part>[];
      for (final part in message.content) {
        if (isA2uiPart(part)) {
          msgChanged = true;
          final text = _summarizeA2uiPart(a2uiEnvelopes(part));
          if (text.isNotEmpty) content.add(TextPart(text: text));
        } else {
          content.add(part);
        }
      }
      if (!msgChanged) return message;
      changed = true;
      return Message(
        role: message.role,
        content: content,
        metadata: message.metadata,
      );
    }).toList();
    if (!changed) return req;
    return ModelRequest(
      messages: messages,
      config: req.config,
      tools: req.tools,
      toolChoice: req.toolChoice,
      output: req.output,
      docs: req.docs,
    );
  }
}

/// Turns ordered parse segments into parts, preserving the exact source order
/// (so prose after a block stays after it).
List<Part> _partsFromSegments(List<ParseSegment> segments) {
  final out = <Part>[];
  for (final seg in segments) {
    switch (seg) {
      case ProseSegment(:final prose):
        if (prose.isNotEmpty) out.add(TextPart(text: prose));
      case EnvelopeSegment(:final envelopes):
        out.add(a2uiPart(envelopes));
    }
  }
  return out;
}

/// Summarizes a list of a2ui envelopes / actions into a short text string.
String _summarizeA2uiPart(List<A2uiEnvelope> envelopes) {
  final lines = <String>[];
  for (final env in envelopes) {
    final action = env['action'];
    if (action is Map) {
      final name = action['name'];
      final surfaceId = action['surfaceId'];
      final context = action['context'];
      final ctx = (context is Map && context.isNotEmpty)
          ? ' context=${jsonEncode(context)}'
          : '';
      lines.add('[UI action "$name" on surface $surfaceId$ctx]');
    } else if (env['createSurface'] is Map) {
      final surfaceId = (env['createSurface'] as Map)['surfaceId'];
      lines.add('[UI surface $surfaceId created]');
    } else if (env['updateComponents'] != null ||
        env['updateDataModel'] != null ||
        env['deleteSurface'] != null) {
      // Prior assistant surface content - summarize as a rendered surface.
      lines.add('[rendered UI surface]');
    }
  }
  // Collapse repeated "[rendered UI surface]" lines from one assistant turn.
  return {...lines}.join(' ');
}

/// Wraps a surface-id factory so a single model turn's streamed parse and its
/// final-message parse mint the *same* surface ids.
class _ReplayableSurfaceIds {
  final String Function() _base;
  final List<String> _generated = [];
  int _cursor = 0;

  _ReplayableSurfaceIds(this._base);

  String next() {
    final id = _base();
    _generated.add(id);
    return id;
  }

  String replayNext() =>
      _cursor < _generated.length ? _generated[_cursor++] : next();

  void reset() {
    _cursor = 0;
  }
}
