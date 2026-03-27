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

import 'dart:convert';
import 'dart:io';

/// Geminiu CLI hook to run `dart format` on a specific file or the entire project.
///
/// Expected input on stdin is a JSON object with the structure:
/// {
///   "tool_input": {
///     "args": {
///       "file_path": "path/to/file.dart"
///     }
///   }
/// }
///
/// If no file_path is found, it defaults to formatting the current directory.
void main() async {
  String? filePath;

  try {
    // Read stdin
    final inputString = await stdin.transform(utf8.decoder).join();
    if (inputString.isNotEmpty) {
      final input = jsonDecode(inputString);
      if (input is Map<String, dynamic>) {
        final toolInput = input['tool_input'];
        if (toolInput is Map<String, dynamic>) {
          final args = toolInput['args'];
          if (args is Map<String, dynamic>) {
            final path = args['file_path'];
            if (path is String) {
              filePath = path;
            }
          }
        }
      }
    }
  } catch (e) {
    // Silent failure on parse errors, will fallback to '.'
  }

  final formatPath = (filePath != null && filePath.isNotEmpty) ? filePath : '.';

  // Run dart format
  final result = Process.runSync('dart', ['format', formatPath]);

  // Output results to stderr
  if (result.stdout != null && result.stdout.toString().isNotEmpty) {
    stderr.write(result.stdout);
  }

  if (result.stderr != null && result.stderr.toString().isNotEmpty) {
    stderr.write(result.stderr);
  }

  exit(result.exitCode);
}
