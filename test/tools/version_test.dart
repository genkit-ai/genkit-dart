import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../../tools/version.dart';

class MockGitService implements GitService {
  final Map<String, String?> latestTags = {};
  final Map<String, List<String>> commits = {};

  @override
  Future<String?> getLatestTag(String packageName) async {
    return latestTags[packageName];
  }

  @override
  Future<List<String>> getCommitsSince(String? tag, String path) async {
    return commits[path] ?? [];
  }
}

void main() {
  group('ConventionalCommit parsing', () {
    test('parses feat correctly', () {
      final commit = ConventionalCommit.parse('feat: add cool feature');
      expect(commit.type, 'feat');
      expect(commit.isBreaking, false);
      expect(commit.bumpType, BumpType.minor);
    });

    test('parses fix correctly', () {
      final commit = ConventionalCommit.parse('fix: solve a problem');
      expect(commit.type, 'fix');
      expect(commit.isBreaking, false);
      expect(commit.bumpType, BumpType.patch);
    });

    test('parses breaking change correctly', () {
      final commit1 = ConventionalCommit.parse('feat!: massive change');
      expect(commit1.isBreaking, true);
      expect(commit1.bumpType, BumpType.major);

      final commit2 = ConventionalCommit.parse('chore: stuff\\n\\nBREAKING CHANGE: broke everything');
      expect(commit2.isBreaking, true);
      expect(commit2.bumpType, BumpType.major);
    });
  });

  group('VersionPlanner', () {
    late MockGitService mockGit;

    setUp(() {
      mockGit = MockGitService();
    });

    Workspace createWorkspace({
      required Version pkgA_version,
      required Version pkgB_version,
    }) {
      final pkgA = Package(
        name: 'pkgA',
        path: 'pkgA_path',
        version: pkgA_version,
        publishToNone: false,
        dependencies: {},
        devDependencies: {},
        pubspecContent: '',
      );
      final pkgB = Package(
        name: 'pkgB',
        path: 'pkgB_path',
        version: pkgB_version,
        publishToNone: false,
        dependencies: {'pkgA': 'any'},
        devDependencies: {},
        pubspecContent: '',
      );
      return Workspace({'pkgA': pkgA, 'pkgB': pkgB});
    }

    test('bumps minor for feat on >1.0.0', () async {
      final ws = createWorkspace(pkgA_version: Version(1, 0, 0), pkgB_version: Version(1, 0, 0));
      mockGit.commits['pkgA_path'] = ['feat: new stuff'];
      final planner = VersionPlanner(ws, mockGit);
      final bumps = await planner.planBumps();

      expect(bumps['pkgA'].toString(), '1.1.0');
      // pkgB depends on pkgA, gets patch bump implicitly
      expect(bumps['pkgB'].toString(), '1.0.1');
    });

    test('bumps patch for feat on 0.x.y', () async {
      final ws = createWorkspace(pkgA_version: Version(0, 1, 0), pkgB_version: Version(0, 1, 0));
      mockGit.commits['pkgA_path'] = ['feat: new stuff'];
      final planner = VersionPlanner(ws, mockGit);
      final bumps = await planner.planBumps();

      expect(bumps['pkgA'].toString(), '0.1.1');
      expect(bumps['pkgB'].toString(), '0.1.1');
    });

    test('applies RC bump logic correctly', () async {
      final ws = createWorkspace(pkgA_version: Version(1, 0, 0), pkgB_version: Version(1, 0, 0));
      mockGit.commits['pkgA_path'] = ['feat: beta stuff'];
      final planner = VersionPlanner(ws, mockGit, rcTag: 'beta');
      final bumps = await planner.planBumps();

      expect(bumps['pkgA'].toString(), '1.1.0-beta.1');
      expect(bumps['pkgB'].toString(), '1.0.1-beta.1');
    });

    test('increments existing RC tag', () async {
      final ws = createWorkspace(pkgA_version: Version.parse('1.1.0-beta.1'), pkgB_version: Version.parse('1.0.1-beta.1'));
      mockGit.commits['pkgA_path'] = ['fix: beta bug'];
      final planner = VersionPlanner(ws, mockGit, rcTag: 'beta');
      final bumps = await planner.planBumps();

      expect(bumps['pkgA'].toString(), '1.1.0-beta.2');
      expect(bumps['pkgB'].toString(), '1.0.1-beta.2');
    });

    test('graduates RC version', () async {
      final ws = createWorkspace(pkgA_version: Version.parse('1.1.0-beta.2'), pkgB_version: Version.parse('1.0.1-beta.2'));
      // Even without commits, graduate should drop the -beta
      final planner = VersionPlanner(ws, mockGit, graduate: true);
      final bumps = await planner.planBumps();

      expect(bumps['pkgA'].toString(), '1.1.0');
      expect(bumps['pkgB'].toString(), '1.0.1');
    });
  });
}
