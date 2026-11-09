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

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../version.dart';

/// In-memory git: each package is tagged at its current version, and
/// [commits] holds the commit subjects since that tag, keyed by package name.
class FakeGit implements GitService {
  final Map<String, Package> packages;
  final Map<String, List<String>> commits;

  FakeGit(this.packages, {this.commits = const {}});

  @override
  Future<bool> tagExists(String tagName) async =>
      packages.values.any((p) => tagName == '${p.name}-v${p.version}');

  @override
  Future<String?> getLatestTag(String packageName) async =>
      '$packageName-v${packages[packageName]!.version}';

  @override
  Future<String?> getLatestStableTag(String packageName) async => null;

  @override
  Future<List<String>> getCommitsSince(String? tag, String path) async {
    final name = packages.values.firstWhere((p) => p.path == path).name;
    return commits[name] ?? const [];
  }
}

Package pkg(
  String name,
  String version, {
  List<String> deps = const [],
  List<String> devDeps = const [],
  bool publishToNone = false,
}) => Package(
  name: name,
  path: 'packages/$name',
  version: Version.parse(version),
  publishToNone: publishToNone,
  dependencies: {for (final d in deps) d: 'any'},
  devDependencies: {for (final d in devDeps) d: 'any'},
  pubspecContent: '',
);

Map<String, Version> versions(Map<String, String> m) =>
    m.map((k, v) => MapEntry(k, Version.parse(v)));

/// Plans bumps for [pkgs], returning them as `name -> version string` along
/// with the planner (for floorBumps and warnings).
Future<(Map<String, String>, VersionPlanner)> plan(
  List<Package> pkgs, {
  Map<String, String> floors = const {},
  Map<String, List<String>> commits = const {},
  String? rcTag,
  bool graduate = false,
  bool allowMajor = false,
}) async {
  final packages = {for (final p in pkgs) p.name: p};
  final planner = VersionPlanner(
    Workspace(packages, floors: versions(floors)),
    FakeGit(packages, commits: commits),
    rcTag: rcTag,
    graduate: graduate,
    allowMajor: allowMajor,
  );
  final bumps = await planner.planBumps();
  return (bumps.map((k, v) => MapEntry(k, v.toString())), planner);
}

void main() {
  group('floors', () {
    test('bump a package with no new commits to the floor', () async {
      final (bumps, planner) = await plan(
        [pkg('genkit', '0.17.0')],
        floors: {'genkit': '1.0.0'},
      );
      expect(bumps, {'genkit': '1.0.0'});
      expect(planner.floorBumps, {'genkit'});
    });

    test('bump to the first rc of the floor with --rc', () async {
      final (bumps, _) = await plan(
        [pkg('genkit', '0.17.0')],
        floors: {'genkit': '1.0.0'},
        rcTag: 'rc',
      );
      expect(bumps, {'genkit': '1.0.0-rc.1'});
    });

    test('move a 0.x rc to the first rc of the floor', () async {
      final (bumps, _) = await plan(
        [pkg('genkit', '0.17.0-rc.2')],
        floors: {'genkit': '1.0.0'},
        rcTag: 'rc',
      );
      expect(bumps, {'genkit': '1.0.0-rc.1'});
    });

    test('do nothing once an rc has reached the floor', () async {
      final (bumps, planner) = await plan(
        [pkg('genkit', '1.0.0-rc.1')],
        floors: {'genkit': '1.0.0'},
        commits: {
          'genkit': ['fix(genkit): something'],
        },
        rcTag: 'rc',
      );
      expect(bumps, {'genkit': '1.0.0-rc.2'});
      expect(planner.floorBumps, isEmpty);
    });

    test('graduate floored and unfloored rcs together', () async {
      final (bumps, planner) = await plan(
        [
          pkg('genkit', '1.0.0-rc.2'),
          pkg('genkit_otel', '0.1.1-rc.2', deps: ['genkit']),
        ],
        floors: {'genkit': '1.0.0'},
        graduate: true,
      );
      expect(bumps, {'genkit': '1.0.0', 'genkit_otel': '0.1.1'});
      expect(planner.warnings, isEmpty);
    });

    test(
      'graduate warns about a pending floor and does not apply it',
      () async {
        final (bumps, planner) = await plan(
          [pkg('genkit', '0.17.0')],
          floors: {'genkit': '1.0.0'},
          graduate: true,
        );
        expect(bumps, isEmpty);
        expect(planner.warnings.single, contains('below its floor'));
      },
    );

    test('graduate does not promote a 0.x rc below its floor', () async {
      final (bumps, planner) = await plan(
        [
          pkg('genkit', '0.17.0-rc.1'),
          pkg('genkit_otel', '0.1.1-rc.1', deps: ['genkit']),
          pkg('genkit_openai', '0.5.0-rc.1', deps: ['genkit', 'genkit_otel']),
        ],
        floors: {'genkit': '1.0.0', 'genkit_openai': '1.0.0'},
        graduate: true,
      );
      // genkit_openai is skipped directly and must not be pulled back in by
      // propagation from genkit_otel either.
      expect(bumps, {'genkit_otel': '0.1.1'});
      expect(planner.warnings, hasLength(2));
    });

    test('leave unfloored packages on 0.x rules and propagate', () async {
      final (bumps, _) = await plan(
        [
          pkg('genkit', '0.17.0'),
          pkg('genkit_otel', '0.1.0', deps: ['genkit']),
          pkg('genkit_chrome', '0.1.2', deps: ['genkit']),
        ],
        floors: {'genkit': '1.0.0'},
        commits: {
          // Breaking on 0.x is a minor bump.
          'genkit_chrome': ['feat(genkit_chrome)!: redo things'],
        },
        rcTag: 'rc',
      );
      expect(bumps, {
        'genkit': '1.0.0-rc.1',
        'genkit_chrome': '0.2.0-rc.1',
        'genkit_otel': '0.1.1-rc.1',
      });
    });
  });

  group('major guard', () {
    final commits = {
      'genkit': ['refactor(genkit)!: drop X', 'fix(genkit): y'],
    };

    test('refuse a breaking bump on a >=1.0 package', () async {
      await expectLater(
        plan([pkg('genkit', '1.3.0')], commits: commits),
        throwsA(
          isA<MajorBumpException>().having((e) => e.details, 'details', [
            '  genkit 1.3.0 -> 2.0.0',
            '    refactor(genkit)!: drop X',
          ]),
        ),
      );
    });

    test('allow it with allowMajor', () async {
      final (bumps, _) = await plan(
        [pkg('genkit', '1.3.0')],
        commits: commits,
        allowMajor: true,
      );
      expect(bumps, {'genkit': '2.0.0'});
    });

    test('refuse a breaking rc bump on a >=1.0 package', () async {
      await expectLater(
        plan([pkg('genkit', '1.3.0')], commits: commits, rcTag: 'rc'),
        throwsA(isA<MajorBumpException>()),
      );
    });

    test('not apply to 0.x packages', () async {
      final (bumps, _) = await plan([
        pkg('genkit', '0.17.0'),
      ], commits: commits);
      expect(bumps, {'genkit': '0.18.0'});
    });

    test('not apply to floor bumps', () async {
      final (bumps, _) = await plan(
        [pkg('genkit', '1.3.0')],
        floors: {'genkit': '2.0.0'},
        commits: commits,
      );
      expect(bumps, {'genkit': '2.0.0'});
    });
  });

  group('0.x dependency warning', () {
    test('warn for a regular dependency on a 0.x package', () async {
      final (_, planner) = await plan(
        [
          pkg('genkit', '0.17.0'),
          pkg('genkit_vertex_auth', '0.1.14', deps: ['genkit']),
          pkg(
            'genkit_vertexai',
            '0.3.2',
            deps: ['genkit', 'genkit_vertex_auth'],
          ),
        ],
        floors: {'genkit': '1.0.0', 'genkit_vertexai': '1.0.0'},
      );
      expect(planner.warnings, hasLength(1));
      expect(
        planner.warnings.single,
        startsWith(
          'genkit_vertexai 1.0.0 depends on genkit_vertex_auth 0.1.15',
        ),
      );
    });

    test('ignore dev dependencies and unpublished packages', () async {
      final (_, planner) = await plan(
        [
          pkg('genkit', '0.17.0', devDeps: ['genkit_otel']),
          pkg('genkit_otel', '0.1.0'),
          pkg('_schema_generator', '0.0.0', publishToNone: true),
          pkg('genkit_mcp', '0.4.0', deps: ['genkit', '_schema_generator']),
        ],
        floors: {'genkit': '1.0.0', 'genkit_mcp': '1.0.0'},
      );
      expect(planner.warnings, isEmpty);
    });
  });

  group('Workspace floors validation', () {
    Workspace workspace(Map<String, String> floors) => Workspace({
      'genkit': pkg('genkit', '0.17.0'),
      'basic_sample': pkg('basic_sample', '0.0.0', publishToNone: true),
    }, floors: versions(floors));

    test('reject an unknown package', () {
      expect(
        () => workspace({'genkt': '1.0.0'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('unknown package "genkt"'),
          ),
        ),
      );
    });

    test('reject an unpublished package', () {
      expect(
        () => workspace({'basic_sample': '1.0.0'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('reject a pre-release floor', () {
      expect(
        () => workspace({'genkit': '1.0.0-rc.1'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
