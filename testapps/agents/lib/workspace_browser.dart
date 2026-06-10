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

/// Workspace browser flows — expose the coding agent's sandboxed `workspace/`
/// directory over HTTP so the web UI can list and read files.
///
/// Ported from the workspace-browser flows in the JS `coding-agent.ts`.
library;

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:path/path.dart' as p;
import 'package:schemantic/schemantic.dart';

import 'coding_agent.dart' show workspaceDir;
import 'genkit.dart';

part 'workspace_browser.g.dart';

@Schema()
abstract class $WorkspaceFile {
  String get name;
  String get path;

  /// `'file'` or `'directory'`.
  String get type;
  List<$WorkspaceFile>? get children;
}

@Schema()
abstract class $ListWorkspaceFilesOutput {
  List<$WorkspaceFile> get files;
}

@Schema()
abstract class $ReadWorkspaceFileOutput {
  String get path;
  String get content;
}

Future<List<WorkspaceFile>> _walk(String dir, String rootDir) async {
  final d = Directory(dir);
  if (!await d.exists()) return [];

  final result = <WorkspaceFile>[];
  await for (final entity in d.list()) {
    final name = p.basename(entity.path);
    if (name.startsWith('.')) continue;
    final relativePath = p.relative(entity.path, from: rootDir);
    if (entity is Directory) {
      result.add(
        WorkspaceFile(
          name: name,
          path: relativePath,
          type: 'directory',
          children: await _walk(entity.path, rootDir),
        ),
      );
    } else {
      result.add(WorkspaceFile(name: name, path: relativePath, type: 'file'));
    }
  }

  result.sort((a, b) {
    if (a.type != b.type) return a.type == 'directory' ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return result;
}

/// Lists all files and directories in the workspace, recursively.
final listWorkspaceFiles = ai.defineFlow(
  name: 'listWorkspaceFiles',
  outputSchema: ListWorkspaceFilesOutput.$schema,
  fn: (_, _) async =>
      ListWorkspaceFilesOutput(files: await _walk(workspaceDir, workspaceDir)),
);

/// Reads the contents of a single file in the workspace.
final readWorkspaceFile = ai.defineFlow(
  name: 'readWorkspaceFile',
  inputSchema: .string(),
  outputSchema: ReadWorkspaceFileOutput.$schema,
  fn: (filePath, _) async {
    final relative = filePath;
    final fullPath = p.canonicalize(p.join(workspaceDir, relative));
    if (!p.isWithin(workspaceDir, fullPath) && fullPath != workspaceDir) {
      throw GenkitException(
        'Path outside workspace',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    final content = await File(fullPath).readAsString();
    return ReadWorkspaceFileOutput(path: relative, content: content);
  },
);
