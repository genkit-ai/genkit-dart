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
