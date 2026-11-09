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

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../check_plugin_exports.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('plugin_exports'));
  tearDown(() => root.deleteSync(recursive: true));

  /// Writes a fixture package. Cross-package imports use relative paths, so
  /// no package config is needed to resolve them.
  void package(
    String name,
    Map<String, String> libFiles, {
    bool private = false,
  }) {
    final dir = Directory(p.join(root.path, name))..createSync();
    File(
      p.join(dir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: $name\n${private ? 'publish_to: none\n' : ''}');
    for (final MapEntry(key: path, value: content) in libFiles.entries) {
      File(p.join(dir.path, 'lib', path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  }

  Future<Exporters> check({List<Set<String>> accepted = const []}) async {
    final exporters = await collectExports(discoverBarrels(root));
    return findCollisions(exporters, accepted: accepted);
  }

  test('flags different declarations under the same name', () async {
    package('pkg_a', {'pkg_a.dart': 'class ThinkingConfig {}'});
    package('pkg_b', {'pkg_b.dart': 'class ThinkingConfig {}'});

    final collisions = await check();

    expect(collisions.keys, ['ThinkingConfig']);
    expect(collisions['ThinkingConfig']!.values, [
      {'pkg_a'},
      {'pkg_b'},
    ]);
  });

  test('allows re-exports of the same declaration', () async {
    package('pkg_a', {
      'pkg_a.dart': "export 'src/model.dart';",
      'src/model.dart': 'class ThinkingConfig {}',
    });
    package('pkg_b', {
      'pkg_b.dart': "export '../../pkg_a/lib/src/model.dart';",
    });

    expect(await check(), isEmpty);
  });

  test('ignores accepted pairs but still checks other packages', () async {
    package('pkg_a', {'pkg_a.dart': 'class ThinkingConfig {}'});
    package('pkg_b', {'pkg_b.dart': 'class ThinkingConfig {}'});
    package('pkg_c', {'pkg_c.dart': 'class Other {}'});

    expect(
      await check(
        accepted: [
          {'pkg_a', 'pkg_b'},
        ],
      ),
      isEmpty,
    );

    package('pkg_d', {'pkg_d.dart': 'class ThinkingConfig {}'});
    final collisions = await check(
      accepted: [
        {'pkg_a', 'pkg_b'},
      ],
    );
    expect(collisions.keys, ['ThinkingConfig']);
  });

  test('skips part files in lib/', () async {
    package('pkg_a', {
      'pkg_a.dart': "part 'pkg_a.g.dart';\nclass A {}",
      'pkg_a.g.dart': "part of 'pkg_a.dart';\nclass B {}",
    });

    final exporters = await collectExports(discoverBarrels(root));

    expect(exporters.keys, containsAll(['A', 'B']));
  });

  test('skips packages with publish_to: none', () async {
    package('pkg_a', {'pkg_a.dart': 'class ThinkingConfig {}'});
    package('pkg_b', {'pkg_b.dart': 'class ThinkingConfig {}'}, private: true);

    expect(discoverBarrels(root).keys, ['pkg_a']);
    expect(await check(), isEmpty);
  });
}
