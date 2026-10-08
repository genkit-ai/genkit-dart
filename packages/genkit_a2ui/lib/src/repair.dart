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
/// Rather than resending the conversation, the middleware sends a small prompt
/// holding the error, the Express contract with the catalog's signatures, and
/// the failed block. Exactly one attempt is made. A repair that does not
/// compile is discarded and the caller falls back to its normal failure
/// handling, so a bad repair is never worse than no repair.
library;

import 'catalog_types.dart';
import 'express.dart';

/// Builds the repair prompt for a failed block.
///
/// Carries the full Express contract rather than just the signatures of the
/// components the block mentions: picking those out would need an Express
/// tokenizer, and a2ui_agent does not export one. The contract is the same
/// text the turn was prompted with, so it costs tokens but no surprises.
String buildRepairPrompt({
  required String source,
  required String error,
  required A2uiCatalog catalog,
}) =>
    '''
${ExpressEngine.of(catalog).promptSnippet}

# Fix this block

The following A2UI Express block failed to compile.

Error: $error

<a2ui>
$source
</a2ui>

Fix the error and return ONLY the corrected block, wrapped in <a2ui> tags.
Keep its surface(...) line unchanged. Do not explain the change.''';

/// Extracts the Express source from a repair reply, tolerating a model that
/// omits the tags or wraps the block in a Markdown fence.
String? extractRepairedBlock(String reply) {
  // Matched case-insensitively, like the streaming parser's tags: a model that
  // answers with `<A2UI>` has still produced a usable repair, and discarding it
  // over casing would waste the call.
  final lower = reply.toLowerCase();
  final open = lower.indexOf('<a2ui>');
  if (open >= 0) {
    final start = open + '<a2ui>'.length;
    final close = lower.indexOf('</a2ui>', start);
    // Opened but never closed: take the rest, the compiler will judge it.
    return _stripFence(reply.substring(start, close < 0 ? null : close));
  }
  return _stripFence(reply);
}

final _fenceRe = RegExp(r'```[a-zA-Z0-9_-]*\r?\n([\s\S]*?)```');

String? _stripFence(String text) {
  final inner = _fenceRe.firstMatch(text)?.group(1) ?? text;
  final trimmed = inner.trim();
  return trimmed.isEmpty ? null : trimmed;
}
