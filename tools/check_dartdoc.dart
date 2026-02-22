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

/// A utility script to validate dartdoc generation across packages in the monorepo.
///
/// Usage:
///   dart run tools/check_dartdoc.dart [package_name_or_path ...]
///
/// If no arguments are provided, all non-private packages in the repository
/// will be checked. If arguments are provided, they can be either package
/// names or paths to package directories, and only those matching packages
/// will be checked.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final _isGitHubActions = Platform.environment['GITHUB_ACTIONS'] == 'true';

void _print(
  String message, {
  bool isWarning = false,
  String? file,
  int? line,
  int? col,
}) {
  final locParts = <String>[];
  if (file != null) locParts.add(file);
  if (line != null) locParts.add(line.toString());
  if (col != null) locParts.add(col.toString());
  final suffix = locParts.isEmpty ? '' : ' (${locParts.join(':')})';

  if (_isGitHubActions && isWarning) {
    final props = <String>[];
    if (file != null) props.add('file=$file');
    if (line != null) props.add('line=$line');
    if (col != null) props.add('col=$col');
    final propStr = props.isEmpty ? '' : ' ${props.join(',')}';
    print('::warning$propStr::$message$suffix');
  } else {
    final prefix = isWarning ? '🔶 warning: ' : '';
    print('$prefix$message$suffix');
  }
}

Future<void> main(List<String> args) async {
  // Get list of non-private packages using melos
  final melosResult = await Process.run('melos', [
    'list',
    '--no-private',
    '--json',
  ]);
  if (melosResult.exitCode != 0) {
    print('Error running melos list: ${melosResult.stderr}');
    exitCode = 1;
    return;
  }

  final stdout = melosResult.stdout as String;
  final jsonStartIndex = stdout.indexOf('[');
  final jsonEndIndex = stdout.lastIndexOf(']');
  if (jsonStartIndex == -1 ||
      jsonEndIndex == -1 ||
      jsonEndIndex < jsonStartIndex) {
    print('Could not find JSON output in melos list result.');
    print('Output was: $stdout');
    exitCode = 1;
    return;
  }

  final jsonString = stdout.substring(jsonStartIndex, jsonEndIndex + 1);
  var packages = (jsonDecode(jsonString) as List).cast<Map<String, dynamic>>();

  if (args.isNotEmpty) {
    final targetPaths = args
        .map((arg) => p.canonicalize(Directory(arg).absolute.path))
        .toSet();
    final targetNames = args.toSet();

    packages = packages.where((pkg) {
      final pkgPath = p.canonicalize(
        Directory(pkg['location'] as String).absolute.path,
      );
      return targetNames.contains(pkg['name']) || targetPaths.contains(pkgPath);
    }).toList();

    if (packages.isEmpty) {
      print(
        'No non-private packages found matching provided targets: ${args.join(', ')}',
      );
      exitCode = 1;
      return;
    }
  }

  var globalHasWarning = false;

  for (final package in packages) {
    final name = package['name'] as String;
    final location = package['location'] as String;
    final hasWarning = await _checkPackage(name, location);
    if (hasWarning) {
      globalHasWarning = true;
    }
  }

  if (globalHasWarning) {
    print('\nDocumentation check failed with warnings or errors.');
    exitCode = 1;
    return;
  } else {
    print('\nDocumentation check passed.');
  }
}

Future<bool> _checkPackage(String name, String location) async {
  print('Checking documentation for $name...');

  final tempDir = Directory.systemTemp.createTempSync('dartdoc_$name');

  final process = await Process.start(Platform.executable, [
    'doc',
    '--output',
    tempDir.path,
  ], workingDirectory: location);

  var hasWarning = false;
  var packageHadIssues = false;

  final summaryRegex = RegExp(r'Found (\d+) warning[s]? and (\d+) error[s]?');
  final locationRegex = RegExp(r'from [^:]+: \(file://([^:]+):(\d+):(\d+)\)');

  var inWarningBlock = false;
  String? currentWarningMessage;

  void processLine(String line) {
    if (line.isEmpty) return;

    final trimmed = line.trim();
    if (trimmed.startsWith('warning:') || trimmed.startsWith('error:')) {
      currentWarningMessage = trimmed;
      hasWarning = true;
      packageHadIssues = true;
      inWarningBlock = true;
    } else if (inWarningBlock && trimmed.startsWith('from ')) {
      final match = locationRegex.firstMatch(trimmed);
      if (match != null) {
        final filePath = p.relative(match.group(1)!);
        final lineNum = int.tryParse(match.group(2) ?? '');
        final colNum = int.tryParse(match.group(3) ?? '');

        _print(
          '[$name] ${currentWarningMessage ?? 'warning'}',
          isWarning: true,
          file: filePath,
          line: lineNum,
          col: colNum,
        );
      } else {
        // Fallback if regex fails to match
        _print(
          '[$name] ${currentWarningMessage ?? 'warning'}\n  $trimmed',
          isWarning: true,
        );
      }
      inWarningBlock = false;
      currentWarningMessage = null;
    } else {
      if (inWarningBlock) {
        // Warning block ended without a location line
        _print(
          '[$name] ${currentWarningMessage ?? 'warning'}',
          isWarning: true,
        );
        inWarningBlock = false;
        currentWarningMessage = null;
      }

      final match = summaryRegex.firstMatch(line);
      if (match != null) {
        final warnings = int.parse(match.group(1)!);
        final errors = int.parse(match.group(2)!);
        if (warnings > 0 || errors > 0) {
          hasWarning = true;
          packageHadIssues = true;
        }
      }
    }
  }

  final stdoutFuture = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(processLine)
      .asFuture();

  final stderrFuture = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(processLine)
      .asFuture();

  final exitCode = await process.exitCode;
  await Future.wait([stdoutFuture, stderrFuture]);

  if (exitCode != 0) {
    print('[$name] dartdoc exited with code $exitCode');
    packageHadIssues = true;
  }

  if (!hasWarning && exitCode == 0) {
    print('[$name] No warnings found.');
  }

  // Cleanup temp dir
  try {
    tempDir.deleteSync(recursive: true);
  } catch (e) {
    print('Failed to delete temp dir ${tempDir.path}: $e');
  }

  return packageHadIssues;
}
