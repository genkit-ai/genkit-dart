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

import 'dart:async';
import 'dart:convert';

import 'package:genkit/plugin.dart';
import 'package:logging/logging.dart';
import 'package:schemantic/schemantic.dart';

import 'catalog.dart';
import 'loader.dart';
import 'parser.dart';
import 'part.dart';
import 'repair.dart';
import 'types.dart';

part 'a2ui_middleware.g.dart';

final _logger = Logger('genkit_a2ui.middleware');

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

  /// Whether to ask the model to fix a block that failed to compile. Defaults
  /// to `true`.
  ///
  /// On a failure the middleware sends one small follow-up call containing the
  /// error, the Express contract, and the failed block, then compiles the
  /// reply. This costs an extra model call on the failure path only, and never
  /// runs for errors a rewrite cannot fix. Set `false` to drop bad blocks
  /// outright.
  bool? get repair;
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
  bool? repair,
}) {
  return middlewareRef(
    name: 'a2ui',
    config: A2uiOptions(
      catalog: catalog,
      instructions: instructions,
      validate: validate,
      version: version,
      repair: repair,
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
  final bool _repair;

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
      _validate = _parseValidateMode(config?.validate),
      _repair = config?.repair ?? true {
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

    _warnOnPreSpecClient(request);

    // Every A2UI message the client already holds. Blocks are checked against
    // the surfaces it leaves live, so one may update or replace them (see
    // A2uiStreamParser).
    final history = [
      for (final m in request.messages) ...a2uiEnvelopesFromParts(m.content),
    ];

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
    // Sources of the blocks already sent on the stream, so the parts the final
    // message adds (a repaired block, or one that depended on it) can be sent
    // after it.
    final streamed = <String>[];
    // Whether the model streamed at all. If it did not (a provider or cache
    // that answers in one piece), the client reads the final message and gets
    // no catch-up chunk either.
    var sawChunks = false;
    if (ctx.streamingRequested) {
      streamParser = A2uiStreamParser(
        catalog: catalog,
        // Never throw from here: this runs inside the provider's chunk
        // callback, where a throw fails (and retries) the whole model call.
        // A bad block is just left off the stream; the final message, after
        // any repair, applies the configured mode.
        validate: _validate == A2uiValidateMode.off
            ? A2uiValidateMode.off
            : A2uiValidateMode.warn,
        // The final parse sees these blocks again and reports them.
        quiet: true,
        history: history,
      );
      wrappedCtx = ctx.copyWith(
        sendChunk: (chunk) {
          sawChunks = true;
          final transformed = _transformChunk(chunk, streamParser!);
          if (transformed != null) {
            streamed.addAll(_sourcesOf(transformed.content));
            ctx.sendChunk(transformed);
          }
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
        streamed.addAll(_sourcesOf(tail));
        ctx.sendChunk(ModelResponseChunk(role: Role.model, content: tail));
      }
    }

    // 4) Transform the final message. Surface ids are the model's own, so the
    //    final parse produces the same envelopes the stream did.
    final message = response.message;
    if (message == null) return response;
    // What the repair calls cost, reported with the turn's own usage.
    GenerationUsage? repairUsage;
    // A turn that did not finish normally (blocked, failed, ...) is not
    // repaired, just as Genkit skips output parsing for it.
    final repairs = _repair && !_isAbnormal(response.finishReason)
        ? await _repairFailedBlocks(
            message,
            catalog,
            history,
            ctx.cancel,
            // Repair reuses the model this hook already wraps, by calling
            // `next` with a one-shot request. That needs no extra
            // configuration and skips a2ui and anything before it in the
            // chain, which would re-inject the instructions and re-parse the
            // reply; middleware after it (retry, say) still applies.
            // Streaming is suppressed: a repair is an internal detail.
            //
            // The config is forwarded because it can carry what the call
            // needs to succeed at all (a per-request API key, for one). The
            // tradeoff: an output-shaping option (a JSON response type, a
            // forced function call) can defeat a plain-text repair, which then
            // fails, is logged, and leaves the block dropped as before.
            // Provider-side tools enabled in `config` stay on for the same
            // reason.
            (prompt, cancel) async {
              final reply = await next(
                ModelRequest(
                  messages: [
                    Message(
                      role: Role.user,
                      content: [TextPart(text: prompt)],
                    ),
                  ],
                  config: request.config,
                ),
                ctx.copyWith(
                  streamingRequested: false,
                  sendChunk: (_) {},
                  cancel: cancel,
                ),
              );
              repairUsage = _sumUsage(repairUsage, reply.usage);
              // A reply cut off by the token limit may still compile, as a
              // fragment; don't take it.
              if (reply.finishReason == FinishReason.length) return null;
              return reply.message?.content
                      .where((p) => p.isText)
                      .map((p) => p.text ?? '')
                      .join() ??
                  '';
            },
          )
        : const <String, String>{};
    final result = _transformResponse(
      response,
      message,
      catalog,
      history,
      repairs,
      extraUsage: repairUsage,
    );

    // 5) A block that failed on the stream and was repaired afterwards exists
    //    only in the final message. Send it (and any block that failed only
    //    because it depended on it) as one last chunk, so clients that render
    //    from the stream get the same surfaces the session history records.
    if (streamParser != null && sawChunks) {
      final catchUp = _catchUp(result.message?.content ?? [], streamed);
      if (catchUp.isNotEmpty) {
        ctx.sendChunk(ModelResponseChunk(role: Role.model, content: catchUp));
      }
    }
    return result;
  }

  /// Finds the blocks in [message] that fail to compile and asks the model to
  /// fix each one, returning original source to repaired source for the ones
  /// that now compile.
  ///
  /// Repair runs on the final message rather than during streaming because
  /// the streaming callback cannot await a model call; the caller sends the
  /// repaired surface as the last chunk. One attempt per distinct block; a
  /// repair that still fails is dropped, so it is never worse than no repair.
  ///
  /// Bounded, since it runs after the prose has streamed and a slow repair
  /// holds open a turn that looks finished: at most [_maxRepairCalls] calls
  /// within [_repairBudget]. [cancel] (the turn's token) still aborts the turn;
  /// running out of budget only ends the repairs.
  Future<Map<String, String>> _repairFailedBlocks(
    Message message,
    A2uiCatalog catalog,
    List<A2uiEnvelope> history,
    CancellationToken? cancel,
    Future<String?> Function(String prompt, CancellationToken cancel) ask,
  ) async {
    // Parses the whole message with [repairs] applied, without throwing, and
    // returns the blocks that still fail. Each block is checked against the
    // history plus every block before it, repaired or not, so a repaired block
    // may update a surface an earlier block of the same response created.
    List<FailedBlock> probe(Map<String, String> repairs) {
      final parser = A2uiStreamParser(
        catalog: catalog,
        validate: _validate == A2uiValidateMode.off
            ? A2uiValidateMode.off
            : A2uiValidateMode.warn,
        history: history,
        repairs: repairs,
        // The final parse reports what stays broken.
        quiet: true,
      );
      // Fed exactly like the final parse (a non-text part ends a run of
      // text), so the failed blocks are keyed by the sources it will see.
      for (final part in message.content) {
        final text = part.text;
        if (part.isText && text != null && text.isNotEmpty) {
          parser.push(text);
        } else {
          parser.flush();
        }
      }
      parser.flush();
      return parser.failedBlocks;
    }

    var repairs = <String, String>{};
    // Repaired sources are keyed by block text, so one attempt covers every
    // copy of a block repeated in the same response. One block at a time, in
    // order: a block that failed only because an earlier one did passes once
    // that one is repaired, and costs no call of its own.
    final attempted = <String>{};
    final budget = CancellationController();
    final unlink = cancel?.link(budget);
    final timer = Timer(_repairBudget, () => budget.cancel('repair budget'));
    var calls = 0;
    try {
      while (true) {
        final block = probe(
          repairs,
        ).where((b) => !attempted.contains(b.source)).firstOrNull;
        if (block == null) break;
        attempted.add(block.source);
        if (!block.isModelFixable) {
          _logger.info(
            'skipping repair, not fixable by rewriting: ${block.error}',
          );
          continue;
        }
        // Every block starts with surface(...); without one this is most
        // likely the tag mentioned in prose, not a block worth a model call.
        if (!_surfaceLineRe.hasMatch(block.source)) {
          _logger.fine('skipping repair of a block with no surface(...)');
          continue;
        }
        cancel?.throwIfCancelled();
        if (calls == _maxRepairCalls || budget.isCancelled) {
          _logger.warning(
            'A2UI repair limit reached ($_maxRepairCalls calls or '
            '${_repairBudget.inSeconds}s); dropping the remaining broken '
            'blocks.',
          );
          break;
        }
        calls++;
        _noteFirstRepair();
        final repaired = await _askForRepair(
          block,
          catalog,
          ask,
          budget.token,
          cancel,
        );
        if (repaired == null) continue;
        // Only accept a repair that holds up in place, under the configured
        // mode.
        final candidate = {...repairs, block.source: repaired};
        final still = probe(
          candidate,
        ).where((b) => b.source == block.source).firstOrNull;
        if (still != null) {
          _logger.warning('repair failed for "${block.error}": ${still.error}');
          continue;
        }
        repairs = candidate;
        _logger.info('repaired an A2UI block after: ${block.error}');
      }
    } finally {
      timer.cancel();
      unlink?.call();
    }
    return repairs;
  }

  /// Asks for one repair; returns the repaired source, or null.
  Future<String?> _askForRepair(
    FailedBlock block,
    A2uiCatalog catalog,
    Future<String?> Function(String prompt, CancellationToken cancel) ask,
    CancellationToken budget,
    CancellationToken? cancel,
  ) async {
    try {
      // Raced against the budget too: not every model plugin honours its
      // cancellation token, and the budget must bound the wait either way.
      final reply = await Future.any([
        ask(
          buildRepairPrompt(
            source: block.source,
            error: block.error,
            catalog: catalog,
          ),
          budget,
        ),
        budget.whenCancelled.then<String?>(
          (_) => throw TimeoutException('A2UI repair budget'),
        ),
      ]);
      final repaired = reply == null ? null : extractRepairedBlock(reply);
      if (repaired == null) {
        _logger.warning('repair returned nothing for: ${block.error}');
        return null;
      }
      if (!_keepsSurface(block.source, repaired)) {
        _logger.warning(
          'repair changed which surfaces the block targets, discarding it: '
          '${block.error}',
        );
        return null;
      }
      return repaired;
    } catch (e) {
      // The caller's cancellation aborts the turn; only the repair's own
      // budget running out, or a failing call, is swallowed here.
      if (cancel?.isCancelled ?? false) rethrow;
      if (budget.isCancelled) {
        _logger.warning('A2UI repair ran out of time: ${block.error}');
      } else {
        _logger.warning('repair failed for "${block.error}": $e');
      }
      return null;
    }
  }

  /// At most this many repair calls per model call.
  static const _maxRepairCalls = 3;

  /// The time all repairs of one model call may take together.
  static const _repairBudget = Duration(seconds: 30);

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

  /// Transforms the final response message: prose text + a2ui parts, with
  /// [repairs] substituted for the blocks that failed.
  ModelResponse _transformResponse(
    ModelResponse response,
    Message message,
    A2uiCatalog catalog,
    List<A2uiEnvelope> history,
    Map<String, String> repairs, {
    GenerationUsage? extraUsage,
  }) {
    final parser = A2uiStreamParser(
      catalog: catalog,
      validate: _validate,
      history: history,
      repairs: repairs,
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
    if (!newContent.any(isA2uiPart)) _warnOnPreExpressOutput(message);

    return ModelResponse(
      message: Message(
        role: message.role,
        content: newContent,
        metadata: message.metadata,
      ),
      finishReason: response.finishReason,
      finishMessage: response.finishMessage,
      latencyMs: response.latencyMs,
      usage: _sumUsage(response.usage, extraUsage),
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

/// [a] and [b] summed field by field, or whichever is set.
GenerationUsage? _sumUsage(GenerationUsage? a, GenerationUsage? b) {
  if (a == null || b == null) return a ?? b;
  final x = a.toJson(), y = b.toJson();
  return GenerationUsage.fromJson({
    for (final key in {...x.keys, ...y.keys})
      key: switch ((x[key], y[key])) {
        (final num p, final num q) => p + q,
        (final v, final w) => v ?? w,
      },
  });
}

final _surfaceLineRe = RegExp(r'^\s*surface\(', multiLine: true);
final _surfaceTargetRe = RegExp(
  r'''^\s*(surface|deleteSurface)\(\s*["']([^"']*)["']''',
  multiLine: true,
);

/// Whether [repaired] targets exactly the surfaces [original] does (its
/// `surface(...)` and `deleteSurface(...)` lines): the repair prompt asks to
/// keep them, and a repair that renamed a surface or reached for another one
/// would act on surfaces the conversation never chose.
bool _keepsSurface(String original, String repaired) {
  Set<String> targets(String source) => {
    for (final m in _surfaceTargetRe.allMatches(source))
      '${m.group(1)}:${m.group(2)}',
  };
  final a = targets(original), b = targets(repaired);
  return a.length == b.length && a.containsAll(b);
}

bool _isAbnormal(FinishReason? reason) => const {
  'blocked',
  'aborted',
  'failed',
  'interrupted',
  'other',
}.contains(reason?.value);

var _notedFirstRepair = false;

/// Logs, once per process, why an extra model call happened.
void _noteFirstRepair() {
  if (_notedFirstRepair) return;
  _notedFirstRepair = true;
  _logger.info(
    'A2UI: asking the model to repair a block that failed to compile (an '
    'extra model call). Turn this off with a2ui(repair: false).',
  );
}

/// The Express sources of the a2ui parts in [parts], in order.
Iterable<String> _sourcesOf(List<Part> parts) sync* {
  for (final p in parts.where(isA2uiPart)) {
    if (p.metadata?[a2uiExpressMetadataKey] case final String src) yield src;
  }
}

/// What a stream client still needs once the final message is known: the
/// a2ui parts the stream did not carry (a repaired block, or one that failed
/// only because an earlier one did), matched to [streamed] by source, one for
/// one.
///
/// A late part may belong before parts that already streamed for the same
/// surface; applied after them, it would undo them. So from the first late
/// part on, every part touching a surface a late part touches is sent again,
/// in final order. That is safe to repeat: each `createSurface` comes with its
/// `deleteSurface`, and updates are idempotent.
List<Part> _catchUp(List<Part> parts, List<String> streamed) {
  final pending = <String, int>{};
  for (final s in streamed) {
    pending[s] = (pending[s] ?? 0) + 1;
  }
  final a2ui = parts.where(isA2uiPart).toList();
  final late = <int>{};
  for (final (i, p) in a2ui.indexed) {
    if (p.metadata?[a2uiExpressMetadataKey] case final String src
        when (pending[src] ?? 0) > 0) {
      pending[src] = pending[src]! - 1;
    } else {
      late.add(i);
    }
  }
  if (late.isEmpty) return const [];
  // Grows as parts are re-sent, so a re-sent part that also touches another
  // surface pulls in that surface's later parts too.
  final affected = {for (final i in late) ..._surfacesOf(a2ui[i])};
  final out = <Part>[];
  for (final (i, p) in a2ui.indexed.skip(late.first)) {
    final surfaces = _surfacesOf(p);
    if (late.contains(i) || surfaces.any(affected.contains)) {
      out.add(p);
      affected.addAll(surfaces);
    }
  }
  return out;
}

/// The surface ids an a2ui part's messages target.
Set<String> _surfacesOf(Part part) => {
  for (final e in a2uiEnvelopesFromParts([part]))
    for (final body in e.values)
      if (body case {'surfaceId': final String id}) id,
};

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

var _warnedPreSpecClient = false;
var _warnedPreExpressOutput = false;

/// Warns once per process when the latest user message carries an a2ui part
/// with only the pre-0.5 `envelopes` key: that client cannot read this
/// version's `messages` parts, so its surfaces would silently stop rendering.
void _warnOnPreSpecClient(ModelRequest request) {
  if (_warnedPreSpecClient) return;
  final last = request.messages.where((m) => m.role == Role.user).lastOrNull;
  for (final part in last?.content ?? const <Part>[]) {
    final data = part.data;
    if (part.metadata?['mimeType'] == a2uiMimeType &&
        data != null &&
        data.containsKey('envelopes') &&
        !data.containsKey('messages')) {
      _warnedPreSpecClient = true;
      _logger.warning(
        'A2UI: a client sent an a2ui part with the pre-0.5 `envelopes` key. '
        'It cannot render the `messages` parts this version sends; update it '
        'to the client helpers in the genkit_a2ui README.',
      );
      return;
    }
  }
}

/// Warns once per process when the model wrote the pre-0.5 JSON format, which
/// passes through as plain text, typically because custom instructions
/// (`instructions: 'none'`) or examples still describe it.
void _warnOnPreExpressOutput(Message message) {
  if (_warnedPreExpressOutput) return;
  final text = message.content.map((p) => p.text ?? '').join();
  if (!text.contains('```a2ui')) return;
  _warnedPreExpressOutput = true;
  _logger.warning(
    'A2UI: the model wrote a ```a2ui fenced block, which genkit_a2ui 0.5 no '
    'longer reads. It expects A2UI Express between <a2ui> tags; see '
    'renderCatalogInstructions.',
  );
}

/// An id from a client-supplied message, as prompt text: plain ids read as
/// is, anything else is JSON-encoded so it cannot reshape the line. Null for
/// a missing or empty id.
String? _idText(Object? id) => switch (id) {
  final String s when s.isEmpty => null,
  final String s when RegExp(r'^[\w.:-]+$').hasMatch(s) => s,
  final String s => jsonEncode(s),
  _ => null,
};

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
  final rendered = <String>{};
  final removed = <String>{};
  void flushSurfaces() {
    if (rendered.isNotEmpty) {
      out.add('(UI surface ${rendered.join(', ')} was rendered here.)');
    }
    if (removed.isNotEmpty) {
      out.add('(UI surface ${removed.join(', ')} was removed here.)');
    }
    rendered.clear();
    removed.clear();
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
      final surfaceId = _idText(action['surfaceId']) ?? '(unknown)';
      // Which component fired it tells apart two buttons with one action name.
      final from = switch (_idText(action['sourceComponentId'])) {
        final id? => ' from $id',
        null => '',
      };
      final context = action['context'];
      final ctx = (context is Map && context.isNotEmpty)
          ? ' context=${jsonEncode(context)}'
          : '';
      out.add('[UI action $name$from on surface $surfaceId$ctx]');
      continue;
    }
    // Patterns rather than casts: this runs on stored history, so a malformed
    // body (`{'createSurface': 'oops'}`) must be skipped, not throw on every
    // later turn of the session.
    for (final kind in const [
      'createSurface',
      'updateComponents',
      'updateDataModel',
    ]) {
      if (env[kind] case {'surfaceId': final Object? raw}) {
        if (_idText(raw) case final id?) {
          // Every render starts with a delete, which this undoes.
          removed.remove(id);
          rendered.add(id);
        }
      }
    }
    if (env['deleteSurface'] case {'surfaceId': final Object? raw}) {
      if (_idText(raw) case final id?) {
        rendered.remove(id);
        removed.add(id);
      }
    }
  }
  flushSurfaces();
  return out.join('\n');
}
