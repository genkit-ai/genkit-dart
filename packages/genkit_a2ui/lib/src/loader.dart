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

/// Catalog loading helpers.
///
/// The `a2ui()` middleware references catalogs by id and looks them up in the
/// Genkit registry (value type [a2uiCatalogValueType]). [loadCatalog] registers
/// a catalog under an id so the middleware can find it. Provide the catalog
/// inline, or load it from a JSON file.
///
/// The `file` variant uses `dart:io`, so it is server-only (it is exported from
/// the main `package:genkit_a2ui/a2ui.dart` entry, not the client entry).
library;

import 'dart:convert';
import 'dart:io';

import 'package:genkit/plugin.dart';

import 'catalog.dart';

/// Registers an A2UI catalog under an [id] so the `a2ui()` middleware can look
/// it up (via `a2ui(catalog: id)`). Provide either [catalog] or [file].
///
/// Returns the registered catalog (with its `id` set to the catalog's own id if
/// present, otherwise the given [id]).
Future<A2uiCatalog> loadCatalog(
  Registry registry, {
  required String id,
  A2uiCatalog? catalog,
  String? file,
}) async {
  if (id.isEmpty) {
    throw ArgumentError('loadCatalog(): `id` is required.');
  }

  A2uiCatalog resolved;
  if (file != null) {
    resolved = await _readCatalogFile(file);
  } else if (catalog != null) {
    resolved = catalog;
  } else {
    throw ArgumentError('loadCatalog(): provide either `catalog` or `file`.');
  }

  // Register under the requested id. Keep the catalog's own `id` (used as the
  // `catalogId` on surfaces) intact if present; otherwise default it to the id.
  final registered = A2uiCatalog(
    id: resolved.id.isNotEmpty ? resolved.id : id,
    components: resolved.components,
  );
  registry.registerValue(a2uiCatalogValueType, id, registered);
  return registered;
}

/// Reads and parses a catalog from a JSON file.
Future<A2uiCatalog> _readCatalogFile(String file) async {
  String raw;
  try {
    raw = await File(file).readAsString();
  } catch (e) {
    throw StateError('loadCatalog(): failed to read catalog file "$file": $e');
  }
  try {
    final json = jsonDecode(raw);
    return A2uiCatalog.fromJson((json as Map).cast<String, dynamic>());
  } catch (e) {
    throw StateError(
      'loadCatalog(): catalog file "$file" is not valid JSON: $e',
    );
  }
}

/// Resolves a catalog by id from the registry, falling back to the bundled
/// [basicCatalog] for the default id. Used by the `a2ui()` middleware.
A2uiCatalog resolveCatalog(Registry registry, String id) {
  final found = registry.lookupValue<A2uiCatalog>(a2uiCatalogValueType, id);
  if (found != null) return found;
  if (id == defaultCatalogId) return basicCatalog;
  throw StateError(
    'a2ui(): no catalog registered under id "$id". '
    'Register one with loadCatalog(registry, id: "$id", catalog: ...) or use '
    'the default "$defaultCatalogId" catalog.',
  );
}
