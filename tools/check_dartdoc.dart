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
  final jsonStart = stdout.indexOf('[');
  if (jsonStart == -1) {
    print('Could not find JSON output in melos list result.');
    print('Output was: $stdout');
    exitCode = 1;
    return;
  }

  final jsonString = stdout.substring(jsonStart);
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
      return targetNames.contains(pkg['name']) ||
          targetPaths.any(
            (targetPath) =>
                pkgPath == targetPath || pkgPath.startsWith(targetPath),
          );
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
    'run',
    '${Platform.environment['HOME']}/github/dartdoc/bin/dartdoc.dart',
    '--output',
    tempDir.path,
    '--json',
  ], workingDirectory: location);

  var hasWarning = false;
  var globalHasWarning = false;

  final stdoutFuture = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line.isEmpty) return;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final level = json['level'] as String?;
          final message = json['message'] as String? ?? '';

          if (level == 'WARNING' || level == 'ERROR') {
            if (message.contains('Found 0 warnings and 0 errors')) {
              return;
            }
            print('[$name] $level: $message');
            hasWarning = true;
            globalHasWarning = true;
          }
        } catch (e) {
          // Not JSON
        }
      })
      .asFuture();

  final stderrFuture = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line.isNotEmpty) {
          print('[$name] STDERR: $line');
          globalHasWarning = true;
        }
      })
      .asFuture();

  final exitCode = await process.exitCode;
  await Future.wait([stdoutFuture, stderrFuture]);

  if (exitCode != 0) {
    print('[$name] dartdoc exited with code $exitCode');
    globalHasWarning = true;
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

  return globalHasWarning;
}
