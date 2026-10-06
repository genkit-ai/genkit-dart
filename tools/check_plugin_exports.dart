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

/// Fails when two published packages export different declarations under the
/// same public name.
///
/// Apps commonly import core `genkit` plus several plugins at once (say,
/// `genkit_anthropic` and `genkit_google_genai`), and two packages exporting
/// e.g. `ThinkingConfig` make every use of that name an ambiguous-import
/// error. The analyzer only reports that at a use site, so analyzing the
/// packages or a sample app doesn't catch it; this compares the export
/// namespaces directly.
///
/// Re-exports are fine: `genkit_vertexai` showing `genkit_google_genai`'s
/// types exports the same declarations, not new ones with the same name.
///
/// Runs in Flutter CI because `genkit_firebase_ai` only resolves with Flutter.
///
/// Usage: `dart run tools/check_plugin_exports.dart` from the repo root.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Package pairs whose overlap is known and accepted. `genkit_firebase_ai` is
/// a client-side (Flutter) plugin that deliberately mirrors
/// `genkit_google_genai` names, and the two aren't meant to be used together.
/// Its exports are still checked against every other package.
const acceptedOverlaps = [
  {'genkit_firebase_ai', 'genkit_google_genai'},
  {'genkit_firebase_ai', 'genkit_vertexai'},
];

/// Exported name -> declaring library URI -> packages exporting it.
///
/// Declarations are keyed by library URI rather than `Element` identity so a
/// re-export still matches when packages resolve in different analysis
/// contexts (Flutter packages sit outside the pub workspace).
typedef Exporters = Map<String, Map<String, Set<String>>>;

class UnresolvedLibraryException implements Exception {
  final String path;
  final SomeResolvedLibraryResult result;

  UnresolvedLibraryException(this.path, this.result);

  @override
  String toString() => 'Could not resolve $path: $result';
}

Future<void> main() async {
  final barrels = discoverBarrels(Directory('packages'));
  final Exporters exporters;
  try {
    exporters = await collectExports(barrels);
  } on UnresolvedLibraryException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
    return;
  }

  // An empty namespace means the scan itself is broken (e.g. an analyzer API
  // change), not that there are no collisions.
  if (exporters.isEmpty) {
    stderr.writeln('No exported names found in ${barrels.length} packages.');
    exitCode = 1;
    return;
  }

  final collisions = findCollisions(exporters, accepted: acceptedOverlaps);
  if (collisions.isEmpty) {
    print(
      'No conflicting exports across ${barrels.length} packages '
      '(${exporters.length} names).',
    );
    return;
  }

  stderr.writeln(
    'Packages export different declarations under the same name. '
    'Prefix them with the provider name (e.g. GeminiX, AnthropicX):',
  );
  for (final MapEntry(key: name, value: byLibrary) in collisions.entries) {
    final where = byLibrary.entries
        .map((e) => '${e.value.join(', ')} (${e.key})')
        .join('; ');
    stderr.writeln('  $name: $where');
  }
  exitCode = 1;
}

/// Returns `package name -> top-level lib/*.dart files` for every package
/// under [packagesDir] that is published.
///
/// Uses the same rule as `melos list --no-private` (skip `publish_to: none`),
/// but reads pubspecs directly: melos only lists workspace members, which
/// would drop the Flutter packages.
Map<String, List<String>> discoverBarrels(Directory packagesDir) {
  final barrels = <String, List<String>>{};
  final dirs = packagesDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final dir in dirs) {
    final pubspecFile = File(p.join(dir.path, 'pubspec.yaml'));
    final lib = Directory(p.join(dir.path, 'lib'));
    if (!pubspecFile.existsSync() || !lib.existsSync()) continue;
    final pubspec = loadYaml(pubspecFile.readAsStringSync());
    if (pubspec is! YamlMap || pubspec['publish_to'] == 'none') continue;
    final name = pubspec['name'];
    if (name is! String) continue;
    barrels[name] = [
      for (final f in lib.listSync().whereType<File>())
        if (f.path.endsWith('.dart')) p.normalize(f.absolute.path),
    ]..sort();
  }
  return barrels;
}

/// Resolves every file in [barrels] and records who exports what.
///
/// Part files are skipped (their library is listed separately). Throws an
/// [UnresolvedLibraryException] for any other file that doesn't resolve.
Future<Exporters> collectExports(Map<String, List<String>> barrels) async {
  final collection = AnalysisContextCollection(
    includedPaths: [for (final files in barrels.values) ...files],
  );
  final exporters = <String, Map<String, Set<String>>>{};
  for (final MapEntry(key: package, value: files) in barrels.entries) {
    for (final file in files) {
      final session = collection.contextFor(file).currentSession;
      final result = await session.getResolvedLibrary(file);
      if (result is NotLibraryButPartResult) continue;
      if (result is! ResolvedLibraryResult) {
        throw UnresolvedLibraryException(file, result);
      }
      final namespace = result.element.exportNamespace.definedNames2;
      for (final MapEntry(key: name, value: element) in namespace.entries) {
        // Setters share a name with their getter; one entry is enough.
        if (name.endsWith('=')) continue;
        final library = element.baseElement.library?.uri.toString() ?? '?';
        exporters
            .putIfAbsent(name, () => {})
            .putIfAbsent(library, () => {})
            .add(package);
      }
    }
  }
  return exporters;
}

/// Returns the entries of [exporters] where two packages export different
/// declarations under one name, ignoring package pairs listed in [accepted].
Exporters findCollisions(
  Exporters exporters, {
  List<Set<String>> accepted = const [],
}) {
  bool isAccepted(String a, String b) =>
      accepted.any((pair) => pair.contains(a) && pair.contains(b));

  bool clashes(Map<String, Set<String>> byLibrary) {
    final groups = byLibrary.values.toList();
    for (var i = 0; i < groups.length; i++) {
      for (var j = i + 1; j < groups.length; j++) {
        for (final a in groups[i]) {
          for (final b in groups[j]) {
            if (a != b && !isAccepted(a, b)) return true;
          }
        }
      }
    }
    return false;
  }

  return {
    for (final MapEntry(key: name, value: byLibrary) in exporters.entries)
      if (byLibrary.length > 1 && clashes(byLibrary)) name: byLibrary,
  };
}
