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

import 'catalog_types.dart';
import 'types.dart';

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
    for (final envelope in history) {
      try {
        // History written by a client may leave out the version.
        mirror._state.apply(
          SurfaceMirror._parse([
            {'version': a2uiVersion, ...envelope},
          ]),
        );
      } on A2uiError {
        // Skipped; see above.
      }
    }
    // The renderer already holds all of this, so none of it is judged again:
    // without this, a component an earlier update orphaned would count as new
    // and fail the reachability check of every later update to its surface.
    mirror._state.markChecked(mirror._state.surfaceIds);
    return mirror;
  }
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
    _state.transaction(() {
      final touched = _state.apply(_parse(envelopes));
      // Deleted surfaces are skipped by the tree check.
      if (touched.isNotEmpty) _state.checkTopology(touched);
    });
  }

  static List<AgentToRendererMessage> _parse(List<A2uiEnvelope> envelopes) =>
      AgentToRendererMessage.parseAll([
        for (final e in envelopes) e.cast<String, Object?>(),
      ], protocolVersion: A2uiProtocolVersion.v0_9).messages;
}
