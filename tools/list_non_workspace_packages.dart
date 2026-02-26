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

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Lists directories containing pubspec.yaml files that are NOT listed in the
/// root workspace configuration.
void main() {
  final rootPubspecFile = File('pubspec.yaml');
  if (!rootPubspecFile.existsSync()) {
    stderr.writeln('Error: Could not find pubspec.yaml in current directory.');
    exitCode = 1;
    return;
  }

  final String rootPubspecContent;
  try {
    rootPubspecContent = rootPubspecFile.readAsStringSync();
  } catch (e) {
    stderr.writeln('Error reading pubspec.yaml: $e');
    exitCode = 1;
    return;
  }

  final workspaceMembers = _getWorkspaceMembers(rootPubspecContent);

  final gitResult = Process.runSync('git', [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
    '**/pubspec.yaml',
  ]);

  if (gitResult.exitCode != 0) {
    stderr.writeln('Error running git ls-files: ${gitResult.stderr}');
    exitCode = 1;
    return;
  }

  final allPubspecs = (gitResult.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && line != 'pubspec.yaml')
      .toList();

  final nonWorkspacePackages = allPubspecs
      .where((pubspecPath) {
        final dir = p.dirname(pubspecPath);
        return !workspaceMembers.contains(dir);
      })
      .map(p.dirname)
      .toList();

  for (final pkg in nonWorkspacePackages) {
    print(pkg);
  }
}

List<String> _getWorkspaceMembers(String content) {
  final yaml = loadYaml(content);
  if (yaml is! Map) return const [];

  final workspace = yaml['workspace'];
  if (workspace is! List) return const [];

  return workspace.map((e) => e.toString()).toList();
}
