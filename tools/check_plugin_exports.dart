// Copyright 2026 Google LLC
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

/// Fails when two plugin packages export different declarations under the
/// same public name.
///
/// Apps commonly import several plugins at once (say, `genkit_anthropic` and
/// `genkit_google_genai`), and two plugins exporting e.g. `ThinkingConfig`
/// make every use of that name an ambiguous-import error. The analyzer only
/// reports that at a use site, so analyzing the packages or a sample app
/// doesn't catch it; this compares the export namespaces directly.
///
/// Re-exports are fine: `genkit_vertexai` showing `genkit_google_genai`'s
/// types exports the same declarations, not new ones with the same name.
///
/// Usage: `dart run tools/check_plugin_exports.dart` from the repo root.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

/// Packages whose overlap is known and accepted. `genkit_firebase_ai` is a
/// client-side (Flutter) plugin that deliberately mirrors `genkit_google_genai`
/// names, and the two aren't meant to be used together.
const _excludedPackages = {'genkit_firebase_ai'};

Future<void> main() async {
  final packagesDir = Directory('packages');
  final barrels = <String, List<String>>{}; // package -> top-level libraries
  for (final dir in packagesDir.listSync().whereType<Directory>()) {
    final name = p.basename(dir.path);
    if (!name.startsWith('genkit_') || _excludedPackages.contains(name)) {
      continue;
    }
    final lib = Directory(p.join(dir.path, 'lib'));
    if (!lib.existsSync()) continue;
    barrels[name] = [
      for (final f in lib.listSync().whereType<File>())
        if (f.path.endsWith('.dart')) p.normalize(f.absolute.path),
    ];
  }

  final collection = AnalysisContextCollection(
    includedPaths: [for (final files in barrels.values) ...files],
  );

  // name -> declaring element -> packages exporting it
  final exporters = <String, Map<Element, Set<String>>>{};
  for (final MapEntry(key: package, value: files) in barrels.entries) {
    for (final file in files) {
      final session = collection.contextFor(file).currentSession;
      final result = await session.getResolvedLibrary(file);
      if (result is! ResolvedLibraryResult) {
        stderr.writeln('Could not resolve $file: $result');
        exitCode = 1;
        return;
      }
      final namespace = result.element.exportNamespace.definedNames2;
      for (final MapEntry(key: name, value: element) in namespace.entries) {
        // Setters share a name with their getter; one entry is enough.
        if (name.endsWith('=')) continue;
        final declaration = element.baseElement;
        exporters.putIfAbsent(name, () => {})[declaration] ??= {};
        exporters[name]![declaration]!.add(package);
      }
    }
  }

  final collisions = {
    for (final MapEntry(key: name, value: byElement) in exporters.entries)
      if (byElement.length > 1) name: byElement,
  };
  if (collisions.isEmpty) {
    print('No conflicting exports across ${barrels.length} plugin packages.');
    return;
  }

  stderr.writeln(
    'Plugin packages export different declarations under the '
    'same name. Prefix them with the provider name (e.g. GeminiX, '
    'AnthropicX):',
  );
  for (final MapEntry(key: name, value: byElement) in collisions.entries) {
    final where = byElement.entries
        .map((e) => '${e.value.join(', ')} (${e.key.library?.uri})')
        .join('; ');
    stderr.writeln('  $name: $where');
  }
  exitCode = 1;
}
