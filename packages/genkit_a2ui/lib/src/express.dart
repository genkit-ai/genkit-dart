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
/// a2ui_agent owns the A2UI Express prompt contract and compiler. It is a
/// `-wip` package, so its API is kept behind this narrow adapter: if it
/// changes, only this file should need to.
library;

import 'package:a2ui_agent/a2ui_agent.dart';

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

  /// The Express grammar plus the catalog's component and function
  /// signatures, as model-facing prompt text.
  late final String promptSnippet = _processor.promptSnippet;

  /// Compiles one Express block (without its `<a2ui>` tags) into v0.9
  /// envelopes.
  ///
  /// With [validate], the messages are also checked the way a renderer would
  /// check them: every reference resolves, every surface has a `root`, and
  /// nothing is orphaned. Without it only the compiler's own checks run
  /// (syntax, catalog membership, property schemas).
  ///
  /// Throws an `A2uiError` from `a2ui_core` when the block is rejected:
  /// `A2uiParseError` for a syntax error, `A2uiValidationError` for something
  /// the catalog does not allow, `A2uiIntegrityError` for a broken component
  /// graph.
  List<A2uiEnvelope> compile(String block, {bool validate = true}) {
    final messages = validate
        // The processor only takes a whole response, so the block is wrapped
        // back in its tags. Its tag scanner skips string literals, so a
        // `</a2ui>` inside a Text value does not end the block early.
        ? [
            for (final part
                in _processor
                    .parseResponse('<a2ui>\n$block\n</a2ui>')
                    .whereType<A2uiPart>())
              ...part.a2ui,
          ]
        : _format.createParser().compile(block);
    return [for (final m in messages) m.toJson()];
  }
}
