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

/// The one place this package talks to `a2ui_agent`.
///
/// a2ui_agent owns the A2UI Express prompt contract and compiler. It is
/// pre-1.0 and still makes breaking changes, so its API is kept behind this
/// narrow adapter: if it changes, only this file should need to.
library;

import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart'
    show A2uiError, A2uiProtocolVersion, AgentToRendererMessage;
import 'package:logging/logging.dart';

import 'catalog_types.dart';
import 'types.dart';

final _logger = Logger('genkit_a2ui.express');

/// Prompts for and compiles A2UI Express against one catalog.
final class ExpressEngine {
  ExpressEngine._(A2uiCatalog catalog)
    : _processor = A2uiRequestProcessor(
        activeCatalogs: [catalog.toCore()],
        formatFactory: const ExpressFormatFactory(),
      ),
      _format = const ExpressFormatFactory().createFormat([catalog.toCore()]);

  /// The engine for [catalog], created once per catalog instance.
  factory ExpressEngine.of(A2uiCatalog catalog) =>
      _engines[catalog] ??= ExpressEngine._(catalog);

  static final _engines = Expando<ExpressEngine>();

  final A2uiRequestProcessor _processor;
  final InferenceFormat _format;

  /// Reused across blocks: setting a parser up costs more than compiling a
  /// typical block.
  late final _parser = _format.createParser();

  /// The Express grammar plus the catalog's component and function
  /// signatures, as model-facing prompt text.
  late final String promptSnippet = _processor.promptSnippet;

  /// Compiles one Express block (without its `<a2ui>` tags) into v0.9
  /// envelopes, running only the compiler's own checks (syntax, catalog
  /// membership, property schemas). [SurfaceMirror.apply] checks the result
  /// the way a renderer would.
  ///
  /// Throws an `A2uiError` from `a2ui_core` when the block is rejected:
  /// `A2uiParseError` for a syntax error, `A2uiValidationError` for something
  /// the catalog does not allow.
  List<A2uiEnvelope> compile(String block) => [
    for (final m in _parser.compile(block)) m.toJson(),
  ];

  /// A mirror of the surfaces a renderer holds after receiving [history].
  ///
  /// History is applied message by message and a message the mirror rejects
  /// is skipped, so one bad message from an earlier turn (or from before this
  /// package compiled Express) does not hide the surfaces that did render.
  SurfaceMirror mirror(Iterable<A2uiEnvelope> history) {
    final mirror = SurfaceMirror._(_processor.createState());
    var skipped = 0;
    Object? firstError;
    for (final envelope in _liveHistory(history)) {
      try {
        // History written by a client may leave out the version.
        mirror._state.apply(
          SurfaceMirror._parse([
            {'version': a2uiVersion, ...envelope},
          ]),
        );
      } on A2uiError catch (e) {
        // Skipped; see above.
        skipped++;
        firstError ??= e.message;
      }
    }
    if (skipped > 0) {
      _logger.fine(
        'A2UI: skipped $skipped history message(s) the mirror rejected, '
        'first: $firstError. Updates to their surfaces may be rejected.',
      );
    }
    // The renderer already holds all of this, so none of it is judged again:
    // without this, a component an earlier update orphaned would count as new
    // and fail the reachability check of every later update to its surface.
    mirror._state.markChecked(mirror._state.surfaceIds);
    return mirror;
  }
}

/// The messages of [history] that still shape a live surface, in order.
///
/// A long conversation re-renders and deletes surfaces many times; replaying
/// all of it on every model call would cost time in proportion to the
/// conversation. This keeps, per surface, only what follows its last creation,
/// and drops surfaces that ended deleted. It follows the renderer's rules: a
/// `createSurface` for a surface that is already live is rejected there, so it
/// is ignored here too, and the updates after it still apply to the old tree.
List<A2uiEnvelope> _liveHistory(Iterable<A2uiEnvelope> history) {
  final live = <String, List<(int, A2uiEnvelope)>>{};
  for (final (i, e) in history.indexed) {
    switch (e) {
      case {'createSurface': {'surfaceId': final String id}}:
        if (!live.containsKey(id)) live[id] = [(i, e)];
      case {'deleteSurface': {'surfaceId': final String id}}:
        live.remove(id);
      case {'updateComponents': {'surfaceId': final String id}} ||
          {'updateDataModel': {'surfaceId': final String id}}:
        live[id]?.add((i, e));
    }
  }
  final kept = [for (final l in live.values) ...l]
    ..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, e) in kept) e];
}

/// The agent-side mirror of a renderer's surfaces, which messages are checked
/// against before they are sent.
///
/// Built from the conversation's history, so a block can update a surface an
/// earlier turn rendered (a block without `root` targets an existing surface),
/// and a component reference resolves against what the renderer already holds.
final class SurfaceMirror {
  SurfaceMirror._(this._state);

  final RendererState _state;

  /// Applies [envelopes] as one unit, checking them the way a renderer would:
  /// every update targets a live surface, every reference resolves, every
  /// touched surface has a `root`, and nothing new is orphaned.
  ///
  /// Throws an `A2uiError` (typically `A2uiValidationError` or
  /// `A2uiIntegrityError`) and leaves the mirror unchanged if any check fails.
  void apply(List<A2uiEnvelope> envelopes) {
    if (envelopes.isEmpty) return;
    // Only a surface whose components changed needs its tree checked; a
    // data-only update cannot break it (and should not be blamed for a tree
    // that history left incomplete).
    final reshaped = {
      for (final e in envelopes)
        if (e
            case {'createSurface': {'surfaceId': final String id}} ||
                {'updateComponents': {'surfaceId': final String id}})
          id,
    };
    _state.transaction(() {
      _state.apply(_parse(envelopes));
      // Deleted surfaces are skipped by the tree check.
      if (reshaped.isNotEmpty) _state.checkTopology(reshaped);
    });
  }

  static List<AgentToRendererMessage> _parse(List<A2uiEnvelope> envelopes) =>
      AgentToRendererMessage.parseAll([
        for (final e in envelopes) e.cast<String, Object?>(),
      ], protocolVersion: A2uiProtocolVersion.v0_9).messages;
}
