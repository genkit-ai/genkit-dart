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

import 'package:test/test.dart';

void main() {
  test(
    'release build succeeds and generates wasm and js files',
    () async {
      // Run the build_runner command in release mode
      final result = await Process.run('dart', [
        'run',
        'build_runner',
        'build',
        '-r',
        '-o',
        'build',
      ]);

      // Verify the build succeeded
      expect(
        result.exitCode,
        0,
        reason:
            'build_runner failed with exit code ${result.exitCode}\n'
            'stdout: ${result.stdout}\n'
            'stderr: ${result.stderr}',
      );

      // Verify that the generated Wasm and JS files exist
      final jsFile = File('build/web/main.dart.js');
      final wasmFile = File('build/web/main.wasm');

      expect(jsFile.existsSync(), isTrue, reason: 'main.dart.js is missing');
      expect(wasmFile.existsSync(), isTrue, reason: 'main.wasm is missing');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
