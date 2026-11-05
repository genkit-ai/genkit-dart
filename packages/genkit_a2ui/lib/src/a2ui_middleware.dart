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
/// 1. Injects the catalog's capabilities and the A2UI Express contract into
///    the system prompt so the model knows what UI it may render.
/// 2. Intercepts the model's output (both the streamed chunks and the final
///    message), compiles each `<a2ui>` Express block against the catalog, and
///    rewrites it into the canonical a2ui data part.
/// 3. Turns inbound a2ui parts (replayed history, user actions) back into text
///    the model can read.
///
/// Implemented via the `model` hook, so it wraps each raw model call in the
/// agent's tool loop.
library;

import 'dart:convert';

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
  /// `loadCatalog(ai, id: ..., catalog: ...)` and reference them by id.
  String? get catalog;

  /// Where to inject the catalog's capabilities. `'system'` (default) appends
  /// A2UI instructions to the system prompt; `'none'` injects nothing (useful
  /// if you supply your own instructions).
  String? get instructions;

  /// What to do with a block that fails to compile or validate. `'warn'`
  /// (default) logs a warning and drops the block, keeping the rest of the turn
  /// alive; `'strict'` throws (best during development); `'off'` skips the
  /// renderer-side checks (dangling references, missing `root`) and drops a
  /// block that does not compile without logging a warning.
  String? get validate;

  /// The A2UI protocol version to emit. Only `'v0.9'` (the default) is
  /// supported.
  String? get version;
}

/// The Genkit plugin that registers the [a2ui] middleware. Add it to
/// `Genkit(plugins: [A2uiPlugin()])`.
class A2uiPlugin extends GenkitPlugin {
  @override
  String get name => 'a2ui';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    generateMiddleware<A2uiOptions>(
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
  String? version,
}) {
  return middlewareRef(
    name: 'a2ui',
    config: A2uiOptions(
      catalog: catalog,
      instructions: instructions,
      validate: validate,
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

/// Checks the `version` option against [supportedA2uiVersions] so an
/// unsupported protocol version fails fast rather than emitting envelopes the
/// renderer can't read.
void _checkVersion(String? value) {
  if (value != null && !supportedA2uiVersions.contains(value)) {
    throw ArgumentError(
      'a2ui(): unsupported version "$value" '
      '(supported: ${supportedA2uiVersions.join(', ')}).',
    );
  }
}

/// The A2UI model middleware.
///
/// Injects catalog capabilities into the prompt and rewrites emitted `<a2ui>`
/// blocks (streamed and final) into a2ui data parts.
class A2uiMiddleware extends GenerateMiddleware {
  final Registry _registry;
  final String _catalogId;
  final String _instructions;
  final A2uiValidateMode _validate;

  // Memoizes the rendered catalog instructions. `renderCatalogInstructions`
  // (including the 58-name icon list) is a pure function of the catalog, but the
  // middleware's `model` hook runs once per raw model call - i.e. more than once
  // per turn in a tool loop - so cache the last result keyed by catalog identity.
  A2uiCatalog? _instructionsCatalog;
  String? _instructionsText;

  /// Creates an [A2uiMiddleware].
  A2uiMiddleware(this._registry, [A2uiOptions? config])
    : _catalogId = config?.catalog ?? defaultCatalogId,
      _instructions = _parseInstructions(config?.instructions),
      _validate = _parseValidateMode(config?.validate) {
    _checkVersion(config?.version);
  }

  /// Renders (and caches) the catalog instructions for [catalog].
  String _renderInstructions(A2uiCatalog catalog) {
    if (!identical(_instructionsCatalog, catalog)) {
      _instructionsCatalog = catalog;
      _instructionsText = renderCatalogInstructions(catalog);
    }
    return _instructionsText!;
  }

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

    // Surfaces the client already holds. Re-rendering one of them replaces it
    // (see A2uiStreamParser).
    final liveSurfaces = liveSurfaceIds([
      for (final m in request.messages) ...a2uiEnvelopesFromParts(m.content),
    ]);

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
    A2uiStreamParser? streamParser;
    if (ctx.streamingRequested) {
      streamParser = A2uiStreamParser(
        catalog: catalog,
        // Never throw from here: this runs inside the provider's chunk
        // callback, where a throw fails (and retries) the whole model call.
        // A bad block is just left off the stream; the final message applies
        // the configured mode.
        validate: _validate == A2uiValidateMode.off
            ? A2uiValidateMode.off
            : A2uiValidateMode.warn,
        // The final parse sees these blocks again and reports them.
        quiet: true,
        liveSurfaceIds: liveSurfaces,
      );
      wrappedCtx = ctx.copyWith(
        sendChunk: (chunk) {
          final transformed = _transformChunk(chunk, streamParser!);
          if (transformed != null) ctx.sendChunk(transformed);
        },
      );
    }

    // 3) Run downstream model, then flush the stream parser so the last withheld
    //    prose tail (the parser holds back up to a partial opening tag) and any
    //    unterminated trailing block still reach the streaming consumer. Without
    //    this, clients that render purely from stream deltas would show truncated
    //    prose / miss a final block (the aggregated message recovers it, but the
    //    stream would not).
    final response = await next(newRequest, wrappedCtx);
    if (streamParser != null) {
      final tail = _partsFromSegments(streamParser.flush().segments);
      if (tail.isNotEmpty) {
        ctx.sendChunk(ModelResponseChunk(role: Role.model, content: tail));
      }
    }

    // 4) Transform the final message. Surface ids are the model's own, so the
    //    final parse produces the same envelopes the stream did.
    return _transformResponse(response, catalog, liveSurfaces);
  }

  /// Appends A2UI instructions to (or creates) the system message.
  ModelRequest _injectInstructions(ModelRequest req, A2uiCatalog catalog) {
    final text = _renderInstructions(catalog);
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
      if (part.isText && text != null && text.isNotEmpty) {
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
    Set<String> liveSurfaces,
  ) {
    final message = response.message;
    if (message == null) return response;

    final parser = A2uiStreamParser(
      catalog: catalog,
      validate: _validate,
      liveSurfaceIds: liveSurfaces,
    );
    final newContent = <Part>[];

    // Drains whatever the parser is still holding (a withheld prose tail, or an
    // unterminated trailing block) and appends it. Called at every non-text
    // boundary and once at the end.
    void flushHeld() {
      newContent.addAll(_partsFromSegments(parser.flush().segments));
    }

    for (final part in message.content) {
      final text = part.text;
      if (part.isText && text != null && text.isNotEmpty) {
        // Push WITHOUT flushing between consecutive text parts so an <a2ui> block
        // that spans several adjacent text parts is stitched back together. The
        // model's final message is not guaranteed to coalesce adjacent text:
        // the Gemini plugin, for instance, aggregates a turn into many separate
        // text parts (open tag, block body split many ways, close tag, then a
        // trailing empty-text part carrying the thought signature), so a
        // per-part flush would reset the parser mid-block and leak the whole
        // surface back out as raw prose. This mirrors the streaming path, which
        // shares one parser across all chunks and flushes only once at the end.
        newContent.addAll(_partsFromSegments(parser.push(text).segments));
      } else {
        // A non-text part (e.g. a toolRequest) or an empty-text part (e.g. the
        // trailing thought-signature carrier) is a boundary: flush any held
        // tail so it lands before this part, preserving order. This is what a
        // tool-calling turn [text("Checking the weather."), toolRequest] relies
        // on so the prose is not reordered behind the toolRequest. Then carry
        // the part through untouched so its metadata survives.
        flushHeld();
        newContent.add(part);
      }
    }
    flushHeld();

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
          final text = _summarizeA2uiPart(part, message.role);
          if (text.isNotEmpty) content.add(TextPart(text: text));
        } else {
          content.add(part);
        }
      }
      if (!msgChanged) return message;
      changed = true;
      // Some providers reject a message with empty content. If sanitizing an
      // a2ui-only message summarized to nothing (e.g. an envelope shape this
      // doesn't recognize), keep the message non-empty with a neutral marker.
      if (content.isEmpty) content.add(TextPart(text: '[UI interaction]'));
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
      case EnvelopeSegment(:final envelopes, :final source):
        out.add(a2uiPart(envelopes, source: source));
    }
  }
  return out;
}

/// Converts an inbound a2ui part back into model-readable text, the inverse of
/// the outbound block-to-part transform.
///
/// - A part the model authored carries its Express source in the metadata
///   ([a2uiExpressMetadataKey]) and is replayed verbatim as an `<a2ui>` block,
///   so the model sees exactly what it wrote, in the format it is asked to
///   produce. The source is never rewritten (surface ids are the model's own),
///   so it still describes what the client rendered.
/// - A user `action` becomes a short line the model can reason about.
/// - A surface part with no source (written before parts carried it, or by a
///   client that dropped the metadata) is summarized as a plain sentence. Not
///   as replayed JSON, which would teach the model a second output format, and
///   not as a tag-like marker, which models tend to copy into their output.
///
/// Unknown message shapes are dropped; the caller keeps the message non-empty
/// when everything drops.
String _summarizeA2uiPart(Part part, Role role) {
  // Only the model's own parts are replayed as blocks it wrote; anywhere else
  // the metadata is summarized like any other part.
  if (role == Role.model) {
    if (part.metadata?[a2uiExpressMetadataKey] case final String source) {
      return '<a2ui>\n$source\n</a2ui>';
    }
  }

  final out = <String>[];
  final surfaces = <String>{};
  void flushSurfaces() {
    if (surfaces.isEmpty) return;
    out.add('(UI surface ${surfaces.join(', ')} was rendered here.)');
    surfaces.clear();
  }

  for (final env in a2uiEnvelopesFromParts([part])) {
    final action = env['action'];
    if (action is Map) {
      flushSurfaces();
      // Client-supplied values are JSON-encoded, so a name holding `]` or a
      // newline cannot reshape the line. A plain name reads as before.
      final name = switch (action['name']) {
        final String n => jsonEncode(n),
        _ => '(unnamed)',
      };
      final surfaceId = switch (action['surfaceId']) {
        final String id when RegExp(r'^[\w.:-]+$').hasMatch(id) => id,
        final String id => jsonEncode(id),
        _ => '(unknown)',
      };
      final context = action['context'];
      final ctx = (context is Map && context.isNotEmpty)
          ? ' context=${jsonEncode(context)}'
          : '';
      out.add('[UI action $name on surface $surfaceId$ctx]');
      continue;
    }
    for (final kind in const [
      'createSurface',
      'updateComponents',
      'updateDataModel',
      'deleteSurface',
    ]) {
      if (env[kind] case {'surfaceId': final String id}) surfaces.add(id);
    }
  }
  flushSurfaces();
  return out.join('\n');
}
