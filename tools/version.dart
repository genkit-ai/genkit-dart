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

import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

enum BumpType {
  none,
  patch,
  minor,
  major;

  bool operator >(BumpType other) => index > other.index;
  bool operator <(BumpType other) => index < other.index;
  bool operator >=(BumpType other) => index >= other.index;
  bool operator <=(BumpType other) => index <= other.index;
}

class ConventionalCommit {
  final String type;
  final bool isBreaking;
  final String message;
  final String? scope;

  ConventionalCommit({
    required this.type,
    required this.isBreaking,
    required this.message,
    this.scope,
  });

  factory ConventionalCommit.parse(String message) {
    // Basic regex for conventional commits
    // e.g., "feat(scope)!: message"
    final regex = RegExp(r'^(\w+)(?:\((.*?)\))?(!?):\s*(.*)');
    final match = regex.firstMatch(message);

    if (match != null) {
      final type = match.group(1)!;
      final scope = match.group(2);
      final isBreaking =
          match.group(3) == '!' || message.contains('BREAKING CHANGE');
      final desc = match.group(4)!;
      return ConventionalCommit(
        type: type,
        isBreaking: isBreaking,
        message: desc,
        scope: scope,
      );
    }

    // Fallback if not matching exactly but contains BREAKING CHANGE
    return ConventionalCommit(
      type: 'chore', // default fallback
      isBreaking: message.contains('BREAKING CHANGE'),
      message: message,
    );
  }

  BumpType get bumpType {
    if (isBreaking) return BumpType.major;
    if (type == 'feat') return BumpType.minor;
    if (type == 'fix' || type == 'perf' || type == 'refactor') {
      return BumpType.patch;
    }
    return BumpType.none;
  }
}

class Package {
  final String name;
  final String path;
  final Version version;
  final bool publishToNone;
  final Map<String, String> dependencies;
  final Map<String, String> devDependencies;
  final String pubspecContent;

  Package({
    required this.name,
    required this.path,
    required this.version,
    required this.publishToNone,
    required this.dependencies,
    required this.devDependencies,
    required this.pubspecContent,
  });

  bool dependsOn(String packageName) {
    return dependencies.containsKey(packageName) ||
        devDependencies.containsKey(packageName);
  }
}

class Workspace {
  final Map<String, Package> packages;

  Workspace(this.packages);

  static Future<Workspace> load(String packagesYamlPath) async {
    final file = File(packagesYamlPath);
    if (!await file.exists()) {
      throw Exception('Could not find $packagesYamlPath');
    }

    final content = await file.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    final packageGlobs = yaml['packages'] as YamlList;

    final loadedPackages = <String, Package>{};
    final rootDir = file.parent.path;

    for (final globStr in packageGlobs) {
      final glob = Glob(p.join(rootDir, globStr.toString()));
      await for (final entity in glob.list()) {
        if (entity is Directory) {
          final pubspecFile = File(p.join(entity.path, 'pubspec.yaml'));
          if (await pubspecFile.exists()) {
            final pubspecContent = await pubspecFile.readAsString();
            final pubspec = loadYaml(pubspecContent) as YamlMap;
            final name = pubspec['name'] as String;
            final versionStr = pubspec['version'] as String?;
            if (versionStr == null) continue; // Skip unversioned packages

            final deps = _parseDeps(pubspec['dependencies']);
            final devDeps = _parseDeps(pubspec['dev_dependencies']);
            final publishToNone = pubspec['publish_to'] == 'none';

            loadedPackages[name] = Package(
              name: name,
              path: entity.path,
              version: Version.parse(versionStr),
              publishToNone: publishToNone,
              dependencies: deps,
              devDependencies: devDeps,
              pubspecContent: pubspecContent,
            );
          }
        }
      }
    }

    return Workspace(loadedPackages);
  }

  static Map<String, String> _parseDeps(dynamic yamlDeps) {
    if (yamlDeps is YamlMap) {
      return yamlDeps.map((key, value) {
        if (value is YamlMap) {
          // It might be a path dependency or something else.
          return MapEntry(key.toString(), value.toString());
        }
        return MapEntry(key.toString(), value?.toString() ?? 'any');
      });
    }
    return {};
  }
}

class GitService {
  Future<String?> getLatestTag(String packageName) async {
    final result = await Process.run('git', [
      'describe',
      '--tags',
      '--match',
      '$packageName-v*',
      '--abbrev=0',
    ]);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return null;
  }

  Future<List<String>> getCommitsSince(String? tag, String path) async {
    final range = tag != null ? '$tag..HEAD' : 'HEAD';
    final result = await Process.run('git', [
      'log',
      range,
      '--format=%s',
      '--',
      path,
    ]);
    if (result.exitCode == 0) {
      final out = result.stdout.toString().trim();
      if (out.isEmpty) return [];
      return out.split('\n');
    }
    return [];
  }
}

class VersionPlanner {
  final Workspace workspace;
  final GitService git;
  final String? rcTag;
  final bool graduate;

  VersionPlanner(this.workspace, this.git, {this.rcTag, this.graduate = false});

  Future<Map<String, Version>> planBumps() async {
    final proposedBumps = <String, Version>{};

    for (final pkg in workspace.packages.values) {
      if (pkg.publishToNone) continue;
      final latestTag = await git.getLatestTag(pkg.name);

      final commitMessages = await git.getCommitsSince(latestTag, pkg.path);
      if (commitMessages.isEmpty && !graduate && rcTag == null) continue;

      var maxBump = BumpType.none;
      for (final msg in commitMessages) {
        final commit = ConventionalCommit.parse(msg);
        if (commit.bumpType > maxBump) {
          maxBump = commit.bumpType;
        }
      }

      if (maxBump == BumpType.none && !graduate && rcTag == null) continue;

      final current = pkg.version;
      var next = current;

      if (graduate) {
        if (!current.isPreRelease) continue;
        next = Version(current.major, current.minor, current.patch);
      } else if (rcTag != null) {
        if (current.isPreRelease &&
            current.preRelease.isNotEmpty &&
            current.preRelease.first == rcTag) {
          final rcNum =
              (current.preRelease.length > 1 && current.preRelease[1] is int)
              ? current.preRelease[1] as int
              : 0;
          next = Version(
            current.major,
            current.minor,
            current.patch,
            pre: '$rcTag.${rcNum + 1}',
          );
        } else {
          next = evaluateBaseBump(
            current,
            maxBump == BumpType.none ? BumpType.patch : maxBump,
          );
          next = Version(next.major, next.minor, next.patch, pre: '$rcTag.1');
        }
      } else {
        if (maxBump == BumpType.none) continue;
        next = evaluateBaseBump(current, maxBump);
      }

      proposedBumps[pkg.name] = next;
    }

    // Propagate downstream bumps
    bool changed;
    do {
      changed = false;
      for (final pkg in workspace.packages.values) {
        if (pkg.publishToNone) continue;
        if (proposedBumps.containsKey(pkg.name)) continue;

        var hasBumpedDep = false;
        final deps = List<String>.from(pkg.dependencies.keys)
          ..addAll(pkg.devDependencies.keys);
        for (final depName in deps) {
          if (proposedBumps.containsKey(depName)) {
            hasBumpedDep = true;
            break;
          }
        }

        if (hasBumpedDep) {
          Version next;
          if (graduate && pkg.version.isPreRelease) {
            next = Version(
              pkg.version.major,
              pkg.version.minor,
              pkg.version.patch,
            );
          } else {
            next = evaluateBaseBump(pkg.version, BumpType.patch);
            if (rcTag != null) {
              if (pkg.version.isPreRelease &&
                  pkg.version.preRelease.isNotEmpty &&
                  pkg.version.preRelease.first == rcTag) {
                final rcNum =
                    (pkg.version.preRelease.length > 1 &&
                        pkg.version.preRelease[1] is int)
                    ? pkg.version.preRelease[1] as int
                    : 0;
                next = Version(
                  pkg.version.major,
                  pkg.version.minor,
                  pkg.version.patch,
                  pre: '$rcTag.${rcNum + 1}',
                );
              } else {
                next = Version(
                  next.major,
                  next.minor,
                  next.patch,
                  pre: '$rcTag.1',
                );
              }
            }
          }
          proposedBumps[pkg.name] = next;
          changed = true;
        }
      }
    } while (changed);

    return proposedBumps;
  }

  Version evaluateBaseBump(Version current, BumpType bump) {
    if (bump == BumpType.none) return current;
    if (current.major == 0) {
      // 0.x.y logic
      if (bump == BumpType.major) return current.nextMinor;
      if (bump == BumpType.minor) return current.nextPatch;
      if (bump == BumpType.patch) return current.nextPatch;
    } else {
      if (bump == BumpType.major) return current.nextMajor;
      if (bump == BumpType.minor) return current.nextMinor;
      if (bump == BumpType.patch) return current.nextPatch;
    }
    return current;
  }
}

class VersionApplier {
  final Workspace workspace;
  final GitService git;

  VersionApplier(this.workspace, this.git);

  Future<Set<String>> apply(Map<String, Version> bumps) async {
    final modifiedPackages = <String>{};

    for (final pkg in workspace.packages.values) {
      final newVersion = bumps[pkg.name];
      bool needsDepUpdate = false;

      for (final depName in bumps.keys) {
        if (pkg.dependsOn(depName)) {
          needsDepUpdate = true;
          break;
        }
      }

      if (newVersion == null && !needsDepUpdate) continue;

      modifiedPackages.add(pkg.name);

      var pubspecContent = pkg.pubspecContent;
      final pubspecFile = File(p.join(pkg.path, 'pubspec.yaml'));

      if (newVersion != null) {
        print('Updating ${pkg.name} to $newVersion...');
        pubspecContent = pubspecContent.replaceAll(
          RegExp(r'^version:\s*.*$', multiLine: true),
          'version: $newVersion',
        );
      } else {
        print('Updating dependencies for ${pkg.name}...');
      }

      if (needsDepUpdate) {
        for (final depBump in bumps.entries) {
          final depName = depBump.key;
          if (pkg.dependsOn(depName)) {
            final depNewVersion = depBump.value;
            final depRegex = RegExp(
              '^(\\s+)$depName:\\s*\\^?[\\d\\.]+.*?\$',
              multiLine: true,
            );
            pubspecContent = pubspecContent.replaceAll(
              depRegex,
              '\$1$depName: ^$depNewVersion',
            );
          }
        }
      }

      await pubspecFile.writeAsString(pubspecContent);

      if (newVersion != null) {
        // Extract commits to build Changelog
        final latestTag = await git.getLatestTag(pkg.name);
        final commitMessages = await git.getCommitsSince(latestTag, pkg.path);
        final changelogEntry = _buildChangelogEntry(newVersion, commitMessages);

        // Write Changelog
        final changelogFile = File(p.join(pkg.path, 'CHANGELOG.md'));
        if (await changelogFile.exists()) {
          final existing = await changelogFile.readAsString();
          await changelogFile.writeAsString('$changelogEntry\n$existing');
        } else {
          await changelogFile.writeAsString(changelogEntry);
        }
      }
    }

    return modifiedPackages;
  }

  String _buildChangelogEntry(Version version, List<String> commitMessages) {
    if (commitMessages.isEmpty) {
      return '## $version\n\n - updated internal dependencies.\n';
    }

    final breaking = <String>[];
    final feats = <String>[];
    final fixes = <String>[];
    final others = <String>[];

    for (final msg in commitMessages) {
      final commit = ConventionalCommit.parse(msg);
      if (commit.isBreaking) {
        breaking.add(commit.message);
      } else if (commit.type == 'feat') {
        feats.add(commit.message);
      } else if (commit.type == 'fix') {
        fixes.add(commit.message);
      } else {
        others.add(commit.message);
      }
    }

    final buf = StringBuffer();
    buf.writeln('## $version\n');

    if (breaking.isNotEmpty) {
      buf.writeln('### Breaking Changes\n');
      for (final msg in breaking) {
        buf.writeln(' - $msg');
      }
      buf.writeln();
    }
    if (feats.isNotEmpty) {
      buf.writeln('### Features\n');
      for (final msg in feats) {
        buf.writeln(' - $msg');
      }
      buf.writeln();
    }
    if (fixes.isNotEmpty) {
      buf.writeln('### Fixes\n');
      for (final msg in fixes) {
        buf.writeln(' - $msg');
      }
      buf.writeln();
    }
    if (others.isNotEmpty &&
        breaking.isEmpty &&
        feats.isEmpty &&
        fixes.isEmpty) {
      for (final msg in others) {
        buf.writeln(' - $msg');
      }
      buf.writeln();
    } else if (others.isNotEmpty) {
      buf.writeln('### Other Changes\n');
      for (final msg in others) {
        buf.writeln(' - $msg');
      }
      buf.writeln();
    }

    return buf.toString();
  }
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'rc',
      help: 'Create an RC release with the given tag (e.g. beta)',
    )
    ..addFlag(
      'graduate',
      abbr: 'g',
      help: 'Graduate RC to a stable release',
      negatable: false,
    )
    ..addFlag(
      'dry-run',
      help: 'Preview changes without applying them',
      negatable: false,
    )
    ..addFlag(
      'commit',
      help: 'Create a commit with the version bumps',
      defaultsTo: true,
    )
    ..addFlag(
      'tags',
      help: 'Create git tags for the bumped versions',
      defaultsTo: true,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Print this usage information',
      negatable: false,
    );

  late final ArgResults parsedArgs;
  try {
    parsedArgs = parser.parse(args);
  } on FormatException catch (e) {
    print(e.message);
    print(parser.usage);
    exit(1);
  }

  if (parsedArgs['help'] == true) {
    print(parser.usage);
    exit(0);
  }

  // Support optionally passing the path to a custom packages.yaml config.
  final configPath = parsedArgs.rest.isNotEmpty
      ? parsedArgs.rest.first
      : 'packages.yaml';

  final workspace = await Workspace.load(configPath);
  print('Loaded ${workspace.packages.length} packages from $configPath.');

  final git = GitService();
  final rcTag = parsedArgs['rc'] as String?;
  final graduate = parsedArgs['graduate'] as bool;
  final planner = VersionPlanner(
    workspace,
    git,
    rcTag: rcTag,
    graduate: graduate,
  );

  final bumps = await planner.planBumps();

  if (bumps.isEmpty) {
    print('No changes found. Nothing to bump.');
    return;
  }

  print('\nProposed Bumps:');
  for (final entry in bumps.entries) {
    final cur = workspace.packages[entry.key]!.version;
    print('  ${entry.key}: $cur -> ${entry.value}');
  }

  if (parsedArgs['dry-run'] == true) {
    print('\n--- Changelog Previews ---');
    final applier = VersionApplier(workspace, git);
    for (final entry in bumps.entries) {
      final pkgName = entry.key;
      final newVersion = entry.value;
      final pkg = workspace.packages[pkgName]!;
      final latestTag = await git.getLatestTag(pkg.name);
      final commitMessages = await git.getCommitsSince(latestTag, pkg.path);
      final changelogEntry = applier._buildChangelogEntry(
        newVersion,
        commitMessages,
      );
      print('\nPackage: $pkgName');
      print(changelogEntry.trimRight());
      print('--------------------------');
    }
    print('\nDry run complete. No files were changed.');
    return;
  }

  // Apply bumps and generate changelog
  final applier = VersionApplier(workspace, git);
  final modifiedPackages = await applier.apply(bumps);

  if (!(parsedArgs['commit'] as bool)) {
    print('\nSkipping git commit due to --no-commit flag.');
    return;
  }

  print('\nCreating git commit...');
  await Process.run('git', [
    'add',
    'packages.yaml',
  ]); // placeholder just ignoring error if any
  for (final pkgName in modifiedPackages) {
    final pkg = workspace.packages[pkgName]!;
    await Process.run('git', ['add', p.join(pkg.path, 'pubspec.yaml')]);
    if (bumps.containsKey(pkgName)) {
      await Process.run('git', ['add', p.join(pkg.path, 'CHANGELOG.md')]);
    }
  }

  final commitResult = await Process.run('git', [
    'commit',
    '-m',
    'chore(release): publish packages',
  ]);
  if (commitResult.exitCode != 0) {
    print('Warning: Failed to create git commit. ${commitResult.stderr}');
    return;
  }

  if (!(parsedArgs['tags'] as bool)) {
    print('\nSkipping git tags due to --no-tags flag.');
    return;
  }
  print('\nCreating git tags...');
  for (final entry in bumps.entries) {
    final pkgName = entry.key;
    final newVersion = entry.value;
    final tagName = '$pkgName-v$newVersion';
    await Process.run('git', ['tag', tagName]);
    print('Created tag $tagName');
  }

  print('Done!');
}
