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

/// Streaming parser that extracts A2UI Express blocks from model output.
///
/// The model writes UI as A2UI Express between `<a2ui>` and `</a2ui>` tags
/// (see [renderCatalogInstructions]). This parser scans a text stream
/// incrementally, separating ordinary prose (which streams through as deltas)
/// from complete blocks (which are buffered until the closing tag, then
/// compiled into whole envelopes; the protocol requires ordered, complete
/// messages, so half a block is never emitted).
library;

import 'package:a2ui_core/a2ui_core.dart' show A2uiError;
import 'package:logging/logging.dart';

import 'catalog.dart';
import 'express.dart';
import 'types.dart';

final _logger = Logger('genkit_a2ui.parser');

/// How the parser treats a block that fails to compile or validate.
enum A2uiValidateMode {
  /// Throw. Best during development.
  strict,

  /// Log a warning and drop the block, keeping the rest of the turn.
  warn,

  /// Skip the renderer-side checks (dangling references, missing `root`) and
  /// drop a block that does not compile without logging a warning.
  off,
}

/// Opening tag, as loosely as `a2ui_agent` reads it (attributes, any case),
/// plus the backticks a model sometimes wraps it in.
final _openTagRe = RegExp(
  r'`?<a2ui(?:\s[^>]*)?>`?[ \t]*\r?\n?',
  caseSensitive: false,
);

/// Closing tag, as loosely as `a2ui_agent` reads it, plus wrapping backticks.
/// A literal `</a2ui>` inside an Express string would end the block early;
/// that is accepted as a model error rather than worth a string-aware scanner
/// here.
final _closeTagRe = RegExp(r'`?</a2ui\s*>`?', caseSensitive: false);

/// Where the tail of [text] that could still grow into an opening tag starts,
/// or `text.length` if none could. Held back from the prose so a tag split
/// across chunks never leaks into it.
int _partialOpenTagStart(String text) {
  var start = text.length;
  final lt = text.lastIndexOf('<');
  if (lt >= 0) {
    final tail = text.substring(lt).toLowerCase();
    final couldBeTag =
        '<a2ui'.startsWith(tail) ||
        (tail.startsWith('<a2ui') &&
            !tail.contains('>') &&
            (tail.length == 5 || tail[5].trim().isEmpty));
    if (couldBeTag) start = lt;
  }
  // A backtick, or a code-fence line, right before the (possible) tag may be
  // wrapping it; hold it back too, so it can be dropped if the tag follows.
  if (_trailingFenceLineRe.firstMatch(text.substring(0, start)) case final m?) {
    return m.start;
  }
  if (start > 0 && text[start - 1] == '`') return start - 1;
  return start;
}

/// A code-fence line (or the start of one) at the very end of the text.
final _trailingFenceLineRe = RegExp(
  r'(?:^|(?<=\n))[ \t]*``+[\w-]*[ \t]*\r?\n?[ \t]*$',
);

/// What may directly follow a closing tag and is not prose: a backtick that
/// wrapped the tag, a newline, and a code fence the model closed around the
/// block.
final _afterCloseRe = RegExp(
  r'^(?:[ \t]*```[ \t]*(?:\r?\n|$)|`?(?:[ \t]*\r?\n)?(?:[ \t]*```[ \t]*(?:\r?\n|$))?)',
);

/// The start of a closing code fence, split from the rest by a chunk boundary.
final _partialFenceRe = RegExp(r'^[ \t]*`{1,2}$');

/// A code-fence line right before an opening tag (``` or ```a2ui).
final _fenceBeforeTagRe = RegExp(r'```[\w-]*[ \t]*\r?\n[ \t]*$');

/// Markdown fences some models wrap around the block content.
final _leadingFenceRe = RegExp(r'^```[a-zA-Z-]*\s*');
final _trailingFenceRe = RegExp(r'\s*```$');
final _strayBacktickStartRe = RegExp(r'^`(?!`)\s*');
final _strayBacktickEndRe = RegExp(r'(?<!`)\s*`$');

/// A single ordered piece of parsed output: either a run of prose or one
/// compiled block. Segments preserve the exact source order, so prose that
/// appears *after* a block is not reordered ahead of it.
sealed class ParseSegment {
  const ParseSegment();
}

/// A run of prose text (never contains A2UI blocks).
class ProseSegment extends ParseSegment {
  /// The prose text.
  final String prose;

  /// Creates a [ProseSegment].
  const ProseSegment(this.prose);
}

/// The envelopes compiled from one Express block.
class EnvelopeSegment extends ParseSegment {
  /// The compiled envelopes, ready to send to a renderer.
  final List<A2uiEnvelope> envelopes;

  /// The Express block the envelopes were compiled from, without its tags.
  final String source;

  /// Creates an [EnvelopeSegment].
  const EnvelopeSegment(this.envelopes, this.source);
}

/// Result of feeding text to [A2uiStreamParser.push].
class ParseResult {
  /// Ordered prose/envelope segments exactly as they appear in the source text.
  final List<ParseSegment> segments;

  /// Creates a [ParseResult].
  const ParseResult(this.segments);

  /// All prose runs concatenated. Loses the relative order of prose and
  /// blocks; use [segments] when that matters.
  String get prose => [
    for (final s in segments)
      if (s is ProseSegment) s.prose,
  ].join();

  /// The compiled envelope batches, one per block, in order.
  List<List<A2uiEnvelope>> get envelopeBatches => [
    for (final s in segments)
      if (s is EnvelopeSegment) s.envelopes,
  ];
}

/// Incremental A2UI extractor. Create one per model response, [push] text
/// deltas as they arrive, and [flush] at the end to drain any trailing block.
///
/// Surface ids are the model's own (`surface("tokyo-weather")`). Rendering a
/// surface id that already exists replaces that surface: every `createSurface`
/// is preceded by a `deleteSurface` for the same id, which renderers treat as
/// a no-op when the surface is new. That way a re-render never depends on the
/// server knowing which surfaces the client holds. The Express source is never
/// edited, so it can be replayed verbatim.
class A2uiStreamParser {
  /// Catalog the blocks are compiled and validated against.
  final A2uiCatalog catalog;

  /// What to do with a block that fails to compile or validate.
  final A2uiValidateMode validate;

  /// Logs rejected blocks at `FINE` instead of `WARNING`, for a pass whose
  /// rejections another pass reports (the stream parser, whose blocks the
  /// final parse sees again).
  final bool quiet;

  final ExpressEngine _engine;

  /// Surfaces this response created so far, to flag a model that renders the
  /// same id twice in one response.
  final Set<String> _createdHere = {};

  String _buffer = '';
  bool _inBlock = false;

  /// The opening tag of the block being read, given back as prose if the
  /// "block" turns out to be a mention of the tag (see [_drain]).
  String _openTag = '';

  /// Set when a block closed at the very end of the buffer, so what
  /// conventionally follows `</a2ui>` (a newline, a closing backtick or code
  /// fence) is dropped even when it arrives in the next chunk.
  bool _afterClose = false;

  /// Creates an [A2uiStreamParser].
  A2uiStreamParser({
    required this.catalog,
    this.validate = A2uiValidateMode.strict,
    this.quiet = false,
  }) : _engine = ExpressEngine.of(catalog);

  /// Feeds a chunk of model text, returning prose + any completed blocks.
  ParseResult push(String text) {
    _buffer += text;
    if (_afterClose && _buffer.isNotEmpty) {
      _buffer = _buffer.replaceFirst(_afterCloseRe, '');
      _afterClose = _partialFenceRe.hasMatch(_buffer);
    }
    return _drain(false);
  }

  /// Drains any remaining buffered content at end of stream.
  ParseResult flush() => _drain(true);

  ParseResult _drain(bool finalPass) {
    final segments = <ParseSegment>[];
    // Accumulates prose across loop iterations so consecutive prose runs (e.g.
    // when a partial tag is held back) coalesce into a single segment.
    var proseBuf = '';
    void flushProse() {
      if (proseBuf.isNotEmpty) {
        segments.add(ProseSegment(proseBuf));
        proseBuf = '';
      }
    }

    void emitBlock(String raw) {
      final segment = _compileBlock(raw);
      if (segment != null) {
        flushProse();
        segments.add(segment);
      }
    }

    // Loop because a single push may contain multiple prose/block transitions.
    // Each iteration makes progress or breaks.
    while (true) {
      if (!_inBlock) {
        final open = _openTagRe.firstMatch(_buffer);
        if (open == null) {
          // No opening tag (yet). Emit prose, but hold back a tail that could
          // be the start of an incomplete opening tag, unless finalizing.
          final safeLen = finalPass
              ? _buffer.length
              : _partialOpenTagStart(_buffer);
          proseBuf += _buffer.substring(0, safeLen);
          _buffer = _buffer.substring(safeLen);
          break;
        }
        // A code fence the model opened around the tag is not prose.
        proseBuf += _buffer
            .substring(0, open.start)
            .replaceFirst(_fenceBeforeTagRe, '');
        _openTag = open.group(0)!;
        _buffer = _buffer.substring(open.end);
        _inBlock = true;
        continue;
      }

      final close = _closeTagRe.firstMatch(_buffer);
      if (close == null) {
        if (finalPass) {
          // Unterminated block at end of stream. If it does not even start
          // like Express, the model mentioned the tag in prose ("I render UI
          // with <a2ui> tags"): give it back as prose rather than swallowing
          // the rest of the reply. Otherwise compile what there is.
          if (_startsLikeExpress(_buffer)) {
            emitBlock(_buffer);
          } else {
            proseBuf += _openTag + _buffer;
          }
          _buffer = '';
          _inBlock = false;
        }
        break;
      }
      final blockText = _buffer.substring(0, close.start);
      _buffer = _buffer.substring(close.end).replaceFirst(_afterCloseRe, '');
      _afterClose = _buffer.isEmpty || _partialFenceRe.hasMatch(_buffer);
      _inBlock = false;
      emitBlock(blockText);
    }
    flushProse();
    return ParseResult(segments);
  }

  /// Compiles one block, or returns null if it is empty or rejected.
  EnvelopeSegment? _compileBlock(String raw) {
    final source = raw
        .trim()
        .replaceFirst(_leadingFenceRe, '')
        .replaceFirst(_trailingFenceRe, '')
        // A backtick wrapping a tag that arrived in its own chunk, after the
        // tag regex already matched without it.
        .replaceFirst(_strayBacktickStartRe, '')
        .replaceFirst(_strayBacktickEndRe, '')
        .trim();
    if (source.isEmpty) return null;

    final List<A2uiEnvelope> compiled;
    try {
      compiled = _engine.compile(
        source,
        validate: validate != A2uiValidateMode.off,
      );
    } on A2uiError catch (e) {
      return _reject('failed to compile A2UI Express block: ${e.message}');
    }
    if (compiled.isEmpty) return null;
    return EnvelopeSegment(_withReplacements(compiled), source);
  }

  /// Puts a `deleteSurface` in front of every `createSurface`, so a re-render
  /// replaces a surface the client holds instead of being rejected (or worse,
  /// merged into the old component tree), whether or not the conversation's
  /// history records it. For a new surface the delete is a no-op.
  List<A2uiEnvelope> _withReplacements(List<A2uiEnvelope> envelopes) {
    final out = <A2uiEnvelope>[];
    for (final e in envelopes) {
      if (_surfaceIdOf(e, 'createSurface') case final id?) {
        if (!_createdHere.add(id)) {
          _log(
            'A2UI: surface "$id" was rendered twice in one response; the '
            'later render replaces the earlier one.',
          );
        }
        out.add({
          'version': e['version'] ?? a2uiVersion,
          'deleteSurface': {'surfaceId': id},
        });
      }
      out.add(e);
    }
    return out;
  }

  void _log(String message) =>
      quiet ? _logger.fine(message) : _logger.warning(message);

  /// Handles a rejected block according to [validate]: throws in strict mode,
  /// logs in warn mode. Always returns null so callers can `return _reject()`.
  Null _reject(String message) {
    final full = 'A2UI: $message';
    switch (validate) {
      case A2uiValidateMode.off:
        _logger.fine('$full (dropping block)');
        return null;
      case A2uiValidateMode.warn:
        if (quiet) {
          _logger.fine('$full (dropping block)');
        } else {
          _logger.warning('$full (dropping block)');
        }
        return null;
      case A2uiValidateMode.strict:
        throw StateError(full);
    }
  }
}

/// Whether [block] begins with something an Express block can begin with: a
/// `surface(...)` / `deleteSurface(...)` call, a data path or variable
/// assignment, or a comment.
bool _startsLikeExpress(String block) {
  final first = block
      .replaceFirst(_leadingFenceRe, '')
      .replaceFirst(_strayBacktickStartRe, '')
      .trimLeft();
  return _expressStartRe.hasMatch(first);
}

final _expressStartRe = RegExp(
  r'^(?:(?:surface|deleteSurface)\s*\(|\$/|[A-Za-z_]\w*\s*=|//)',
);

String? _surfaceIdOf(A2uiEnvelope e, String kind) => switch (e[kind]) {
  {'surfaceId': final String id} => id,
  _ => null,
};
