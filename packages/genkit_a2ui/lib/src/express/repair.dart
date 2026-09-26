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

/// Asks the model to fix an Express block that failed to compile.
///
/// The spec calls this a "micro-refinement loop": rather than resending the
/// conversation, send a small prompt holding the error, the signatures of the
/// components involved, and the failed block. Because it is short and targeted
/// it is fast and cheap relative to the turn that produced it.
///
/// Exactly one attempt is made. A repair that does not compile is discarded and
/// the caller falls back to its normal failure handling, so a bad repair can
/// never be worse than no repair.
library;

import '../catalog_types.dart';
import 'lexer.dart';

/// Builds the repair prompt for a failed block.
///
/// Only the signatures of components the block actually mentions are included:
/// the full catalog would swamp a prompt whose value is being small and
/// specific.
String buildRepairPrompt({
  required String source,
  required String error,
  required A2uiCatalog catalog,
}) {
  final mentioned = _mentionedComponents(source, catalog);
  final signatures = mentioned
      .map((c) => '- ${c.signature.render()}')
      .join('\n');

  return '''
The following A2UI Express block failed to compile.

Error: $error

${signatures.isEmpty ? '' : 'Signatures of the components it uses:\n$signatures\n'}
<a2ui>
$source
</a2ui>

Fix the error and return ONLY the corrected block, wrapped in <a2ui> tags.
Do not explain the change.''';
}

/// The catalog components named in [source], in catalog order.
///
/// Matched by tokenizing rather than substring search, so a component name
/// appearing inside a string literal does not count.
List<A2uiCatalogComponent> _mentionedComponents(
  String source,
  A2uiCatalog catalog,
) {
  final names = <String>{};
  try {
    for (final token in tokenize(source)) {
      if (token.kind == TokenKind.identifier) {
        final value = token.value;
        if (value is String && catalog.components.containsKey(value)) {
          names.add(value);
        }
      }
    }
  } on ExpressSyntaxError {
    // The block may not tokenize at all - that can be the very failure being
    // repaired. Fall back to no signatures rather than giving up on the repair.
    return const [];
  }

  return [
    for (final entry in catalog.components.entries)
      if (names.contains(entry.key)) entry.value,
  ];
}

/// Extracts the Express source from a repair reply, tolerating a model that
/// omits the sentinel tags or wraps the block in a Markdown fence.
String? extractRepairedBlock(String reply) {
  // Matched case-insensitively, like the streaming parser's tags: a model that
  // answers with `<A2UI>` has still produced a usable repair, and discarding it
  // over casing would waste the call.
  final lower = reply.toLowerCase();
  final open = lower.indexOf('<a2ui>');
  if (open >= 0) {
    final close = lower.indexOf('</a2ui>', open);
    if (close > open) {
      return reply.substring(open + '<a2ui>'.length, close).trim();
    }
    // Opened but never closed: take the rest, the compiler will judge it.
    return reply.substring(open + '<a2ui>'.length).trim();
  }

  // No tags at all. Strip a Markdown fence if present, otherwise take the reply
  // whole and let the compiler decide.
  final fence = RegExp(r'```[a-zA-Z0-9_-]*\r?\n([\s\S]*?)```');
  final match = fence.firstMatch(reply);
  if (match != null) return match.group(1)?.trim();

  final trimmed = reply.trim();
  return trimmed.isEmpty ? null : trimmed;
}
