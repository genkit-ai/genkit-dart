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

/// Public API surface snapshot and export-closure checks.
///
/// Compares the public API surface of `package:genkit` against `api.txt` using
/// `package:api_summary`, and verifies `@experimental` and per-library type
/// availability invariants.
///
/// To accept an intentional API change, regenerate `api.txt`:
///
/// ```sh
/// dart run api_summary --write
/// ```
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:api_summary/api_summary.dart';
import 'package:test/test.dart';

/// For each library, the libraries it is documented to be used together with.
/// A type is "available" to callers if any of them exports it.
const _companions = {
  'genkit': <String>[],
  'client': <String>[],
  'plugin': <String>[],
  'telemetry': <String>[],
  // `io.dart` serves actions defined with `genkit.dart`.
  'io': ['genkit'],
  // `lite.dart` is used with a model plugin and, for models/middleware,
  // `genkit.dart` (see the package README).
  'lite': ['genkit'],
  'experimental': ['genkit'],
  'experimental_client': ['client'],
  'experimental_io': ['experimental', 'genkit', 'io'],
};

void main() {
  late final ApiSummary summary;
  late final Map<String, ApiLibrary> librariesByName;

  setUpAll(() async {
    summary = await apiSummary(Directory.current.path);
    librariesByName = {
      for (final lib in summary.libraries)
        if (lib.isPublicEntryPoint)
          Uri.parse(lib.uri).pathSegments.last.replaceAll('.dart', ''): lib,
    };
  });

  test('public API matches api.txt', expectApiSummaryClean);

  test('stable libraries do not export @experimental declarations', () {
    final leaks = <String>[];
    for (final entry in librariesByName.entries) {
      final library = entry.value;
      if (_isExperimental(library.facets)) continue;
      for (final decl in _declarations(library)) {
        if (_isExperimental(decl.facets)) {
          leaks.add('${entry.key}.dart: ${decl.name}');
        }
      }
    }
    expect(leaks, isEmpty);
  });

  // A public signature that mentions a type the library does not export
  // forces callers to import `src/` (or leaves them unable to name the type
  // at all, e.g. to store a returned value in a typed field).
  test('public signatures only use types the library makes available', () {
    expect(
      librariesByName.keys.toSet(),
      equals(_companions.keys.toSet()),
      reason: 'Every public library under lib/ must be listed in _companions.',
    );

    final gaps = <String>[];
    for (final MapEntry(key: name, value: companions) in _companions.entries) {
      final available = {
        for (final libName in [name, ...companions])
          for (final decl in _declarations(librariesByName[libName]!))
            '${decl.locationUri}#${decl.name}',
      };
      for (final decl in _declarations(librariesByName[name]!)) {
        for (final used in _referencedTypes(decl)) {
          if (!available.contains('${used.libraryUri}#${used.name}')) {
            gaps.add('$name.dart: ${decl.name} references ${used.name}');
          }
        }
      }
    }
    expect(gaps.toSet(), isEmpty);
  });
}

bool _isExperimental(Iterable<ApiFacet> facets) => facets
    .whereType<MetaContractFacet>()
    .any((f) => f.contracts.contains(MetaContract.experimental));

Iterable<ApiDeclaration> _declarations(ApiLibrary library) => [
  ...library.classes,
  ...library.enums,
  ...library.mixins,
  ...library.extensions,
  ...library.extensionTypes,
  ...library.functions,
  ...library.typeAliases,
];

/// Public `package:genkit` declarations mentioned in the public signatures of
/// [decl] (supertypes, members, parameters, return types, aliased types).
/// Members annotated `@experimental` are skipped: their types live in the
/// experimental libraries by design.
Iterable<ApiInterfaceType> _referencedTypes(ApiDeclaration decl) {
  final found = <ApiInterfaceType>[];

  void visitType(ApiType? type) {
    switch (type) {
      case null:
      case ApiDynamicType():
      case ApiVoidType():
      case ApiTypeParameterType():
        break;
      case ApiInterfaceType():
        found.add(type);
        type.typeArguments.forEach(visitType);
      case ApiFunctionType():
        type.typeParameters.values.forEach(visitType);
        visitType(type.returnType);
        for (final p in type.parameters) {
          visitType(p.type);
        }
      case ApiRecordType():
        type.positionalFields.forEach(visitType);
        for (final f in type.namedFields) {
          visitType(f.type);
        }
    }
  }

  void visitBounds(Map<String, ApiType?> typeParameters) {
    typeParameters.values.forEach(visitType);
  }

  void visitExecutable(ApiExecutable e) {
    if (_isExperimental(e.facets)) return;
    visitBounds(e.typeParameters);
    visitType(e.returnType);
    for (final p in e.parameters) {
      visitType(p.type);
    }
  }

  switch (decl) {
    case ApiClass():
      visitBounds(decl.typeParameters);
      visitType(decl.supertype);
      decl.interfaces.forEach(visitType);
      decl.mixins.forEach(visitType);
      decl.superclassConstraints.forEach(visitType);
      decl.constructors.forEach(visitExecutable);
      decl.methods.forEach(visitExecutable);
    case ApiExtension():
      visitBounds(decl.typeParameters);
      visitType(decl.extendedType);
      decl.methods.forEach(visitExecutable);
    case ApiExtensionType():
      visitBounds(decl.typeParameters);
      visitType(decl.representationType);
      decl.interfaces.forEach(visitType);
      decl.constructors.forEach(visitExecutable);
      decl.methods.forEach(visitExecutable);
    case ApiExecutable():
      visitExecutable(decl);
    case ApiTypeAlias():
      visitBounds(decl.typeParameters);
      visitType(decl.aliasedType);
  }

  return found.where(
    (t) => t.libraryUri != null && t.libraryUri!.startsWith('package:genkit/'),
  );
}
