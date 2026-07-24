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

/// Streaming parser that extracts A2UI envelopes from model output.
///
/// The model emits A2UI as a fenced code block tagged `a2ui` containing a JSON
/// array of envelopes (see [renderCatalogInstructions]). This parser scans a
/// text stream incrementally, separating ordinary prose (which streams through
/// as deltas) from complete A2UI blocks (which are buffered until the closing
/// fence, then parsed into whole, validated envelopes - the protocol requires
/// ordered, complete messages, so we never emit half-parsed JSON).
library;

import 'dart:convert';

import 'package:logging/logging.dart';

import 'catalog.dart';
import 'types.dart';

final _logger = Logger('genkit_a2ui.parser');

/// How the parser finalizes/validates envelopes.
enum A2uiValidateMode {
  /// Throw on malformed JSON or unknown components.
  strict,

  /// Log a warning and drop the offending block/envelope (keeps the turn alive).
  warn,

  /// Pass envelopes through unchecked.
  off,
}

/// Opening fence, matched case-insensitively (```a2ui).
final _openFenceRe = RegExp(r'```[ \t]*a2ui[ \t]*\r?\n', caseSensitive: false);

/// The longest prefix of an opening fence, used to hold back a partial fence.
const _maxPartialFence = 8; // '```a2ui\n'.length

/// Closing fence: ``` anywhere.
final _closeFenceRe = RegExp('```');

/// Consumes an optional trailing newline after the closing fence.
final _trailingNewlineRe = RegExp(r'^[ \t]*\r?\n');

/// A single ordered piece of parsed output: either a run of prose or one
/// completed A2UI envelope batch. Segments preserve the exact source order, so
/// prose that appears *after* a block is not reordered ahead of it.
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

/// A completed batch of A2UI envelopes from a single block.
class EnvelopeSegment extends ParseSegment {
  /// The envelopes parsed from the block.
  final List<A2uiEnvelope> envelopes;

  /// Creates an [EnvelopeSegment].
  const EnvelopeSegment(this.envelopes);
}

/// Result of feeding text to [A2uiStreamParser.push].
class ParseResult {
  /// Ordered prose/envelope segments exactly as they appear in the source text.
  /// Prefer this over [prose]/[envelopeBatches] when order between prose and
  /// blocks matters.
  final List<ParseSegment> segments;

  /// Convenience: all prose runs concatenated (never contains A2UI blocks).
  /// Loses the relative order of prose vs. blocks - use [segments] when that
  /// matters.
  final String prose;

  /// Convenience: the fully-parsed A2UI envelope batches, in order.
  final List<List<A2uiEnvelope>> envelopeBatches;

  /// Creates a [ParseResult].
  const ParseResult(this.segments, this.prose, this.envelopeBatches);
}

/// Incremental A2UI extractor. Create one per model turn, [push] text deltas as
/// they arrive, and [flush] at the end to drain any trailing block.
class A2uiStreamParser {
  /// Catalog used to validate component references.
  final A2uiCatalog? catalog;

  /// How to finalize/validate envelopes.
  final A2uiValidateMode validate;

  /// Protocol version stamped onto envelopes lacking one.
  final String version;

  /// Produces the surface id substituted for the model's placeholder.
  final String Function() surfaceId;

  String _buffer = '';
  bool _inBlock = false;

  /// Stable surface id for the current block (placeholders map to this).
  String? _currentSurfaceId;

  /// Creates an [A2uiStreamParser].
  A2uiStreamParser({
    required this.surfaceId,
    this.catalog,
    this.validate = A2uiValidateMode.strict,
    this.version = a2uiVersion,
  });

  /// Feeds a chunk of model text, returning prose + any completed blocks.
  ParseResult push(String text) {
    _buffer += text;
    return _drain(false);
  }

  /// Drains any remaining buffered content at end of stream.
  ParseResult flush() {
    return _drain(true);
  }

  ParseResult _drain(bool finalPass) {
    final segments = <ParseSegment>[];
    // Accumulates prose across loop iterations so consecutive prose runs (e.g.
    // when a partial fence is held back) coalesce into a single segment.
    var proseBuf = '';
    void flushProse() {
      if (proseBuf.isNotEmpty) {
        segments.add(ProseSegment(proseBuf));
        proseBuf = '';
      }
    }

    // Loop because a single push may contain multiple prose/block transitions.
    // Each iteration makes progress or returns.
    while (true) {
      if (!_inBlock) {
        final open = _openFenceRe.firstMatch(_buffer);
        if (open == null) {
          // No opening fence (yet). Emit prose, but hold back a tail that could
          // be the start of an incomplete opening fence, unless finalizing.
          if (finalPass) {
            proseBuf += _buffer;
            _buffer = '';
          } else {
            final keep = _maxPartialFence < _buffer.length
                ? _maxPartialFence
                : _buffer.length;
            final safeLen = _buffer.length - keep;
            if (safeLen > 0) {
              proseBuf += _buffer.substring(0, safeLen);
              _buffer = _buffer.substring(safeLen);
            }
          }
          break;
        }
        // Emit prose before the fence, then enter the block.
        proseBuf += _buffer.substring(0, open.start);
        _buffer = _buffer.substring(open.end);
        _inBlock = true;
        _currentSurfaceId = surfaceId();
        continue;
      }

      // In a block: look for the closing fence.
      final close = _closeFenceRe.firstMatch(_buffer);
      if (close == null) {
        if (finalPass) {
          // Unterminated block at end of stream - try to parse what we have.
          final batch = _finalizeBlock(_buffer);
          if (batch != null) {
            flushProse();
            segments.add(EnvelopeSegment(batch));
          }
          _buffer = '';
          _inBlock = false;
        }
        break;
      }
      final blockText = _buffer.substring(0, close.start);
      _buffer = _buffer.substring(close.end);
      // Consume an optional trailing newline after the closing fence.
      _buffer = _buffer.replaceFirst(_trailingNewlineRe, '');
      _inBlock = false;
      final batch = _finalizeBlock(blockText);
      if (batch != null) {
        // Emit any prose seen before this block first, preserving source order.
        flushProse();
        segments.add(EnvelopeSegment(batch));
      }
      continue;
    }
    flushProse();

    // Derive the convenience fields from the ordered segments.
    var prose = '';
    final envelopeBatches = <List<A2uiEnvelope>>[];
    for (final seg in segments) {
      switch (seg) {
        case ProseSegment(prose: final proseText):
          prose += proseText;
        case EnvelopeSegment(:final envelopes):
          envelopeBatches.add(envelopes);
      }
    }
    return ParseResult(segments, prose, envelopeBatches);
  }

  /// Handles a validation failure according to the configured [validate] mode:
  /// throws in [A2uiValidateMode.strict], logs a warning in
  /// [A2uiValidateMode.warn], and is silent in [A2uiValidateMode.off]. Always
  /// returns `null` so callers can `return _reject(...)`.
  Null _reject(String message) {
    final full = 'A2UI: $message';
    switch (validate) {
      case A2uiValidateMode.off:
        return null;
      case A2uiValidateMode.warn:
        _logger.warning('$full (dropping block/envelope)');
        return null;
      case A2uiValidateMode.strict:
        throw StateError(full);
    }
  }

  /// Parses, validates, and normalizes one block's JSON into envelopes.
  List<A2uiEnvelope>? _finalizeBlock(String raw) {
    final surface = _currentSurfaceId ?? surfaceId();
    _currentSurfaceId = null;

    final text = raw.trim();
    if (text.isEmpty) return null;

    Object? parsed;
    try {
      parsed = jsonDecode(text);
    } catch (e) {
      return _reject('failed to parse envelope block as JSON: $e');
    }

    final envelopes = parsed is List ? parsed : [parsed];
    final out = <A2uiEnvelope>[];
    for (final env in envelopes) {
      final normalized = _normalizeEnvelope(env, surface);
      if (normalized != null) out.add(normalized);
    }
    if (out.isEmpty) return null;

    // Guarantee the block opens with a `createSurface`, so the client always
    // has a surface before any update targets it. Models often emit only
    // `updateComponents`/`updateDataModel` on a follow-up (e.g. a "refresh")
    // turn; without this the renderer would drop those updates as "surface not
    // found". Idempotent re-creation is fine - it resets the surface.
    final hasCreate = out.any((e) => e['createSurface'] != null);
    if (!hasCreate) {
      out.insert(0, {
        'version': version,
        'createSurface': {'surfaceId': surface, 'catalogId': catalog?.id ?? ''},
      });
    }
    return out;
  }

  /// Validates a single envelope, substitutes the real surface id for the
  /// placeholder, and stamps the protocol version.
  A2uiEnvelope? _normalizeEnvelope(Object? env, String surface) {
    if (env is! Map) {
      return _reject('envelope must be an object.');
    }
    final e = env.cast<String, dynamic>();
    final envVersion = (e['version'] as String?) ?? version;

    void swapSurfaceId(Object? payload) {
      if (payload is! Map) return;
      final p = payload;
      final current = p['surfaceId'];
      if (current == null || current == surfaceIdPlaceholder || current == '') {
        p['surfaceId'] = surface;
      }
    }

    if (e['createSurface'] != null) {
      swapSurfaceId(e['createSurface']);
      return {'version': envVersion, 'createSurface': e['createSurface']};
    }
    if (e['updateComponents'] != null) {
      swapSurfaceId(e['updateComponents']);
      if (validate != A2uiValidateMode.off) {
        final components = (e['updateComponents'] as Map?)?['components'];
        final err = _validateComponents(components);
        if (err != null) return _reject(err);
      }
      return {'version': envVersion, 'updateComponents': e['updateComponents']};
    }
    if (e['updateDataModel'] != null) {
      swapSurfaceId(e['updateDataModel']);
      return {'version': envVersion, 'updateDataModel': e['updateDataModel']};
    }
    if (e['deleteSurface'] != null) {
      swapSurfaceId(e['deleteSurface']);
      return {'version': envVersion, 'deleteSurface': e['deleteSurface']};
    }
    return _reject('unknown envelope type (keys: ${e.keys.join(', ')}).');
  }

  /// Ensures every component references a known catalog component. Returns an
  /// error message describing the first problem found, or `null` if valid.
  String? _validateComponents(Object? components) {
    final catalog = this.catalog;
    if (catalog == null) return null;
    if (components is! List) {
      return 'updateComponents.components must be an array.';
    }
    final known = catalog.components.map((c) => c.name).toSet();
    final hasRoot = components.any((c) => c is Map && c['id'] == 'root');
    if (!hasRoot) {
      return 'component list must contain a component id "root".';
    }
    for (final c in components) {
      if (c is! Map || c['component'] is! String || c['id'] is! String) {
        return 'every component needs a "component" type name and a string '
            '"id".';
      }

      if (!known.contains(c['component'])) {
        return 'component "${c['component']}" is not in catalog "${catalog.id}".';
      }
    }
    return null;
  }
}
